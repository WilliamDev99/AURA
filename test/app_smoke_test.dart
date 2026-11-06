import 'package:aura/data/demo_repository.dart';
import 'package:aura/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uji asap terhadap aplikasi sungguhan: memastikan layar utama merender dan
/// alur masuk berpindah ke antarmuka yang benar.
///
/// Animasi di AURA berulang tanpa henti (maskot, orb, radar), sehingga
/// `pumpAndSettle` tidak dipakai; frame dimajukan dengan durasi tetap.
void main() {
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(AuraApp(repository: DemoRepository()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> advance(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('layar pembuka menampilkan dua pilihan peran', (tester) async {
    await boot(tester);

    expect(find.text('AURA'), findsOneWidget);
    expect(find.text('Handphone Orang Tua'), findsOneWidget);
    expect(find.text('Handphone Anak'), findsOneWidget);
  });

  testWidgets('orang tua masuk dan melihat dashboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await boot(tester);
    await tester.tap(find.text('Handphone Orang Tua'));
    await advance(tester);

    expect(find.text('Masuk sebagai Orang Tua'), findsOneWidget);

    // Langkah 1: masuk dengan email dan kode (mode demo menerima kode apa
    // pun yang 6 angka).
    await tester.enterText(find.byType(TextFormField), 'bunda@contoh.id');
    await tester.tap(find.text('Kirim kode ke email'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump(const Duration(milliseconds: 300));
    await advance(tester);

    // Langkah 2: akun baru, jadi diminta nama dan nomor HP.
    expect(find.text('Masuk sebagai bunda@contoh.id'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Bunda');
    await tester.enterText(find.byType(TextFormField).last, '0812 3456 7890');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump(const Duration(milliseconds: 500));
    await advance(tester);

    expect(find.text('Halo Bunda,'), findsOneWidget);
    expect(find.text('AICyber Threat Heatmap'), findsOneWidget);
    expect(find.text('Status Proteksi'), findsOneWidget);
    expect(find.text('Anak terhubung'), findsOneWidget);
    // Navigasi bawah sesuai desain; Pengaturan pindah ke tab Profil.
    for (final tab in ['Beranda', 'Log', 'Laporan', 'Profil']) {
      expect(find.text(tab), findsOneWidget);
    }

    await tester.tap(find.text('Profil'));
    await advance(tester);
    expect(find.text('PROFIL'), findsOneWidget);
    expect(find.text('Integritas bukti'), findsOneWidget);

    // Tombol kembali di kepala halaman membawa ke Beranda.
    await tester.tap(find.bySemanticsLabel('Kembali ke Beranda'));
    await advance(tester);
    expect(find.text('Halo Bunda,'), findsOneWidget);
  });

  testWidgets('perangkat anak diminta menyetujui lebih dulu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await boot(tester);
    await tester.tap(find.text('Handphone Anak'));
    await advance(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Ayu');
    await tester.enterText(find.byType(TextFormField).last, '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pump(const Duration(milliseconds: 500));
    await advance(tester);

    // DemoRepository menandai anak sudah pernah menyetujui, sehingga beranda
    // anak langsung tampil sesuai desain.
    expect(find.text('Meet The'), findsOneWidget);
    expect(find.text('AURA!'), findsOneWidget);
    expect(find.text('Butuh bantuan?'), findsOneWidget);
    expect(find.text('Panic Orb'), findsOneWidget);
    expect(find.text('Tekan sekali untuk SOS'), findsOneWidget);
    // Status perlindungan tetap terlihat, sesuai janji di layar persetujuan.
    expect(find.bySemanticsLabel('Perlindungan aktif'), findsOneWidget);
  });
}
