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

/// Telepon tiruan: mencatat nomor yang ditelepon, tanpa benar-benar menelepon.
class _FakeCall extends EmergencyCallService {
  _FakeCall([this.outcome = CallOutcome.called]);

  final CallOutcome outcome;
  final dialled = <String?>[];

  @override
  Future<CallOutcome> call(String? number) async {
    dialled.add(number);
    return number == null ? CallOutcome.noNumber : outcome;
  }

  @override
  Future<bool> requestPermission() async => true;
}

/// Telepon yang tidak pernah menjawab, untuk memastikan layar tidak macet.
class _HangingCall extends EmergencyCallService {
  const _HangingCall();

  @override
  Future<CallOutcome> call(String? number) => Completer<CallOutcome>().future;
}

/// Meniru HP anak tanpa internet: menyimpan bukti dan peringatan gagal.
class _OfflineRepository extends DemoRepository {
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
  }) => Future.error(const _NoInternet());
}

class _NoInternet implements Exception {
  const _NoInternet();
  @override
  String toString() => 'SocketException: Failed host lookup';
}

/// Keluarga yang orang tuanya belum mengisi nomor HP.
class _NoNumberRepository extends DemoRepository {
  @override
  Future<String?> emergencyNumber() async => null;
}

/// Perilaku Panic Orb: "tekan sekali untuk SOS", dengan jeda 3 detik yang bisa
/// dibatalkan supaya sentuhan tak sengaja tidak membuat orang tua panik.
void main() {
  // Dibuat di dalam test: finder semantik butuh binding yang sudah siap.
  Finder orb() => find.bySemanticsLabel(
    'Tombol darurat. Ketuk untuk mengirim SOS ke orang tua.',
  );

  Future<AppState> openChildHome(
    WidgetTester tester, {
    LocationService? location,
    EmergencyCallService? call,
    AuraRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(1344, 2992);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AuraApp(
        repository: repository ?? DemoRepository(),
        locationService: location ?? _FakeLocation.found(),
        callService: call ?? _FakeCall(),
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

  testWidgets('satu ketukan mengirim SOS setelah hitung mundur 3 detik', (
    tester,
  ) async {
    final state = await openChildHome(tester);
    final before = panicAlerts(state);

    await tester.tap(orb());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Batalkan'), findsOneWidget);
    expect(find.text('SOS terkirim dalam 3 detik'), findsOneWidget);
    expect(panicAlerts(state), before, reason: 'belum boleh terkirim');

    await wait(tester, const Duration(milliseconds: 1100));
    expect(find.text('SOS terkirim dalam 2 detik'), findsOneWidget);

    await wait(tester, const Duration(milliseconds: 2400));
    expect(panicAlerts(state), before + 1);
    expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
  });

  testWidgets('kartu Batalkan menghentikan SOS', (tester) async {
    final state = await openChildHome(tester);
    final before = panicAlerts(state);

    await tester.tap(orb());
    await wait(tester, const Duration(milliseconds: 1200));
    await tester.tap(find.text('Batalkan'));
    await wait(tester, const Duration(seconds: 4));

    expect(panicAlerts(state), before, reason: 'SOS yang dibatalkan terkirim');
    expect(find.text('Panic Orb'), findsOneWidget);
    expect(find.text('Tekan sekali untuk SOS'), findsOneWidget);
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

  testWidgets('ketukan kedua saat hitung mundur langsung mengirim', (
    tester,
  ) async {
    // Anak yang panik sering mengetuk berulang kali; jangan buat mereka
    // menunggu sisa hitung mundur.
    final state = await openChildHome(tester);
    final before = panicAlerts(state);

    await tester.tap(orb());
    await tester.pump(const Duration(milliseconds: 300));

    // Saat menghitung mundur, pembaca layar harus tahu bahwa mengetuk lagi
    // berarti kirim sekarang.
    final sendNow = find.bySemanticsLabel(RegExp(r'^Kirim SOS sekarang'));
    expect(sendNow, findsOneWidget);
    await tester.tap(sendNow);
    await wait(tester, const Duration(milliseconds: 600));

    expect(panicAlerts(state), before + 1);
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
      callService: _FakeCall(),
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

  group('telepon orang tua', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('SOS menelepon nomor orang tua', (tester) async {
      final call = _FakeCall();
      await openChildHome(tester, call: call);

      await tester.tap(orb());
      await wait(tester, const Duration(milliseconds: 3600));

      expect(call.dialled, ['+6281234567890']);
      expect(find.text('Kami sudah menelepon orang tuamu.'), findsOneWidget);
      expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
    });

    testWidgets('tanpa internet: tetap menelepon dan jujur soal peringatan', (
      tester,
    ) async {
      // Justru di sini telepon paling berguna: lewat jaringan seluler, tidak
      // butuh internet. Dulu layar juga macet di "Mengirim SOS...".
      final call = _FakeCall();
      await openChildHome(tester, call: call, repository: _OfflineRepository());

      await tester.tap(orb());
      await wait(tester, const Duration(milliseconds: 3600));

      expect(call.dialled, hasLength(1), reason: 'telepon harus tetap jalan');
      expect(find.text('Peringatan belum terkirim'), findsOneWidget);
      expect(find.text('Mengirim SOS...'), findsNothing);
      expect(
        find.textContaining('Sebutkan kamu di mana'),
        findsOneWidget,
        reason: 'lokasi tidak boleh diklaim terkirim',
      );
    });

    testWidgets('tanpa nomor: tidak menelepon dan mengatakannya', (
      tester,
    ) async {
      final call = _FakeCall();
      await openChildHome(
        tester,
        call: call,
        repository: _NoNumberRepository(),
      );

      await tester.tap(orb());
      await wait(tester, const Duration(milliseconds: 3600));

      expect(call.dialled, [null]);
      expect(find.textContaining('belum diisi'), findsOneWidget);
      expect(find.text('Telepon orang tua lagi'), findsNothing);
    });

    testWidgets('SOS yang dibatalkan tidak menelepon', (tester) async {
      final call = _FakeCall();
      await openChildHome(tester, call: call);

      await tester.tap(orb());
      await wait(tester, const Duration(milliseconds: 1000));
      await tester.tap(find.text('Batalkan'));
      await wait(tester, const Duration(seconds: 4));

      expect(call.dialled, isEmpty);
    });

    testWidgets('telepon yang tak pernah menjawab tidak membuat layar macet', (
      tester,
    ) async {
      await openChildHome(tester, call: const _HangingCall());

      await tester.tap(orb());
      await wait(tester, const Duration(seconds: 10));

      expect(find.text('Mengirim SOS...'), findsNothing);
      expect(find.text('Pesan daruratmu terkirim'), findsOneWidget);
    });

    testWidgets('tanpa izin telepon: aplikasi Telepon dibuka dengan nomor', (
      tester,
    ) async {
      await openChildHome(tester, call: _FakeCall(CallOutcome.dialerOpened));

      await tester.tap(orb());
      await wait(tester, const Duration(milliseconds: 3600));

      expect(find.textContaining('tombol panggil hijau'), findsOneWidget);
      expect(find.text('Kami sudah menelepon orang tuamu.'), findsNothing);
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

    expect(find.text('Ditelepon saat darurat'), findsOneWidget);
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
