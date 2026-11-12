package id.aura.aura

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log

/** Satu SOS yang membunyikan alarm di HP orang tua. */
data class SosAlarmInfo(
    /** Kosong bila tidak diketahui; tampil sebagai "Anak". */
    val childName: String,
    /** 6 heksadesimal pertama ID peringatan, untuk mengenali SOS yang sama. */
    val sosId: String?,
    /** Rincian peringatan di AURA. */
    val route: String?,
    /** Waktu SOS ditekan, bila diketahui. */
    val at: Long?,
    /** Tombol "Coba bunyikan" di Profil orang tua. */
    val isTest: Boolean = false,
) {
    fun writeTo(intent: Intent): Intent = intent
        .putExtra("childName", childName)
        .putExtra("sosId", sosId)
        .putExtra("route", route)
        .putExtra("at", at ?: 0L)
        .putExtra("test", isTest)

    companion object {
        fun test() = SosAlarmInfo("", null, null, null, isTest = true)

        fun from(intent: Intent) = SosAlarmInfo(
            childName = intent.getStringExtra("childName").orEmpty(),
            sosId = intent.getStringExtra("sosId"),
            route = intent.getStringExtra("route"),
            at = intent.getLongExtra("at", 0L).takeIf { it > 0L },
            isTest = intent.getBooleanExtra("test", false),
        )

        /** ID peringatan (UUID) menjadi ID pendek untuk catatan alarm. */
        fun shortId(alertId: String?): String? =
            alertId?.replace("-", "")?.take(6)?.uppercase()?.takeIf {
                it.length == 6 && it.all { c -> c in '0'..'9' || c in 'A'..'F' }
            }
    }
}

/**
 * Alarm SOS di HP orang tua: sirene dan getar berulang sampai dimatikan.
 *
 * Suaranya diputar [SosAlarmService] sendiri, seperti aplikasi jam alarm,
 * bukan oleh suara notifikasi: Android hanya memutar satu suara notifikasi
 * dalam satu waktu, sehingga notifikasi lain (mis. SMS atau chat WhatsApp
 * yang masuk) dulu langsung membungkam alarm.
 */
object SosAlarm {
    private const val TAG = "AURA"

    /** Tampilan alarm selama berbunyi. Tanpa suara: suaranya dari layanan. */
    const val RINGING_CHANNEL_ID = "aura_sos_ringing"

    /** Cadangan bila layanan tidak boleh dimulai: notifikasi yang bersuara
     *  sendiri. Sama dengan saluran yang dulu dibuat sos_alarm.dart. */
    const val CHANNEL_ID = "aura_sos_alarm"
    const val TAG_FALLBACK = "aura-sos"
    const val ID_FALLBACK = 0

    /** Notifikasi layanan; tidak boleh 0. */
    const val NOTIFICATION_ID = 7110

    val VIBRATION = longArrayOf(0, 800, 400, 800, 400, 800, 400, 800, 400, 800, 1000)

    const val ACTION_OPEN = "id.aura.aura.action.SOS_OPEN"

    private const val COLOR = 0xFFE5484D.toInt()
    private const val HANDLED_PREFS = "aura_sos_alarm"
    private const val HANDLED_KEY = "handled"
    private const val HANDLED_FOR_MS = 24 * 60 * 60 * 1000L

    val audio: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    fun sound(context: Context): Uri =
        Uri.parse("android.resource://${context.packageName}/raw/aura_sos_alarm")

    /** Membunyikan alarm untuk [info]. Dipanggil penerima pesan FCM dan
     *  tombol "Coba bunyikan". False bila SOS ini sudah pernah dibunyikan dan
     *  tidak diulang. */
    fun start(context: Context, info: SosAlarmInfo): Boolean {
        val ringing = SosAlarmService.current
        val id = info.sosId
        if (id != null && ringing?.sosId != id) {
            // FCM sesekali mengantar pesan yang sama dua kali. Yang kedua
            // tidak boleh membunyikan lagi alarm yang sudah dimatikan.
            if (wasHandled(context, id)) {
                Log.i(TAG, "SOS ini sudah dibunyikan sebelumnya; tidak diulang.")
                return false
            }
        }
        if (id != null) markHandled(context, id)

        val intent = info.writeTo(
            Intent(context, SosAlarmService::class.java).setAction(SosAlarmService.ACTION_START),
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (error: Exception) {
            Log.w(TAG, "Layanan alarm tidak bisa dimulai; memakai notifikasi.", error)
            ringWithNotification(context, info)
        }
        return true
    }

    /** Menghentikan alarm, apa pun yang membunyikannya. */
    fun stop(context: Context) {
        context.stopService(Intent(context, SosAlarmService::class.java))
        manager(context).cancel(TAG_FALLBACK, ID_FALLBACK)
    }

    private fun wasHandled(context: Context, id: String): Boolean =
        handled(context).any { it.first == id }

    private fun markHandled(context: Context, id: String) {
        val now = System.currentTimeMillis()
        val kept = handled(context).filter { it.first != id }.takeLast(19) + (id to now)
        context.getSharedPreferences(HANDLED_PREFS, Context.MODE_PRIVATE).edit()
            .putString(HANDLED_KEY, kept.joinToString(",") { "${it.first}@${it.second}" })
            .apply()
    }

    private fun handled(context: Context): List<Pair<String, Long>> {
        val now = System.currentTimeMillis()
        val raw = context.getSharedPreferences(HANDLED_PREFS, Context.MODE_PRIVATE)
            .getString(HANDLED_KEY, "") ?: ""
        return raw.split(',').mapNotNull { entry ->
            val parts = entry.split('@')
            val at = parts.getOrNull(1)?.toLongOrNull() ?: return@mapNotNull null
            if (now - at > HANDLED_FOR_MS) null else parts[0] to at
        }
    }

    // ------------------------------------------------------------ tampilan

    /** Teks alarm dalam bahasa yang dipilih orang tua di AURA. */
    private class Text(context: Context) {
        private val english = context
            .getSharedPreferences(AuraPrefs.FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(AuraPrefs.LANGUAGE_KEY, null) == "en"

        fun pick(id: String, en: String) = if (english) en else id

        val ringingChannel = pick("Alarm SOS berbunyi", "SOS alarm ringing")
        val ringingChannelDescription = pick(
            "Tampil selama alarm SOS berbunyi, dengan tombol untuk mematikannya.",
            "Shown while the SOS alarm rings, with a button to turn it off.",
        )
        val channel = pick("Alarm SOS", "SOS alarm")
        val channelDescription = pick(
            "Berbunyi dan bergetar terus saat anak menekan tombol SOS, sampai Anda mematikannya.",
            "Rings and vibrates nonstop when your child presses the SOS button, until you turn it off.",
        )
        val stop = pick("Matikan alarm", "Turn off alarm")

        private fun name(info: SosAlarmInfo, id: String, en: String) =
            info.childName.takeIf { it.isNotBlank() } ?: pick(id, en)

        fun title(info: SosAlarmInfo) = if (info.isTest) {
            pick("Tes alarm SOS", "SOS alarm test")
        } else {
            pick(
                "Darurat: ${name(info, "Anak", "Your child")} menekan tombol SOS",
                "Emergency: ${name(info, "Anak", "Your child")} pressed the SOS button",
            )
        }

        fun body(info: SosAlarmInfo): String {
            if (info.isTest) {
                return pick(
                    "Begini bunyinya saat anak menekan tombol SOS. Tekan \"Matikan alarm\" untuk berhenti.",
                    "This is how it sounds when your child presses the SOS button. Tap \"Turn off alarm\" to stop it.",
                )
            }
            return when {
                info.route != null -> pick(
                    "Alarm berbunyi sampai Anda mematikannya. Ketuk untuk melihat lokasi " +
                        "${name(info, "anak", "your child")}.",
                    "The alarm rings until you turn it off. Tap to see where " +
                        "${name(info, "anak", "your child")} is.",
                )
                else -> pick(
                    "Alarm berbunyi sampai Anda mematikannya.",
                    "The alarm rings until you turn it off.",
                )
            }
        }
    }

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannels(context: Context, text: Text) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = manager(context)
        if (manager.getNotificationChannel(RINGING_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    RINGING_CHANNEL_ID,
                    text.ringingChannel,
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = text.ringingChannelDescription
                    // Suara dan getar dari layanan, bukan dari notifikasi.
                    setSound(null, null)
                    enableVibration(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                },
            )
        }
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    text.channel,
                    NotificationManager.IMPORTANCE_MAX,
                ).apply {
                    description = text.channelDescription
                    setSound(sound(context), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
                    enableVibration(true)
                    vibrationPattern = VIBRATION
                },
            )
        }
    }

    /** Notifikasi selama layanan alarm berbunyi. */
    fun ringingNotification(context: Context, info: SosAlarmInfo): Notification {
        val text = Text(context)
        ensureChannels(context, text)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, RINGING_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_MAX)
        }
        return decorate(context, builder, info, text)
            .setOnlyAlertOnce(true)
            // Berlatar merah: menonjol di antara notifikasi lain. Hanya
            // berlaku untuk notifikasi layanan latar depan seperti ini.
            .setColorized(true)
            .build()
    }

    /**
     * Cadangan bila Android menolak layanan latar depan: notifikasi yang
     * bersuara dan bergetar berulang sendiri. Bisa terbungkam notifikasi lain,
     * tetapi lebih baik daripada tidak berbunyi sama sekali.
     */
    fun ringWithNotification(context: Context, info: SosAlarmInfo) {
        val text = Text(context)
        ensureChannels(context, text)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
                .setPriority(Notification.PRIORITY_MAX)
                .setSound(sound(context), audio)
                .setVibrate(VIBRATION)
        }
        val notification = decorate(context, builder, info, text).build()
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        manager(context).notify(TAG_FALLBACK, ID_FALLBACK, notification)
    }

    private fun decorate(
        context: Context,
        builder: Notification.Builder,
        info: SosAlarmInfo,
        text: Text,
    ): Notification.Builder {
        val body = text.body(info)
        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(text.title(info))
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_ALARM)
            // "Matikan alarm" harus bisa ditekan tanpa membuka kunci layar;
            // isinya hanya "anak menekan SOS".
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(COLOR)
            .setOngoing(true)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(info.at ?: System.currentTimeMillis())
            .setContentIntent(
                activity(context, ACTION_OPEN, null, 4) { it.putExtra("route", info.route) },
            )
            .addAction(
                action(
                    context,
                    text.stop,
                    PendingIntent.getBroadcast(
                        context,
                        1,
                        Intent(context, SosAlarmStopReceiver::class.java),
                        flags(),
                    ),
                ),
            )
        return builder
    }

    private fun flags() = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT

    private fun action(context: Context, title: String, intent: PendingIntent) =
        Notification.Action.Builder(
            Icon.createWithResource(context, R.mipmap.ic_launcher),
            title,
            intent,
        ).build()

    /** Membuka AURA lewat MainActivity, yang lebih dulu mematikan alarm. */
    private fun activity(
        context: Context,
        action: String,
        data: Uri?,
        requestCode: Int,
        extras: (Intent) -> Intent = { it },
    ) = PendingIntent.getActivity(
        context,
        requestCode,
        extras(
            Intent(context, MainActivity::class.java)
                .setAction(action)
                .setData(data)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        ),
        flags(),
    )
}
