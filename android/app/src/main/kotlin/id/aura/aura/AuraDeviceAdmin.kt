package id.aura.aura

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Melindungi AURA dari penghapusan di HP anak.
 *
 * Selama AURA aktif sebagai admin perangkat, Android menolak menghapusnya,
 * baik dari layar utama maupun dari Pengaturan. AURA tidak memakai satu pun
 * kewenangan admin (lihat res/xml/aura_device_admin.xml): tidak mengunci
 * layar, tidak menghapus data, tidak membaca kata sandi.
 *
 * Untuk menghapus AURA, anak meminta izin orang tua lewat AURA. Setelah
 * diizinkan, [release] melepas perlindungan ini. Bila anak melepasnya sendiri
 * lewat Pengaturan, Android menampilkan peringatan dari [onDisableRequested],
 * dan orang tua langsung diberi tahu.
 */
class AuraDeviceAdmin : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        report(context, true)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        report(context, false)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        if (english(context)) {
            "AURA may only be removed with your parent's permission. Ask " +
                "for it in AURA > Settings > Remove AURA. If you turn this " +
                "off, your parent will be told."
        } else {
            "AURA hanya boleh dihapus dengan izin orang tuamu. Minta izinnya " +
                "di AURA > Pengaturan > Hapus AURA. Kalau ini dimatikan, " +
                "orang tuamu akan diberi tahu."
        }

    private fun report(context: Context, protected: Boolean) {
        Log.i("AURA", "Perlindungan hapus ${if (protected) "menyala" else "mati"}.")
        // Dart (realtime ke Supabase) yang mengabarkannya ke orang tua,
        // juga saat AURA berjalan tanpa layar.
        runCatching { AuraEngine.reportUninstallProtection(context, protected) }
            .onFailure { Log.e("AURA", "Status perlindungan hapus gagal dikirim", it) }
    }

    companion object {
        fun component(context: Context) = ComponentName(context, AuraDeviceAdmin::class.java)

        private fun policy(context: Context) =
            context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

        fun isActive(context: Context) = policy(context).isAdminActive(component(context))

        /** Dialog Android "Aktifkan aplikasi admin perangkat ini?". */
        fun activationIntent(context: Context): Intent =
            Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component(context))
                .putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    if (english(context)) {
                        "Keeps AURA from being removed without your parent's " +
                            "permission. AURA does not use any other admin power."
                    } else {
                        "Supaya AURA tidak bisa dihapus tanpa izin orang tuamu. " +
                            "AURA tidak memakai kewenangan admin lainnya."
                    },
                )

        /** Setelah orang tua mengizinkan: AURA boleh dihapus. */
        fun release(context: Context) {
            if (isActive(context)) policy(context).removeActiveAdmin(component(context))
        }

        private fun english(context: Context) = context
            .getSharedPreferences(AuraPrefs.FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(AuraPrefs.LANGUAGE_KEY, null) == "en"
    }
}
