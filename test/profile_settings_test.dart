import 'dart:typed_data';

import 'package:aura/core/l10n/l10n.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/core/widgets/user_avatar.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/features/auth/change_email_page.dart';
import 'package:aura/features/shared/settings_page.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gambar PNG 1x1 piksel, cukup untuk mewakili foto profil.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Lang.instance.resetForTest());

  /// Orang tua yang sudah masuk dengan email di mode demo.
  Future<AppState> parentWithEmail(WidgetTester tester) async {
    final repository = DemoRepository();
    final state = AppState(repository: repository);
    await tester.runAsync(() async {
      await repository.requestEmailCode('bunda@contoh.id');
      await repository.verifyEmailCode(
        email: 'bunda@contoh.id',
        code: '123456',
      );
      await state.signIn(
        name: 'Bunda',
        role: UserRole.parent,
        phone: '+6281234567890',
      );
    });
    return state;
  }

  Future<void> pump(WidgetTester tester, AppState state, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: AuraTheme.build(), home: page),
      ),
    );
    await tester.pump();
  }

  // Dua frame: yang pertama memulai animasi lembar, yang kedua
  // menyelesaikannya.
  Future<void> wait(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Profil menampilkan bagian Akun: nomor, email, bahasa', (
    tester,
  ) async {
    final state = await parentWithEmail(tester);
    await pump(tester, state, const Scaffold(body: SettingsBody()));

    expect(find.text('Akun'), findsOneWidget);
    expect(find.text('Nomor HP darurat'), findsOneWidget);
    expect(find.text('+62 812-3456-7890'), findsOneWidget);
    expect(find.text('bunda@contoh.id'), findsOneWidget);
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Ganti foto profil',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ganti bahasa ke English langsung mengubah teks Profil', (
    tester,
  ) async {
    final state = await parentWithEmail(tester);
    await pump(tester, state, const Scaffold(body: SettingsBody()));

    await tester.tap(find.text('Bahasa'));
    await wait(tester);
    await tester.tap(find.text('English'));
    await wait(tester);
    // Di aplikasi, AuraApp membangun ulang semuanya; di sini cukup halaman.
    await pump(tester, state, const Scaffold(body: SettingsBody()));

    expect(Lang.instance.current, AppLanguage.en);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Emergency phone number'), findsOneWidget);
    expect(find.text('Evidence integrity'), findsOneWidget);
    expect(find.text('Akun'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('aura.language'), 'en');
  });

  testWidgets('nomor HP darurat bisa diganti, nomor salah ditolak', (
    tester,
  ) async {
    final state = await parentWithEmail(tester);
    await pump(tester, state, const Scaffold(body: SettingsBody()));

    await tester.tap(find.text('Nomor HP darurat'));
    await wait(tester);
    expect(find.text('Ubah nomor HP'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0812');
    await tester.tap(find.text('Simpan'));
    await wait(tester);
    expect(
      find.text('Isi nomor HP Indonesia, mis. 0812 3456 7890'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '0813 1111 2222');
    await tester.tap(find.text('Simpan'));
    await wait(tester);

    expect(state.user?.phone, '+6281311112222');
    expect(find.text('Nomor HP darurat diperbarui.'), findsOneWidget);
  });

  testWidgets('email bisa diganti dengan kode', (tester) async {
    final state = await parentWithEmail(tester);
    await pump(tester, state, const ChangeEmailPage());

    expect(find.textContaining('bunda@contoh.id'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'bunda@contoh.id');
    await tester.tap(find.text('Kirim kode'));
    await wait(tester);
    expect(find.text('Ini sudah email Anda sekarang.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'bunda.baru@contoh.id');
    await tester.tap(find.text('Kirim kode'));
    await wait(tester);

    expect(find.text('Kode dari email baru'), findsOneWidget);
    expect(find.text('Kode dari email lama'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.tap(find.text('Simpan email baru'));
    await wait(tester);

    expect(find.text('Email berhasil diganti'), findsOneWidget);
    expect(state.accountEmail, 'bunda.baru@contoh.id');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('foto profil tampil setelah diunggah, inisial setelah dihapus', (
    tester,
  ) async {
    final state = await parentWithEmail(tester);
    await tester.runAsync(() => state.uploadAvatar(_pixel));
    expect(state.user?.avatarPath, isNotNull);

    await pump(tester, state, Scaffold(body: UserAvatar(user: state.user)));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.runAsync(state.removeAvatar);
    await pump(tester, state, Scaffold(body: UserAvatar(user: state.user)));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });
}
