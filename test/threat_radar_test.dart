import 'dart:math' as math;

import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/features/parent/threat_radar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Radar seperti layar radar sungguhan: titik muncul saat dilewati jarum,
/// lalu memudar sampai jarum datang lagi.
void main() {
  const dot = 1.0; // sudut titik, radian

  test('titik menyala penuh tepat setelah dilewati jarum', () {
    expect(ThreatRadar.blipStrength(dot + 0.01, dot), greaterThan(0.95));
  });

  test('titik belum terlihat sesaat sebelum jarum tiba', () {
    expect(ThreatRadar.blipStrength(dot - 0.05, dot), 0);
  });

  test('titik memudar perlahan, bukan hilang mendadak', () {
    final values = [
      for (var turn = 0.05; turn < 0.8; turn += 0.1)
        ThreatRadar.blipStrength(dot + turn * 2 * math.pi, dot),
    ];
    for (var i = 1; i < values.length; i++) {
      expect(values[i], lessThan(values[i - 1]));
    }
    expect(values.last, greaterThan(0));
  });

  test('putaran berikutnya menyalakan titik lagi', () {
    final first = ThreatRadar.blipStrength(dot + 0.01, dot);
    final next = ThreatRadar.blipStrength(dot + 0.01 + 2 * math.pi, dot);
    expect(next, closeTo(first, 1e-9));
  });

  ThreatAlert alert(String id) => ThreatAlert(
    id: id,
    familyId: 'f',
    childId: 'c',
    childName: 'Ayu',
    riskLevel: RiskLevel.high,
    categories: const [ThreatCategory.profanity],
    source: AlertSource.messageScan,
    platform: 'WhatsApp',
    detectedAt: DateTime.now(),
    summary: '',
    excerpt: null,
    score: 0.7,
    evidenceIds: const [],
  );

  testWidgets('jarum berputar tanpa galat', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ThreatRadar(
            alerts: [for (var i = 0; i < 8; i++) alert('a$i')],
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('animasi dimatikan: radar diam dan tetap tampil', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Center(child: ThreatRadar(alerts: [alert('a1')])),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ThreatRadar), findsOneWidget);
    // Tidak ada animasi yang terus berjalan.
    expect(tester.hasRunningAnimations, isFalse);
  });
}
