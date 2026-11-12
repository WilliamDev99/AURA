package id.aura.aura

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** Jawaban permintaan menyalakan lokasi yang sedang menunggu pilihan anak. */
    private var pendingLocationSettings: MethodChannel.Result? = null

    /** Rincian SOS yang dibuka dari notifikasi alarm, menunggu diambil Dart. */
    private var pendingSosRoute: String? = null

    /**
     * Layar memakai mesin yang sama dengan pemindai pesan (lihat AuraEngine),
     * bukan membuat mesin baru setiap kali aplikasi dibuka.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        AuraEngine.obtain(context)

    /** Pemindai tetap berjalan setelah layar aplikasi ditutup. */
    override fun shouldDestroyEngineWithHost() = false

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Mesin hidup lebih lama dari activity ini; jangan sampai kanal masih
        // menunjuk ke activity yang sudah ditutup.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Bukan saat layar dibuat ulang (mis. diputar): tombolnya sudah
        // dijalankan sebelumnya.
        if (savedInstanceState == null) handleSosAction(intent)
    }

    override fun onResume() {
        super.onResume()
        // Kembali dari halaman izin: Pengaturan terkunci lagi saat jam
        // istirahat.
        ScreenLock.endSettingsGrace()
        hideFromRecentsOnChildPhone()
    }

    /**
     * HP anak yang punya jam istirahat: AURA tidak tampil di daftar aplikasi
     * terbaru. Realme dan OPPO mematikan semua aplikasi di daftar itu saat
     * "Bersihkan semua" ditekan, termasuk AURA, dan selama AURA mati tidak
     * ada yang mengunci. Hanya HP anak yang menyimpan jadwal ini.
     */
    private fun hideFromRecentsOnChildPhone() {
        val child = ScreenLock.schedule(this) != null
        val tasks = (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).appTasks
        for (task in tasks) runCatching { task.setExcludeFromRecents(child) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSosAction(intent)
    }

    /**
     * Notifikasi alarm SOS diketuk: alarmnya dimatikan (orang tua sudah tahu)
     * dan rincian SOS-nya disiapkan untuk dibuka.
     */
    private fun handleSosAction(intent: Intent?) {
        if (intent?.action != SosAlarm.ACTION_OPEN) return
        // Diambil Dart lewat "takeSosRoute" saat layar kembali.
        pendingSosRoute = intent.getStringExtra("route")
        SosAlarm.stop(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentLocation" -> currentLocation(
                        timeoutMs = call.argument<Int>("timeoutMs") ?: 6000,
                        result = result,
                    )
                    "ensureLocationOn" -> ensureLocationOn(result)
                    "lockAccess" -> result.success(
                        mapOf(
                            "usage" to ScreenLock.hasUsageAccess(this),
                            "overlay" to ScreenLock.canDrawOverlay(this),
                            "battery" to ScreenLock.ignoresBatteryOptimizations(this),
                        ),
                    )
                    "openUsageAccessSettings" -> {
                        openSettings(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        openSettings(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(null)
                    }
                    "testSosAlarm" -> {
                        SosAlarm.start(this, SosAlarmInfo.test())
                        result.success(true)
                    }
                    "stopSosAlarm" -> {
                        SosAlarm.stop(this)
                        result.success(null)
                    }
                    "sosAlarmState" -> {
                        val ringing = SosAlarmService.current
                        result.success(
                            mapOf(
                                "ringing" to (ringing != null),
                                "route" to ringing?.route,
                            ),
                        )
                    }
                    "takeSosRoute" -> {
                        result.success(pendingSosRoute)
                        pendingSosRoute = null
                    }
                    "openNotificationAccessSettings" -> {
                        openNotificationAccessSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Mengambil satu titik lokasi untuk tombol darurat.
     *
     * Sengaja tidak memakai `Geolocator.getCurrentPosition`: di
     * geolocator_android 5.1.1 fungsi itu selalu mendaftarkan pendengar NMEA
     * lewat panggilan binder di thread utama. Bila layanan GPS sistem tidak
     * menjawab, seluruh aplikasi membeku — termasuk tombol daruratnya.
     *
     * `getCurrentLocation` milik Play Services sepenuhnya asinkron dan tidak
     * menyentuh NMEA sama sekali.
     */
    @SuppressLint("MissingPermission") // Izin diperiksa tepat di bawah.
    private fun currentLocation(timeoutMs: Int, result: MethodChannel.Result) {
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        if (fine != PackageManager.PERMISSION_GRANTED &&
            coarse != PackageManager.PERMISSION_GRANTED
        ) {
            result.success(mapOf("error" to "permission"))
            return
        }

        val request = CurrentLocationRequest.Builder()
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            .setDurationMillis(timeoutMs.toLong())
            // Titik yang baru diukur dalam 30 detik terakhir boleh langsung
            // dipakai: saat darurat, cepat lebih penting daripada sempurna.
            .setMaxUpdateAgeMillis(30_000)
            .build()

        // Hanya satu jawaban yang boleh dikirim ke Dart.
        var answered = false
        fun reply(value: Map<String, Any?>) {
            if (answered) return
            answered = true
            result.success(value)
        }

        LocationServices.getFusedLocationProviderClient(this)
            .getCurrentLocation(request, CancellationTokenSource().token)
            .addOnSuccessListener { location ->
                if (location == null) {
                    reply(mapOf("error" to "unavailable"))
                } else {
                    reply(
                        mapOf(
                            "latitude" to location.latitude,
                            "longitude" to location.longitude,
                            "accuracy" to location.accuracy.toDouble(),
                            "time" to location.time,
                        ),
                    )
                }
            }
            .addOnFailureListener { reply(mapOf("error" to "unavailable")) }
    }

    /**
     * Android tidak menyediakan dialog izin untuk akses notifikasi; anak
     * harus menyalakannya sendiri di Pengaturan. Bila bisa, langsung dibuka
     * di halaman AURA supaya tidak perlu mencari di daftar.
     */
    private fun openNotificationAccessSettings() {
        ScreenLock.allowSettingsBriefly()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val component = ComponentName(this, AuraNotificationListener::class.java)
            val detail = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component.flattenToString(),
                )
            try {
                startActivity(detail)
                return
            } catch (_: Exception) {
                // Sebagian ponsel tidak punya halaman rinci; pakai daftarnya.
            }
        }
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    /**
     * Meminta anak menyalakan lokasi (GPS) lewat jendela resmi Google
     * "Aktifkan lokasi?", sehingga cukup satu ketukan tanpa membuka
     * Pengaturan. Android tidak mengizinkan aplikasi menyalakannya diam-diam.
     *
     * Jawaban: "on" (sudah atau baru dinyalakan), "declined" (anak menolak),
     * atau "unavailable" (ponsel tidak mendukung jendela ini).
     */
    private fun ensureLocationOn(result: MethodChannel.Result) {
        val request = LocationSettingsRequest.Builder()
            .addLocationRequest(
                LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000).build(),
            )
            // Tanpa pilihan "Jangan tanya lagi": orang tua ingin GPS selalu
            // siap untuk tombol darurat.
            .setAlwaysShow(true)
            .build()

        LocationServices.getSettingsClient(this)
            .checkLocationSettings(request)
            .addOnSuccessListener { result.success("on") }
            .addOnFailureListener { error ->
                if (error !is ResolvableApiException) {
                    result.success("unavailable")
                    return@addOnFailureListener
                }
                try {
                    // Permintaan sebelumnya yang belum dijawab dianggap ditolak.
                    pendingLocationSettings?.success("declined")
                    pendingLocationSettings = result
                    error.startResolutionForResult(this, LOCATION_SETTINGS_REQUEST)
                } catch (_: IntentSender.SendIntentException) {
                    pendingLocationSettings = null
                    result.success("unavailable")
                }
            }
    }

    /**
     * Halaman izin khusus untuk jam istirahat. Bila bisa, langsung di baris
     * AURA, supaya anak tidak perlu mencarinya di daftar.
     */
    private fun openSettings(action: String) {
        ScreenLock.allowSettingsBriefly()
        val own = Intent(action, android.net.Uri.fromParts("package", packageName, null))
        try {
            startActivity(own)
        } catch (_: Exception) {
            startActivity(Intent(action))
        }
    }

    /**
     * Dialog Android "Izinkan AURA selalu berjalan di latar belakang?". Bila
     * HP tidak menyediakannya, daftar pengecualian penghemat baterai.
     */
    private fun openBatterySettings() {
        ScreenLock.allowSettingsBriefly()
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    android.net.Uri.fromParts("package", packageName, null),
                ),
            )
        } catch (_: Exception) {
            runCatching {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != LOCATION_SETTINGS_REQUEST) return
        pendingLocationSettings?.success(
            if (resultCode == Activity.RESULT_OK) "on" else "declined",
        )
        pendingLocationSettings = null
    }

    private companion object {
        const val CHANNEL = "id.aura/sos"
        const val LOCATION_SETTINGS_REQUEST = 4712
    }
}
