package id.aura.aura

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
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
                    "hasWhatsApp" -> result.success(whatsAppPackage() != null)
                    "placeWhatsAppCall" ->
                        placeWhatsAppCall(call.argument<String>("digits"), result)
                    "whatsAppCallReady" ->
                        whatsAppCallReady(call.argument<String>("digits"), result)
                    "saveParentContact" -> saveParentContact(
                        number = call.argument<String>("number"),
                        name = call.argument<String>("name"),
                        result = result,
                    )
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

    /**
     * Meminta izin telepon, sekaligus izin Kontak bila WhatsApp terpasang.
     *
     * Kontak hanya dipakai untuk nomor orang tua: menyimpannya supaya
     * WhatsApp mengenalinya, lalu menemukannya saat anak menekan "Telepon
     * lewat WhatsApp". Tanpa WhatsApp, izin itu tidak berguna, jadi tidak
     * diminta. Baca dan tulis Kontak satu kelompok izin: satu dialog saja.
     */
    private fun requestCallPermission(result: MethodChannel.Result) {
        val missing = buildList {
            if (!hasCallPermission()) add(Manifest.permission.CALL_PHONE)
            if (whatsAppPackage() != null) {
                if (!hasContactsPermission()) add(Manifest.permission.READ_CONTACTS)
                if (!hasWriteContactsPermission()) {
                    add(Manifest.permission.WRITE_CONTACTS)
                }
            }
        }
        if (missing.isEmpty()) {
            result.success(hasCallPermission())
            return
        }
        // Permintaan sebelumnya yang belum dijawab dianggap ditolak.
        pendingCallPermission?.success(false)
        pendingCallPermission = result
        requestPermissions(missing.toTypedArray(), CALL_PERMISSION_REQUEST)
    }

    private fun hasContactsPermission() =
        checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasWriteContactsPermission() =
        checkSelfPermission(Manifest.permission.WRITE_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Apakah "Telepon lewat WhatsApp" akan langsung menelepon: WhatsApp sudah
     * menambahkan baris panggilan suara untuk nomor orang tua di Kontak.
     */
    private fun whatsAppCallReady(digits: String?, result: MethodChannel.Result) {
        val packageName = whatsAppPackage()
        if (digits.isNullOrBlank() || packageName == null) {
            result.success(false)
            return
        }
        Thread {
            val ready = findWhatsAppCallRow(packageName, digits) != null
            runOnUiThread { result.success(ready) }
        }.start()
    }

    /**
     * Menyimpan nomor orang tua di Kontak bila belum ada.
     *
     * WhatsApp hanya bisa langsung menelepon nomor yang ada di Kontak. Tanpa
     * ini, tombol WhatsApp saat SOS baru membuka chat dan anak masih harus
     * menekan ikon telepon. Kontak yang sudah ada tidak pernah diubah.
     *
     * Jawaban: "exists", "added", "no_permission", "not_installed",
     * "no_number", atau "failed".
     */
    private fun saveParentContact(
        number: String?,
        name: String?,
        result: MethodChannel.Result,
    ) {
        if (number.isNullOrBlank()) {
            result.success("no_number")
            return
        }
        if (whatsAppPackage() == null) {
            result.success("not_installed")
            return
        }
        if (!hasContactsPermission() || !hasWriteContactsPermission()) {
            result.success("no_permission")
            return
        }
        Thread {
            val reply = try {
                if (hasContactWithNumber(number)) {
                    "exists"
                } else {
                    insertContact(name?.takeIf { it.isNotBlank() } ?: "AURA", number)
                    "added"
                }
            } catch (_: Exception) {
                "failed"
            }
            runOnUiThread { result.success(reply) }
        }.start()
    }

    /** Pencarian bawaan Android, yang sudah menyamakan 0812... dan +62812... */
    private fun hasContactWithNumber(number: String): Boolean {
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(number),
        )
        contentResolver.query(
            uri,
            arrayOf(ContactsContract.PhoneLookup._ID),
            null,
            null,
            null,
        )?.use { return it.moveToFirst() }
        return false
    }

    /** Kontak lokal di perangkat, tidak masuk akun Google mana pun. */
    private fun insertContact(name: String, number: String) {
        val operations = arrayListOf(
            ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                .build(),
            ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(
                    ContactsContract.Data.MIMETYPE,
                    ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE,
                )
                .withValue(
                    ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME,
                    name,
                )
                .build(),
            ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(
                    ContactsContract.Data.MIMETYPE,
                    ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE,
                )
                .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, number)
                .withValue(
                    ContactsContract.CommonDataKinds.Phone.TYPE,
                    ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE,
                )
                .build(),
        )
        contentResolver.applyBatch(ContactsContract.AUTHORITY, operations)
    }

    /** WhatsApp biasa didahulukan; WhatsApp Business bila hanya itu yang ada. */
    private fun whatsAppPackage(): String? =
        WhatsAppContact.callMimeTypes.keys.firstOrNull { isInstalled(it) }

    private fun isInstalled(packageName: String) = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    /**
     * Menelepon orang tua lewat WhatsApp, untuk HP tanpa pulsa atau tablet
     * tanpa SIM. Butuh internet.
     *
     * Bila nomor orang tua tersimpan di Kontak, panggilan suara langsung
     * dimulai ("called"). Bila tidak, atau izin Kontak tidak ada, chat
     * WhatsApp orang tua dibuka ("chat_opened") dan anak tinggal menekan ikon
     * telepon di sana.
     *
     * Pencarian kontak berjalan di luar thread utama: jalur darurat tidak
     * boleh membuat layar membeku.
     */
    private fun placeWhatsAppCall(digits: String?, result: MethodChannel.Result) {
        if (digits.isNullOrBlank()) {
            result.success("no_number")
            return
        }
        val packageName = whatsAppPackage()
        if (packageName == null) {
            result.success("not_installed")
            return
        }
        Thread {
            val row = findWhatsAppCallRow(packageName, digits)
            runOnUiThread {
                if (row != null) {
                    try {
                        startActivity(
                            Intent(Intent.ACTION_VIEW)
                                .setDataAndType(
                                    ContentUris.withAppendedId(
                                        ContactsContract.Data.CONTENT_URI,
                                        row,
                                    ),
                                    WhatsAppContact.callMimeTypes.getValue(packageName),
                                )
                                .setPackage(packageName)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success("called")
                        return@runOnUiThread
                    } catch (_: Exception) {
                        // WhatsApp menolak baris itu; buka chat-nya saja.
                    }
                }
                try {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$digits"))
                            .setPackage(packageName)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success("chat_opened")
                } catch (_: Exception) {
                    result.success("failed")
                }
            }
        }.start()
    }

    /** ID baris "Panggilan suara" WhatsApp milik [digits], atau null. */
    private fun findWhatsAppCallRow(packageName: String, digits: String): Long? {
        if (!hasContactsPermission()) return null
        val mimeType = WhatsAppContact.callMimeTypes[packageName] ?: return null
        return try {
            contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                arrayOf(
                    ContactsContract.Data._ID,
                    ContactsContract.Data.DATA1,
                    ContactsContract.Data.DATA3,
                ),
                "${ContactsContract.Data.MIMETYPE} = ?",
                arrayOf(mimeType),
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    if (WhatsAppContact.matches(cursor.getString(1), cursor.getString(2), digits)) {
                        return cursor.getLong(0)
                    }
                }
                null
            }
        } catch (_: Exception) {
            null
        }
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
        // Bisa berisi izin Kontak juga; yang dilaporkan tetap izin telepon.
        pendingCallPermission?.success(hasCallPermission())
        pendingCallPermission = null
    }

    private companion object {
        const val CHANNEL = "id.aura/sos"
        const val CALL_PERMISSION_REQUEST = 4711
        const val LOCATION_SETTINGS_REQUEST = 4712
    }
}
