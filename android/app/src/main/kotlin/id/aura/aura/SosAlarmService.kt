package id.aura.aura

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Memutar alarm SOS sampai orang tua mematikannya, seperti aplikasi jam
 * alarm: sirene lewat volume alarm (tetap berbunyi dalam mode senyap) dan
 * getar berulang.
 *
 * Layanan latar depan, supaya Android tidak menghentikannya di tengah jalan
 * dan notifikasi lain tidak bisa membungkamnya.
 */
class SosAlarmService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var focus: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) {
            stopSelf()
            return START_NOT_STICKY
        }
        // SOS berikutnya selagi alarm berbunyi hanya memperbarui tampilannya:
        // bunyinya tidak diulang dari awal.
        val info = SosAlarmInfo.from(intent)
        val notification = SosAlarm.ringingNotification(this, info)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    SosAlarm.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(SosAlarm.NOTIFICATION_ID, notification)
            }
        } catch (error: Exception) {
            // Android menolak layanan latar depan: tetap bunyikan, lewat
            // notifikasi yang bersuara sendiri.
            Log.w(TAG, "Alarm SOS tidak boleh berjalan sebagai layanan.", error)
            SosAlarm.ringWithNotification(this, info)
            stopSelf()
            return START_NOT_STICKY
        }
        current = info
        startSound()
        startVibration()
        return START_NOT_STICKY
    }

    private fun startSound() {
        if (player != null) return
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Musik atau video yang sedang diputar dijeda selama alarm.
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(SosAlarm.audio)
                .build()
                .also { audio.requestAudioFocus(it) }
        }
        player = try {
            MediaPlayer().apply {
                setAudioAttributes(SosAlarm.audio)
                setDataSource(this@SosAlarmService, SosAlarm.sound(this@SosAlarmService))
                isLooping = true
                setWakeMode(this@SosAlarmService, PowerManager.PARTIAL_WAKE_LOCK)
                prepare()
                start()
            }
        } catch (error: Exception) {
            Log.e(TAG, "Sirene SOS tidak bisa diputar.", error)
            null
        }
    }

    private fun startVibration() {
        if (vibrator != null) return
        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!device.hasVibrator()) return
        vibrator = device
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> device.vibrate(
                VibrationEffect.createWaveform(SosAlarm.VIBRATION, 0),
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> @Suppress("DEPRECATION")
            device.vibrate(VibrationEffect.createWaveform(SosAlarm.VIBRATION, 0), SosAlarm.audio)
            else -> @Suppress("DEPRECATION")
            device.vibrate(SosAlarm.VIBRATION, 0)
        }
    }

    override fun onDestroy() {
        player?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        player = null
        vibrator?.cancel()
        vibrator = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focus?.let { (getSystemService(Context.AUDIO_SERVICE) as AudioManager).abandonAudioFocusRequest(it) }
        }
        focus = null
        current = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "AURA"
        const val ACTION_START = "id.aura.aura.action.SOS_ALARM_START"

        /** SOS yang sedang berbunyi; null bila senyap. Dibaca MainActivity
         *  untuk kartu "Matikan alarm" di layar AURA. */
        @Volatile
        var current: SosAlarmInfo? = null
            private set
    }
}
