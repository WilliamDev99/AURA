package id.aura.aura

/**
 * Kanal notifikasi yang tidak dipindai, per aplikasi.
 *
 * TikTok dan Instagram juga mengirim notifikasi video baru, rekomendasi,
 * siaran live, dan like. Teksnya berupa judul atau caption konten umum,
 * bukan pesan untuk anak, dan kata seperti "anjir" di caption akan memicu
 * peringatan palsu ke orang tua.
 *
 * Sengaja berupa daftar yang DIABAIKAN, bukan daftar yang dibaca: kanal yang
 * belum dikenal tetap dipindai, termasuk kanal baru setelah aplikasi
 * diperbarui dan kanal pihak ketiga seperti "Heytap PUSH" di ponsel
 * realme/OPPO yang bisa membawa DM. Pesan berbahaya yang terlewat lebih buruk
 * daripada satu peringatan palsu.
 */
object ChannelFilter {
    /** Video baru, rekomendasi, live, like ("digg"), pengikut, unggahan, panggilan. */
    private val TIKTOK = Regex(
        "new_video|recommend|live|digg|follow|publish|telecom",
        RegexOption.IGNORE_CASE,
    )

    private val IGNORED = mapOf(
        "com.instagram.android" to Regex(
            // Like, pengikut baru, pengumuman, statistik, dan status unggahan.
            // Dicocokkan utuh: "ig_likes_and_comments_on_photos_of_you" berisi
            // komentar untuk anak dan harus tetap dipindai.
            "^(ig_likes|ig_comment_likes|ig_new_followers|" +
                "ig_private_user_follow_request|ig_friends_on_instagram|" +
                "ig_product_announcements|ig_first_posts_and_stories|" +
                "ig_view_counts|ig_posting_status|uploads|ig_support_requests|" +
                "ig_heads_up_reminders\\w*)$" +
                // Video, siaran live, rekomendasi, belanja, dan sorotan.
                "|igtv|live|recommend|shopping|highlights",
            RegexOption.IGNORE_CASE,
        ),
        "com.zhiliaoapp.musically" to TIKTOK,
        "com.ss.android.ugc.trill" to TIKTOK,
    )

    fun isIgnored(packageName: String, channelId: String?): Boolean {
        if (channelId == null) return false
        return IGNORED[packageName]?.containsMatchIn(channelId) == true
    }
}
