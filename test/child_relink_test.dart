import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/features/child/child_pairing_page.dart';
import 'package:aura/features/shared/settings_page.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// HP anak bisa ditautkan ulang ke orang tua dari Profil, tanpa keluar akun.
void main() {
  Future<AppState> child(WidgetTester tester) async {
    final state = AppState(repository: DemoRepository());
    await tester.runAsync(
      () => state.signIn(name: 'Ayu', role: UserRole.child, age: 10),
    );
    return state;
  }

  Future<void> pump(WidgetTester tester, AppState state, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: AuraTheme.build(), home: home),
      ),
    );
    await tester.pump();
  }

  Future<void> wait(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Profil anak punya pilihan "Tautkan ke orang tua"', (
    tester,
  ) async {
    final state = await child(tester);
    await pump(tester, state, const Scaffold(body: SettingsBody()));

    expect(find.text('Tautkan ke orang tua'), findsOneWidget);
    expect(find.text('Sudah tersambung'), findsOneWidget);
    // Ubah nomor dan email hanya untuk orang tua.
    expect(find.text('Nomor HP darurat'), findsNothing);
  });

  testWidgets('tautkan ulang: konfirmasi dulu, lalu kembali ke Profil', (
    tester,
  ) async {
    final state = await child(tester);
    await pump(
      tester,
      state,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChildPairingPage(relink: true),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await wait(tester);

    // Halaman dibuka dari Profil: ada tombol kembali, tanpa tautan keluar.
    expect(find.text('Tautkan ke Orang Tua'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Keluar'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.pump();
    await tester.tap(find.text('Hubungkan'));
    await wait(tester);

    expect(find.text('Ganti sambungan orang tua?'), findsOneWidget);
    await tester.tap(find.text('Sambungkan'));
    await wait(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await wait(tester);

    expect(find.text('Tersambung ke orang tua.'), findsOneWidget);
    expect(find.text('buka'), findsOneWidget);
    expect(state.user?.familyId, DemoRepository.demoFamilyId);
  });

  testWidgets('batal di konfirmasi tidak mengubah sambungan', (tester) async {
    final state = await child(tester);
    await pump(tester, state, const ChildPairingPage(relink: true));

    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.pump();
    await tester.tap(find.text('Hubungkan'));
    await wait(tester);
    await tester.tap(find.text('Batal'));
    await wait(tester);

    expect(find.text('Tautkan ke Orang Tua'), findsOneWidget);
    expect(find.text('Tersambung ke orang tua.'), findsNothing);
  });
}
