import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/features/auth/secure_account_page.dart';
import 'package:aura/features/auth/sign_in_page.dart';
import 'package:aura/features/shared/settings_page.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Orang tua lama yang masuk lagi setelah pasang ulang aplikasi: akunnya
/// sudah punya profil.
class _ReturningParentRepo extends DemoRepository {
  @override
  Future<bool> hasProfile() async => true;
}

void main() {
  Future<AppState> pump(
    WidgetTester tester,
    Widget page, {
    AppState? state,
  }) async {
    // Layar setinggi ponsel: di 800x600 bawaan, tombol Masuk di bawah layar.
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appState = state ?? AppState(repository: DemoRepository());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(theme: AuraTheme.build(), home: page),
      ),
    );
    return appState;
  }

  Future<void> wait(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 300));

  Future<void> sendCode(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.tap(find.text('Kirim kode ke email'));
    await wait(tester);
  }

  testWidgets('orang tua baru: email, kode, lalu nama dan nomor HP', (
    tester,
  ) async {
    await pump(tester, const SignInPage(asChild: false));

    // Belum masuk: hanya pilihan Facebook dan email, belum ada kolom nama.
    expect(find.text('Lanjutkan dengan Facebook'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nama Anda'), findsNothing);

    await sendCode(tester, 'Bunda@Contoh.id');
    expect(find.textContaining('bunda@contoh.id'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await wait(tester);
    await tester.pump();

    expect(find.text('Masuk sebagai bunda@contoh.id'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nama Anda'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nomor HP Anda'), findsOneWidget);
  });

  testWidgets('kode kurang dari 6 angka ditolak, huruf tidak bisa diketik', (
    tester,
  ) async {
    await pump(tester, const SignInPage(asChild: false));
    await sendCode(tester, 'bunda@contoh.id');

    await tester.enterText(find.byType(TextFormField), '12a3');
    expect(find.text('123'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    expect(find.text('Kode terdiri dari 6 angka'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('email yang salah ditolak sebelum kode dikirim', (tester) async {
    await pump(tester, const SignInPage(asChild: false));

    await sendCode(tester, 'bunda.contoh.id');

    expect(
      find.text('Isi alamat email yang benar, mis. nama@gmail.com'),
      findsOneWidget,
    );
    expect(find.text('Kode dari email'), findsNothing);
  });

  testWidgets('kirim ulang kode baru bisa setelah 60 detik', (tester) async {
    await pump(tester, const SignInPage(asChild: false));
    await sendCode(tester, 'bunda@contoh.id');

    expect(find.text('Kirim ulang (0:60)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kirim ulang (0:59)'), findsOneWidget);

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Kirim ulang kode'), findsOneWidget);

    // Ganti email kembali ke kolom email.
    await tester.tap(find.text('Ganti email'));
    await tester.pump();
    expect(find.text('Kirim kode ke email'), findsOneWidget);
  });

  testWidgets('Facebook: akun baru lalu diminta nama dan nomor HP', (
    tester,
  ) async {
    await pump(tester, const SignInPage(asChild: false));

    await tester.tap(find.text('Lanjutkan dengan Facebook'));
    await wait(tester);
    await tester.pump();

    expect(find.text('Masuk sebagai Facebook'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nama Anda'), findsOneWidget);
  });

  testWidgets('orang tua lama tidak diminta mengisi nama lagi', (tester) async {
    await pump(
      tester,
      const SignInPage(asChild: false),
      state: AppState(repository: _ReturningParentRepo()),
    );
    await sendCode(tester, 'bunda@contoh.id');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await wait(tester);
    await tester.pump();

    expect(find.text('Membuka akun Anda...'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nama Anda'), findsNothing);
  });

  group('akun orang tua lama yang masih anonim', () {
    Future<AppState> signedInWithoutAccount(WidgetTester tester) async {
      final state = AppState(repository: DemoRepository());
      await tester.runAsync(
        () => state.signIn(
          name: 'Bunda',
          role: UserRole.parent,
          phone: '+6281234567890',
        ),
      );
      return state;
    }

    testWidgets('Profil mengajak mengamankan akun', (tester) async {
      final state = await signedInWithoutAccount(tester);
      expect(state.needsAccountSecuring, isTrue);

      await pump(tester, const Scaffold(body: SettingsBody()), state: state);

      expect(find.text('Amankan akun Anda'), findsOneWidget);
    });

    testWidgets('keluar diperingatkan dulu, dan bisa dibatalkan', (
      tester,
    ) async {
      final state = await signedInWithoutAccount(tester);
      await pump(tester, const Scaffold(body: SettingsBody()), state: state);

      await tester.ensureVisible(find.text('Keluar'));
      await tester.pump();
      await tester.tap(find.text('Keluar'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Akun belum diamankan'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.isSignedIn, isTrue);
    });

    testWidgets('setelah email disambungkan, akun dinyatakan aman', (
      tester,
    ) async {
      final state = await signedInWithoutAccount(tester);
      await pump(tester, const SecureAccountPage(), state: state);

      await sendCode(tester, 'bunda@contoh.id');
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await wait(tester);

      expect(find.text('Akun sudah aman'), findsOneWidget);
      expect(state.needsAccountSecuring, isFalse);
      // Akunnya tetap yang sama.
      expect(state.user?.name, 'Bunda');
    });
  });
}
