package id.aura.aura

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.provider.AlarmClock
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import android.view.View
import android.view.WindowManager
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * Pengunci jam istirahat di HP anak.
 *
 * Selama jam istirahat, aplikasi yang sedang dibuka anak langsung ditutup
 * lapisan "Jam istirahat", lalu digantikan layar penuh [RestLockActivity]
 * supaya aplikasinya berhenti (video dan game tidak terus bersuara). AURA
 * (tombol SOS), telepon, jam alarm, dan layar utama tetap bisa dipakai: anak
 * harus selalu bisa minta tolong, dan alarm paginya harus tetap bisa
 * dimatikan.
 *
 * Berjalan di dalam AuraNotificationListener, layanan yang dijaga hidup oleh
 * Android selama "Akses notifikasi" menyala. Butuh izin "Akses penggunaan"
 * (untuk tahu aplikasi apa yang terbuka) dan "Tampil di atas aplikasi lain"
 * (untuk menutupinya); tanpa keduanya, tidak ada yang dikunci, dan orang tua
 * diberi tahu lewat status `lock_ready`.
 *
 * Semua pemeriksaan berjalan di thread sendiri, bukan thread utama. Di
 * Flutter versi ini thread utama Android juga menjalankan Dart (pemindai
 * pesan, realtime), dan selama Dart sibuk, pemeriksaan di thread utama ikut
 * tertunda: aplikasi sempat terbuka beberapa detik sebelum terkunci.
 */
object ScreenLock {
    private const val TAG = "AURA"

    /** Jadwal ditulis Dart (AppState) setiap profil anak berubah. */
    private const val SCHEDULE_KEY = "flutter.aura.lock_schedule"

    /** Selama terkunci: aplikasi yang baru dibuka tertutup dalam setengah detik. */
    private const val CHECK_LOCKED_MS = 500L

    /** Jeda sebelum layar penuh menggantikan lapisan (lihat [show]). */
    private const val REPLACE_DELAY_MS = 300L

    /** Lama halaman izin boleh terbuka selama jam istirahat. */
    private const val SETTINGS_GRACE_MS = 90_000L

    /** Pemeriksaan yang terlambat lebih dari ini dicatat (lihat [tick]). */
    private const val LATE_MS = 1_500L

    private val thread = HandlerThread("aura-jam-istirahat").apply { start() }
    private val handler = Handler(thread.looper)
    private val main = Handler(Looper.getMainLooper())

    // Diubah dari thread utama (start/stop), dibaca di thread pengunci.
    @Volatile
    private var context: Context? = null

    // Hanya disentuh di thread pengunci.
    private var overlay: View? = null
    private var lockedApp: String? = null
    private var foreground: String? = null
    private var allowed: Set<String> = emptySet()
    private var allowedAt = 0L
    private var settingsApps: Set<String>? = null
    private var tickDueAt = 0L
    private var wakeRegistered = false
    private var prefs: SharedPreferences? = null
    private var watchdogArmedAt = 0L

    /**
     * Pengaturan Android terkunci selama jam istirahat, supaya izin AURA
     * tidak bisa dimatikan. Tetapi halaman izin yang dibuka AURA sendiri
     * (tombol "Izinkan") harus bisa dipakai, juga di malam hari: tanpanya,
     * anak tidak bisa memberi izin yang dibutuhkan pengunci ini.
     */
    @Volatile
    private var settingsGraceUntil = 0L

    /** Dipanggil tepat sebelum AURA membuka halaman izin. */
    fun allowSettingsBriefly() {
        settingsGraceUntil = SystemClock.elapsedRealtime() + SETTINGS_GRACE_MS
    }

    /** Anak sudah kembali ke AURA: Pengaturan terkunci lagi. */
    fun endSettingsGrace() {
        settingsGraceUntil = 0L
    }

    /**
     * Layar menyala atau kunci layar dibuka: periksa saat itu juga, jangan
     * menunggu giliran berikutnya. Tanpa ini, anak bisa membuka aplikasi
     * beberapa detik setelah menyalakan HP.
     */
    private val wake = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val app = this@ScreenLock.context ?: return
            checkNow()
            // Jam istirahat mungkin diubah orang tua selagi HP tidur. Mesin
            // Dart hanya boleh disentuh dari thread utama.
            main.post { runCatching { AuraEngine.refreshProfile(app) } }
        }
    }

    /**
     * Jadwal baru dari orang tua baru saja disimpan Dart di HP ini: periksa
     * saat itu juga. Tanpa ini, jam istirahat yang dinyalakan baru berlaku di
     * pergantian menit berikutnya.
     */
    private val scheduleChanged = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == SCHEDULE_KEY) checkNow()
    }

    private fun checkNow() {
        if (context == null) return
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    private val replace = Runnable {
        val ctx = context ?: return@Runnable
        // Lapisan sudah hilang: anak sudah meninggalkan aplikasinya.
        if (overlay == null) return@Runnable
        try {
            RestLockActivity.open(ctx)
        } catch (error: Exception) {
            // Mis. dicegah sistem. Lapisan tetap menutupi aplikasinya.
            Log.w(TAG, "Jam istirahat: layar penuh tidak bisa dibuka", error)
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            val ctx = context ?: return
            val now = SystemClock.uptimeMillis()
            if (tickDueAt > 0 && now - tickDueAt > LATE_MS) {
                Log.w(TAG, "Jam istirahat: pemeriksaan terlambat ${now - tickDueAt} ms")
            }
            val delay = try {
                check(ctx)
            } catch (error: Throwable) {
                Log.e(TAG, "Jam istirahat gagal diperiksa", error)
                LockSchedule.delayToNextMinute(System.currentTimeMillis())
            }
            tickDueAt = SystemClock.uptimeMillis() + delay
            handler.postDelayed(this, delay)
        }
    }

    /** Dari thread mana pun. */
    fun start(context: Context) {
        val app = context.applicationContext
        handler.post {
            this.context = app
            if (!wakeRegistered) {
                val filter = IntentFilter().apply {
                    addAction(Intent.ACTION_SCREEN_ON)
                    addAction(Intent.ACTION_USER_PRESENT)
                }
                ContextCompat.registerReceiver(
                    app,
                    wake,
                    filter,
                    null,
                    handler,
                    ContextCompat.RECEIVER_NOT_EXPORTED,
                )
                wakeRegistered = true
            }
            if (prefs == null) {
                prefs = app.getSharedPreferences(AuraPrefs.FLUTTER_PREFS, Context.MODE_PRIVATE).also {
                    it.registerOnSharedPreferenceChangeListener(scheduleChanged)
                }
            }
            Log.i(TAG, "Jam istirahat: pengunci berjalan.")
            tickDueAt = 0L
            handler.removeCallbacks(tick)
            handler.post(tick)
        }
    }

    /** Dari thread mana pun. */
    fun stop() {
        handler.post {
            val app = context ?: return@post
            handler.removeCallbacks(tick)
            hide()
            if (wakeRegistered) {
                runCatching { app.unregisterReceiver(wake) }
                wakeRegistered = false
            }
            prefs?.unregisterOnSharedPreferenceChangeListener(scheduleChanged)
            prefs = null
            context = null
            Log.i(TAG, "Jam istirahat: pengunci berhenti.")
        }
    }

    fun hasUsageAccess(context: Context): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun canDrawOverlay(context: Context) = Settings.canDrawOverlays(context)

    /**
     * Dikecualikan dari penghemat baterai. Tanpa ini, HP seperti Realme dan
     * OPPO lebih sering mematikan AURA di latar belakang, dan selama itu
     * tidak ada yang mengunci.
     */
    fun ignoresBatteryOptimizations(context: Context): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun schedule(context: Context): LockSchedule? = LockSchedule.parse(
        context.getSharedPreferences(AuraPrefs.FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(SCHEDULE_KEY, null),
    )

    /** Satu pemeriksaan; mengembalikan jeda sampai pemeriksaan berikutnya. */
    private fun check(context: Context): Long {
        val schedule = schedule(context)
        val idle = LockSchedule.delayToNextMinute(System.currentTimeMillis())
        if (schedule == null || !schedule.active) {
            hide()
            disarmWatchdog(context)
            return idle
        }
        val locked = schedule.isLockedAt(Calendar.getInstance())
        armWatchdog(context, locked)
        if (!locked) {
            hide()
            return idle
        }
        if (!hasUsageAccess(context) || !canDrawOverlay(context)) {
            hide()
            return idle
        }
        // Layar mati: tidak ada yang bisa dibuka. Penerima [wake] memeriksa
        // lagi begitu layar menyala.
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!power.isInteractive) return idle

        val app = foregroundApp(context)
        val permitted = app == null ||
            app in allowedApps(context) ||
            (SystemClock.elapsedRealtime() < settingsGraceUntil && app in settingsApps(context))
        if (permitted) hide() else show(context, schedule, app!!)
        return CHECK_LOCKED_MS
    }

    /**
     * Penjaga cadangan ([LockWatchdog]) selalu dijadwalkan beberapa detik ke
     * depan dan terus ditunda selama AURA hidup. Bila sistem mematikan AURA
     * (mis. ColorOS saat "Bersihkan semua"), penjaga itu berjalan dan
     * menghidupkan pengunci lagi.
     */
    private fun armWatchdog(context: Context, locked: Boolean) {
        val now = SystemClock.elapsedRealtime()
        val every = if (locked) LockWatchdog.REARM_LOCKED_MS else LockWatchdog.REARM_IDLE_MS
        if (now - watchdogArmedAt < every) return
        watchdogArmedAt = now
        runCatching { LockWatchdog.arm(context, locked) }
            .onFailure { Log.w(TAG, "Jam istirahat: penjaga tidak bisa dijadwalkan", it) }
    }

    private fun disarmWatchdog(context: Context) {
        if (watchdogArmedAt == 0L) return
        watchdogArmedAt = 0L
        runCatching { LockWatchdog.disarm(context) }
    }

    /** Aplikasi terakhir yang tampil di layar, dari catatan penggunaan. */
    private fun foregroundApp(context: Context): String? {
        val usage = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        // Pemeriksaan pertama melihat jauh ke belakang: anak mungkin sudah
        // lama berada di satu aplikasi saat jam istirahat dimulai.
        val since = if (foreground == null) 24 * 60 * 60 * 1000L else 15_000L
        val events = usage.queryEvents(end - since, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // ACTIVITY_RESUMED (dulu MOVE_TO_FOREGROUND) bernilai 1.
            if (event.eventType == 1) foreground = event.packageName
        }
        return foreground
    }

    /** Aplikasi yang menampilkan halaman izin jam istirahat dan notifikasi. */
    private fun settingsApps(context: Context): Set<String> {
        settingsApps?.let { return it }
        val own = android.net.Uri.fromParts("package", context.packageName, null)
        val pages = listOf(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, own),
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, own),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
        )
        val set = mutableSetOf("com.android.settings")
        for (page in pages) {
            runCatching {
                context.packageManager.resolveActivity(page, PackageManager.MATCH_DEFAULT_ONLY)
                    ?.activityInfo?.packageName
            }.getOrNull()?.let { set += it }
        }
        // "android" adalah pemilih aplikasi, bukan halaman izin.
        set -= "android"
        settingsApps = set
        return set
    }

    /**
     * Yang tetap bisa dibuka selama jam istirahat: AURA, layar utama yang
     * sedang dipakai, aplikasi Telepon bawaan (termasuk panggilan masuk dan
     * darurat), jam alarm bawaan, keyboard, dialog sistem, dan konfirmasi
     * pemasangan aplikasi (supaya pembaruan AURA bisa dipasang di malam
     * hari).
     *
     * Sengaja sempit. Menanyakan "aplikasi apa saja yang bisa menelepon"
     * ikut meloloskan Zoom; "yang bisa membuka APK" meloloskan toko aplikasi
     * dan WPS Office; "semua layar utama" meloloskan Pengaturan Android
     * (FallbackHome), tempat izin AURA bisa dimatikan.
     */
    private fun allowedApps(context: Context): Set<String> {
        val now = System.currentTimeMillis()
        if (now - allowedAt < 60_000 && allowed.isNotEmpty()) return allowed
        val pm = context.packageManager
        fun systemHandlers(intent: Intent) = try {
            pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                .filter { it.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0 }
                .map { it.activityInfo.packageName }
        } catch (_: Exception) {
            emptyList()
        }

        val set = mutableSetOf(
            context.packageName,
            "android",
            "com.android.systemui",
            "com.android.phone",
            "com.android.server.telecom",
            "com.android.incallui",
            "com.android.permissioncontroller",
            "com.google.android.permissioncontroller",
            "com.google.android.gms",
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            // Pemeriksa keamanan pemasangan aplikasi di Realme dan OPPO.
            "com.oplus.stdsp",
        )
        // Layar utama yang sedang dipakai. Bila belum dipilih, semua layar
        // utama bawaan sistem.
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val defaultHome = runCatching {
            pm.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
        }.getOrNull()
        if (defaultHome != null && defaultHome != "android") {
            set += defaultHome
        } else {
            set += systemHandlers(home)
        }
        (context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)
            ?.defaultDialerPackage?.let { set += it }
        set += systemHandlers(Intent(AlarmClock.ACTION_SHOW_ALARMS))
        set += systemHandlers(Intent(AlarmClock.ACTION_SET_ALARM))
        Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            ?.substringBefore('/')?.let { set += it }
        // Pengaturan hanya lewat masa tenggang halaman izin (lihat atas).
        set -= "com.android.settings"

        allowed = set
        allowedAt = now
        return set
    }

    /**
     * Lapisan menutupi aplikasi saat itu juga. Sesaat kemudian, setelah
     * lapisannya tampil, layar penuh menggantikan aplikasinya: Android
     * mengizinkan AURA membuka layar dari latar belakang hanya selama
     * lapisannya terlihat.
     */
    private fun show(context: Context, schedule: LockSchedule, app: String) {
        if (overlay != null) {
            // Masih aplikasi yang sama: lapisannya sudah ada. Aplikasi lain
            // yang dibuka dari balik lapisan (mis. lewat notifikasi) juga
            // harus digantikan layar penuh.
            if (app == lockedApp) return
            lockedApp = app
            Log.i(TAG, "Jam istirahat: $app dikunci.")
            handler.removeCallbacks(replace)
            handler.postDelayed(replace, REPLACE_DELAY_MS)
            return
        }
        val view = RestLockView.build(context, schedule, onOpenAura = { RestLockView.openAura(context) })
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            // Tidak mengambil fokus: tombol Kembali dan Beranda tetap jalan,
            // jadi anak selalu bisa keluar ke layar utama.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        try {
            (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(view, params)
            overlay = view
            lockedApp = app
            Log.i(TAG, "Jam istirahat: $app dikunci.")
            handler.removeCallbacks(replace)
            handler.postDelayed(replace, REPLACE_DELAY_MS)
        } catch (error: Exception) {
            Log.e(TAG, "Jam istirahat: lapisan gagal ditampilkan", error)
        }
    }

    private fun hide() {
        handler.removeCallbacks(replace)
        lockedApp = null
        val view = overlay ?: return
        overlay = null
        try {
            (view.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(view)
        } catch (_: Exception) {
        }
    }
}
