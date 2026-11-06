import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/l10n/l10n.dart';

/// Tingkat risiko sebuah pesan atau kejadian.
enum RiskLevel {
  safe(0, 'Aman', AuraColors.safe),
  low(1, 'Rendah', AuraColors.low),
  medium(2, 'Sedang', AuraColors.medium),
  high(3, 'Tinggi', AuraColors.high),
  critical(4, 'Kritis', AuraColors.critical);

  const RiskLevel(this.severity, this._label, this.color);

  final int severity;
  final String _label;
  final Color color;

  /// Nama dalam bahasa Indonesia, untuk berkas bukti resmi.
  String get labelId => _label;

  /// Nama dalam bahasa tampilan yang sedang dipakai.
  String get label => tr(_label);

  bool get notifiesParent => severity >= RiskLevel.medium.severity;
  bool get interruptsChild => severity >= RiskLevel.high.severity;

  static RiskLevel fromScore(double score) {
    if (score >= 0.85) return RiskLevel.critical;
    if (score >= 0.6) return RiskLevel.high;
    if (score >= 0.35) return RiskLevel.medium;
    if (score >= 0.15) return RiskLevel.low;
    return RiskLevel.safe;
  }

  static RiskLevel fromName(String? name) => RiskLevel.values.firstWhere(
    (r) => r.name == name,
    orElse: () => RiskLevel.safe,
  );
}

/// Kategori ancaman yang dikenali mesin analisis.
enum ThreatCategory {
  grooming('Grooming / Pendekatan Predator', Icons.person_search_rounded),
  sextortion('Permintaan Konten Seksual', Icons.no_photography_rounded),
  sexualHarassment('Pelecehan Seksual', Icons.do_not_touch_rounded),
  cyberbullying('Perundungan Siber', Icons.sentiment_very_dissatisfied_rounded),
  violence('Ancaman Kekerasan', Icons.warning_amber_rounded),
  selfHarm('Indikasi Menyakiti Diri', Icons.favorite_border_rounded),
  personalData('Kebocoran Data Pribadi', Icons.badge_outlined),
  meetup('Ajakan Bertemu Diam-diam', Icons.pin_drop_outlined),
  financial('Penipuan / Pemerasan Uang', Icons.payments_outlined),
  profanity('Kata Kasar Berlebihan', Icons.block_rounded),
  substance('Zat Terlarang', Icons.medication_liquid_rounded),
  gambling('Judi Online', Icons.casino_rounded);

  const ThreatCategory(this._label, this.icon);

  final String _label;
  final IconData icon;

  /// Nama dalam bahasa Indonesia, untuk berkas bukti resmi.
  String get labelId => _label;

  /// Nama dalam bahasa tampilan yang sedang dipakai.
  String get label => tr(_label);

  static ThreatCategory fromName(String? name) =>
      ThreatCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => ThreatCategory.profanity,
      );
}
