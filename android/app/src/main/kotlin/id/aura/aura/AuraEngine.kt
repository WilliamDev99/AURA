package id.aura.aura

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Satu-satunya mesin Flutter di aplikasi ini, dipakai bersama oleh layar
 * aplikasi dan pemindai pesan.
 *
 * Kenapa tidak dua mesin? Setiap mesin menjalankan klien Supabase sendiri
 * dengan salinan sesi sendiri. Bila keduanya memperbarui token di waktu yang
 * berdekatan, Supabase menganggap token lama dipakai ulang lalu mencabut
 * seluruh sesi. Akun anak bersifat anonim, jadi sesi yang dicabut berarti
 * ponsel anak terputus dari keluarganya untuk selamanya.
 *
 * Mesin ini menjalankan `main()` biasa, persis seperti saat aplikasi dibuka.
 * Bila pemindai yang lebih dulu menyalakannya, layar aplikasi nanti cukup
 * menempel ke mesin yang sudah berjalan.
 */
object AuraEngine {
    private const val ENGINE_ID = "aura"
    private const val SCAN_CHANNEL = "id.aura/scan"

    /** Batas antrean selagi Dart belum siap, supaya memori tidak membengkak. */
    private const val MAX_PENDING = 50

    private var scanChannel: MethodChannel? = null
    private var dartReady = false
    /** Antrean (nama metode, argumen) selagi Dart belum siap. */
    private val pending = ArrayDeque<Pair<String, Any?>>()

    /** Harus dipanggil di thread utama. */
    fun obtain(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }

        val appContext = context.applicationContext
        val engine = FlutterEngine(appContext)
        dartReady = false
        scanChannel = MethodChannel(engine.dartExecutor.binaryMessenger, SCAN_CHANNEL)
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "ready" -> {
                            dartReady = true
                            flush()
                            result.success(null)
                        }
                        // Di sini, bukan di MainActivity: mesin sering
                        // dinyalakan oleh pemindai (setelah ponsel menyala
                        // ulang atau aplikasi diperbarui) tanpa layar apa pun.
                        "hasNotificationAccess" -> result.success(
                            NotificationManagerCompat.getEnabledListenerPackages(appContext)
                                .contains(appContext.packageName),
                        )
                        else -> result.notImplemented()
                    }
                }
            }
        engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            // Hot restart saat pengembangan: Dart akan mengirim "ready" lagi.
            override fun onPreEngineRestart() {
                dartReady = false
            }

            override fun onEngineWillDestroy() {
                FlutterEngineCache.getInstance().remove(ENGINE_ID)
                scanChannel = null
                dartReady = false
            }
        })
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    /** Meneruskan satu pesan ke pemindai di Dart. Harus di thread utama. */
    fun deliver(context: Context, message: Map<String, Any?>) {
        enqueue(context, "message", message)
    }

    /**
     * Memberi tahu Dart bahwa "Akses notifikasi" baru saja diberikan atau
     * dicabut, supaya orang tua segera tahu. Harus di thread utama.
     */
    fun reportAccess(context: Context, enabled: Boolean) {
        enqueue(context, "accessChanged", enabled)
    }

    private fun enqueue(context: Context, method: String, arguments: Any?) {
        obtain(context)
        if (pending.size >= MAX_PENDING) pending.removeFirst()
        pending.addLast(method to arguments)
        if (dartReady) flush()
    }

    private fun flush() {
        val channel = scanChannel ?: return
        while (pending.isNotEmpty()) {
            val (method, arguments) = pending.removeFirst()
            channel.invokeMethod(method, arguments)
        }
    }
}
