import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hasil percobaan menelepon orang tua saat tombol darurat ditekan.
enum CallOutcome {
  /// Panggilan langsung keluar.
  called,

  /// Izin telepon tidak ada: aplikasi Telepon dibuka dengan nomor terisi,
  /// anak tinggal menekan tombol panggil.
  dialerOpened,

  /// Orang tua belum mengisi nomor HP.
  noNumber,

  /// Perangkat tidak bisa menelepon sama sekali (mis. tablet tanpa SIM).
  failed,
}

/// Menelepon orang tua lewat jaringan seluler.
///
/// Sengaja tidak memakai internet: jalur ini harus tetap berfungsi justru
/// ketika peringatan lewat Supabase gagal terkirim.
class EmergencyCallService {
  const EmergencyCallService();

  static const _native = MethodChannel('id.aura/sos');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Diminta setelah anak menyetujui perlindungan, bukan saat darurat:
  /// dialog izin di tengah keadaan panik menunda pertolongan.
  Future<bool> requestPermission() async {
    if (!_isAndroid) return false;
    try {
      return await _native.invokeMethod<bool>('requestCallPermission') ?? false;
    } catch (error) {
      debugPrint('AURA: permintaan izin telepon gagal ($error).');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    if (!_isAndroid) return false;
    try {
      return await _native.invokeMethod<bool>('hasCallPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<CallOutcome> call(String? number) async {
    if (number == null || number.isEmpty) return CallOutcome.noNumber;

    if (_isAndroid) {
      try {
        final reply = await _native.invokeMethod<String>('placeCall', {
          'number': number,
        });
        if (reply == 'called') return CallOutcome.called;
        if (reply == 'no_number') return CallOutcome.noNumber;
        // 'no_permission' atau 'failed': coba lewat aplikasi Telepon.
      } catch (error) {
        debugPrint('AURA: panggilan langsung gagal ($error).');
      }
    }

    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: number));
      return opened ? CallOutcome.dialerOpened : CallOutcome.failed;
    } catch (error) {
      debugPrint('AURA: aplikasi Telepon tidak bisa dibuka ($error).');
      return CallOutcome.failed;
    }
  }
}
