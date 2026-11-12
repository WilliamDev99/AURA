package id.aura.aura

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.util.Log

/**
 * Penjaga cadangan pengunci jam istirahat.
 *
 * Realme dan OPPO mematikan AURA saat anak menekan "Bersihkan semua" di
 * daftar aplikasi terbaru, lalu menahannya hampir satu menit sebelum Android
 * boleh menyalakannya lagi. Selama itu tidak ada yang mengunci.
 *
 * Selama AURA hidup, [ScreenLock] terus menjadwalkan ulang tugas ini beberapa
 * detik ke depan, sehingga tugas ini tidak pernah berjalan. Bila AURA
 * dimatikan, jadwalnya tetap tersimpan di Android: tugas ini berjalan,
 * menghidupkan pengunci, dan meminta Android menyambungkan lagi pemindai
 * notifikasi (yang menjaga AURA tetap hidup).
 */
class LockWatchdog : JobService() {
    private val handler = Handler(Looper.getMainLooper())

    override fun onStartJob(params: JobParameters): Boolean {
        running = true
        Log.i("AURA", "Jam istirahat: AURA dihidupkan lagi oleh penjaga.")
        ScreenLock.start(applicationContext)
        runCatching {
            NotificationListenerService.requestRebind(
                ComponentName(this, AuraNotificationListener::class.java),
            )
        }
        // Tetap berjalan sebentar: selama tugas ini berjalan, Android tidak
        // membekukan AURA, sampai pemindai notifikasi tersambung lagi.
        handler.postDelayed({
            running = false
            jobFinished(params, false)
        }, HOLD_MS)
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        handler.removeCallbacksAndMessages(null)
        running = false
        return false
    }

    companion object {
        private const val JOB_ID = 7120
        private const val HOLD_MS = 30_000L

        /** Selama terkunci, penjaga berjalan paling lambat ±10 detik setelah AURA mati. */
        const val REARM_LOCKED_MS = 3_000L
        private const val DELAY_LOCKED_MS = 6_000L

        /** Di luar jam terkunci cukup lebih jarang. */
        const val REARM_IDLE_MS = 50_000L
        private const val DELAY_IDLE_MS = 90_000L

        /**
         * Penjaga sedang berjalan. Menjadwalkan tugas yang sama saat itu
         * akan menghentikannya sebelum pemindai notifikasi tersambung.
         */
        @Volatile
        private var running = false

        fun arm(context: Context, locked: Boolean) {
            if (running) return
            val delay = if (locked) DELAY_LOCKED_MS else DELAY_IDLE_MS
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, LockWatchdog::class.java))
                .setMinimumLatency(delay)
                .setOverrideDeadline(delay + 4_000)
                .build()
            context.getSystemService(JobScheduler::class.java).schedule(job)
        }

        fun disarm(context: Context) {
            context.getSystemService(JobScheduler::class.java).cancel(JOB_ID)
        }
    }
}
