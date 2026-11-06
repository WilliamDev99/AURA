import 'package:aura/core/theme/aura_colors.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/core/widgets/aura_widgets.dart';
import 'package:aura/core/widgets/clay.dart';
import 'package:aura/core/widgets/heat_tier.dart';
import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/features/parent/alert_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tulisan di atas kartu clay yang terang harus gelap; di luar kartu clay
/// (latar gelap) tetap terang seperti semula.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AuraTheme.build(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  Color colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  testWidgets('InfoRow di atas clay memakai tulisan gelap', (tester) async {
    await pump(
      tester,
      const ClayCard(
        child: InfoRow(label: 'Waktu', value: '10.00'),
      ),
    );

    expect(colorOf(tester, 'Waktu'), ClayColors.inkMuted);
    expect(colorOf(tester, '10.00'), ClayColors.ink);
  });

  testWidgets('InfoRow di latar gelap tetap terang', (tester) async {
    await pump(tester, const InfoRow(label: 'Waktu', value: '10.00'));

    expect(colorOf(tester, 'Waktu'), AuraColors.textMuted);
    expect(colorOf(tester, '10.00'), AuraColors.textPrimary);
  });

  testWidgets('lencana risiko digelapkan di atas clay', (tester) async {
    await pump(
      tester,
      const ClayCard(child: RiskBadge(level: RiskLevel.medium)),
    );

    expect(colorOf(tester, 'SEDANG'), ClayColors.deep(AuraColors.medium));
  });

  testWidgets('teks bergaya tema di kartu peringatan ikut gelap', (
    tester,
  ) async {
    // Dulu "Ayu - WhatsApp" memakai tema halaman yang gelap, sehingga
    // tulisannya putih di atas kartu putih.
    await pump(
      tester,
      AlertCard(
        alert: ThreatAlert(
          id: 'a1',
          familyId: 'f1',
          childId: 'c1',
          childName: 'Ayu',
          riskLevel: RiskLevel.high,
          categories: const [ThreatCategory.profanity],
          source: AlertSource.messageScan,
          platform: 'WhatsApp',
          detectedAt: DateTime(2026, 10, 29, 6, 33),
          summary: 'Ancaman terdeteksi.',
          excerpt: 'contoh',
          score: 0.7,
          evidenceIds: const [],
        ),
      ),
    );

    expect(colorOf(tester, 'Ayu - WhatsApp'), ClayColors.inkSoft);
    expect(colorOf(tester, '29 Okt, 06:33'), ClayColors.inkSoft);
  });

  // Kartu peringatan memakai label yang sama dengan heatmap dan Log.
  for (final (level, label, old) in [
    (RiskLevel.medium, 'LOW', 'SEDANG'),
    (RiskLevel.high, 'MEDIUM', 'TINGGI'),
    (RiskLevel.critical, 'HARD', 'KRITIS'),
  ]) {
    testWidgets('kartu peringatan ${level.label} berlabel $label', (
      tester,
    ) async {
      await pump(
        tester,
        AlertCard(
          alert: ThreatAlert(
            id: 'a-$label',
            familyId: 'f1',
            childId: 'c1',
            childName: 'Ayu',
            riskLevel: level,
            categories: const [ThreatCategory.profanity],
            source: AlertSource.messageScan,
            platform: 'WhatsApp',
            detectedAt: DateTime(2026, 10, 29, 6, 33),
            summary: '',
            excerpt: 'contoh',
            score: 0.7,
            evidenceIds: const [],
          ),
        ),
      );

      expect(find.text(label), findsOneWidget);
      expect(find.text(old), findsNothing);
      expect(colorOf(tester, label), HeatTier.of(level).ink);
    });
  }

  testWidgets('tombol darurat berlabel SOS, bukan HARD, tetap merah', (
    tester,
  ) async {
    await pump(
      tester,
      AlertCard(
        alert: ThreatAlert(
          id: 'sos',
          familyId: 'f1',
          childId: 'c1',
          childName: 'William',
          riskLevel: RiskLevel.critical,
          categories: const [ThreatCategory.violence],
          source: AlertSource.panicButton,
          platform: 'Tombol Darurat AURA',
          detectedAt: DateTime(2026, 11, 2, 14, 57),
          summary: '',
          score: 1,
        ),
      ),
    );

    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('HARD'), findsNothing);
    expect(find.text('Tombol SOS ditekan'), findsOneWidget);
    expect(find.byIcon(Icons.crisis_alert_rounded), findsOneWidget);
    expect(colorOf(tester, 'SOS'), HeatTier.hard.ink);
  });

  testWidgets('tulisan biasa di dalam clay ikut gelap', (tester) async {
    await pump(tester, const ClayCard(child: Text('Halo')));

    final style = DefaultTextStyle.of(tester.element(find.text('Halo'))).style;
    expect(style.color, ClayColors.ink);
  });
}
