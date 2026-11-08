package id.aura.aura

/**
 * Mencari baris "Panggilan suara" WhatsApp milik orang tua di Kontak Android.
 *
 * WhatsApp tidak punya cara resmi bagi aplikasi lain untuk memulai panggilan.
 * Yang bisa dipakai hanyalah baris yang WhatsApp sendiri tambahkan ke setiap
 * kontak yang terdaftar di WhatsApp: membuka baris itu langsung menelepon.
 * Karena itu nomor orang tua harus tersimpan di Kontak perangkat anak.
 */
object WhatsAppContact {
    /** Paket WhatsApp yang dikenali, beserta jenis baris panggilan suaranya. */
    val callMimeTypes: Map<String, String> = linkedMapOf(
        "com.whatsapp" to "vnd.android.cursor.item/vnd.com.whatsapp.voip.call",
        "com.whatsapp.w4b" to "vnd.android.cursor.item/vnd.com.whatsapp.w4b.voip.call",
    )

    /**
     * Apakah baris kontak ini milik [digits] (mis. `6281234567890`).
     *
     * [data1] biasanya ID WhatsApp, `6281234567890@s.whatsapp.net`. [data3]
     * adalah labelnya, mis. "Panggilan suara +62 812-3456-7890", dipakai
     * sebagai cadangan bila bentuk ID berubah di versi WhatsApp lain.
     */
    fun matches(data1: String?, data3: String?, digits: String): Boolean {
        if (digits.isBlank()) return false
        val id = data1?.takeIf { it.endsWith("@s.whatsapp.net") }
        if (id != null && internationalDigits(id.substringBefore('@')) == digits) {
            return true
        }
        return data3 != null && internationalDigits(data3) == digits
    }

    /** Hanya angkanya, dengan awalan 0 lokal diganti kode negara 62. */
    private fun internationalDigits(text: String): String {
        val only = text.filter(Char::isDigit)
        return if (only.startsWith("0")) "62" + only.drop(1) else only
    }
}
