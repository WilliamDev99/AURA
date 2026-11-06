package id.aura.aura

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Nama kanal diambil dari ponsel realme sungguhan (TikTok 47.5, Instagram 453). */
class ChannelFilterTest {
    private val tiktok = "com.ss.android.ugc.trill"
    private val instagram = "com.instagram.android"

    @Test
    fun `TikTok - DM, komentar, dan sebutan tetap dipindai`() {
        for (channel in listOf(
            "im_push_associated_4",
            "comment_push_associated_4",
            "mention_push_associated_4",
            "other_channel_associated_4",
            "Heytap PUSH",
        )) {
            assertFalse(channel, ChannelFilter.isIgnored(tiktok, channel))
        }
        // Versi global memakai kanal yang sama.
        assertFalse(ChannelFilter.isIgnored("com.zhiliaoapp.musically", "im_push_associated_4"))
    }

    @Test
    fun `TikTok - video, rekomendasi, live, dan like diabaikan`() {
        for (channel in listOf(
            "follow_new_video_push_associated_4",
            "recommend_video_push_associated_4",
            "live_push_associated_4",
            "video_live_bg_notify",
            "audio_live_notify_associated_2",
            "digg_push_associated_4",
            "follow_push_associated_4",
            "com.ss.android.ugc.trill.publish",
            "tiktok_telecom_incoming_channel_v7",
        )) {
            assertTrue(channel, ChannelFilter.isIgnored(tiktok, channel))
        }
    }

    @Test
    fun `Instagram - DM, permintaan pesan, komentar, dan sebutan tetap dipindai`() {
        for (channel in listOf(
            "ig_direct",
            "ig_direct_requests",
            "DIRECT",
            "ig_heads_up_comments",
            "ig_likes_and_comments_on_photos_of_you",
            "ig_photos_of_you",
            "ig_mentions_in_bio",
            "ig_other",
            "ig_alerts",
        )) {
            assertFalse(channel, ChannelFilter.isIgnored(instagram, channel))
        }
    }

    @Test
    fun `Instagram - like, video, rekomendasi, dan pengumuman diabaikan`() {
        for (channel in listOf(
            "ig_likes",
            "ig_comment_likes",
            "ig_new_followers",
            "ig_igtv_recommended_videos",
            "ig_igtv_video_updates",
            "IGTV",
            "ig_live_videos",
            "ig_product_announcements",
            "ig_shopping_drops",
            "ig_first_posts_and_stories",
            "ig_heads_up_reminders_with_vibrations",
        )) {
            assertTrue(channel, ChannelFilter.isIgnored(instagram, channel))
        }
    }

    @Test
    fun `aplikasi lain dan notifikasi tanpa kanal tidak pernah diabaikan`() {
        assertFalse(ChannelFilter.isIgnored("com.whatsapp", "live_location"))
        assertFalse(ChannelFilter.isIgnored(tiktok, null))
    }
}
