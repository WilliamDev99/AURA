package id.aura.aura

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WhatsAppContactTest {
    private val parent = "6281234567890"

    @Test
    fun `ID WhatsApp nomor orang tua cocok`() {
        assertTrue(WhatsAppContact.matches("6281234567890@s.whatsapp.net", null, parent))
    }

    @Test
    fun `label panggilan suara dipakai bila ID tidak terbaca`() {
        assertTrue(WhatsAppContact.matches(null, "Panggilan suara +62 812-3456-7890", parent))
        assertTrue(WhatsAppContact.matches(null, "Voice call 0812 3456 7890", parent))
    }

    @Test
    fun `nomor lain tidak cocok`() {
        assertFalse(WhatsAppContact.matches("6281234567891@s.whatsapp.net", null, parent))
        assertFalse(WhatsAppContact.matches(null, "Panggilan suara +62 812-3456-7891", parent))
        // Nomor yang hanya berawalan sama tetap nomor orang lain.
        assertFalse(WhatsAppContact.matches("62812345678901@s.whatsapp.net", null, parent))
    }

    @Test
    fun `grup dan baris kosong tidak pernah cocok`() {
        assertFalse(WhatsAppContact.matches("6281234567890-1600000000@g.us", null, parent))
        assertFalse(WhatsAppContact.matches(null, null, parent))
        assertFalse(WhatsAppContact.matches("6281234567890@s.whatsapp.net", null, ""))
    }
}
