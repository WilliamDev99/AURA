import 'package:aura/core/utils/name_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<TextEditingController> pumpField(WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: nameInputFormatters(),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('kolom nama menolak angka dan simbol saat diketik', (
    tester,
  ) async {
    final controller = await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'Bunda123');
    expect(controller.text, 'Bunda');

    await tester.enterText(find.byType(TextField), 'Ayu_2015!@#');
    expect(controller.text, 'Ayu');
  });

  testWidgets('nama yang wajar tetap bisa diketik', (tester) async {
    final controller = await pumpField(tester);

    for (final name in [
      "Ma'ruf Amin",
      'St. Aisyah',
      'Anne-Marie',
      'Sinta Dewi',
      'Zoë',
    ]) {
      await tester.enterText(find.byType(TextField), name);
      expect(controller.text, name);
    }
  });

  test('validasi nama', () {
    expect(validateName('Bunda'), isNull);
    expect(validateName('Al'), isNull);
    expect(validateName('A'), isNotNull);
    expect(validateName("..'-"), isNotNull);
    expect(validateName(null), isNotNull);
    // Bila angka lolos lewat jalur lain, tetap ditolak.
    expect(validateName('Bunda 2'), 'Nama tidak boleh berisi angka');
  });
}
