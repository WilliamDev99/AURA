import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Izin "Akses notifikasi" yang dibutuhkan untuk memindai pesan masuk.
///
/// Berbeda dengan izin lain, Android tidak punya dialog untuk ini: anak harus
/// menyalakannya sendiri di Pengaturan. Kelas ini hanya memeriksa statusnya
/// dan membukakan halaman pengaturannya.
class NotificationAccess {
  const NotificationAccess();

  static const _native = MethodChannel('id.aura/sos');

  /// Terdaftar di mesin bersama (`AuraEngine.kt`), jadi tetap bisa dijawab
  /// saat aplikasi dinyalakan pemindai tanpa layar.
  static const _engine = MethodChannel('id.aura/scan');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Null bila tidak bisa diketahui (bukan Android).
  Future<bool?> isGranted() async {
    if (!_isAndroid) return null;
    try {
      return await _engine.invokeMethod<bool>('hasNotificationAccess');
    } catch (error) {
      debugPrint('AURA: status akses notifikasi tidak terbaca ($error).');
      return null;
    }
  }

  Future<void> openSettings() async {
    if (!_isAndroid) return;
    try {
      await _native.invokeMethod<void>('openNotificationAccessSettings');
    } catch (error) {
      debugPrint('AURA: pengaturan akses notifikasi gagal dibuka ($error).');
    }
  }
}
