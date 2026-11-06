"""Skrip sekali pakai: Gemma 4 di Cloudflare untuk semua umur. Dihapus setelah dipakai."""
import io


def patch_file(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:70], s.count(old))
        s = s.replace(old, new, 1)
    io.open(path, 'w', encoding='utf-8').write(s)


fn = 'supabase/functions/aura-chat/index.ts'
s = io.open(fn, encoding='utf-8').read()

# --- Kepala berkas dan konfigurasi -------------------------------------------
head_end = s.index("const OPENAI_KEY = ")
s = """// =============================================================================
// aura-chat
//
// Balasan obrolan Aura memakai AI. Dipanggil ponsel anak lewat
// supabase.functions.invoke('aura-chat').
//
// Penyedia (rahasia AURA_AI_PROVIDER):
//   cloudflare (bawaan) - Gemma 4 buatan Google DeepMind di Cloudflare
//                         Workers AI. Gratis dengan kuota harian, isi obrolan
//                         tidak dipakai melatih AI, dan Gemma 4 berlisensi
//                         Apache 2.0 tanpa batas umur. Untuk semua umur.
//                         Rahasia: CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN,
//                         opsional CLOUDFLARE_MODEL.
//   openai              - ChatGPT. Khusus anak 13+, sesuai panduan OpenAI.
//                         Rahasia: OPENAI_API_KEY, opsional OPENAI_MODEL.
//
// Pengaman, apa pun penyedianya:
// - hanya profil anak yang tertaut keluarga dan sudah menyetujui;
// - pesan berbahaya tidak pernah sampai ke sini: ponsel anak menanganinya
//   sendiri dan memberi tahu orang tua;
// - balasan AI disaring (Llama Guard / OpenAI Moderation) sebelum ke anak;
// - isi obrolan tidak pernah ditulis ke log.
// Kunci API hanya ada di sini, tidak pernah di dalam aplikasi.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const PROVIDER = Deno.env.get("AURA_AI_PROVIDER") ?? "cloudflare";
const MAX_LENGTH = 1000;
const MAX_HISTORY = 10;

const CF_ACCOUNT = Deno.env.get("CLOUDFLARE_ACCOUNT_ID") ?? "";
const CF_TOKEN = Deno.env.get("CLOUDFLARE_API_TOKEN") ?? "";
const CF_MODEL = Deno.env.get("CLOUDFLARE_MODEL") ??
  "@cf/google/gemma-4-26b-a4b-it";
const CF_GUARD = "@cf/meta/llama-guard-3-8b";

/**
 * Batas waktu satu panggilan ke AI. Ponsel menunggu sedikit lebih lama dari
 * ini; lewat dari itu Aura lokal yang menjawab.
 */
const AI_TIMEOUT_MS = 18_000;

""" + s[head_end:]

# --- Pemanggil Cloudflare: kembalikan status, batasi waktu -------------------------
start = s.index("async function cloudflareRun(")
end = s.index("/** Workers AI memakai dua bentuk jawaban")
s = s[:start] + """type CloudflareResult = { status: number; result: unknown };

async function cloudflareRun(
  model: string,
  body: unknown,
): Promise<CloudflareResult> {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/ai/run/${model}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${CF_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(AI_TIMEOUT_MS),
    },
  );
  if (!response.ok) {
    // 401/403: token salah. 404/400: model atau parameter tidak dikenal.
    // 429: kuota gratis harian habis.
    console.error(`AURA: Cloudflare ${model} ${response.status}.`);
    return { status: response.status, result: null };
  }
  const data = await response.json();
  return { status: response.status, result: data?.result ?? null };
}

""" + s[end:]

start = s.index("async function generateCloudflare(")
end = s.index("async function safeCloudflare(")
s = s[:start] + """async function generateCloudflare(messages: ChatMessage[]): Promise<Generated> {
  const isQwen = CF_MODEL.includes("qwen");
  const [system, ...rest] = messages;
  const body: Record<string, unknown> = {
    // "/no_think" mematikan mode berpikir pada model Qwen.
    messages: isQwen
      ? [{ ...system, content: `${system.content}\\n/no_think` }, ...rest]
      : messages,
    max_tokens: 1500,
    // Obrolan santai tidak butuh mode berpikir: tanpa itu jawaban lebih cepat
    // dan kuota lebih hemat. Qwen3.8 dulu berpikir 20 detik lalu kehabisan
    // jatah token sebelum sempat menjawab.
    chat_template_kwargs: { enable_thinking: false },
  };
  if (isQwen) body.reasoning_effort = "low";

  let attempt = await cloudflareRun(CF_MODEL, body);
  // Bila model tidak mengenal pengaturan mode berpikir, coba sekali lagi
  // tanpa pengaturan itu.
  if (attempt.status === 400) {
    delete body.chat_template_kwargs;
    delete body.reasoning_effort;
    attempt = await cloudflareRun(CF_MODEL, body);
  }
  const text = cloudflareText(attempt.result);
  return text ? { text } : null;
}

""" + s[end:]

s = s.replace("""  const result = await cloudflareRun(CF_GUARD, {
    messages: [
      { role: "user", content: child },
      { role: "assistant", content: reply },
    ],
    response_format: { type: "json_object" },
  }) as { response?: unknown } | null;
  const verdict = result?.response;""", """  const { result } = await cloudflareRun(CF_GUARD, {
    messages: [
      { role: "user", content: child },
      { role: "assistant", content: reply },
    ],
    response_format: { type: "json_object" },
  });
  const verdict = (result as { response?: unknown } | null)?.response;""", 1)
assert "const { result } = await cloudflareRun(CF_GUARD" in s

s = s.replace("""async function openai(path: string, body: unknown): Promise<Response> {
  return await fetch(`https://api.openai.com/v1/${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENAI_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}""", """async function openai(path: string, body: unknown): Promise<Response> {
  return await fetch(`https://api.openai.com/v1/${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENAI_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(AI_TIMEOUT_MS),
  });
}""", 1)
assert "signal: AbortSignal.timeout(AI_TIMEOUT_MS),\n  });\n}" in s
io.open(fn, 'w', encoding='utf-8').write(s)

# --- Aplikasi: AI untuk semua umur ----------------------------------------------
patch_file('lib/state/app_state.dart', [
    ("""  /// Umur minimum obrolan dengan ChatGPT. Di bawah ini Aura lokal yang
  /// menjawab: OpenAI mensyaratkan Zero Data Retention untuk anak di bawah
  /// 13 tahun. Server memeriksa batas yang sama.
  static const aiChatMinAge = 13;

""", ""),
    ("""  ///
  /// Mati secara bawaan: keputusan pemilik AURA adalah memakai Aura lokal
  /// untuk semua umur dulu, karena API ChatGPT berbayar. Nyalakan dengan
  /// `--dart-define=AURA_AI_CHAT=true` setelah `OPENAI_API_KEY` dipasang di
  /// Supabase.
  static const aiChatEnabled = bool.fromEnvironment('AURA_AI_CHAT');""",
     """  ///
  /// Penyedia AI dan batas umurnya ditentukan server (lihat
  /// `supabase/functions/aura-chat`): Gemma 4 di Cloudflare untuk semua umur,
  /// atau ChatGPT khusus 13+. Bila server menolak atau AI tidak tersedia,
  /// Aura lokal yang menjawab.
  static const aiChatEnabled = bool.fromEnvironment(
    'AURA_AI_CHAT',
    defaultValue: true,
  );"""),
    ("""  /// Apakah obrolan anak ini dibalas ChatGPT.
  bool get usesAiChat =>
      aiChat &&
      (_user?.isChild ?? false) &&
      (_user?.age ?? 0) >= aiChatMinAge;""",
     """  /// Apakah obrolan anak ini dibalas AI.
  bool get usesAiChat => aiChat && (_user?.isChild ?? false);"""),
    ("""          // AI kadang perlu beberapa detik; lebih dari ini Aura lokal menjawab.
          .timeout(const Duration(seconds: 25), onTimeout: () => null);""",
     """          // Server berhenti menunggu AI setelah 18 detik; sisanya untuk
          // perjalanan jaringan. Lewat dari ini Aura lokal yang menjawab.
          .timeout(const Duration(seconds: 22), onTimeout: () => null);"""),
])

patch_file('lib/features/child/guardian_chat_page.dart', [
    ("""                  ? 'Aura dibantu AI (ChatGPT). Jangan bagikan data '
                        'pribadi. Orang tuamu hanya diberi tahu kalau kamu '
                        'dalam bahaya.'""",
     """                  ? 'Aura dibantu AI. Jangan bagikan data pribadi. Orang '
                        'tuamu hanya diberi tahu kalau kamu dalam bahaya.'"""),
])

patch_file('lib/features/child/child_consent_page.dart', [
    ("""  /// Hanya ditampilkan ke anak 13 tahun ke atas, yang obrolannya dibalas
  /// ChatGPT. Anak yang lebih muda memakai Aura lokal di ponsel.
  static const _aiItem = (
    Icons.smart_toy_rounded,
    'Membalas obrolanmu dengan Aura memakai ChatGPT',
    'Pesan yang kamu tulis ke Aura dikirim ke ChatGPT (OpenAI) supaya Aura '
        'bisa menjawab. Pesan yang berbahaya tidak dikirim ke sana; orang '
        'tuamu yang diberi tahu.',
  );""",
     """  /// Ditampilkan bila obrolan dengan Aura dibalas AI.
  static const _aiItem = (
    Icons.smart_toy_rounded,
    'Membalas obrolanmu dengan Aura memakai AI',
    'Pesan yang kamu tulis ke Aura dikirim ke layanan AI supaya Aura bisa '
        'menjawab, dan tidak dipakai untuk melatih AI. Pesan yang berbahaya '
        'tidak dikirim ke sana; orang tuamu yang diberi tahu.',
  );"""),
])

# --- Test -------------------------------------------------------------------------
patch_file('test/ai_chat_test.dart', [
    ("""  test('anak 10 tahun memakai Aura lokal, tidak dikirim ke ChatGPT', () async {
    final repo = _FakeChatGpt();
    final state = await childAged(10, repo);

    final reply = await state.sendToGuardian('aku kalah terus main ml');

    expect(state.usesAiChat, isFalse);
    expect(repo.sent, isEmpty);
    expect(reply.text, contains('Kalah terus'));
  });""",
     """  test('anak 10 tahun juga dibalas AI (Gemma 4, semua umur)', () async {
    final repo = _FakeChatGpt();
    final state = await childAged(10, repo);

    final reply = await state.sendToGuardian('aku kalah terus main ml');

    expect(state.usesAiChat, isTrue);
    expect(repo.sent, ['aku kalah terus main ml']);
    expect(reply.text, 'Balasan dari ChatGPT');
  });"""),
])
s = io.open('test/ai_chat_test.dart', encoding='utf-8').read()
start = s.index("  test('bawaan: ChatGPT mati, anak 15 tahun pun memakai Aura lokal'")
end = s.index("  });\n", start) + len("  });\n")
s = s[:start] + """  test('bawaan: obrolan AI menyala untuk semua anak', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeChatGpt();
    final state = AppState(repository: repo);
    addTearDown(state.dispose);
    await state.signIn(name: 'Rani', role: UserRole.child, age: 9);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await state.sendToGuardian('halo');

    expect(AppState.aiChatEnabled, isTrue);
    expect(state.usesAiChat, isTrue);
    expect(repo.sent, ['halo']);
  });
""" + s[end:]
io.open('test/ai_chat_test.dart', 'w', encoding='utf-8').write(s)

# --- README -----------------------------------------------------------------------
p = 'README.md'
s = io.open(p, encoding='utf-8').read()
start = s.index("### Obrolan Aura dengan AI")
end = s.index("### Peta lokasi anak")
s = s[:start] + """### Obrolan Aura dengan AI

Obrolan biasa dibalas **Gemma 4** (`@cf/google/gemma-4-26b-a4b-it`, buatan
Google DeepMind) di **Cloudflare Workers AI** lewat Edge Function
[aura-chat](supabase/functions/aura-chat/index.ts). Gratis dengan kuota
harian akun Cloudflare (dibagi semua anak), isi obrolan tidak dipakai melatih
AI, dan Gemma 4 berlisensi Apache 2.0 tanpa batas umur, jadi untuk semua umur.
Bila kuota habis, internet mati, AI lebih lambat dari 18 detik, atau balasan
ditahan penyaring, Aura lokal
([guardian_dialogue.dart](lib/domain/services/guardian_dialogue.dart)) yang
menjawab.

- Pesan berbahaya tidak pernah dikirim ke AI: ponsel menanganinya sendiri
  dan memberi tahu orang tua.
- Balasan AI disaring Llama Guard 3 sebelum sampai ke anak.
- Anak diberi tahu di layar persetujuan dan di halaman obrolan bahwa Aura
  dibantu AI.

Pemasangan, di **Edge Functions → Secrets**: `CLOUDFLARE_ACCOUNT_ID` dan
`CLOUDFLARE_API_TOKEN` (izin *Workers AI*), lalu deploy `aura-chat`. Model bisa
diganti lewat `CLOUDFLARE_MODEL` tanpa memasang ulang aplikasi. Matikan dari
aplikasi dengan `--dart-define=AURA_AI_CHAT=false`.

ChatGPT juga didukung (`AURA_AI_PROVIDER=openai`, `OPENAI_API_KEY`), tetapi
berbayar dan khusus anak 13+: OpenAI mensyaratkan *Zero Data Retention* untuk
anak di bawah 13. Jangan memakai Gemini API: syaratnya melarang aplikasi yang
ditujukan atau kemungkinan diakses pengguna di bawah 18 tahun.

""" + s[end:]
io.open(p, 'w', encoding='utf-8').write(s)
print('ok')
