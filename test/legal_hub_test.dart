import 'package:aura/core/widgets/clay.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/legal_article.dart';
import 'package:aura/domain/services/legal_mapper.dart';
import 'package:aura/features/parent/legal_hub_tab.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Tab "Laporan" orang tua: empat lembaga resmi dalam satu ketukan.
void main() {
  test('tautan WhatsApp memakai format internasional', () {
    const contact = EmergencyContact(
      name: 'SAPA 129 via WhatsApp',
      organization: 'Kementerian PPPA',
      channel: ContactChannel.whatsapp,
      value: '0811-1129-129',
      description: '',
    );
    expect(contact.uri.toString(), 'https://wa.me/628111129129');
  });

  test('semua kontak WhatsApp bisa dibuka', () {
    const mapper = LegalMapper();
    final whatsapp = mapper
        .contactsFor(const [])
        .where((c) => c.channel == ContactChannel.whatsapp);
    expect(whatsapp, isNotEmpty);
    for (final contact in whatsapp) {
      expect(contact.uri.path, startsWith('/62'), reason: contact.name);
    }
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final state = AppState(repository: DemoRepository());
    addTearDown(state.dispose);
    final signingIn = state.signIn(
      name: 'Bunda',
      role: UserRole.parent,
      phone: '+6281234567890',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: LegalHubTab())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('tampilan sesuai desain', (tester) async {
    await open(tester);

    expect(find.text('Pusat Aksi Hukum'), findsOneWidget);
    expect(find.text('Satu Ketukan, Perlindungan Hukum!'), findsOneWidget);
    for (final title in [
      'Buat laporan Polisi',
      'Hubungi Unit PPA',
      'Komnas Anak & KPAI',
      'LBH & Bantuan Hukum',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Kontak Darurat'), findsOneWidget);
    expect(find.text('Layanan Darurat Nasional'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kartu polisi membuka pilihan pelaporan', (tester) async {
    await open(tester);

    await tester.tap(find.text('Buat laporan Polisi'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Lapor online lewat Super App Polri'), findsOneWidget);
    // Lembar clay yang terang, dengan judul yang terbaca.
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      const Color(0xFFF2F0FB),
    );
    expect(
      tester.widget<Text>(find.text('Buat laporan Polisi').last).style?.color,
      ClayColors.ink,
    );
    expect(find.text('Datang ke SPKT terdekat'), findsOneWidget);
    expect(find.text('Darurat: telepon 110'), findsOneWidget);
  });

  testWidgets('layar kecil dengan huruf besar tidak berantakan', (
    tester,
  ) async {
    await open(tester);
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });
}
