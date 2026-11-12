import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../data/aura_repository.dart';
import 'sos_alarm.dart';

/// Penangan pesan latar belakang.
///
/// Harus berupa fungsi tingkat atas dengan anotasi `vm:entry-point` karena
/// Android menjalankannya di isolate terpisah saat aplikasi sedang mati. Di
/// sini sengaja tidak ada pekerjaan berat: Android sudah menampilkan
/// notifikasinya sendiri dari payload `notification`, dan alarm SOS
/// dibunyikan SosPushReceiver.kt langsung dari pesannya.
@pragma('vm:entry-point')
Future<void> auraBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'AURA: peringatan diterima di latar belakang (${message.data['riskLevel']}).',
  );
}

/// Menghubungkan peringatan dari server ke notifikasi di perangkat orang tua.
///
/// Alur lengkapnya:
/// 1. Anak melaporkan, AURA mendeteksi pesan berbahaya, atau anak menekan
///    tombol SOS.
/// 2. Peringatan masuk ke tabel `alerts`.
/// 3. Fungsi `notify-parents` mengirimnya ke perangkat orang tua lewat FCM.
/// 4. Kelas ini memunculkan notifikasinya, lalu mengantar orang tua
///    langsung ke halaman rincian saat notifikasi diketuk. SOS membunyikan
///    alarm sampai dimatikan (lihat [SosAlarm]); kelas ini menampilkan kartu
///    "Matikan alarm" di layar AURA selama alarm itu berbunyi.
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
    description: 'Ancaman serius terdeteksi.',
    importance: Importance.max,
  );

  final _local = FlutterLocalNotificationsPlugin();

  AuraRepository? _repository;
  GoRouter? _router;
  StreamSubscription<String>? _registrationSub;

  /// Selesai saat sesi pengguna sudah dipulihkan. Rute yang dibuka sebelum
  /// itu dibelokkan router ke layar memuat, lalu ke beranda.
  Future<void> Function()? _untilReady;

  /// Firebase Installation ID perangkat ini — alamat tujuan peringatan.
  String? _deviceId;
  bool _started = false;
  bool _localReady = false;

  /// Notifikasi yang terakhir membuka AURA. Intent pembukanya tetap sama
  /// selama layar itu hidup, jadi jangan dibuka ulang setiap kali kembali.
  String? _handledLaunch;

  final _sosAlarm = ValueNotifier<String?>(null);
  Timer? _sosWatch;

  String? get deviceId => _deviceId;

  /// Rute peringatan SOS yang alarmnya sedang berbunyi di HP ini (kosong
  /// untuk tes alarm), atau null bila tidak ada.
  ValueListenable<String?> get sosAlarm => _sosAlarm;

  /// Menyiapkan izin, saluran notifikasi, dan pendengar pesan.
  /// Aman dipanggil berulang kali; isinya hanya berjalan sekali.
  Future<void> attach({
    required GoRouter router,
    required AuraRepository repository,
    Future<void> Function()? untilReady,
  }) async {
    _router = router;
    _repository = repository;
    _untilReady = untilReady;

    // Web memakai service worker dengan penyiapan tersendiri, dan
    // flutter_local_notifications tidak berjalan di sana.
    if (_started || kIsWeb) return;
    _started = true;

    try {
      await FirebaseMessaging.instance.requestPermission();
      await _prepareLocal();

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

      // Aplikasi yang dibuka dari keadaan mati lewat ketukan notifikasi:
      // notifikasi FCM, atau notifikasi AURA sendiri seperti alarm SOS.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openAlert(initial);
      await _openLaunchNotification();
      await _syncSosAlarm();
    } catch (error) {
      debugPrint('AURA: penyiapan notifikasi gagal ($error).');
    }
  }

  /// Dipanggil setiap AURA kembali ke depan, termasuk setelah panel
  /// notifikasi ditutup.
  Future<void> onResumed() async {
    if (!_localReady) return;
    try {
      await _openLaunchNotification();
      await _syncSosAlarm();
    } catch (error) {
      debugPrint('AURA: status alarm SOS tidak terbaca ($error).');
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

  /// Menghentikan alarm SOS dari kartu di layar AURA.
  Future<void> stopSosAlarm() async {
    _setSosAlarm(null);
    await SosAlarm.stop();
  }

  /// Tombol "Coba bunyikan" di Profil orang tua: membunyikan alarm yang sama
  /// persis dengan SOS sungguhan. False bila notifikasi AURA dimatikan, yang
  /// berarti alarm SOS pun tidak akan pernah berbunyi.
  Future<bool> testSosAlarm() async {
    if (kIsWeb) return false;
    try {
      await _prepareLocal();
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null &&
          !(await android.areNotificationsEnabled() ?? false) &&
          !(await android.requestNotificationsPermission() ?? false)) {
        return false;
      }
      if (!await SosAlarm.test()) return false;
      _setSosAlarm('');
      return true;
    } catch (error) {
      debugPrint('AURA: tes alarm SOS gagal ($error).');
      return false;
    }
  }

  Future<void> _prepareLocal() async {
    if (_localReady) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_alertChannel);
    await android?.createNotificationChannel(_criticalChannel);
    _localReady = true;
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
    try {
      if (SosAlarm.isSos(message.data)) {
        await _ringSos(message.data);
        return;
      }
      await _showAlert(message);
    } catch (error) {
      debugPrint('AURA: notifikasi gagal ditampilkan ($error).');
    }
  }

  /// SOS saat AURA sedang dibuka. Alarmnya sudah dibunyikan
  /// SosPushReceiver.kt dari pesan yang sama; di sini peringatannya langsung
  /// dibuka di layar, dengan kartu "Matikan alarm".
  Future<void> _ringSos(Map<String, dynamic> data) async {
    final route = data['route'] as String? ?? '';
    _setSosAlarm(route);
    if (route.isNotEmpty) unawaited(_go(route));
  }

  Future<void> _showAlert(RemoteMessage message) async {
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
    if (route != null && route.isNotEmpty) unawaited(_go(route));
  }

  static String _launchKey(NotificationResponse response) =>
      '${response.id}|${response.actionId}|${response.payload}';

  void _onNotificationResponse(NotificationResponse response) {
    _handledLaunch = _launchKey(response);
    final route = response.payload;
    if (route != null && route.isNotEmpty) unawaited(_go(route));
  }

  /// Layar AURA dibuat ulang oleh ketukan notifikasi. Bila mesin Flutter-nya
  /// masih hidup (lihat AuraEngine.kt), plugin tidak memanggil
  /// [_onNotificationResponse], jadi ditanyakan di sini.
  Future<void> _openLaunchNotification() async {
    final launch = await _local.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch == null || !launch.didNotificationLaunchApp) return;
    if (response == null || _launchKey(response) == _handledLaunch) return;
    _onNotificationResponse(response);
  }

  /// Menyamakan kartu alarm di layar dengan alarmnya. Alarm dibunyikan
  /// kode Android selagi layar AURA tidak tahu, dan bisa dimatikan lewat
  /// notifikasinya tanpa AURA diberi tahu.
  Future<void> _syncSosAlarm() async {
    // Dibuka dari notifikasi alarm: alarmnya sudah dimatikan, tinggal
    // membuka rinciannya.
    final opened = await SosAlarm.takeOpenedRoute();
    if (opened != null && opened.isNotEmpty) unawaited(_go(opened));

    final alarm = await SosAlarm.state();
    if (!alarm.ringing) {
      _setSosAlarm(null);
      return;
    }
    final route = alarm.route ?? '';
    final wasSilent = _sosAlarm.value == null;
    _setSosAlarm(route);
    // Orang tua membuka AURA sendiri selagi alarm berbunyi: langsung ke
    // peringatannya, sekali saja.
    if (wasSilent && route.isNotEmpty) unawaited(_go(route));
  }

  void _setSosAlarm(String? route) {
    _sosAlarm.value = route;
    if (route == null) {
      _sosWatch?.cancel();
      _sosWatch = null;
      return;
    }
    // "Matikan alarm" di notifikasi berjalan di luar AURA. Diperiksa berkala
    // supaya kartu alarm di layar ikut hilang.
    _sosWatch ??= Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!(await SosAlarm.state()).ringing) _setSosAlarm(null);
    });
  }

  /// Membuka [route] setelah sesi siap. Saat AURA baru dibuka dari keadaan
  /// mati, router masih menahan semua rute di layar memuat.
  Future<void> _go(String route) async {
    await _untilReady?.call();
    // Biarkan router selesai berpindah dari layar memuat lebih dulu.
    await WidgetsBinding.instance.endOfFrame;
    _router?.go(route);
  }

  Future<void> dispose() async {
    await _registrationSub?.cancel();
    _registrationSub = null;
    _sosWatch?.cancel();
    _sosWatch = null;
  }
}
