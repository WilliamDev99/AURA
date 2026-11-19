import 'dart:async';
import 'dart:io';

import 'package:aura/core/services/notification_scanner.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/uninstall_permission.dart';
import 'package:aura/domain/services/uninstall_guard.dart';
import 'package:aura/features/child/widgets/uninstall_setup.dart';
import 'package:aura/features/parent/uninstall_card.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AURA hanya bisa dihapus dari HP anak dengan PIN dari orang tua. PIN-nya
/// dibuat server dan hanya sampai ke HP orang tua.
void main() {
  group('PIN', () {
    final now = DateTime(2026, 11, 13, 21, 0);
    UninstallPin pin({
      Duration left = const Duration(minutes: 20),
      int attempts = 0,
      DateTime? closedAt,
    }) => UninstallPin(
      childId: 'ayu',
      pin: '482913',
      expiresAt: now.add(left),
      attempts: attempts,
      closedAt: closedAt,
    );

    test('berlaku 30 menit, 5 kali salah, sekali pakai', () {
      expect(UninstallPin.lifetime, const Duration(minutes: 30));
      expect(pin().activeAt(now), isTrue);
      expect(pin(left: Duration.zero).activeAt(now), isFalse);
      expect(pin(attempts: 5).activeAt(now), isFalse);
      expect(pin(closedAt: now).activeAt(now), isFalse);
    });

    test('dibacakan per tiga angka', () {
      expect(pin().spaced, '482 913');
    });

    test('terbaca dari baris basis data', () {
      final read = UninstallPin.fromRow({
        'child_id': 'ayu',
        'pin': '004217',
        'expires_at': '2026-11-13T13:30:00+00:00',
        'attempts': 2,
        'closed_at': null,
      })!;
      expect(read.pin, '004217');
      expect(read.attempts, 2);
      expect(UninstallPin.fromRow({'pin': 1}), isNull);
      expect(PinCheck.fromName('locked'), PinCheck.locked);
      expect(PinCheck.fromName('aneh'), PinCheck.none);
    });
  });

  group('HP anak', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<(AppState, DemoRepository, _FakeGuard)> childPhone(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1344, 2992);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repository = DemoRepository();
      final guard = _FakeGuard();
      final state = AppState(repository: repository, uninstallGuard: guard);
      addTearDown(state.dispose);
      final signingIn = state.signIn(
        name: 'Ayu',
        role: UserRole.child,
        age: 12,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await signingIn;
      await tester.pump();
      return (state, repository, guard);
    }

    Future<void> show(WidgetTester tester, AppState state) => tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: UninstallSetup())),
        ),
      ),
    );

    /// PIN yang dilihat orang tua (di Supabase: hanya orang tua yang boleh
    /// membaca tabelnya).
    Future<String> parentSees(DemoRepository repository, String childId) async {
      final pins = await repository.watchUninstallPins('family').first;
      return pins.singleWhere((p) => p.childId == childId).pin;
    }

    testWidgets('minta PIN, salah, lalu benar: AURA dihapus', (tester) async {
      final (state, repository, guard) = await childPhone(tester);
      await show(tester, state);
      expect(find.text('Butuh PIN dari orang tuamu.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Minta PIN'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('PIN dikirim ke HP orang tuamu'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);

      final pin = await parentSees(repository, state.user!.id);
      // PIN tidak pernah tampil di HP anak.
      expect(find.textContaining(pin), findsNothing);

      final wrong = pin == '111111' ? '222222' : '111111';
      await tester.enterText(find.byType(TextField), wrong);
      await tester.pump();
      await tester.tap(find.text('Hapus AURA').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('PIN salah. Coba lagi.'), findsOneWidget);
      expect(guard.uninstalls, 0);

      await tester.enterText(find.byType(TextField), pin);
      await tester.pump();
      await tester.tap(find.text('Hapus AURA').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(guard.uninstalls, 1);

      // Sekali pakai.
      expect(await state.enterUninstallPin(pin), PinCheck.none);
      expect(guard.uninstalls, 1);
    });

    testWidgets('5 kali salah: harus minta PIN baru', (tester) async {
      final (state, repository, guard) = await childPhone(tester);
      await state.requestUninstallPin();
      final pin = await parentSees(repository, state.user!.id);
      final wrong = pin == '000000' ? '999999' : '000000';
      for (var i = 0; i < 4; i++) {
        expect(await state.enterUninstallPin(wrong), PinCheck.wrong);
      }
      expect(await state.enterUninstallPin(wrong), PinCheck.locked);
      // Yang benar pun tidak berlaku lagi.
      expect(await state.enterUninstallPin(pin), PinCheck.locked);
      expect(guard.uninstalls, 0);
    });

    test('HP anak tidak pernah memuat daftar PIN', () async {
      final repository = _CountingPinsRepo();
      final state = AppState(repository: repository);
      addTearDown(state.dispose);
      await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await state.requestUninstallPin();
      expect(repository.pinWatchers, 0);
      expect(state.uninstallPinFor(state.user!.id), isNull);
    });

    test(
      'perlindungan dimatikan di Pengaturan: orang tua diberi tahu',
      () async {
        final state = AppState(
          repository: DemoRepository(),
          uninstallGuard: _FakeGuard(),
        );
        addTearDown(state.dispose);
        await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
        NotificationScanner(state).start();

        Future<void> android(bool protected) async {
          await TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .handlePlatformMessage(
                'id.aura/scan',
                const StandardMethodCodec().encodeMethodCall(
                  MethodCall('uninstallProtectionChanged', protected),
                ),
                (_) {},
              );
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        await android(true);
        expect(state.user!.uninstallProtected, isTrue);
        await android(false);
        expect(state.user!.uninstallProtected, isFalse);
      },
    );
  });

  group('HP orang tua', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<(AppState, _FamilyWithPinRepo)> parentPhone(
      WidgetTester tester, {
      bool withPin = true,
      bool? protected = true,
    }) async {
      tester.view.physicalSize = const Size(1344, 2992);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repository = _FamilyWithPinRepo(
        withPin: withPin,
        protected: protected,
      );
      final state = AppState(repository: repository);
      addTearDown(state.dispose);
      final signingIn = state.signIn(
        name: 'Bunda',
        role: UserRole.parent,
        phone: '081234567890',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await signingIn;
      await tester.pump(const Duration(milliseconds: 100));
      return (state, repository);
    }

    Future<void> showCard(WidgetTester tester, AppState state) =>
        tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => UninstallCard(
                    child: context.watch<AppState>().children.first,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('anak meminta PIN: PIN tampil untuk diberikan', (tester) async {
      final (state, _) = await parentPhone(tester);
      await showCard(tester, state);
      expect(find.textContaining('minta izin menghapus AURA'), findsOneWidget);
      expect(find.text('482 913'), findsOneWidget);
      expect(find.textContaining('sekali pakai'), findsOneWidget);
    });

    testWidgets('tidak mengizinkan: Batalkan PIN', (tester) async {
      final (state, repository) = await parentPhone(tester);
      await showCard(tester, state);
      await tester.tap(find.text('Batalkan PIN'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.cancelled, ['ayu']);
      expect(find.text('482 913'), findsNothing);
    });

    testWidgets('perlindungan mati: orang tua diberi tahu cara menyalakan', (
      tester,
    ) async {
      final (state, _) = await parentPhone(
        tester,
        withPin: false,
        protected: false,
      );
      await showCard(tester, state);
      expect(find.text('Perlindungan hapus mati.'), findsOneWidget);
      expect(
        find.textContaining('bisa menghapus AURA tanpa izin'),
        findsOneWidget,
      );
    });
  });

  group('Android, basis data, dan notifikasi', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('AURA admin perangkat tanpa kewenangan lain', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final receiver = RegExp(
        r'<receiver\s+android:name="\.AuraDeviceAdmin"[\s\S]*?</receiver>',
      ).firstMatch(manifest)?.group(0);
      expect(receiver, isNotNull);
      expect(receiver, contains('android.permission.BIND_DEVICE_ADMIN'));
      expect(receiver, contains('@xml/aura_device_admin'));
      expect(manifest, contains('android.permission.REQUEST_DELETE_PACKAGES'));

      final policies = read(
        'android/app/src/main/res/xml/aura_device_admin.xml',
      );
      expect(policies, contains('<uses-policies />'));
      for (final power in ['force-lock', 'wipe-data', 'limit-password']) {
        expect(policies, isNot(contains(power)));
      }
    });

    test('dialog hapus dibuka setelah perlindungan dilepas', () {
      final main = read(
        'android/app/src/main/kotlin/id/aura/aura/MainActivity.kt',
      );
      final uninstall = main.substring(
        main.indexOf('private fun uninstallAura('),
      );
      expect(uninstall, contains('AuraDeviceAdmin.release(this)'));
      expect(uninstall, contains('Intent.ACTION_DELETE'));
    });

    test('PIN dibuat dan diperiksa server; anak tidak bisa membacanya', () {
      for (final path in [
        'supabase/patch_07_uninstall_permission.sql',
        'supabase/schema.sql',
      ]) {
        final sql = read(path);
        // Hanya orang tua sekeluarga yang boleh membaca.
        expect(
          sql,
          contains(
            "using (public.my_role() = 'parent' and family_id = "
            'public.my_family_id())',
          ),
          reason: path,
        );
        expect(
          sql,
          contains(
            'revoke insert, update, delete on public.uninstall_pins from '
            'anon, authenticated',
          ),
          reason: path,
        );
        // Yang kembali ke HP anak hanya waktu kedaluwarsa, bukan PIN-nya.
        final request = sql.substring(
          sql.indexOf('function public.request_uninstall_pin()'),
        );
        expect(
          request.substring(0, request.indexOf('as \$\$')),
          contains('returns timestamptz'),
          reason: path,
        );
        expect(sql, contains('active_pin.attempts >= 5'), reason: path);
        expect(sql, contains("interval '30 minutes'"), reason: path);
      }
    });

    test(
      'notifikasi PIN hanya ke HP orang tua, tidak tampil di layar kunci',
      () {
        final function = read('supabase/functions/notify-parents/index.ts');
        final send = function.substring(
          function.indexOf('async function sendUninstallPin('),
          function.indexOf('Deno.serve('),
        );
        expect(send, contains('db.auth.getUser(jwt)'));
        expect(send, contains('child.role !== "child"'));
        expect(send, contains('.eq("role", "parent")'));
        expect(send, contains('visibility: "PRIVATE"'));
        // Tanpa PIN di log.
        expect(send, isNot(contains(r'console.log(`AURA: PIN ${')));
        expect(function, contains('payload?.type === "uninstall_pin"'));
      },
    );
  });
}

class _FakeGuard extends UninstallGuard {
  int uninstalls = 0;

  @override
  Future<bool?> isProtected() async => null;

  @override
  Future<void> protect() async {}

  @override
  Future<void> uninstall() async => uninstalls++;
}

class _CountingPinsRepo extends DemoRepository {
  int pinWatchers = 0;

  @override
  Stream<List<UninstallPin>> watchUninstallPins(String familyId) {
    pinWatchers++;
    return super.watchUninstallPins(familyId);
  }
}

/// Keluarga dengan satu anak, yang (bisa jadi) sedang meminta PIN.
class _FamilyWithPinRepo extends DemoRepository {
  _FamilyWithPinRepo({required bool withPin, bool? protected})
    : _child = AppUser(
        id: 'ayu',
        name: 'Ayu',
        role: UserRole.child,
        uninstallProtected: protected,
      ),
      _pin = withPin
          ? UninstallPin(
              childId: 'ayu',
              pin: '482913',
              expiresAt: DateTime.now().add(const Duration(minutes: 20)),
            )
          : null;

  final AppUser _child;
  UninstallPin? _pin;
  final cancelled = <String>[];
  final _pinUpdates = StreamController<List<UninstallPin>>.broadcast();

  @override
  Stream<List<AppUser>> watchChildren(String familyId) =>
      Stream.value([_child]);

  @override
  Stream<List<UninstallPin>> watchUninstallPins(String familyId) async* {
    yield [?_pin];
    yield* _pinUpdates.stream;
  }

  @override
  Future<void> cancelUninstallPin(String childId) async {
    cancelled.add(childId);
    _pin = null;
    _pinUpdates.add(const []);
  }
}
