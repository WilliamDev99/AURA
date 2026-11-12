import 'dart:io';

import 'package:aura/core/services/notification_scanner.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jam istirahat yang diubah orang tua berlaku di HP anak dalam hitungan
/// detik, bukan menunggu satu menit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> android(String method) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'id.aura/scan',
          const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
          (_) {},
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('layar HP anak menyala: profil langsung diambil ulang', () async {
    final repo = _CountingRepo();
    final state = AppState(repository: repo);
    addTearDown(state.dispose);
    await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    NotificationScanner(state).start();

    await android('refreshProfile');
    expect(repo.refreshes, 1);
  });

  test('HP orang tua tidak mengambil ulang apa pun', () async {
    final repo = _CountingRepo();
    final state = AppState(repository: repo);
    addTearDown(state.dispose);
    await state.signIn(
      name: 'Bunda',
      role: UserRole.parent,
      phone: '081234567890',
    );
    await state.refreshProfile();
    expect(repo.refreshes, 0);
  });

  group('di Android', () {
    String read(String path) => File(path).readAsStringSync();

    test('pengunci memeriksa saat itu juga begitu jadwal baru tersimpan', () {
      final lock = read(
        'android/app/src/main/kotlin/id/aura/aura/ScreenLock.kt',
      );
      expect(lock, contains('registerOnSharedPreferenceChangeListener'));
      expect(lock, contains('if (key == SCHEDULE_KEY) checkNow()'));
      expect(lock, contains('unregisterOnSharedPreferenceChangeListener'));
    });

    test('layar menyala: Dart diminta mengambil ulang profil', () {
      final lock = read(
        'android/app/src/main/kotlin/id/aura/aura/ScreenLock.kt',
      );
      expect(lock, contains('AuraEngine.refreshProfile('));
      final engine = read(
        'android/app/src/main/kotlin/id/aura/aura/AuraEngine.kt',
      );
      expect(engine, contains('"refreshProfile"'));
    });

    test('token login HP anak tetap diperbarui tanpa layar', () {
      final repository = read('lib/data/supabase_repository.dart');
      expect(repository, contains('class _ChildSessionKeeper'));
      expect(repository, contains('_auth.startAutoRefresh()'));
      // Juga saat sesi tersimpan sudah kedaluwarsa ketika AURA dinyalakan
      // tanpa layar.
      final saved = repository.substring(
        repository.indexOf('Future<void> showSavedProfile('),
      );
      expect(
        saved.substring(0, saved.indexOf('\n    }\n')),
        contains('keeper.keepFresh()'),
      );
    });
  });
}

class _CountingRepo extends DemoRepository {
  int refreshes = 0;

  @override
  Future<void> refreshProfile() async => refreshes++;
}
