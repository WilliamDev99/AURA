import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Izin yang dibutuhkan jam istirahat di HP anak.
class LockAccess {
  const LockAccess({
    required this.usage,
    required this.overlay,
    required this.battery,
  });

  /// "Akses penggunaan": untuk tahu aplikasi apa yang sedang dibuka.
  final bool usage;

  /// "Tampil di atas aplikasi lain": untuk menutupi aplikasi itu.
  final bool overlay;

  /// Dikecualikan dari penghemat baterai. Tanpa ini, HP seperti Realme dan
  /// OPPO mematikan AURA saat daftar aplikasi terbaru dibersihkan atau mode
  /// game menyala, dan selama itu tidak ada yang mengunci.
  final bool battery;

  bool get ready => usage && overlay && battery;
}

/// Seperti "Akses notifikasi", dua izin pertama tidak punya dialog: anak
/// menyalakannya sendiri di Pengaturan Android. Kelas ini memeriksa
/// statusnya dan membukakan halamannya. Penguncinya sendiri ada di
/// ScreenLock.kt.
class ScreenLockAccess {
  const ScreenLockAccess();

  static const _native = MethodChannel('id.aura/sos');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Null bila tidak bisa diketahui: bukan Android, atau AURA sedang
  /// berjalan tanpa layar (hanya pemindai).
  Future<LockAccess?> check() async {
    if (!_isAndroid) return null;
    try {
      final reply = await _native.invokeMapMethod<String, Object?>(
        'lockAccess',
      );
      if (reply == null) return null;
      return LockAccess(
        usage: reply['usage'] == true,
        overlay: reply['overlay'] == true,
        battery: reply['battery'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> openUsageAccessSettings() => _open('openUsageAccessSettings');

  Future<void> openOverlaySettings() => _open('openOverlaySettings');

  Future<void> openBatterySettings() => _open('openBatterySettings');

  Future<void> _open(String method) async {
    if (!_isAndroid) return;
    try {
      await _native.invokeMethod<void>(method);
    } catch (error) {
      debugPrint('AURA: pengaturan izin jam istirahat gagal dibuka ($error).');
    }
  }
}
