import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { z } from "zod";

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

/**
 * Model yang dipakai untuk analisis.
 *
 * Classifier ini berjalan pada setiap pesan yang lolos saringan lokal, jadi
 * volumenya tinggi. `claude-opus-5-5` dipakai sebagai bawaan karena paling
 * akurat; bila biaya menjadi masalah, ganti ke `claude-haiku-5-5` dan ukur
 * ulang akurasinya dengan berkas uji di `test/threat_analyzer_test.dart`.
 */
const MODEL = "claude-opus-5-5";

const AssessmentSchema = z.object({
  risk_level: z.enum(["safe", "low", "medium", "high", "critical"]),
  categories: z.array(
    z.enum([
      "grooming",
      "sextortion",
      "cyberbullying",
      "violence",
      "selfHarm",
      "personalData",
      "meetup",
      "financial",
      "profanity",
      "substance",
    ]),
  ),
  confidence: z.number().min(0).max(1),
  summary_id: z
    .string()
    .describe("Ringkasan satu kalimat dalam Bahasa Indonesia untuk orang tua."),
  excerpt: z
    .string()
    .describe(
      "Potongan terpendek dari pesan yang memicu penilaian. Kosongkan bila aman.",
    ),
  child_advice_id: z
    .string()
    .describe(
      "Satu kalimat menenangkan dalam Bahasa Indonesia untuk anak. Kosongkan bila aman.",
    ),
});

const SYSTEM_PROMPT = `Kamu adalah penilai risiko untuk aplikasi perlindungan anak di Indonesia.

Tugasmu: menilai satu percakapan yang diterima anak di bawah umur, lalu
mengklasifikasikan risikonya. Keluaranmu dibaca orang tua yang sedang cemas,
jadi ringkasanmu harus tenang, faktual, dan tidak dramatis.

Pedoman penilaian:
- Fokus pada niat lawan bicara terhadap anak, bukan pada kata kasar semata.
- Permintaan merahasiakan sesuatu dari orang tua adalah penanda grooming yang
  kuat, meskipun kalimatnya terdengar ramah.
- Permintaan atau ancaman terkait foto/video intim anak selalu "critical".
- Ungkapan ingin mati atau menyakiti diri sendiri selalu "critical" dengan
  kategori selfHarm, sekalipun disampaikan sambil bercanda.
- Candaan antar teman sebaya dengan kata kasar biasanya "low", bukan "high".
  Jangan mengubah keluarga menjadi panik karena anak bercanda dengan temannya.
- Bahasa gaul, singkatan, dan campuran bahasa daerah itu normal; nilai maknanya,
  bukan kesopanan bahasanya.
- Bila ragu antara dua tingkat, pilih yang lebih rendah dan turunkan confidence.
  Peringatan palsu yang terlalu sering membuat orang tua berhenti memperhatikan.

Kutipan (excerpt) harus sependek mungkin: hanya bagian yang memicu penilaian,
bukan seluruh percakapan. Privasi anak tetap dijaga walau ada ancaman.`;

/**
 * Analisis lapis kedua untuk pesan yang ambigu.
 *
 * Lapis pertama adalah pemindai berbasis aturan yang berjalan di perangkat
 * (`lib/domain/services/threat_analyzer.dart`). Fungsi ini hanya dipanggil
 * untuk kasus yang tidak jelas, sehingga sebagian besar percakapan anak tidak
 * pernah meninggalkan ponselnya.
 */
export const analyzeMessage = onCall(
  {
    region: "asia-southeast2",
    secrets: [anthropicApiKey],
    enforceAppCheck: false,
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Perlu masuk terlebih dahulu.");
    }

    const text = String(request.data?.text ?? "").trim();
    const platform = String(request.data?.platform ?? "tidak diketahui");
    const childAge = Number(request.data?.childAge ?? 0) || null;

    if (!text) {
      throw new HttpsError("invalid-argument", "Teks pesan kosong.");
    }
    if (text.length > 8000) {
      throw new HttpsError("invalid-argument", "Teks pesan terlalu panjang.");
    }

    const client = new Anthropic({ apiKey: anthropicApiKey.value() });

    try {
      const response = await client.messages.parse({
        model: MODEL,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        output_config: {
          format: zodOutputFormat(AssessmentSchema),
          // Klasifikasi pendek tidak butuh penalaran dalam; effort rendah
          // menekan biaya dan latensi tanpa mengurangi akurasi di tugas ini.
          effort: "low",
        },
        messages: [
          {
            role: "user",
            content: [
              `Aplikasi: ${platform}`,
              childAge ? `Usia anak: ${childAge} tahun` : null,
              "",
              "Percakapan yang diterima anak:",
              "---",
              text,
              "---",
            ]
              .filter((line) => line !== null)
              .join("\n"),
          },
        ],
      });

      // Classifier dapat menolak permintaan; jangan baca hasilnya begitu saja.
      if (response.stop_reason === "refusal") {
        logger.warn("Analisis ditolak oleh classifier", {
          category: response.stop_details?.category,
        });
        throw new HttpsError(
          "unavailable",
          "Analisis lanjutan tidak tersedia untuk pesan ini.",
        );
      }

      const parsed = response.parsed_output;
      if (!parsed) {
        throw new HttpsError("internal", "Hasil analisis tidak terbaca.");
      }

      return {
        riskLevel: parsed.risk_level,
        categories: parsed.categories,
        confidence: parsed.confidence,
        summary: parsed.summary_id,
        excerpt: parsed.excerpt,
        childAdvice: parsed.child_advice_id,
        model: MODEL,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Analisis gagal", error);
      // Perangkat tetap memakai hasil pemindai lokal bila lapis ini gagal.
      throw new HttpsError("internal", "Analisis lanjutan gagal dijalankan.");
    }
  },
);
