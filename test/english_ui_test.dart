import 'package:aura/core/l10n/l10n.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aplikasi sungguhan dalam bahasa Inggris, dari layar pembuka sampai
/// dashboard orang tua.
void main() {
  setUp(() => Lang.instance.resetForTest(AppLanguage.en));
  tearDown(() => Lang.instance.resetForTest());

  Future<void> advance(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('orang tua masuk dan melihat dashboard dalam bahasa Inggris', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(AuraApp(repository: DemoRepository()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Safe online, at peace offline.'), findsOneWidget);
    await tester.tap(find.text("Parent's Phone"));
    await advance(tester);

    expect(find.text('Sign in as Parent'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'mom@example.com');
    await tester.tap(find.text('Send code to email'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 300));
    await advance(tester);

    expect(find.text('One more step'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Sarah');
    await tester.enterText(find.byType(TextFormField).last, '0812 3456 7890');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 500));
    await advance(tester);

    expect(find.text('Hello Sarah,'), findsOneWidget);
    expect(find.text('Protection Status'), findsOneWidget);
    expect(find.text('Connected children'), findsOneWidget);
    expect(find.text('Latest alerts'), findsOneWidget);
    for (final tab in ['Home', 'Log', 'Reports', 'Profile']) {
      expect(find.text(tab), findsOneWidget);
    }
    // Tidak ada sisa bahasa Indonesia di menu bawah.
    expect(find.text('Beranda'), findsNothing);
  });

  testWidgets('ponsel anak juga berbahasa Inggris', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(AuraApp(repository: DemoRepository()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text("Child's Phone"));
    await advance(tester);

    expect(find.text('Register Child'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Ayu');
    await tester.enterText(find.byType(TextFormField).last, '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump(const Duration(milliseconds: 500));
    await advance(tester);

    // DemoRepository menandai anak sudah menyetujui: beranda anak tampil.
    expect(find.text('Need help?'), findsOneWidget);
    expect(find.text('Press once for SOS'), findsOneWidget);
    expect(find.bySemanticsLabel('Protection on'), findsOneWidget);
    expect(find.text('Butuh bantuan?'), findsNothing);
  });
}
