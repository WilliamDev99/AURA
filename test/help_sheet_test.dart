import 'package:aura/features/child/help_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Di Realme pengguna, pilihan "Pengaturan" terpotong ("BOTTOM OVERFLOWED")
/// sehingga anak tidak bisa membuka Pengaturan untuk menyalakan pemindaian
/// chat. Emulator berlayar tinggi tidak memperlihatkan masalah ini.
void main() {
  testWidgets('semua pilihan terjangkau di layar pendek dengan huruf besar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280); // 360 x 640 logis
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showHelpSheet(context),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'tidak boleh overflow');
    final settings = find.text('Pengaturan');
    await tester.ensureVisible(settings);
    await tester.pumpAndSettle();
    expect(settings.hitTestable(), findsOneWidget);
  });
}
