// =============================================================================
// notify-parents
//
// Dipicu oleh Database Webhook Supabase setiap ada baris baru di tabel
// `alerts`, lalu meneruskannya sebagai notifikasi ke perangkat orang tua.
//
// Kenapa masih lewat Firebase? Supabase tidak punya layanan push, dan FCM
// adalah satu-satunya jalan resmi mengirim notifikasi ke perangkat Android.
// Kabar baiknya, FCM gratis dan tidak menuntut paket berbayar: yang menuntut
// kartu adalah Cloud Functions, dan fungsi ini menggantikannya.
//
// Menjalankan: lihat README bagian "Notifikasi push". Rahasia yang dibutuhkan:
//   FCM_SERVICE_ACCOUNT  isi berkas JSON service account Firebase
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const SEVERITY: Record<string, number> = {
  safe: 0,
  low: 1,
  medium: 2,
  high: 3,
  critical: 4,
};

/// Bagian peringatan yang menentukan bunyi notifikasi.
interface PushAlert {
  child_name: string | null;
  risk_level: string;
  categories: string[] | null;
  source: string | null;
}

/// Judul notifikasi, dan apakah dibunyikan lewat kanal Darurat.
///
/// Tingkat di aplikasi orang tua: LOW (medium), MEDIUM (high), HARD
/// (critical). "Darurat" dengan bunyi mendesak hanya untuk tombol SOS dan
/// ancaman serius. Kata kasar berat juga HARD, tetapi tidak dibunyikan
/// sebagai darurat.
export function pushMessageFor(
  alert: PushAlert,
): { title: string; urgent: boolean } {
  const child = alert.child_name ?? "Anak";
  const severity = SEVERITY[alert.risk_level] ?? 0;
  const categories = alert.categories ?? [];

  if (alert.source === "panicButton") {
    return { title: `Darurat: ${child} menekan tombol SOS`, urgent: true };
  }
  if (severity >= SEVERITY.critical) {
    const onlyProfanity =
      categories.length > 0 && categories.every((c) => c === "profanity");
    return onlyProfanity
      ? { title: `HARD: ${child} menerima kata kasar berat`, urgent: false }
      : { title: `Darurat: ${child} butuh bantuan`, urgent: true };
  }
  if (severity >= SEVERITY.high) {
    return { title: `MEDIUM: ${child} menerima pesan berisiko`, urgent: false };
  }
  return {
    title: `LOW: ada yang perlu Anda ketahui tentang ${child}`,
    urgent: false,
  };
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/// Menukar kunci service account menjadi access token OAuth2 untuk FCM.
async function accessTokenFor(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (value: unknown) =>
    btoa(JSON.stringify(value))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode(claim)}`;

  // PEM dibersihkan lalu diimpor sebagai kunci PKCS#8 untuk ditandatangani.
  const pem = account.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  const signed = `${unsigned}.${
    btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "")
  }`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signed,
    }),
  });

  if (!response.ok) {
    throw new Error(`Gagal menukar token FCM: ${await response.text()}`);
  }

  const { access_token } = await response.json();
  return access_token as string;
}

Deno.serve(async (request) => {
  try {
    const payload = await request.json();
    const alertId = payload?.record?.id;

    if (!alertId) {
      return new Response("Tidak ada data peringatan.", { status: 400 });
    }

    // Kunci service_role dipakai di sini, bukan di aplikasi: fungsi ini perlu
    // membaca token milik orang tua lain, yang ditutup oleh RLS bagi klien.
    const db = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Isi peringatan dibaca ulang dari basis data, bukan dipercaya dari
    // permintaan. Siapa pun yang tahu alamat fungsi ini tidak bisa mengarang
    // peringatan palsu untuk dikirim ke orang tua.
    const { data: alert, error: alertError } = await db
      .from("alerts")
      .select(
        "id, family_id, child_name, risk_level, summary, categories, source",
      )
      .eq("id", alertId)
      .maybeSingle();

    if (alertError) throw alertError;
    if (!alert) {
      return new Response("Peringatan tidak ditemukan.", { status: 404 });
    }

    const severity = SEVERITY[alert.risk_level] ?? 0;

    // Risiko rendah tidak mengganggu orang tua; tetap tampil di dashboard.
    // Peringatan yang terlalu sering membuat orang tua berhenti memperhatikan.
    if (severity < SEVERITY.medium) {
      return Response.json({ skipped: true, reason: "risiko rendah" });
    }

    const { data: parents, error: parentsError } = await db
      .from("profiles")
      .select("id")
      .eq("family_id", alert.family_id)
      .eq("role", "parent");

    if (parentsError) throw parentsError;
    if (!parents?.length) {
      return Response.json({ sent: 0, reason: "tidak ada orang tua" });
    }

    const { data: devices, error: devicesError } = await db
      .from("device_tokens")
      .select("token, user_id")
      .in("user_id", parents.map((p) => p.id));

    if (devicesError) throw devicesError;
    if (!devices?.length) {
      return Response.json({ sent: 0, reason: "tidak ada perangkat terdaftar" });
    }

    const account: ServiceAccount = JSON.parse(
      Deno.env.get("FCM_SERVICE_ACCOUNT")!,
    );
    const token = await accessTokenFor(account);

    const { title, urgent } = pushMessageFor(alert);

    // FCM v1 mengirim satu per satu; tidak ada lagi endpoint multicast.
    const results = await Promise.all(
      devices.map((device) =>
        fetch(
          `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                // Kolom `token` menyimpan Firebase Installation ID dari
                // FirebaseMessaging.onRegistered; FCM v1 menamainya `fid`.
                fid: device.token,
                notification: {
                  title,
                  body: alert.summary ?? "Buka AURA untuk melihat rincian.",
                },
                data: {
                  alertId: String(alert.id),
                  familyId: String(alert.family_id),
                  riskLevel: String(alert.risk_level),
                  // Aplikasi memakai ini saat AURA sedang terbuka.
                  urgent: String(urgent),
                  route: `/orangtua/peringatan/${alert.id}`,
                },
                android: {
                  priority: "high",
                  notification: {
                    // Saluran dibuat di sisi aplikasi, lihat
                    // lib/core/services/push_service.dart.
                    channel_id: urgent ? "aura_critical" : "aura_alerts",
                    default_vibrate_timings: !urgent,
                    visibility: "PRIVATE",
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                      "interruption-level": urgent
                        ? "critical"
                        : "time-sensitive",
                    },
                  },
                },
              },
            }),
          },
        ),
      ),
    );

    // Hanya perangkat yang dinyatakan FCM sudah tidak terdaftar yang
    // dibersihkan. Dulu status 400 ikut dihapus, padahal 400 juga muncul bila
    // format pesannya yang salah: satu kekeliruan di sini akan menghapus
    // semua perangkat orang tua, dan sejak itu tidak ada lagi yang menerima
    // peringatan.
    const stale: string[] = [];
    await Promise.all(
      results.map(async (result, index) => {
        if (result.ok) return;
        const detail = await result.text();
        console.error(`AURA: FCM menolak (${result.status}): ${detail}`);
        if (result.status === 404 || detail.includes("UNREGISTERED")) {
          stale.push(devices[index].token);
        }
      }),
    );

    if (stale.length > 0) {
      await db.from("device_tokens").delete().in("token", stale);
    }

    const delivered = results.filter((r) => r.ok).length;
    console.log(
      `AURA: ${delivered}/${devices.length} notifikasi terkirim, ` +
        `${stale.length} token dibersihkan.`,
    );

    return Response.json({
      sent: delivered,
      failed: devices.length - delivered,
      cleaned: stale.length,
    });
  } catch (error) {
    console.error("AURA: pengiriman notifikasi gagal.", error);
    return new Response(String(error), { status: 500 });
  }
});
