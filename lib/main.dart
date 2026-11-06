import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/l10n/l10n.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_scanner.dart';
import 'core/services/push_service.dart';
import 'core/theme/aura_theme.dart';
import 'data/aura_repository.dart';
import 'data/demo_repository.dart';
import 'data/firestore_repository.dart';
import 'data/supabase_repository.dart';
import 'domain/services/emergency_call_service.dart';
import 'domain/services/location_service.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'supabase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bahasa dibaca sebelum layar pertama, supaya tidak berkedip dari bahasa
  // Indonesia ke bahasa Inggris.
  await Lang.instance.load();
  final backend = await _startBackend();

  // Dibuat di sini, bukan di dalam widget: di ponsel anak, Android bisa
  // menjalankan main() hanya untuk pemindai pesan, tanpa layar apa pun
  // (lihat AuraEngine.kt). Widget baru dibangun saat layar dibuka, sedangkan
  // pemindai harus sudah bekerja sejak awal.
  final state = AppState(repository: backend.repository);
  NotificationScanner(state).start();

  runApp(
    AuraApp(
      repository: backend.repository,
      pushReady: backend.pushReady,
      state: state,
    ),
  );
}

/// Backend yang berhasil disiapkan saat aplikasi dijalankan.
class _Backend {
  const _Backend(this.repository, {required this.pushReady});

  final AuraRepository repository;

  /// Notifikasi push selalu lewat Firebase Cloud Messaging, apa pun basis
  /// datanya. Supabase tidak menyediakan layanan push, dan FCM adalah
  /// satu-satunya jalan resmi mengirim notifikasi ke perangkat Android.
  final bool pushReady;
}

/// Memilih penyimpanan sesuai yang sudah dikonfigurasi, dengan urutan:
/// Supabase, lalu Firebase, lalu data demo di memori.
Future<_Backend> _startBackend() async {
  final pushReady = await _initFirebaseMessaging();

  if (SupabaseOptions.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseOptions.url,
        publishableKey: SupabaseOptions.publishableKey,
      );
      debugPrint('AURA: tersambung ke Supabase.');
      return _Backend(SupabaseRepository(), pushReady: pushReady);
    } catch (error) {
      debugPrint('AURA: Supabase gagal dimulai ($error).');
    }
  }

  if (pushReady) {
    try {
      final repository = FirestoreRepository();
      debugPrint('AURA: tersambung ke Firebase Firestore.');
      return _Backend(repository, pushReady: true);
    } catch (error) {
      debugPrint('AURA: Firestore gagal dimulai ($error).');
    }
  }

  debugPrint(
    'AURA: belum ada backend yang dikonfigurasi. Berjalan dengan data demo '
    'di memori, notifikasi push nonaktif.',
  );
  return _Backend(DemoRepository(), pushReady: false);
}

/// Menyiapkan Firebase hanya untuk pengiriman notifikasi.
Future<bool> _initFirebaseMessaging() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (_) {
    return false;
  }
}

class AuraApp extends StatefulWidget {
  const AuraApp({
    super.key,
    required this.repository,
    this.pushReady = false,
    this.locationService = const LocationService(),
    this.callService = const EmergencyCallService(),
    this.state,
  });

  final AuraRepository repository;

  /// Status yang sudah dibuat di luar widget (lihat main). Bila null, AuraApp
  /// membuat dan memiliki status sendiri, seperti di test.
  final AppState? state;

  /// Push hanya disiapkan bila Firebase Cloud Messaging tersedia.
  final bool pushReady;

  /// Bisa diganti pada pengujian, agar tidak menunggu perangkat GPS asli.
  final LocationService locationService;

  /// Bisa diganti pada pengujian, agar test tidak benar-benar menelepon.
  final EmergencyCallService callService;

  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp> {
  late final AppState _state =
      widget.state ??
      AppState(
        repository: widget.repository,
        locationService: widget.locationService,
        callService: widget.callService,
      );

  // Router dibuat sekali di sini, bukan di dalam build: GoRouter yang
  // dibangun ulang akan kehilangan tumpukan navigasi pengguna.
  late final GoRouter _router = createRouter(_state);

  /// Dipakai untuk mendeteksi pergantian pengguna, karena AppState memberi
  /// notifikasi untuk banyak hal lain juga (peringatan baru, bukti, dsb).
  String? _registeredUserId;

  /// Memeriksa ulang status pemindaian chat setiap aplikasi kembali ke
  /// depan, mis. setelah anak mengubah "Akses notifikasi" di Pengaturan.
  late final AppLifecycleListener _lifecycle;

  /// Selama AURA berjalan (juga di latar belakang untuk pemindai), ponsel
  /// anak berkala mengabarkan bahwa ia masih aktif.
  late final Timer _heartbeat;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _state.refreshChatScanStatus();
        _state.markActive();
      },
    );
    _heartbeat = Timer.periodic(
      AppState.heartbeatEvery,
      (_) => _state.markActive(),
    );
    Lang.instance.addListener(_onLanguageChanged);
    if (widget.pushReady) _setUpPush();
  }

  /// Teks memakai `tr()`, yang tidak terikat ke widget mana pun. Setelah
  /// bahasa berganti, seluruh tampilan dibangun ulang di tempat: halaman yang
  /// sedang dibuka dan isiannya tetap.
  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
    rebuildAllChildren(context);
  }

  Future<void> _setUpPush() async {
    await PushService.instance.attach(
      router: _router,
      repository: widget.repository,
    );

    // Token dilepas sebelum sesi berakhir, selagi pengguna masih berwenang
    // menulis ke barisnya sendiri.
    _state.onBeforeSignOut = PushService.instance.clearToken;
    _state.addListener(_syncPushRegistration);
    _syncPushRegistration();
  }

  void _syncPushRegistration() {
    final userId = _state.user?.id;
    if (userId == _registeredUserId) return;
    _registeredUserId = userId;
    if (userId != null) PushService.instance.syncToken();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _heartbeat.cancel();
    Lang.instance.removeListener(_onLanguageChanged);
    _state.removeListener(_syncPushRegistration);
    // Status milik main() tetap hidup: pemindai pesan masih memakainya.
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: MaterialApp.router(
        title: 'AURA',
        debugShowCheckedModeBanner: false,
        theme: AuraTheme.build(),
        routerConfig: _router,
      ),
    );
  }
}
