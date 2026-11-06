package id.aura.aura

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationTextTest {
    @Test
    fun `jumlah pesan dibuang dari nama grup`() {
        // Diambil dari notifikasi WhatsApp sungguhan di ponsel realme.
        assertEquals(
            "LOMBA SIIF GO INTER🥺🙏🏻",
            NotificationText.cleanTitle("LOMBA SIIF GO INTER🥺🙏🏻 (4 pesan)"),
        )
        assertEquals("Keluarga", NotificationText.cleanTitle("Keluarga (12 messages)"))
        assertEquals("Kelas 5A", NotificationText.cleanTitle("Kelas 5A (1 message)"))
    }

    @Test
    fun `nama grup yang sama tetap sama walau jumlahnya berubah`() {
        assertEquals(
            NotificationText.cleanTitle("Kelas 5A (4 pesan)"),
            NotificationText.cleanTitle("Kelas 5A (5 pesan)"),
        )
    }

    @Test
    fun `tanda kurung lain tidak disentuh`() {
        assertEquals("Budi (kakak)", NotificationText.cleanTitle("Budi (kakak)"))
        assertEquals("Tim (2024)", NotificationText.cleanTitle("Tim (2024)"))
    }

    @Test
    fun `judul kosong menjadi null`() {
        assertNull(NotificationText.cleanTitle(null))
        assertNull(NotificationText.cleanTitle("  "))
        assertNull(NotificationText.cleanTitle("(3 pesan)"))
    }
}
