package id.aura.aura

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SosAlarmInfoTest {
    @Test
    fun alertIdBecomesShortId() {
        assertEquals("1F3A9C", SosAlarmInfo.shortId("1f3a9c42-7b1d-4c3e-9a55-0d2b6e8f1a77"))
        assertNull(SosAlarmInfo.shortId(null))
        assertNull(SosAlarmInfo.shortId("zz"))
    }
}
