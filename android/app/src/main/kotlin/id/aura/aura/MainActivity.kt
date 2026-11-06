package id.aura.aura

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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

    /** Jawaban permintaan izin telepon yang sedang menunggu pilihan pengguna. */
    private var pendingCallPermission: MethodChannel.Result? = null

    /** Jawaban permintaan menyalakan lokasi yang sedang menunggu pilihan anak. */
    private var pendingLocationSettings: MethodChannel.Result? = null

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentLocation" -> currentLocation(
                        timeoutMs = call.argument<Int>("timeoutMs") ?: 6000,
                        result = result,
                    )
                    "placeCall" -> placeCall(call.argument<String>("number"), result)
                    "hasCallPermission" -> result.success(hasCallPermission())
                    "requestCallPermission" -> requestCallPermission(result)
                    "ensureLocationOn" -> ensureLocationOn(result)
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

    private fun hasCallPermission() =
        checkSelfPermission(Manifest.permission.CALL_PHONE) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Menelepon orang tua langsung saat anak menekan tombol darurat.
     *
     * Lewat jaringan seluler biasa, jadi tetap jalan saat internet mati.
     * Tanpa izin CALL_PHONE, Dart membuka aplikasi Telepon dengan nomor
     * terisi sebagai gantinya.
     */
    @SuppressLint("MissingPermission") // Izin diperiksa tepat di bawah.
    private fun placeCall(number: String?, result: MethodChannel.Result) {
        if (number.isNullOrBlank()) {
            result.success("no_number")
            return
        }
        if (!hasCallPermission()) {
            result.success("no_permission")
            return
        }
        try {
            startActivity(
                Intent(Intent.ACTION_CALL, Uri.fromParts("tel", number, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            result.success("called")
        } catch (error: Exception) {
            result.success("failed")
        }
    }

    private fun requestCallPermission(result: MethodChannel.Result) {
        if (hasCallPermission()) {
            result.success(true)
            return
        }
        // Permintaan sebelumnya yang belum dijawab dianggap ditolak.
        pendingCallPermission?.success(false)
        pendingCallPermission = result
        requestPermissions(
            arrayOf(Manifest.permission.CALL_PHONE),
            CALL_PERMISSION_REQUEST,
        )
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != LOCATION_SETTINGS_REQUEST) return
        pendingLocationSettings?.success(
            if (resultCode == Activity.RESULT_OK) "on" else "declined",
        )
        pendingLocationSettings = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALL_PERMISSION_REQUEST) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingCallPermission?.success(granted)
        pendingCallPermission = null
    }

    private companion object {
        const val CHANNEL = "id.aura/sos"
        const val CALL_PERMISSION_REQUEST = 4711
        const val LOCATION_SETTINGS_REQUEST = 4712
    }
}
