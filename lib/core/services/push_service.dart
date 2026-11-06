import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../data/aura_repository.dart';

/// Penangan pesan latar belakang.
///
/// Harus berupa fungsi tingkat atas dengan anotasi `vm:entry-point` karena
/// Android menjalankannya di isolate terpisah saat aplikasi sedang mati. Di
/// sini sengaja tidak ada pekerjaan berat: Android sudah menampilkan
/// notifikasinya sendiri dari payload `notification`.
@pragma('vm:entry-point')
Future<void> auraBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'AURA: peringatan diterima di latar belakang (${message.data['riskLevel']}).',
  );
}

/// Menghubungkan peringatan dari server ke notifikasi di perangkat orang tua.
///
/// Alur lengkapnya:
/// 1. Anak melaporkan atau AURA mendeteksi pesan berbahaya.
/// 2. Peringatan masuk ke Firestore.
/// 3. Cloud Function `onAlertCreated` mengirimnya ke perangkat orang tua
///    (lihat `functions/src/notify.ts`).
/// 4. Kelas ini memunculkan notifikasinya, lalu mengantar orang tua langsung
///    ke halaman rincian saat notifikasi diketuk.
///
/// Hanya aktif bila Firebase sudah dikonfigurasi. Dalam mode demo tidak ada
/// yang dijalankan, dan kegagalan apa pun di sini tidak menjatuhkan aplikasi:
/// dashboard tetap menampilkan peringatan secara langsung walau push mati.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const _alertChannel = AndroidNotificationChannel(
    'aura_alerts',
    'Peringatan AURA',
    description: 'Pemberitahuan saat ditemukan pesan mencurigakan.',
    importance: Importance.high,
  );

  /// Saluran terpisah untuk keadaan darurat, supaya orang tua bisa mengatur
  /// nadanya sendiri tanpa ikut mematikan peringatan biasa.
  static const _criticalChannel = AndroidNotificationChannel(
    'aura_critical',
    'Darurat AURA',
    description: 'Tombol darurat ditekan atau ancaman serius terdeteksi.',
    importance: Importance.max,
  );

  final _local = FlutterLocalNotificationsPlugin();

  AuraRepository? _repository;
  GoRouter? _router;
  StreamSubscription<String>? _registrationSub;

  /// Firebase Installation ID perangkat ini — alamat tujuan peringatan.
  String? _deviceId;
  bool _started = false;

  String? get deviceId => _deviceId;

  /// Menyiapkan izin, saluran notifikasi, dan pendengar pesan.
  /// Aman dipanggil berulang kali; isinya hanya berjalan sekali.
  Future<void> attach({
    required GoRouter router,
    required AuraRepository repository,
  }) async {
    _router = router;
    _repository = repository;

    // Web memakai service worker dengan penyiapan tersendiri, dan
    // flutter_local_notifications tidak berjalan di sana.
    if (_started || kIsWeb) return;
    _started = true;

    try {
      await FirebaseMessaging.instance.requestPermission();
      await _prepareChannels();

      FirebaseMessaging.onBackgroundMessage(auraBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_openAlert);

      // Identitas perangkat tiba lewat stream, termasuk saat Firebase
      // memperbaruinya sendiri di kemudian hari.
      _registrationSub = FirebaseMessaging.instance.onRegistered.listen((id) {
        _deviceId = id;
        _repository?.registerPushToken(id);
        debugPrint('AURA: perangkat terdaftar menerima peringatan.');
      });

      // Aplikasi yang dibuka dari keadaan mati lewat ketukan notifikasi.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openAlert(initial);
    } catch (error) {
      debugPrint('AURA: penyiapan notifikasi gagal ($error).');
    }
  }

  /// Mendaftarkan perangkat ini setelah pengguna masuk.
  Future<void> syncToken() async {
    if (kIsWeb || !_started) return;
    try {
      await FirebaseMessaging.instance.register();
    } catch (error) {
      debugPrint('AURA: pendaftaran perangkat gagal ($error).');
    }
  }

  /// Melepas perangkat ini sebelum pengguna keluar, supaya ponsel yang sudah
  /// bukan miliknya berhenti menerima peringatan keluarga ini.
  Future<void> clearToken() async {
    final id = _deviceId;
    if (kIsWeb || id == null) return;
    try {
      // Dicabut dari daftar lebih dulu, selagi pengguna masih punya izin
      // menulis ke dokumennya sendiri.
      await _repository?.removePushToken(id);
      await FirebaseMessaging.instance.unregister();
      _deviceId = null;
    } catch (error) {
      debugPrint('AURA: pelepasan perangkat gagal ($error).');
    }
  }

  Future<void> _prepareChannels() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _router?.go(route);
      },
    );

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_alertChannel);
    await android?.createNotificationChannel(_criticalChannel);
  }

  /// Apakah notifikasi dibunyikan lewat kanal Darurat. Mengikuti keputusan
  /// server (`urgent`): kata kasar berat juga HARD, tetapi bukan darurat.
  /// Server versi lama belum mengirim `urgent`; saat itu dipakai levelnya.
  @visibleForTesting
  static bool isUrgent(Map<String, dynamic> data) => switch (data['urgent']) {
    final String urgent => urgent == 'true',
    _ => data['riskLevel'] == 'critical',
  };

  /// Android tidak memunculkan notifikasi sendiri saat aplikasi sedang dibuka,
  /// padahal justru saat itulah orang tua perlu langsung tahu.
  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final critical = isUrgent(message.data);
    final channel = critical ? _criticalChannel : _alertChannel;

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: critical ? Priority.max : Priority.high,
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
          category: critical ? AndroidNotificationCategory.alarm : null,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: critical
              ? InterruptionLevel.critical
              : InterruptionLevel.timeSensitive,
        ),
      ),
      payload: message.data['route'] as String?,
    );
  }

  void _openAlert(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) _router?.go(route);
  }

  Future<void> dispose() async {
    await _registrationSub?.cancel();
    _registrationSub = null;
  }
}
