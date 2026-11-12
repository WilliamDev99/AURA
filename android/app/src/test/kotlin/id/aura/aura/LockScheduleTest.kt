package id.aura.aura

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/** Contoh yang sama dipakai test/lock_schedule_test.dart. */
class LockScheduleTest {
    private val nightly = LockSchedule(true, 22 * 60, 9 * 60, setOf(1, 2, 3, 4, 5, 6, 7))
    private val schoolNights = LockSchedule(true, 22 * 60, 9 * 60, setOf(1, 2, 3, 4, 5))

    @Test
    fun locksOvernight() {
        assertFalse(nightly.isLockedAt(1, 21 * 60 + 59))
        assertTrue(nightly.isLockedAt(1, 22 * 60))
        assertTrue(nightly.isLockedAt(2, 3 * 60))
        assertTrue(nightly.isLockedAt(2, 8 * 60 + 59))
        assertFalse(nightly.isLockedAt(2, 9 * 60))
        assertFalse(nightly.isLockedAt(2, 12 * 60))
    }

    @Test
    fun dayIsTheNightTheLockStarts() {
        // Jumat malam terkunci, sampai Sabtu 09.00.
        assertTrue(schoolNights.isLockedAt(5, 23 * 60))
        assertTrue(schoolNights.isLockedAt(6, 8 * 60))
        // Sabtu malam bebas.
        assertFalse(schoolNights.isLockedAt(6, 23 * 60))
        // Minggu malam bebas, tapi Senin dini hari juga bebas: kuncinya
        // milik Minggu.
        assertFalse(schoolNights.isLockedAt(1, 2 * 60))
        assertTrue(schoolNights.isLockedAt(1, 22 * 60))
    }

    @Test
    fun sameDayWindow() {
        val afternoon = LockSchedule(true, 13 * 60, 15 * 60, setOf(3))
        assertTrue(afternoon.isLockedAt(3, 14 * 60))
        assertFalse(afternoon.isLockedAt(3, 15 * 60))
        assertFalse(afternoon.isLockedAt(4, 14 * 60))
    }

    @Test
    fun offOrEmptyNeverLocks() {
        assertFalse(nightly.copy(enabled = false).isLockedAt(1, 23 * 60))
        assertFalse(nightly.copy(days = emptySet()).isLockedAt(1, 23 * 60))
    }

    @Test
    fun readsClock() {
        assertEquals(22 * 60, LockSchedule.minutes("22:00"))
        assertEquals(9 * 60 + 5, LockSchedule.minutes("9:05"))
        assertNull(LockSchedule.minutes("24:00"))
        assertNull(LockSchedule.minutes("abc"))
    }

    @Test
    fun readsPhoneClock() {
        // Kamis, 12 November 2026, 22.15.
        val thursday = Calendar.getInstance().apply { set(2026, Calendar.NOVEMBER, 12, 22, 15, 0) }
        assertEquals(4, LockSchedule.isoDay(thursday))
        assertEquals(22 * 60 + 15, LockSchedule.minuteOf(thursday))
        assertTrue(nightly.isLockedAt(thursday))
        val sunday = Calendar.getInstance().apply { set(2026, Calendar.NOVEMBER, 15, 12, 0, 0) }
        assertEquals(7, LockSchedule.isoDay(sunday))
    }

    @Test
    fun checksRightAfterTheMinuteTurns() {
        // 22.14.59: diperiksa lagi tepat setelah 22.15.00, bukan setengah
        // menit kemudian.
        val minute = 60_000L
        assertEquals(1_000L + 200, LockSchedule.delayToNextMinute(100 * minute - 1_000))
        assertEquals(minute + 200, LockSchedule.delayToNextMinute(100 * minute))
    }
}
