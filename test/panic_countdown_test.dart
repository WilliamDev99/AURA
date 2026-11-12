import 'dart:async';

import 'package:aura/data/aura_repository.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/evidence_item.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/domain/services/emergency_call_service.dart';
import 'package:aura/domain/services/location_service.dart';
import 'package:aura/features/child/child_home_page.dart';
import 'package:aura/main.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokasi tiruan: menjawab seketika, supaya test tidak menunggu perangkat
/// GPS yang memang tidak ada di lingkungan pengujian.
class _FakeLocation extends LocationService {
  const _FakeLocation(this.result);

  factory _FakeLocation.found() => const _FakeLocation(
    LocationResult.found(
      latitude: -6.2,
      longitude: 106.8,
      accuracyMetres: 10,
      fixedAt: null,
      isLastKnown: false,
    ),
  );

  factory _FakeLocation.unavailable() => const _FakeLocation(
    LocationResult.failed(LocationFailure.serviceDisabled),
  );

  final LocationResult result;

  @override
  Future<LocationResult> current({Duration timeout = Duration.zero}) async =>
      result;

  @override
  Future<bool> requestPermission() async => result.hasPosition;
}

/// Aplikasi Telepon tiruan: mencatat nomor yang dibuka, tanpa benar-benar
/// membuka apa pun.
class _FakeDialer extends EmergencyCallService {
  _FakeDialer({this.opens = true});

  /// False meniru tablet tanpa SIM: aplikasi Telepon tidak ada.
  final bool opens;
  final opened = <String?>[];

  @override
  Future<bool> openDialer(String? number) async {
    opened.add(number);
    return number != null && opens;
  }
}

/// Meniru HP anak tanpa internet: menyimpan bukti dan peringatan gagal.
/// [online] bisa dinyalakan di tengah test, seperti sinyal yang kembali.
class _OfflineRepository extends DemoRepository {
  bool online = false;

  @override
  Future<EvidenceItem> appendEvidence({
    required String childId,
    required EvidenceKind kind,
    required DateTime capturedAt,
    required String description,
    required String payload,
    String? alertId,
    String? storagePath,
    String? consentNote,
  }) {
    if (!online) return Future.error(const _NoInternet());
    return super.appendEvidence(
      childId: childId,
      kind: kind,
      capturedAt: capturedAt,
      description: description,
      payload: payload,
      alertId: alertId,
      storagePath: storagePath,
      consentNote: consentNote,
    );
  }
}

class _NoInternet implements Exception {
  const _NoInternet();
  @override
  String toString() => 'SocketException: Failed host lookup';
}

/// Tanpa internet, dan orang tuanya belum mengisi nomor HP.
class _OfflineNoNumberRepository extends _OfflineRepository {
  @override
  Future<String?> emergencyNumber() async => null;
}

/// Jaringan yang tidak pernah menjawab: permintaan menggantung, tidak gagal.
class _HangingRepository extends DemoRepository {
  @override
  Future<EvidenceItem> appendEvidence({
    required String childId,
    required EvidenceKind kind,
    required DateTime capturedAt,
    required String description,
    required String payload,
    String? alertId,
    String? storagePath,
    String? consentNote,
  }) => Completer<EvidenceItem>().future;
}

/// GPS yang tidak pernah menjawab, mis. di dalam gedung.
class _HangingLocation extends LocationService {
  const _HangingLocation();

  @override
  Future<LocationResult> current({Duration timeout = Duration.zero}) =>
      Completer<LocationResult>().future;

  @override
  Future<bool> requestPermission() async => true;
}

/// Perilaku Panic Orb: "tekan sekali untuk SOS", langsung terkirim tanpa
/// hitung mundur. Anak yang sedang dalam bahaya tidak boleh dibuat menunggu.
void main() {
  // Dibuat di dalam test: finder semantik butuh binding yang sudah siap.
  Finder orb() => find.bySemanticsLabel(
    'Tombol darurat. Ketuk untuk mengirim SOS ke orang tua.',
  );

  Future<AppState> openChildHome(
    WidgetTester tester, {
    LocationService? location,
    EmergencyCallService? dialer,
    AuraRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(1344, 2992);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AuraApp(
        repository: repository ?? DemoRepository(),
        locationService: location ?? _FakeLocation.found(),
        callService: dialer ?? _FakeDialer(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Handphone Anak'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.enterText(find.byType(TextFormField).first, 'Ayu');
    await tester.enterText(find.byType(TextFormField).last, '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.byType(ChildHomePage), findsOneWidget);
    return Provider.of<AppState>(
      tester.element(find.byType(ChildHomePage)),
      listen: false,
    );
  }

  int panicAlerts(AppState state) =>
      state.alerts.where((a) => a.source == AlertSource.panicButton).length;

  Future<void> wait(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  testWidgets('satu ketukan langsung mengirim SOS, tanpa hitung mundur', (
    tester,
  ) async {
    final state = await openChildHome(tester);
    final before = panicAlerts(state);

    await tester.tap(orb());
    await tester.pump();

    expect(find.text('Batalkan'), findsNothing);
    expect(find.textContaining('SOS terkirim dalam'), findsNothing);

    await wait(tester, const Duration(milliseconds: 600));
    expect(panicAlerts(state), before + 1);
    expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
  });

  testWidgets('GPS yang lambat tidak menahan SOS lebih dari 3 detik', (
    tester,
  ) async {
    final state = await openChildHome(
      tester,
      location: const _HangingLocation(),
    );
    final before = panicAlerts(state);

    await tester.tap(orb());
    await wait(tester, const Duration(milliseconds: 2500));
    expect(panicAlerts(state), before, reason: 'masih menunggu lokasi');

    await wait(tester, const Duration(milliseconds: 1000));
    expect(panicAlerts(state), before + 1, reason: 'SOS harus tetap berangkat');
    expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
    expect(find.textContaining('sinyal GPS belum didapat'), findsOneWidget);
  });

  testWidgets('lembar konfirmasi menyebut lokasi ikut terkirim', (
    tester,
  ) async {
    await openChildHome(tester);
    await tester.tap(orb());
    await wait(tester, const Duration(milliseconds: 3600));

    expect(find.text('Lokasimu ikut terkirim.'), findsOneWidget);
  });

  testWidgets('kalau GPS mati, anak diberi tahu lokasinya tidak terkirim', (
    tester,
  ) async {
    // Kegagalan paling berbahaya di aplikasi ini bukan lokasi yang gagal,
    // melainkan anak yang mengira orang tuanya sudah tahu dia di mana.
    final state = await openChildHome(
      tester,
      location: _FakeLocation.unavailable(),
    );
    final before = panicAlerts(state);

    await tester.tap(orb());
    await wait(tester, const Duration(milliseconds: 3600));

    expect(panicAlerts(state), before + 1, reason: 'SOS tetap harus terkirim');
    expect(find.textContaining('GPS di ponsel sedang mati'), findsOneWidget);
    expect(find.textContaining('kabari orang tuamu'), findsOneWidget);
  });

  testWidgets('ketukan berulang hanya mengirim satu SOS', (tester) async {
    // Anak yang panik sering mengetuk berulang kali; orang tuanya tidak boleh
    // menerima peringatan berlipat.
    final state = await openChildHome(tester);
    final before = panicAlerts(state);

    for (var i = 0; i < 4; i++) {
      // warnIfMissed: ketukan berikutnya mendarat di lembar konfirmasi,
      // memang itu yang diuji.
      await tester.tap(orb(), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await wait(tester, const Duration(milliseconds: 600));

    expect(panicAlerts(state), before + 1);
    // Lembar konfirmasinya tetap terbuka dan terbaca.
    expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
  });

  testWidgets('SOS tetap terkirim walau layar membeku', (tester) async {
    // Di emulator, layanan GPS sistem pernah membuat thread utama tersangkut:
    // tidak ada frame, animasi hitung mundur berhenti di angka 3, dan karena
    // pengiriman dulu menunggu animasi selesai, SOS tidak pernah berangkat.
    // TickerMode(enabled: false) meniru keadaan itu: semua animasi diam.
    tester.view.physicalSize = const Size(1344, 2992);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = AppState(
      repository: DemoRepository(),
      locationService: _FakeLocation.found(),
      callService: _FakeDialer(),
    );
    addTearDown(state.dispose);

    // Di testWidgets, waktu hanya maju lewat pump. Masuk ke demo memakai
    // Future.delayed, jadi harus dimajukan dulu sebelum ditunggu.
    final signingIn = state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: TickerMode(
            enabled: false,
            child: Scaffold(body: ChildHomePage()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final before = panicAlerts(state);

    await tester.tap(orb());
    await wait(tester, const Duration(milliseconds: 3600));

    expect(
      panicAlerts(state),
      before + 1,
      reason: 'SOS harus berangkat tepat waktu walau animasi tidak berjalan',
    );
  });

  group('alarm di HP orang tua', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> sendSos(WidgetTester tester) async {
      await tester.tap(orb());
      await wait(tester, const Duration(milliseconds: 3600));
    }

    testWidgets('SOS tidak menelepon: HP orang tua yang berbunyi', (
      tester,
    ) async {
      final dialer = _FakeDialer();
      await openChildHome(tester, dialer: dialer);
      await sendSos(tester);

      expect(dialer.opened, isEmpty, reason: 'HP anak tidak boleh menelepon');
      expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
      expect(find.textContaining('akan berbunyi alarm'), findsOneWidget);
      // Tombol cadangan hanya untuk SOS yang gagal terkirim.
      expect(find.text('Telepon orang tua'), findsNothing);
      expect(find.text('Coba kirim lagi'), findsNothing);
    });

    testWidgets('tanpa internet: jujur, lalu anak bisa menelepon orang tua', (
      tester,
    ) async {
      // Alarm butuh internet. Telepon seluler tidak, jadi itulah jalan
      // cadangannya. Dulu layar juga macet di "Mengirim SOS...".
      final dialer = _FakeDialer();
      await openChildHome(
        tester,
        dialer: dialer,
        repository: _OfflineRepository(),
      );
      await sendSos(tester);

      expect(find.text('Peringatan belum terkirim'), findsOneWidget);
      expect(find.text('Mengirim SOS...'), findsNothing);
      expect(
        find.textContaining('belum berbunyi'),
        findsOneWidget,
        reason: 'anak tidak boleh mengira orang tuanya sudah tahu',
      );
      expect(
        find.textContaining('sebutkan kamu di mana'),
        findsOneWidget,
        reason: 'lokasi tidak boleh diklaim terkirim',
      );
      expect(dialer.opened, isEmpty, reason: 'telepon hanya bila diminta');

      await tester.tap(find.text('Telepon orang tua'));
      await wait(tester, const Duration(milliseconds: 300));

      expect(dialer.opened, ['+6281234567890']);
      expect(find.textContaining('tombol panggil hijau'), findsOneWidget);
    });

    testWidgets('Coba kirim lagi: SOS terkirim begitu internet kembali', (
      tester,
    ) async {
      final repository = _OfflineRepository();
      final state = await openChildHome(tester, repository: repository);
      final before = panicAlerts(state);
      await sendSos(tester);
      expect(find.text('Peringatan belum terkirim'), findsOneWidget);

      repository.online = true;
      await tester.tap(find.text('Coba kirim lagi'));
      await wait(tester, const Duration(milliseconds: 600));

      expect(panicAlerts(state), before + 1);
      expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
      expect(find.textContaining('akan berbunyi alarm'), findsOneWidget);
      expect(find.text('Coba kirim lagi'), findsNothing);
    });

    testWidgets('tanpa internet dan tanpa nomor: tidak ada tombol telepon', (
      tester,
    ) async {
      await openChildHome(tester, repository: _OfflineNoNumberRepository());
      await sendSos(tester);

      expect(find.text('Peringatan belum terkirim'), findsOneWidget);
      expect(find.text('Telepon orang tua'), findsNothing);
      expect(find.textContaining('orang dewasa di dekatmu'), findsOneWidget);
      expect(find.text('Coba kirim lagi'), findsOneWidget);
    });

    testWidgets('tablet tanpa SIM: anak diarahkan ke orang dewasa', (
      tester,
    ) async {
      await openChildHome(
        tester,
        dialer: _FakeDialer(opens: false),
        repository: _OfflineRepository(),
      );
      await sendSos(tester);
      await tester.tap(find.text('Telepon orang tua'));
      await wait(tester, const Duration(milliseconds: 300));

      expect(find.textContaining('tidak bisa menelepon'), findsOneWidget);
    });

    testWidgets('jaringan yang tak pernah menjawab tidak membuat layar macet', (
      tester,
    ) async {
      await openChildHome(tester, repository: _HangingRepository());
      await tester.tap(orb());
      await wait(tester, const Duration(seconds: 14));

      expect(find.text('Mengirim SOS...'), findsNothing);
      expect(find.text('Peringatan belum terkirim'), findsOneWidget);
    });
  });

  testWidgets('anak bisa membuka Pengaturan dan keluar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await openChildHome(tester);
    expect(state.emergencyNumber, isNotNull);

    await tester.tap(find.bySemanticsLabel('Pusat bantuan'));
    await wait(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Pengaturan'));
    await wait(tester, const Duration(milliseconds: 600));

    expect(find.text('Nomor orang tua'), findsOneWidget);
    // Daftar hanya membangun yang dekat layar; gulir dulu sampai tombolnya
    // ada, lalu pastikan seluruhnya terlihat.
    await tester.scrollUntilVisible(
      find.text('Keluar'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Keluar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Keluar'));
    await wait(tester, const Duration(milliseconds: 800));

    expect(state.user, isNull);
    expect(state.emergencyNumber, isNull, reason: 'nomor keluarga lama');
    expect(find.text('Handphone Anak'), findsOneWidget);
  });
}
