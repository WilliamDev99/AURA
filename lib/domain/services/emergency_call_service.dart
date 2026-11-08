import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/phone_number.dart';

/// Hasil percobaan menelepon orang tua lewat WhatsApp.
enum WhatsAppCallOutcome {
  /// Panggilan suara WhatsApp langsung dimulai.
  called,

  /// Nomor orang tua tidak ada di Kontak (atau izin Kontak tidak ada):
  /// chat WhatsApp orang tua dibuka, anak tinggal menekan ikon telepon.
  chatOpened,

  /// WhatsApp tidak terpasang, tidak ada nomor, atau gagal dibuka.
  failed,
}

/// Kesiapan "Telepon lewat WhatsApp" di perangkat anak.
enum WhatsAppCallStatus {
  /// WhatsApp tidak terpasang atau nomor orang tua belum diisi.
  unavailable,

  /// Tombol WhatsApp saat SOS langsung menelepon.
  ready,

  /// Tombol WhatsApp baru membuka chat: nomor orang tua belum ada di
  /// Kontak, izin Kontak belum diberikan, atau WhatsApp belum tersinkron.
  needsSetup,
}

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

  /// Apakah WhatsApp (biasa atau Business) terpasang di perangkat ini.
  Future<bool> hasWhatsApp() async {
    if (!_isAndroid) return false;
    try {
      return await _native.invokeMethod<bool>('hasWhatsApp') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Menyimpan nomor orang tua di Kontak bila belum ada, supaya WhatsApp
  /// bisa langsung meneleponnya. True bila nomor itu kini ada di Kontak.
  Future<bool> saveParentContact(String? number, {required String name}) async {
    if (number == null || !_isAndroid) return false;
    try {
      final reply = await _native.invokeMethod<String>('saveParentContact', {
        'number': number,
        'name': name,
      });
      return reply == 'added' || reply == 'exists';
    } catch (error) {
      debugPrint('AURA: nomor orang tua belum tersimpan di Kontak ($error).');
      return false;
    }
  }

  /// Apakah "Telepon lewat WhatsApp" akan langsung menelepon [number],
  /// bukan sekadar membuka chat.
  Future<bool> whatsAppCallReady(String? number) async {
    final digits = number == null ? null : whatsAppDigits(number);
    if (digits == null || !_isAndroid) return false;
    try {
      return await _native.invokeMethod<bool>('whatsAppCallReady', {
            'digits': digits,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Menelepon orang tua lewat WhatsApp, untuk HP tanpa pulsa atau tablet
  /// tanpa SIM. Berbeda dengan [call], jalur ini butuh internet.
  Future<WhatsAppCallOutcome> callViaWhatsApp(String? number) async {
    final digits = number == null ? null : whatsAppDigits(number);
    if (digits == null || !_isAndroid) return WhatsAppCallOutcome.failed;
    try {
      final reply = await _native.invokeMethod<String>('placeWhatsAppCall', {
        'digits': digits,
      });
      return switch (reply) {
        'called' => WhatsAppCallOutcome.called,
        'chat_opened' => WhatsAppCallOutcome.chatOpened,
        _ => WhatsAppCallOutcome.failed,
      };
    } catch (error) {
      debugPrint('AURA: panggilan WhatsApp gagal ($error).');
      return WhatsAppCallOutcome.failed;
    }
  }
}
