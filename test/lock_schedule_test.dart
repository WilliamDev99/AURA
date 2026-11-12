import 'dart:convert';
import 'dart:io';

import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/lock_schedule.dart';
import 'package:aura/domain/services/screen_lock_access.dart';
import 'package:aura/features/child/widgets/lock_access_setup.dart';
import 'package:aura/features/parent/lock_schedule_sheet.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jam istirahat: semua aplikasi di HP anak terkunci pada jam yang diatur
/// orang tua. Contoh di sini sama dengan LockScheduleTest.kt.
void main() {
  // 9 November 2026 hari Senin.
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 11, 8 + day, hour, minute);
  const monday = 1, tuesday = 2, wednesday = 3, thursday = 4;
  const friday = 5, saturday = 6;

  const nightly = LockSchedule.standard;
  const schoolNights = LockSchedule(
    enabled: true,
    startMinutes: 22 * 60,
    endMinutes: 9 * 60,
    days: {1, 2, 3, 4, 5},
  );

  group('kapan terkunci', () {
    test('22.00 sampai 09.00 melewati tengah malam', () {
      expect(nightly.isLockedAt(at(monday, 21, 59)), isFalse);
      expect(nightly.isLockedAt(at(monday, 22)), isTrue);
      expect(nightly.isLockedAt(at(tuesday, 3)), isTrue);
      expect(nightly.isLockedAt(at(tuesday, 8, 59)), isTrue);
      expect(nightly.isLockedAt(at(tuesday, 9)), isFalse);
      expect(nightly.isLockedAt(at(tuesday, 12)), isFalse);
    });

    test('hari adalah malam mulainya kunci', () {
      // Jumat malam terkunci sampai Sabtu 09.00.
      expect(schoolNights.isLockedAt(at(friday, 23)), isTrue);
      expect(schoolNights.isLockedAt(at(saturday, 8)), isTrue);
      // Sabtu malam bebas.
      expect(schoolNights.isLockedAt(at(saturday, 23)), isFalse);
      // Senin dini hari bebas: kuncinya milik Minggu, yang tidak dipilih.
      expect(schoolNights.isLockedAt(at(monday, 2)), isFalse);
      expect(schoolNights.isLockedAt(at(monday, 22)), isTrue);
    });

    test('jadwal di siang hari', () {
      const afternoon = LockSchedule(
        enabled: true,
        startMinutes: 13 * 60,
        endMinutes: 15 * 60,
        days: {3},
      );
      expect(afternoon.isLockedAt(at(wednesday, 14)), isTrue);
      expect(afternoon.isLockedAt(at(wednesday, 15)), isFalse);
      expect(afternoon.isLockedAt(at(thursday, 14)), isFalse);
    });

    test('mati atau tanpa hari: tidak pernah mengunci', () {
      expect(
        nightly.copyWith(enabled: false).isLockedAt(at(monday, 23)),
        isFalse,
      );
      expect(nightly.copyWith(days: {}).isLockedAt(at(monday, 23)), isFalse);
    });
  });

  test('bentuk simpanan sama dengan yang dibaca Android', () {
    expect(nightly.toJson(), {
      'enabled': true,
      'start': '22:00',
      'end': '09:00',
      'days': [1, 2, 3, 4, 5, 6, 7],
    });
    expect(
      LockSchedule.fromJson(jsonDecode(jsonEncode(nightly.toJson()))),
      nightly,
    );
    expect(LockSchedule.fromJson({'start': '25:00', 'end': '09:00'}), isNull);
    expect(LockSchedule.fromJson('bukan peta'), isNull);

    final android = File(
      'android/app/src/main/kotlin/id/aura/aura/ScreenLock.kt',
    ).readAsStringSync();
    expect(android, contains('"flutter.${AppState.lockScheduleKey}"'));
  });

  test('ringkasan untuk orang tua dan anak', () {
    expect(nightly.describe(), '22.00 – 09.00, setiap hari');
    expect(schoolNights.describe(), '22.00 – 09.00, Senin – Jumat');
    expect(
      nightly.copyWith(days: {6, 7}).describe(),
      '22.00 – 09.00, akhir pekan',
    );
    expect(
      nightly.copyWith(days: {1, 3}).describe(),
      '22.00 – 09.00, Sen, Rab',
    );
    expect(nightly.copyWith(enabled: false).describe(), 'Tidak aktif');
  });

  group('di HP', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<String?> saved() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppState.lockScheduleKey);
    }

    test(
      'HP anak menyimpan jadwalnya, jadi tetap mengunci tanpa internet',
      () async {
        final repository = DemoRepository();
        final state = AppState(repository: repository);
        addTearDown(state.dispose);
        await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
        expect(await saved(), isNull, reason: 'belum diatur');

        await repository.setLockSchedule(state.user!.id, nightly);
        expect(jsonDecode((await saved())!), nightly.toJson());

        // Dimatikan orang tua: HP anak ikut berhenti mengunci.
        await repository.setLockSchedule(
          state.user!.id,
          nightly.copyWith(enabled: false),
        );
        expect(
          LockSchedule.fromJson(jsonDecode((await saved())!))!.active,
          isFalse,
        );
      },
    );

    test('HP orang tua tidak pernah mengunci dirinya sendiri', () async {
      final state = AppState(repository: DemoRepository());
      addTearDown(state.dispose);
      await state.signIn(
        name: 'Bunda',
        role: UserRole.parent,
        phone: '081234567890',
      );
      expect(await saved(), isNull);
    });
  });

  group('pengaturan orang tua', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<AppState> parentWithChild(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1344, 2992);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final state = AppState(repository: DemoRepository());
      addTearDown(state.dispose);
      final signingIn = state.signIn(
        name: 'Bunda',
        role: UserRole.parent,
        phone: '081234567890',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await signingIn;
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.children, isNotEmpty);
      return state;
    }

    Future<void> showCard(WidgetTester tester, AppState state) =>
        tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => LockScheduleCard(
                    child: context.watch<AppState>().children.first,
                  ),
                ),
              ),
            ),
          ),
        );

    Future<void> wait(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('orang tua menyalakan jam istirahat 22.00 – 09.00', (
      tester,
    ) async {
      final state = await parentWithChild(tester);
      await showCard(tester, state);
      expect(find.textContaining('Belum diatur'), findsOneWidget);

      await tester.tap(find.byType(LockScheduleCard));
      await wait(tester);
      expect(find.text('22.00'), findsOneWidget);
      expect(find.text('09.00'), findsOneWidget);

      await tester.tap(find.text('Simpan dan nyalakan'));
      await wait(tester);

      expect(state.children.first.lockSchedule, LockSchedule.standard);
      expect(find.text('22.00 – 09.00, setiap hari'), findsOneWidget);
    });

    testWidgets('sakelar di kartu langsung berlaku, tanpa Simpan, seperti '
        'sakelar perlindungan', (tester) async {
      final state = await parentWithChild(tester);
      await showCard(tester, state);
      expect(find.textContaining('Belum diatur'), findsOneWidget);

      // Nyalakan: 22.00 – 09.00 setiap hari, tanpa membuka pengaturan.
      await tester.tap(find.byType(Switch));
      await wait(tester);
      expect(find.byType(LockScheduleEditor), findsNothing);
      expect(state.children.first.lockSchedule, LockSchedule.standard);
      expect(find.text('22.00 – 09.00, setiap hari'), findsOneWidget);

      // Matikan: langsung tersimpan, HP anak berhenti mengunci. Jamnya
      // tetap diingat.
      await tester.tap(find.byType(Switch));
      await wait(tester);
      final off = state.children.first.lockSchedule!;
      expect(off.active, isFalse);
      expect(off.startMinutes, 22 * 60);
      expect(find.text('Mati · 22.00 – 09.00, setiap hari'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      // Nyalakan lagi: jam yang sama.
      await tester.tap(find.byType(Switch));
      await wait(tester);
      expect(state.children.first.lockSchedule, LockSchedule.standard);
    });

    testWidgets('sakelar gagal (tanpa internet): kartu memberi tahu dan '
        'sakelar kembali', (tester) async {
      tester.view.physicalSize = const Size(1344, 2992);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final state = AppState(repository: _OfflineLockRepository());
      addTearDown(state.dispose);
      final signingIn = state.signIn(
        name: 'Bunda',
        role: UserRole.parent,
        phone: '081234567890',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await signingIn;
      await tester.pump(const Duration(milliseconds: 100));
      await showCard(tester, state);

      await tester.tap(find.byType(Switch));
      await wait(tester);
      expect(find.textContaining('Belum tersimpan'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(state.children.first.lockSchedule, isNull);
    });

    testWidgets('jam diatur dengan roda gulir seperti di iPhone', (
      tester,
    ) async {
      final state = await parentWithChild(tester);
      await showCard(tester, state);
      await tester.tap(find.byType(LockScheduleCard));
      await wait(tester);
      expect(find.byType(CupertinoDatePicker), findsNothing);

      // Ketuk "Mulai": roda muncul di bawahnya, bukan jam putar.
      await tester.tap(find.text('22.00'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(TimePickerDialog), findsNothing);

      // Gulir jam satu angka ke bawah: 22 menjadi 21.
      await tester.drag(
        find.text('22').first,
        const Offset(0, 32),
        touchSlopY: 0,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('21.00'), findsOneWidget);

      // Ketuk "Selesai": roda pindah ke jam selesai.
      await tester.tap(find.text('09.00'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      // Jam ditulis dua angka seperti menitnya.
      expect(find.text('07'), findsWidgets);
      expect(find.text('7'), findsNothing);
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2000, 1, 1, 6, 30));
      await tester.pumpAndSettle();
      expect(find.text('06.30'), findsOneWidget);

      // Ketuk lagi: roda tertutup.
      await tester.tap(find.text('06.30'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);

      await tester.tap(find.text('Simpan dan nyalakan'));
      await wait(tester);
      final saved = state.children.first.lockSchedule!;
      expect(saved.startMinutes, 21 * 60);
      expect(saved.endMinutes, 6 * 60 + 30);
    });

    testWidgets('gagal menyimpan (tanpa internet): alasannya terlihat di '
        'lembar, bukan tersembunyi di belakangnya', (tester) async {
      tester.view.physicalSize = const Size(1344, 2992);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final state = AppState(repository: _OfflineLockRepository());
      addTearDown(state.dispose);
      final signingIn = state.signIn(
        name: 'Bunda',
        role: UserRole.parent,
        phone: '081234567890',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await signingIn;
      await tester.pump(const Duration(milliseconds: 100));
      await showCard(tester, state);

      await tester.tap(find.byType(LockScheduleCard));
      await wait(tester);
      await tester.tap(find.text('Simpan dan nyalakan'));
      await wait(tester);

      // Lembar tetap terbuka, dengan alasannya di dalam lembar.
      expect(find.byType(LockScheduleEditor), findsOneWidget);
      expect(find.textContaining('Belum tersimpan'), findsOneWidget);
      expect(find.textContaining('internet'), findsOneWidget);
      expect(state.children.first.lockSchedule, isNull);
    });

    testWidgets('hari bisa dipilih, dan minimal satu', (tester) async {
      final state = await parentWithChild(tester);
      await showCard(tester, state);
      await tester.tap(find.byType(LockScheduleCard));
      await wait(tester);

      // Sabtu dan Minggu tidak dikunci.
      await tester.tap(find.text('Sab'));
      await tester.tap(find.text('Min'));
      await tester.pump();
      await tester.tap(find.text('Simpan dan nyalakan'));
      await wait(tester);

      expect(state.children.first.lockSchedule!.days, {1, 2, 3, 4, 5});

      // Semua hari dimatikan: tidak bisa disimpan.
      await tester.tap(find.byType(LockScheduleCard));
      await wait(tester);
      for (final day in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum']) {
        await tester.tap(find.text(day));
      }
      await tester.pump();
      expect(find.text('Pilih minimal satu hari.'), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Simpan'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('izin di HP anak belum ada: orang tua diberi tahu', (
      tester,
    ) async {
      final state = await parentWithChild(tester);
      final child = state.children.first;
      await state.setLockSchedule(child.id, LockSchedule.standard);
      await state.repository.setLockSchedule(child.id, LockSchedule.standard);
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LockScheduleCard(
              child: state.children.first.copyWith(lockReady: false),
            ),
          ),
        ),
      );
      expect(find.textContaining('Belum siap'), findsOneWidget);
    });
  });

  group('HP anak tetap mengunci', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('belum siap tanpa izin tetap berjalan di latar belakang', () {
      const all = LockAccess(usage: true, overlay: true, battery: true);
      expect(all.ready, isTrue);
      // Realme dan OPPO mematikan AURA saat daftar aplikasi terbaru
      // dibersihkan; selama itu tidak ada yang mengunci.
      expect(
        const LockAccess(usage: true, overlay: true, battery: false).ready,
        isFalse,
      );
    });

    testWidgets('anak diminta mengizinkan AURA tetap aktif, orang tua diberi '
        'tahu belum siap', (tester) async {
      final repository = DemoRepository();
      final state = AppState(
        repository: repository,
        lockAccess: const _FakeLockAccess(
          LockAccess(usage: true, overlay: true, battery: false),
        ),
      );
      addTearDown(state.dispose);
      final signingIn = state.signIn(
        name: 'Ayu',
        role: UserRole.child,
        age: 12,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await signingIn;
      await repository.setLockSchedule(state.user!.id, LockSchedule.standard);
      await state.refreshLockAccess();
      await tester.pump();

      expect(state.user!.lockReady, isFalse);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: Scaffold(body: LockAccessSetup())),
        ),
      );
      expect(find.text('Tetap aktif di latar belakang'), findsOneWidget);
      expect(find.text('Akses penggunaan'), findsNothing);
      expect(find.text('Siap'), findsNothing);
    });

    test('aplikasi terkunci digantikan layar penuh jam istirahat', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
      );
      final activity = RegExp(
        r'<activity\s+android:name="\.RestLockActivity"[^>]*/>',
      ).firstMatch(manifest)?.group(0);
      expect(activity, isNotNull);
      // Tidak bisa dibuka aplikasi lain, dan tidak muncul di daftar
      // aplikasi terbaru (tidak bisa digeser untuk ditutup).
      expect(activity, contains('android:exported="false"'));
      expect(activity, contains('android:excludeFromRecents="true"'));

      final lock = File(
        'android/app/src/main/kotlin/id/aura/aura/ScreenLock.kt',
      ).readAsStringSync();
      expect(lock, contains('RestLockActivity.open('));
      expect(lock, contains('Intent.ACTION_USER_PRESENT'));
      expect(lock, contains('CHECK_LOCKED_MS = 500L'));
    });

    test('pengunci berjalan di thread sendiri, tidak tertahan Flutter', () {
      final lock = File(
        'android/app/src/main/kotlin/id/aura/aura/ScreenLock.kt',
      ).readAsStringSync();
      expect(lock, contains('HandlerThread('));
      expect(lock, contains('private val handler = Handler(thread.looper)'));
      // Mesin Dart tetap disentuh dari thread utama.
      expect(lock, contains('main.post { runCatching { AuraEngine'));
    });

    test('yang lolos saat jam istirahat sengaja sempit', () {
      final lock = File(
        'android/app/src/main/kotlin/id/aura/aura/ScreenLock.kt',
      ).readAsStringSync();
      final allowed = lock.substring(
        lock.indexOf('private fun allowedApps('),
        lock.indexOf('private fun show('),
      );
      // "Semua yang bisa menelepon" meloloskan Zoom; "semua yang bisa
      // membuka APK" meloloskan toko aplikasi dan WPS Office.
      expect(allowed, isNot(contains('Intent(Intent.ACTION_DIAL)')));
      expect(allowed, isNot(contains('package-archive')));
      expect(allowed, contains('defaultDialerPackage'));
      expect(allowed, contains('FLAG_SYSTEM'));
      // "Semua layar utama" memuat Pengaturan (FallbackHome).
      expect(allowed, contains('set -= "com.android.settings"'));
    });

    test('AURA dimatikan sistem: penjaga menghidupkan pengunci lagi', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final watchdog = RegExp(
        r'<service\s+android:name="\.LockWatchdog"[^>]*/>',
      ).firstMatch(manifest)?.group(0);
      expect(watchdog, isNotNull);
      expect(watchdog, contains('android.permission.BIND_JOB_SERVICE'));
      expect(watchdog, contains('android:exported="false"'));

      final lock = File(
        'android/app/src/main/kotlin/id/aura/aura/ScreenLock.kt',
      ).readAsStringSync();
      expect(lock, contains('LockWatchdog.arm('));
      expect(lock, contains('LockWatchdog.disarm('));
    });

    test('HP anak: AURA tidak tampil di daftar aplikasi terbaru, supaya '
        '"Bersihkan semua" tidak mematikannya', () {
      final main = File(
        'android/app/src/main/kotlin/id/aura/aura/MainActivity.kt',
      ).readAsStringSync();
      expect(main, contains('setExcludeFromRecents(child)'));
      expect(main, contains('ScreenLock.schedule(this) != null'));
    });

    test('halaman izin dari tombol "Izinkan" tetap terbuka saat jam '
        'istirahat', () {
      // Pengaturan Android terkunci di malam hari, tetapi anak harus tetap
      // bisa memberi izin yang dibutuhkan pengunci.
      final main = File(
        'android/app/src/main/kotlin/id/aura/aura/MainActivity.kt',
      ).readAsStringSync();
      for (final opener in [
        'private fun openSettings(',
        'private fun openBatterySettings(',
        'private fun openNotificationAccessSettings(',
      ]) {
        final body = main.substring(main.indexOf(opener));
        expect(
          body.substring(0, body.indexOf('startActivity')),
          contains('ScreenLock.allowSettingsBriefly()'),
          reason: opener,
        );
      }
      expect(main, contains('ScreenLock.endSettingsGrace()'));
    });
  });
}

/// HP orang tua tanpa internet: jam istirahat tidak bisa disimpan.
class _OfflineLockRepository extends DemoRepository {
  @override
  Future<void> setLockSchedule(String childId, LockSchedule schedule) async {
    throw const SocketException(
      "Failed host lookup: 'fkjdfpbqwaasbabterrd.supabase.co'",
    );
  }
}

class _FakeLockAccess extends ScreenLockAccess {
  const _FakeLockAccess(this.access);

  final LockAccess access;

  @override
  Future<LockAccess?> check() async => access;
}
