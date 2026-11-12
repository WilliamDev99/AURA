import 'package:aura/features/child/panic_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Halo titik-titik di sekeliling Panic Orb bergerak terus seperti suar SOS,
/// kecuali pengguna mematikan animasi di pengaturan aksesibilitas.
void main() {
  Widget orb({required bool reduceMotion}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(child: PanicOrb(size: 200, onTap: () {})),
        ),
      ),
    );
  }

  testWidgets('halo terus bergerak selama animasi diizinkan', (tester) async {
    await tester.pumpWidget(orb(reduceMotion: false));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'halo berhenti bergerak setelah ${(i + 1) * 200} ms',
      );
    }
  });

  testWidgets('halo diam bila pengguna mematikan animasi', (tester) async {
    await tester.pumpWidget(orb(reduceMotion: true));
    // Bila ada animasi yang terus berjalan, pumpAndSettle tidak akan pernah
    // selesai dan test ini gagal karena batas waktu.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('halo kembali bergerak saat animasi dinyalakan lagi', (
    tester,
  ) async {
    await tester.pumpWidget(orb(reduceMotion: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(orb(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets(
    'layar belum punya ukuran: orb tidak membuat aplikasi macet',
    (tester) async {
      // Saat Android menyalakan AURA di latar belakang untuk pemindai pesan,
      // beranda anak dibangun dengan layar 0 x 0. Dulu jarak antarcincin halo
      // ikut nol dan loop menggambarnya tidak pernah selesai: aplikasi macet
      // di layar pembuka saat ikonnya diketuk, dan tombol SOS tidak pernah
      // muncul. Kalau bug itu kembali, test ini berhenti karena batas waktu.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PanicOrb(size: 0, onTap: () {})),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
