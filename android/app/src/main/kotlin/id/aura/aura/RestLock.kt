package id.aura.aura

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import java.util.Calendar

/**
 * Layar "Jam istirahat" yang menutupi aplikasi terkunci. Dipakai dua kali
 * oleh ScreenLock: sebagai lapisan di atas aplikasi (langsung muncul), lalu
 * sebagai [RestLockActivity] yang menggantikan aplikasi itu.
 */
object RestLockView {
    fun build(
        context: Context,
        schedule: LockSchedule,
        onOpenAura: () -> Unit,
        onHome: (() -> Unit)? = null,
    ): View {
        val english = context
            .getSharedPreferences(AuraPrefs.FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(AuraPrefs.LANGUAGE_KEY, null) == "en"
        val until = "%02d.%02d".format(schedule.endMinutes / 60, schedule.endMinutes % 60)
        fun dp(value: Int) = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

        val title = TextView(context).apply {
            text = if (english) "Rest time" else "Jam istirahat"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        val body = TextView(context).apply {
            text = if (english) {
                "Apps are locked until $until, as set by your parents. " +
                    "AURA, phone calls, and your alarm clock still work."
            } else {
                "Aplikasi terkunci sampai pukul $until, sesuai aturan " +
                    "orang tuamu. AURA, telepon, dan jam alarm tetap bisa dibuka."
            }
            setTextColor(0xE6FFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.3f)
            setPadding(0, dp(12), 0, dp(28))
        }
        val open = Button(context).apply {
            text = if (english) "Open AURA" else "Buka AURA"
            isAllCaps = false
            setTextColor(0xFF0B1257.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                cornerRadius = dp(28).toFloat()
                setColor(Color.WHITE)
            }
            setPadding(dp(32), dp(14), dp(32), dp(14))
            setOnClickListener { onOpenAura() }
        }
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(32), dp(32), dp(32))
            setBackgroundColor(0xF20B1257.toInt())
            // Sentuhan tidak tembus ke aplikasi di belakangnya.
            isClickable = true
            addView(title)
            addView(body)
            addView(open)
            if (onHome != null) {
                addView(
                    Button(context).apply {
                        text = if (english) "Home screen" else "Ke layar utama"
                        isAllCaps = false
                        setTextColor(Color.WHITE)
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                        setBackgroundColor(Color.TRANSPARENT)
                        setPadding(dp(24), dp(18), dp(24), dp(12))
                        setOnClickListener { onHome() }
                    },
                )
            }
        }
    }

    /** Beranda anak dengan tombol SOS. */
    fun openAura(context: Context) {
        context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ?.let { context.startActivity(it) }
    }

    fun goHome(context: Context) {
        context.startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

/**
 * Layar penuh "Jam istirahat". Lapisan saja tidak cukup: aplikasi di
 * belakangnya tetap berjalan (video dan game tetap bersuara), dan sebagian
 * aplikasi bisa menyembunyikan lapisan. Layar ini menggantikan aplikasi itu,
 * sehingga aplikasinya berhenti sampai dibuka lagi.
 *
 * Tidak tampil di daftar aplikasi terbaru. Tombol Kembali membawa anak ke
 * layar utama, bukan kembali ke aplikasi yang terkunci.
 */
class RestLockActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())

    /** Jam istirahat selesai saat layar ini terbuka: layar ini ikut tutup. */
    private val watch = object : Runnable {
        override fun run() {
            if (currentSchedule() == null) {
                finish()
                return
            }
            handler.postDelayed(this, 15_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { leave() }
        }
        render()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        render()
    }

    override fun onResume() {
        super.onResume()
        handler.removeCallbacks(watch)
        handler.post(watch)
    }

    override fun onPause() {
        handler.removeCallbacks(watch)
        super.onPause()
    }

    @Deprecated("Android 12 ke bawah; Android 13+ memakai OnBackInvokedCallback.")
    override fun onBackPressed() {
        leave()
    }

    private fun render() {
        val schedule = currentSchedule()
        if (schedule == null) {
            finish()
            return
        }
        setContentView(
            RestLockView.build(
                this,
                schedule,
                onOpenAura = {
                    RestLockView.openAura(this)
                    finish()
                },
                onHome = { leave() },
            ),
        )
    }

    private fun leave() {
        RestLockView.goHome(this)
        finish()
    }

    /** Jadwal yang sedang mengunci saat ini, atau null. */
    private fun currentSchedule(): LockSchedule? {
        val schedule = ScreenLock.schedule(this) ?: return null
        return schedule.takeIf { it.isLockedAt(Calendar.getInstance()) }
    }

    companion object {
        fun open(context: Context) {
            context.startActivity(
                Intent(context, RestLockActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                ),
            )
        }
    }
}
