package id.aura.aura

/** Merapikan teks notifikasi sebelum diteruskan ke pemindai. */
object NotificationText {
    /**
     * Jumlah pesan yang ditempelkan aplikasi chat ke judul, mis.
     * "LOMBA SIIF (4 pesan)" atau "Keluarga (2 messages)".
     */
    private val MESSAGE_COUNT = Regex(
        "\\s*\\(\\d+\\s+(pesan|pesan baru|new messages?|messages?)\\)\\s*$",
        RegexOption.IGNORE_CASE,
    )

    /**
     * Judul tanpa jumlah pesan. Tanpa ini, nama grup berubah setiap ada pesan
     * baru ("(4 pesan)" menjadi "(5 pesan)"), sehingga pesan yang sama bisa
     * dianggap baru dan peringatannya terkirim dua kali.
     */
    fun cleanTitle(title: String?): String? {
        val cleaned = title?.replace(MESSAGE_COUNT, "")?.trim()
        return if (cleaned.isNullOrEmpty()) null else cleaned
    }
}
