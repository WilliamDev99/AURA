import 'package:aura/core/services/notification_scanner.dart';
import 'package:aura/core/widgets/clay.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/services/notification_access.dart';
import 'package:aura/features/parent/parent_dashboard_page.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Izin akses notifikasi tiruan.
class _FakeAccess extends NotificationAccess {
  _FakeAccess(this.granted);

  bool? granted;

  @override
  Future<bool?> isGranted() async => granted;
}

/// Mencatat setiap laporan yang dikirim ke server.
class _CountingRepo extends DemoRepository {
  final reports = <bool>[];

  @override
  Future<void> reportChatScan(bool enabled) async {
    reports.add(enabled);
    await super.reportChatScan(enabled);
  }
}

/// Seperti Supabase saat aplikasi di latar belakang: setelah laporan
/// pertama, laporan tersimpan di server tetapi pembaruan realtime-nya tidak
/// sampai kembali ke ponsel.
class _NoEchoRepo extends DemoRepository {
  final reports = <bool>[];

  @override
  Future<void> reportChatScan(bool enabled) async {
    reports.add(enabled);
    if (reports.length == 1) await super.reportChatScan(enabled);
  }
}

/// Keluarga demo dengan daftar anak yang ditentukan test.
class _ChildrenRepo extends DemoRepository {
  _ChildrenRepo(this.kids);

  final List<AppUser> kids;

  @override
  Stream<List<AppUser>> watchChildren(String familyId) => Stream.value(kids);
}

/// Orang tua harus tahu bila pemindaian chat di ponsel anak sedang mati.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> childPhone(_CountingRepo repo, _FakeAccess access) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(repository: repo, notificationAccess: access);
    addTearDown(state.dispose);
    await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return state;
  }

  test('ponsel anak melaporkan statusnya saat sesi dimulai', () async {
    final repo = _CountingRepo();
    final state = await childPhone(repo, _FakeAccess(true));

    expect(repo.reports, [true]);
    expect(state.user!.chatScanEnabled, isTrue);
    expect(state.user!.chatScanCheckedAt, isNotNull);
  });

  test('akses dimatikan: langsung dilaporkan', () async {
    final repo = _CountingRepo();
    final access = _FakeAccess(true);
    final state = await childPhone(repo, access);

    access.granted = false;
    await state.refreshChatScanStatus();

    expect(repo.reports, [true, false]);
    expect(state.user!.chatScanEnabled, isFalse);
  });

  test('status yang sama tidak dilaporkan berulang-ulang', () async {
    final repo = _CountingRepo();
    final state = await childPhone(repo, _FakeAccess(true));

    await state.refreshChatScanStatus();
    await state.refreshChatScanStatus();

    expect(repo.reports, [true], reason: 'baru diperiksa, tidak berubah');
  });

  test('bukan Android: tidak melaporkan apa pun', () async {
    final repo = _CountingRepo();
    await childPhone(repo, _FakeAccess(null));

    expect(repo.reports, isEmpty);
  });

  test('ponsel orang tua tidak melaporkan status pemindaian', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _CountingRepo();
    final state = AppState(
      repository: repo,
      notificationAccess: _FakeAccess(true),
    );
    addTearDown(state.dispose);
    await state.signIn(name: 'Bunda', role: UserRole.parent);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await state.refreshChatScanStatus();

    expect(repo.reports, isEmpty);
  });

  test('Android mengabarkan akses dicabut lewat kanal id.aura/scan', () async {
    final repo = _CountingRepo();
    final state = await childPhone(repo, _FakeAccess(true));
    NotificationScanner(state).start();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    await messenger.handlePlatformMessage(
      'id.aura/scan',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('accessChanged', false),
      ),
      (_) {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repo.reports.last, isFalse);
    expect(state.user!.chatScanEnabled, isFalse);
  });

  test('dimatikan lalu dinyalakan lagi: keduanya dilaporkan', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _NoEchoRepo();
    final state = AppState(
      repository: repo,
      notificationAccess: _FakeAccess(true),
    );
    addTearDown(state.dispose);
    await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    NotificationScanner(state).start();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<void> android(bool enabled) async {
      await messenger.handlePlatformMessage(
        'id.aura/scan',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('accessChanged', enabled),
        ),
        (_) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await android(false);
    await android(true);

    expect(repo.reports, [true, false, true]);
    expect(state.user!.chatScanEnabled, isTrue);
  });

  test('kabar dari Android tetap dilaporkan walau statusnya sama', () async {
    final repo = _CountingRepo();
    final state = await childPhone(repo, _FakeAccess(true));

    // Mis. layanan pemindai tersambung ulang setelah prosesnya dimatikan.
    await state.reportChatScan(true, changed: true);

    expect(repo.reports, [true, true]);
  });

  Future<AppState> parentDashboard(
    WidgetTester tester, {
    DemoRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(1344, 2992);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = AppState(repository: repository ?? DemoRepository());
    addTearDown(state.dispose);
    final signingIn = state.signIn(
      name: 'Bunda',
      role: UserRole.parent,
      phone: '+6281234567890',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: ParentDashboardPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  testWidgets('Status Proteksi memperingatkan pemindaian yang mati', (
    tester,
  ) async {
    await parentDashboard(tester);

    // Data demo: Ayu menyala, Bima mati.
    expect(find.text('PEMINDAIAN CHAT MATI'), findsOneWidget);
    expect(find.textContaining('Akses notifikasi di HP Bima'), findsOneWidget);
    expect(find.textContaining('HP Ayu'), findsNothing);
    // Baris Bima ikut ditandai; baris Ayu tidak.
    expect(find.text('Chat tidak dipindai'), findsOneWidget);
    expect(find.text('AKTIF'), findsNothing);
  });

  testWidgets('semua menyala: Status Proteksi AKTIF', (tester) async {
    await parentDashboard(
      tester,
      repository: _ChildrenRepo([
        AppUser(
          id: 'anak-1',
          name: 'Felisa',
          role: UserRole.child,
          familyId: DemoRepository.demoFamilyId,
          age: 7,
          monitoringConsentAt: DateTime(2026, 10),
          lastSeenAt: DateTime.now(),
          chatScanEnabled: true,
        ),
      ]),
    );

    expect(find.text('AKTIF'), findsOneWidget);
    expect(find.text('Virtual AI Shield berjalan'), findsOneWidget);
    expect(find.text('PEMINDAIAN CHAT MATI'), findsNothing);
    // Baris anak sesuai desain: umur dan status daring.
    expect(find.text('7 Tahun | Sedang Online'), findsOneWidget);
  });

  testWidgets('heatmap memakai LOW, MEDIUM, HARD sesuai desain', (
    tester,
  ) async {
    final state = await parentDashboard(tester);
    int count(RiskLevel level) =>
        state.unreadAlerts.where((a) => a.riskLevel == level).length;

    for (final (key, label, level) in [
      ('heat-low', 'LOW', RiskLevel.medium),
      ('heat-medium', 'MEDIUM', RiskLevel.high),
      ('heat-hard', 'HARD', RiskLevel.critical),
    ]) {
      final row = find.byKey(ValueKey(key));
      expect(
        find.descendant(of: row, matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('${count(level)}')),
        findsOneWidget,
        reason: '$label = jumlah peringatan ${level.label}',
      );
    }
  });

  testWidgets('menjeda perlindungan lewat rincian anak', (tester) async {
    final state = await parentDashboard(tester);
    final ayu = state.children.firstWhere((c) => c.name == 'Ayu');

    await tester.tap(find.text('Ayu'));
    // Animasi lembar baru mulai di frame berikutnya.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Perlindungan aktif'), findsOneWidget);
    // Lembar clay: latar terang dan nama anak biru tua. Dulu lembar ini
    // gelap, dan nama anak ikut gelap sehingga hampir tidak terbaca.
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      const Color(0xFFF2F0FB),
    );
    expect(
      tester.widget<Text>(find.text('Ayu').last).style?.color,
      ClayColors.ink,
    );
    // Sakelar perlindungan, bukan sakelar jam istirahat di bawahnya.
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Perlindungan aktif'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.children.firstWhere((c) => c.id == ayu.id).protectionActive,
      isFalse,
    );
    expect(find.text('Perlindungan dijeda'), findsWidgets);
  });
}
