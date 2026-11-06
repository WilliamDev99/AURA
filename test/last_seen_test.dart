import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mencatat setiap kabar "masih aktif" yang dikirim ke server.
class _CountingRepo extends DemoRepository {
  int marks = 0;
  bool offline = false;

  @override
  Future<void> markActive() async {
    if (offline) throw Exception('tidak ada internet');
    marks++;
    await super.markActive();
  }
}

/// Tulisan "Aktif ..." di ponsel orang tua harus mengikuti kapan AURA di
/// ponsel anak terakhir berjalan, bukan kapan anak pertama kali masuk.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> signIn(_CountingRepo repo, UserRole role) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(repository: repo);
    addTearDown(state.dispose);
    await state.signIn(name: 'Ayu', role: role, age: 12);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return state;
  }

  test('ponsel anak mengabarkan aktif saat sesi dimulai', () async {
    final repo = _CountingRepo();
    final state = await signIn(repo, UserRole.child);

    expect(repo.marks, 1);
    final seen = state.user!.lastSeenAt!;
    expect(DateTime.now().difference(seen).inSeconds, lessThan(5));
  });

  test('dibuka-tutup berkali-kali: tidak menulis setiap kali', () async {
    final repo = _CountingRepo();
    final state = await signIn(repo, UserRole.child);

    await state.markActive();
    await state.markActive();

    expect(repo.marks, 1);
  });

  test('gagal karena offline: dicoba lagi berikutnya', () async {
    final repo = _CountingRepo()..offline = true;
    final state = await signIn(repo, UserRole.child);
    expect(repo.marks, 0);

    repo.offline = false;
    await state.markActive();

    expect(repo.marks, 1);
  });

  test('ponsel orang tua tidak mengirim kabar aktif', () async {
    final repo = _CountingRepo();
    final state = await signIn(repo, UserRole.parent);

    await state.markActive();

    expect(repo.marks, 0);
  });
}
