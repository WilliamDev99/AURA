package id.aura.aura

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.time.OffsetDateTime

/** Data Flutter yang juga dibaca kode Android. */
object AuraPrefs {
    /** Tempat shared_preferences Flutter menyimpan datanya. */
    const val FLUTTER_PREFS = "FlutterSharedPreferences"
    const val LANGUAGE_KEY = "flutter.aura.language"

    /** ID keluarga, hanya di HP orang tua yang sedang masuk (lihat AppState
     *  di sisi Dart). HP anak dan HP yang sudah keluar tidak menyimpannya. */
    const val ALARM_FAMILY_KEY = "flutter.aura.sos_alarm_family"

    fun alarmFamily(context: Context): String? =
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(ALARM_FAMILY_KEY, null)
}

/**
 * Membunyikan alarm SOS saat SOS datang lewat internet (FCM).
 *
 * Langsung dari pesan FCM-nya, tanpa menunggu Flutter: isolate latar
 * belakang Flutter butuh waktu untuk menyala, dan tidak bisa memulai
 * layanan alarm. Pesan FCM lain tidak disentuh; firebase_messaging tetap
 * menerimanya seperti biasa.
 */
class SosPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getStringExtra("sos") != "true") return
        // Hanya HP orang tua dari keluarga anak itu yang berbunyi.
        val family = AuraPrefs.alarmFamily(context) ?: return
        if (intent.getStringExtra("familyId") != family) return
        try {
            val rang = SosAlarm.start(
                context,
                SosAlarmInfo(
                    childName = intent.getStringExtra("childName").orEmpty(),
                    sosId = SosAlarmInfo.shortId(intent.getStringExtra("alertId")),
                    route = intent.getStringExtra("route")?.takeIf { it.isNotBlank() },
                    at = parseTime(intent.getStringExtra("detectedAt")),
                ),
            )
            if (rang) Log.i(TAG, "SOS diterima: alarm berbunyi.")
        } catch (error: Exception) {
            Log.e(TAG, "Alarm SOS gagal dibunyikan.", error)
        }
    }

    private fun parseTime(value: String?): Long? {
        if (value.isNullOrBlank() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        return try {
            OffsetDateTime.parse(value).toInstant().toEpochMilli()
        } catch (_: Exception) {
            null
        }
    }

    private companion object {
        const val TAG = "AURA"
    }
}

/** Tombol "Matikan alarm" di notifikasi alarm SOS. */
class SosAlarmStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SosAlarm.stop(context)
    }
}
