import 'dart:async';

import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/domain/services/chain_of_custody.dart';
import 'package:aura/domain/services/dossier_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Berkas PDF untuk polisi harus tetap jadi dan tidak boleh kehilangan satu
/// karakter pun, walau isi chat anak berisi emoji, tanda baca miring, dan
/// nama grup WhatsApp yang aneh-aneh.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThreatAlert alert(String excerpt, String sender) => ThreatAlert(
    id: 'a-${excerpt.hashCode}',
    familyId: 'f1',
    childId: 'c1',
    childName: 'William',
    riskLevel: RiskLevel.high,
    categories: const [ThreatCategory.profanity],
    source: AlertSource.messageScan,
    platform: 'WhatsApp',
    detectedAt: DateTime(2026, 10, 30, 18, 35),
    summary:
        'Ancaman terdeteksi: percakapan memuat kata kasar atau tidak sopan.',
    excerpt: excerpt,
    counterpartName: sender,
    score: 0.6,
    evidenceIds: const [],
  );

  test('emoji ditulis sebagai kodenya, bukan dibuang', () {
    expect(DossierBuilder.printable('njirr😭'), 'njirr[U+1F62D]');
    // Penyambung emoji (ZWJ) dan pemilih varian tidak terlihat.
    expect(DossierBuilder.printable('🙏🏻'), '[U+1F64F][U+1F3FB]');
    expect(DossierBuilder.printable('❤️'), '[U+2764]');
  });

  test('huruf Indonesia dan tanda baca tetap apa adanya', () {
    const text = '“Kutip” ‘tunggal’ – tanda pisah — elipsis… café, Rp 5.000 €';
    expect(DossierBuilder.printable(text), text);
  });

  test('PDF jadi tanpa ada karakter yang hilang', () async {
    final warnings = <String>[];
    final bytes = await runZoned(
      () => const DossierBuilder().build(
        reporter: const AppUser(
          id: 'p1',
          name: 'william',
          role: UserRole.parent,
          phone: '+6281243456789',
        ),
        alerts: [
          alert('komen komennya berasa dark web njirr😭😭😭', 'Budi'),
          alert(
            'cok knp kek di sessa ta',
            '~ tacaaa di grup LOMBA SIIF 🥺🙏🏻',
          ),
          alert('“kutip” – tanda pisah … café dan 中文', 'Ayu'),
        ],
        evidence: const [],
        verification: const ChainVerification(
          isIntact: true,
          checked: 0,
          brokenAt: null,
          reason: 'Belum ada bukti.',
        ),
        childName: 'William',
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => warnings.add(line),
      ),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      warnings.where((w) => w.contains('Unable to find a font')),
      isEmpty,
      reason: 'ada karakter yang hilang dari PDF',
    );
    expect(warnings.where((w) => w.contains('no Unicode support')), isEmpty);
  });
}
