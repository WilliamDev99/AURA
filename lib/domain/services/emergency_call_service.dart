import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Membuka aplikasi Telepon dengan nomor orang tua sudah terisi.
///
/// Bukan jalur utama SOS: tombol SOS membunyikan alarm di HP orang tua lewat
/// internet. Ini cadangan untuk saat peringatan itu tidak bisa terkirim,
/// mis. internet anak mati, karena telepon seluler tetap jalan tanpa
/// internet. Anak sendiri yang menekan tombol panggil, jadi AURA tidak butuh
/// izin menelepon.
class EmergencyCallService {
  const EmergencyCallService();

  /// True bila aplikasi Telepon terbuka.
  Future<bool> openDialer(String? number) async {
    if (number == null || number.isEmpty) return false;
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (error) {
      debugPrint('AURA: aplikasi Telepon tidak bisa dibuka ($error).');
      return false;
    }
  }
}
