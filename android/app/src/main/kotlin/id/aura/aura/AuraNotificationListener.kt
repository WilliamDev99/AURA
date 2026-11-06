package id.aura.aura

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Membaca notifikasi pesan masuk di ponsel anak, lalu meneruskannya ke
 * pemindai AURA.
 *
 * Hanya aktif bila anak sendiri menyalakan "Akses notifikasi" untuk AURA di
 * Pengaturan Android, setelah menyetujui perlindungan. Teks diperiksa di
 * ponsel ini; yang dikirim ke orang tua hanya pesan yang terdeteksi
 * berbahaya. Notifikasi dari aplikasi lain di luar daftar diabaikan
 * seluruhnya, tanpa dibaca isinya.
 */
class AuraNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        Log.i(TAG, "Akses notifikasi tersambung")
        // Mesin disiapkan sejak awal supaya pesan pertama tidak menunggu
        // Supabase tersambung.
        runCatching { AuraEngine.reportAccess(this, enabled = true) }
            .onFailure { Log.e(TAG, "Mesin pemindai gagal disiapkan", it) }
    }

    /**
     * Dipanggil saat "Akses notifikasi" untuk AURA dimatikan. Orang tua harus
     * tahu: tanpa akses ini, chat anak tidak lagi dipindai.
     */
    override fun onListenerDisconnected() {
        Log.i(TAG, "Akses notifikasi terputus")
        runCatching { AuraEngine.reportAccess(this, enabled = false) }
            .onFailure { Log.e(TAG, "Status pemindaian gagal dilaporkan", it) }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Pemindai tidak boleh pernah menjatuhkan layanannya sendiri: bila
        // layanan mati, Android tidak selalu menyalakannya kembali.
        try {
            val app = WATCHED[sbn.packageName] ?: return
            val channel = NotificationCompat.getChannelId(sbn.notification)
            if (ChannelFilter.isIgnored(sbn.packageName, channel)) return
            val message = extract(sbn.notification) ?: return

            val key = "${sbn.packageName}|${message.sender}|${message.text}"
            if (!remember(key)) return

            AuraEngine.deliver(
                this,
                mapOf(
                    "app" to app,
                    "text" to message.text,
                    "sender" to message.sender,
                    "postedAt" to sbn.postTime,
                ),
            )
        } catch (error: Throwable) {
            Log.e(TAG, "Notifikasi gagal dipindai", error)
        }
    }

    private data class Extracted(val text: String, val sender: String?)

    private fun extract(notification: Notification): Extracted? {
        val flags = notification.flags
        if (flags and Notification.FLAG_GROUP_SUMMARY != 0) return null
        // Panggilan berlangsung, "Memeriksa pesan baru", dan sejenisnya.
        if (flags and Notification.FLAG_ONGOING_EVENT != 0) return null
        if (notification.category == Notification.CATEGORY_CALL) return null

        // WhatsApp, Telegram, dan Google Messages memakai MessagingStyle:
        // pesan terakhir adalah pesan yang baru saja masuk.
        val style = NotificationCompat.MessagingStyle
            .extractMessagingStyleFromNotification(notification)
        if (style != null) {
            val last = style.messages.lastOrNull() ?: return null
            // Tanpa pengirim berarti pesan yang ditulis anak sendiri.
            val person = last.person ?: return null
            val text = last.text?.toString()?.trim().orEmpty()
            if (text.isEmpty()) return null
            val name = person.name?.toString()
            val group = NotificationText.cleanTitle(style.conversationTitle?.toString())
            val sender = if (style.isGroupConversation && group != null) {
                "${name ?: "Seseorang"} di grup $group"
            } else {
                name
            }
            return Extracted(text, sender)
        }

        val extras = notification.extras
        val title = NotificationText.cleanTitle(
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
        )
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString()?.trim().orEmpty()
        if (text.isEmpty() || SUMMARY.containsMatchIn(text)) return null
        return Extracted(text, title)
    }

    companion object {
        private const val TAG = "AURA"

        /**
         * Aplikasi yang dipindai, beserta nama yang tampil ke orang tua.
         * Aplikasi lain (bank, kalender, game) tidak pernah dibaca.
         */
        private val WATCHED = mapOf(
            "com.whatsapp" to "WhatsApp",
            "com.whatsapp.w4b" to "WhatsApp Business",
            "com.instagram.android" to "Instagram",
            "com.instagram.barcelona" to "Threads",
            "org.telegram.messenger" to "Telegram",
            "org.telegram.messenger.web" to "Telegram",
            "org.thunderdog.challegram" to "Telegram X",
            "com.facebook.orca" to "Messenger",
            "com.facebook.katana" to "Facebook",
            "jp.naver.line.android" to "LINE",
            "com.discord" to "Discord",
            "com.zhiliaoapp.musically" to "TikTok",
            "com.ss.android.ugc.trill" to "TikTok",
            "com.snapchat.android" to "Snapchat",
            "com.twitter.android" to "X",
            // Chat dengan orang asing di dalam game, jalur umum pendekatan
            // pelaku ke anak.
            "com.roblox.client" to "Roblox",
            // Sering disalahgunakan untuk mendekati anak di Indonesia.
            "com.michatapp.im" to "MiChat",
            "com.tencent.mm" to "WeChat",
            "org.thoughtcrime.securesms" to "Signal",
            "com.viber.voip" to "Viber",
            // YouTube sengaja tidak dipantau: notifikasinya kebanyakan video
            // baru, dan judul seperti "cara membunuh boss" akan memicu
            // peringatan palsu. Balasan komentar tidak bisa dipisahkan
            // karena kanal notifikasinya hanya bernomor.
            "com.google.android.apps.messaging" to "SMS",
            "com.samsung.android.messaging" to "SMS",
            "com.android.mms" to "SMS",
        )

        /** Notifikasi ringkasan seperti "3 pesan baru" atau "5 new messages". */
        private val SUMMARY = Regex(
            "^\\d+\\s+(pesan|new messages?|messages?)\\b",
            RegexOption.IGNORE_CASE,
        )

        /**
         * Aplikasi chat sering memasang ulang notifikasi yang sama (misalnya
         * saat pesan berikutnya masuk). Tanpa ini satu pesan bisa memicu
         * beberapa peringatan.
         */
        private val recent = LinkedHashSet<String>()
        private const val RECENT_LIMIT = 300

        private fun remember(key: String): Boolean {
            if (!recent.add(key)) return false
            if (recent.size > RECENT_LIMIT) recent.remove(recent.first())
            return true
        }
    }
}
