package id.aura.aura

import org.json.JSONObject
import java.util.Calendar

/**
 * Jam istirahat anak, diatur orang tua: semua aplikasi terkunci pada jam
 * ini, kecuali AURA, telepon, dan jam alarm.
 *
 * Aturannya harus sama dengan lib/domain/models/lock_schedule.dart; test di
 * kedua sisi memakai contoh yang sama.
 */
data class LockSchedule(
    val enabled: Boolean,
    /** Menit sejak tengah malam, mis. 22.00 = 1320. */
    val startMinutes: Int,
    val endMinutes: Int,
    /** Hari mulainya kunci: 1 = Senin ... 7 = Minggu. */
    val days: Set<Int>,
) {
    val active get() = enabled && days.isNotEmpty() && startMinutes != endMinutes

    /** [isoDay]: 1 = Senin ... 7 = Minggu; [minute]: menit sejak tengah malam. */
    fun isLockedAt(isoDay: Int, minute: Int): Boolean {
        if (!active) return false
        val yesterday = if (isoDay == 1) 7 else isoDay - 1
        return if (startMinutes > endMinutes) {
            // Melewati tengah malam: kunci Senin 22.00 berlanjut sampai
            // Selasa 09.00.
            (minute >= startMinutes && isoDay in days) ||
                (minute < endMinutes && yesterday in days)
        } else {
            isoDay in days && minute >= startMinutes && minute < endMinutes
        }
    }

    /** Sedang terkunci pada waktu HP saat ini. */
    fun isLockedAt(time: Calendar) = isLockedAt(isoDay(time), minuteOf(time))

    companion object {
        /** 1 = Senin ... 7 = Minggu (Calendar memakai 1 = Minggu). */
        fun isoDay(time: Calendar) = ((time.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1

        fun minuteOf(time: Calendar) =
            time.get(Calendar.HOUR_OF_DAY) * 60 + time.get(Calendar.MINUTE)

        /**
         * Jeda sampai sesaat setelah pergantian menit berikutnya. Jadwal
         * diatur per menit, jadi pemeriksaan tepat setelah pergantian menit
         * membuat kunci mulai tepat waktu, bukan sampai setengah menit
         * kemudian.
         */
        fun delayToNextMinute(nowMillis: Long): Long = 60_000 - nowMillis % 60_000 + 200

        /** Bentuk yang ditulis Dart: {"enabled":true,"start":"22:00",...}. */
        fun parse(json: String?): LockSchedule? {
            if (json.isNullOrBlank()) return null
            return try {
                val obj = JSONObject(json)
                val start = minutes(obj.optString("start")) ?: return null
                val end = minutes(obj.optString("end")) ?: return null
                val list = obj.optJSONArray("days")
                val days = buildSet {
                    if (list != null) {
                        for (i in 0 until list.length()) {
                            val d = list.optInt(i, 0)
                            if (d in 1..7) add(d)
                        }
                    }
                }
                LockSchedule(obj.optBoolean("enabled", false), start, end, days)
            } catch (_: Exception) {
                null
            }
        }

        fun minutes(clock: String?): Int? {
            val match = Regex("""^(\d{1,2}):(\d{2})$""").find(clock ?: return null) ?: return null
            val h = match.groupValues[1].toInt()
            val m = match.groupValues[2].toInt()
            if (h > 23 || m > 59) return null
            return h * 60 + m
        }
    }
}
