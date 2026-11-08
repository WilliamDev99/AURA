import 'package:aura/core/utils/phone_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nomor yang biasa diketik orang tua diterima', () {
    for (final input in [
      '081234567890',
      '0812 3456 7890',
      '0812-3456-7890',
      '+62 812 3456 7890',
      '6281234567890',
      '(0812) 3456-7890',
    ]) {
      test(input, () {
        expect(normalizeIndonesianPhone(input), '+6281234567890');
      });
    }
  });

  group('nomor yang tidak masuk akal ditolak', () {
    // Nomor salah lebih berbahaya daripada tidak ada nomor: anak akan mengira
    // orang tuanya sedang ditelepon.
    for (final input in [
      '',
      '12345',
      '021 555 1234', // telepon rumah, bukan seluler
      '0812345', // terlalu pendek
      '08123456789012345', // terlalu panjang
      '+1 415 555 0100', // bukan nomor Indonesia
      'nomor saya',
    ]) {
      test(input.isEmpty ? '(kosong)' : input, () {
        expect(normalizeIndonesianPhone(input), isNull);
      });
    }
  });

  test('tampilan nomor mudah dibaca', () {
    expect(formatIndonesianPhone('+6281234567890'), '+62 812-3456-7890');
  });

  test('nomor WhatsApp: angka saja, berawalan 62', () {
    expect(whatsAppDigits('+6281234567890'), '6281234567890');
    expect(whatsAppDigits('0812-3456-7890'), '6281234567890');
    // Nomor yang tidak masuk akal tidak boleh ditelepon lewat WhatsApp juga.
    expect(whatsAppDigits('12345'), isNull);
  });

  testWidgets('kolom nomor HP menolak huruf saat diketik', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: phoneInputFormatters(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'abc0812-34x56 78+90z');
    expect(controller.text, '0812-3456 78+90');

    await tester.enterText(find.byType(TextField), 'nomor saya');
    expect(controller.text, ' ');

    // Nomor terpanjang yang wajar tetap muat.
    await tester.enterText(find.byType(TextField), '+62 812-3456-789012');
    expect(controller.text, '+62 812-3456-789012');
  });
}
