import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/core/utils/name_input.dart';
import 'package:aura/core/utils/phone_number.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/features/auth/sign_in_page.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Begitu diketik karakter yang tidak boleh, kolom langsung memberi
/// peringatan, tidak menunggu tombol Lanjut.
void main() {
  Future<void> pump(WidgetTester tester, {required bool asChild}) async {
    final repository = DemoRepository();
    if (!asChild) {
      // Kolom nama dan nomor HP orang tua muncul setelah masuk dengan email.
      // runAsync: jeda pura-pura di DemoRepository memakai jam sungguhan.
      await tester.runAsync(() async {
        await repository.requestEmailCode('bunda@contoh.id');
        await repository.verifyEmailCode(
          email: 'bunda@contoh.id',
          code: '123456',
        );
      });
    }
    final state = AppState(repository: repository);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AuraTheme.build(),
          home: SignInPage(asChild: asChild),
        ),
      ),
    );
    // Pemeriksaan "akun lama atau baru" selesai.
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('angka di kolom nama memunculkan peringatan, lalu hilang', (
    tester,
  ) async {
    await pump(tester, asChild: false);

    await tester.enterText(field('Nama Anda'), 'Bunda1');
    await tester.pump();
    expect(find.text(nameOnlyLettersWarning), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Bunda',
    );

    // Ketikan berikutnya sudah benar: peringatan hilang.
    await tester.enterText(field('Nama Anda'), 'Bunda Sari');
    await tester.pump();
    expect(find.text(nameOnlyLettersWarning), findsNothing);
  });

  testWidgets('huruf di kolom nomor HP memunculkan peringatan', (tester) async {
    await pump(tester, asChild: false);

    await tester.enterText(field('Nomor HP Anda'), '0812abc');
    await tester.pump();
    expect(find.text(phoneOnlyDigitsWarning), findsOneWidget);

    await tester.enterText(field('Nomor HP Anda'), '081234567890');
    await tester.pump();
    expect(find.text(phoneOnlyDigitsWarning), findsNothing);
  });

  testWidgets('huruf di kolom usia anak memunculkan peringatan', (
    tester,
  ) async {
    await pump(tester, asChild: true);

    await tester.enterText(field('Usia anak'), '1a');
    await tester.pump();
    expect(find.text('Usia hanya boleh berisi angka.'), findsOneWidget);

    await tester.enterText(field('Usia anak'), '10');
    await tester.pump();
    expect(find.text('Usia hanya boleh berisi angka.'), findsNothing);
  });
}
