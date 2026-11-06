import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

/** Tingkat risiko sesuai enum di aplikasi Flutter. */
const SEVERITY: Record<string, number> = {
  safe: 0,
  low: 1,
  medium: 2,
  high: 3,
  critical: 4,
};

/**
 * Mengirim notifikasi ke perangkat orang tua saat peringatan baru muncul.
 *
 * Jalur ini berjalan di server, bukan di perangkat anak, karena peringatan
 * harus tetap sampai meskipun aplikasi di ponsel anak ditutup atau ponselnya
 * dimatikan sesaat setelah pesan masuk.
 */
export const onAlertCreated = onDocumentCreated(
  {
    document: "families/{familyId}/alerts/{alertId}",
    region: "asia-southeast2",
  },
  async (event) => {
    const alert = event.data?.data();
    if (!alert) return;

    const { familyId } = event.params;
    const severity = SEVERITY[alert.riskLevel as string] ?? 0;

    // Risiko rendah tidak mengganggu orang tua; tetap tercatat di dashboard.
    if (severity < SEVERITY.medium) {
      logger.info("Peringatan risiko rendah, notifikasi dilewati", {
        familyId,
        riskLevel: alert.riskLevel,
      });
      return;
    }

    const db = getFirestore();
    const parents = await db
      .collection("users")
      .where("familyId", "==", familyId)
      .where("role", "==", "parent")
      .get();

    const tokens = parents.docs
      .flatMap((doc) => (doc.data().fcmTokens as string[] | undefined) ?? [])
      .filter(Boolean);

    if (tokens.length === 0) {
      logger.warn("Tidak ada perangkat orang tua terdaftar", { familyId });
      return;
    }

    const critical = severity >= SEVERITY.critical;
    const childName = (alert.childName as string) ?? "Anak";
    const title = critical
      ? `Darurat: ${childName} butuh bantuan`
      : `Peringatan: ada yang perlu Anda lihat`;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body: (alert.summary as string) ?? "Buka AURA untuk melihat rincian.",
      },
      data: {
        alertId: event.params.alertId,
        familyId,
        riskLevel: String(alert.riskLevel),
        route: `/orangtua/peringatan/${event.params.alertId}`,
      },
      android: {
        priority: "high",
        notification: {
          // Saluran dibuat di sisi aplikasi (lihat lib/core/services/
          // push_service.dart). Menembus mode Jangan Ganggu tidak bisa
          // dipaksa dari server: orang tua harus memberi izin itu sendiri
          // di pengaturan Android.
          channelId: critical ? "aura_critical" : "aura_alerts",
          sound: critical ? "emergency" : "default",
          defaultVibrateTimings: !critical,
          visibility: "private",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: critical ? "emergency.caf" : "default",
            "interruption-level": critical ? "critical" : "time-sensitive",
          },
        },
      },
    });

    // Token yang sudah tidak berlaku dibersihkan agar pengiriman berikutnya
    // tidak terus menerus gagal.
    const stale: string[] = [];
    response.responses.forEach((result, index) => {
      const code = result.error?.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push(tokens[index]);
      }
    });

    if (stale.length > 0) {
      const { FieldValue } = await import("firebase-admin/firestore");
      await Promise.all(
        parents.docs.map((doc) =>
          doc.ref.update({ fcmTokens: FieldValue.arrayRemove(...stale) }),
        ),
      );
    }

    logger.info("Notifikasi peringatan terkirim", {
      familyId,
      berhasil: response.successCount,
      gagal: response.failureCount,
      tokenDibersihkan: stale.length,
    });
  },
);
