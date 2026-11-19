import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Melindungi AURA dari penghapusan di HP anak.
///
/// Selama AURA aktif sebagai admin perangkat, Android menolak menghapusnya,
/// baik dari layar utama maupun dari Pengaturan. Untuk menghapusnya, anak
/// meminta izin orang tua lewat AURA; setelah diizinkan, [uninstall] melepas
/// perlindungan itu dan membuka dialog hapus aplikasi. Bagian Android-nya ada
/// di AuraDeviceAdmin.kt.
class UninstallGuard {
  const UninstallGuard();

  static const _native = MethodChannel('id.aura/sos');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Null bila tidak bisa diketahui: bukan Android, atau AURA sedang
  /// berjalan tanpa layar.
  Future<bool?> isProtected() async {
    if (!_isAndroid) return null;
    try {
      return await _native.invokeMethod<bool>('uninstallProtection');
    } catch (_) {
      return null;
    }
  }

  /// Membuka dialog Android "Aktifkan aplikasi admin perangkat?".
  Future<void> protect() => _call('protectFromUninstall');

  /// Melepas perlindungan lalu membuka dialog hapus AURA. Hanya dipanggil
  /// setelah orang tua mengizinkan.
  Future<void> uninstall() => _call('uninstallAura');

  Future<void> _call(String method) async {
    if (!_isAndroid) return;
    try {
      await _native.invokeMethod<void>(method);
    } catch (error) {
      debugPrint('AURA: perlindungan hapus gagal dibuka ($error).');
    }
  }
}
