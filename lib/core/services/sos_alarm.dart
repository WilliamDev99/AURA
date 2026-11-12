import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keadaan alarm SOS di HP ini.
class SosAlarmState {
  const SosAlarmState({required this.ringing, this.route});

  final bool ringing;

  /// Rincian peringatan yang alarmnya berbunyi. Null untuk tes alarm.
  final String? route;
}

/// Alarm SOS di HP orang tua: sirene dan getar berulang sampai dimatikan.
///
/// Alarmnya sendiri diputar kode Android (SosAlarmService.kt), seperti
/// aplikasi jam alarm, dan dinyalakan SosPushReceiver.kt langsung dari pesan
/// FCM bertanda `sos`, tanpa menunggu Flutter.
///
/// Suara notifikasi biasa tidak dipakai: Android hanya memutar satu suara
/// notifikasi dalam satu waktu, sehingga SMS atau chat yang masuk langsung
/// membungkam alarm. Kelas ini hanya jembatan dari layar AURA: tes alarm,
/// mematikannya, dan menanyakan keadaannya.
class SosAlarm {
  const SosAlarm._();

  static const _native = MethodChannel('id.aura/sos');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Apakah pesan FCM ini dari tombol SOS anak.
  static bool isSos(Map<String, dynamic> data) => data['sos'] == 'true';

  /// Tombol "Coba bunyikan": alarm yang sama persis dengan SOS sungguhan.
  static Future<bool> test() async {
    if (!_isAndroid) return false;
    try {
      return await _native.invokeMethod<bool>('testSosAlarm') ?? false;
    } catch (error) {
      debugPrint('AURA: tes alarm SOS gagal ($error).');
      return false;
    }
  }

  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _native.invokeMethod<void>('stopSosAlarm');
    } catch (error) {
      debugPrint('AURA: alarm SOS gagal dimatikan ($error).');
    }
  }

  static Future<SosAlarmState> state() async {
    if (!_isAndroid) return const SosAlarmState(ringing: false);
    try {
      final reply = await _native.invokeMapMethod<String, Object?>(
        'sosAlarmState',
      );
      return SosAlarmState(
        ringing: reply?['ringing'] == true,
        route: reply?['route'] as String?,
      );
    } catch (_) {
      return const SosAlarmState(ringing: false);
    }
  }

  /// Rincian SOS yang baru dibuka orang tua dari notifikasi alarm. Diambil
  /// sekali; berikutnya null.
  static Future<String?> takeOpenedRoute() async {
    if (!_isAndroid) return null;
    try {
      return await _native.invokeMethod<String>('takeSosRoute');
    } catch (_) {
      return null;
    }
  }
}
