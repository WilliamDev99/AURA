import 'package:flutter/material.dart';

import '../../domain/models/risk.dart';
import '../../domain/models/threat_alert.dart';
import '../../core/l10n/l10n.dart';

/// Tingkat ancaman seperti di desain HP orang tua: LOW, MEDIUM, HARD.
///
/// Tiga tingkat yang dikirim ke orang tua (Sedang, Tinggi, Kritis)
/// ditampilkan dengan nama dan warna ini di heatmap Beranda dan di Log.
enum HeatTier {
  low(
    RiskLevel.medium,
    'LOW',
    color: Color(0xFF34C759),
    pill: Color(0xFFDDFBE3),
    ink: Color(0xFF1F9A40),
  ),
  medium(
    RiskLevel.high,
    'MEDIUM',
    color: Color(0xFFFFCC00),
    pill: Color(0xFFFFF4C2),
    ink: Color(0xFFC08A00),
  ),
  hard(
    RiskLevel.critical,
    'HARD',
    color: Color(0xFFFF2D55),
    pill: Color(0xFFFFD6DD),
    ink: Color(0xFFB3122E),
  );

  const HeatTier(
    this.level,
    this.label, {
    required this.color,
    required this.pill,
    required this.ink,
  });

  final RiskLevel level;
  final String label;
  final Color color;

  /// Latar label dan warna tulisannya.
  final Color pill;
  final Color ink;

  /// Peringatan "Rendah" tidak pernah dikirim ke orang tua; bila ada, ikut
  /// LOW.
  static HeatTier of(RiskLevel level) => switch (level) {
    RiskLevel.critical => hard,
    RiskLevel.high => medium,
    _ => low,
  };
}

/// Judul, ikon, dan label untuk peringatan di kartu, rincian, dan Log.
///
/// Tombol darurat tetap berlevel HARD (merah, dihitung di heatmap HARD),
/// tetapi diberi label SOS supaya orang tua langsung membedakannya dari
/// kata kasar berat, sama seperti judul notifikasinya ("Darurat: ...").
extension AlertLabels on ThreatAlert {
  bool get isSos => source == AlertSource.panicButton;

  String get headline =>
      isSos ? tr('Tombol SOS ditekan') : primaryCategory.label;

  IconData get headlineIcon =>
      isSos ? Icons.crisis_alert_rounded : primaryCategory.icon;

  /// Null berarti label level biasa (LOW / MEDIUM / HARD).
  String? get badgeLabel => isSos ? 'SOS' : null;
}

/// Label level LOW / MEDIUM / HARD, dipakai di kartu peringatan, rincian
/// peringatan, dan Log supaya semuanya sama.
class HeatBadge extends StatelessWidget {
  const HeatBadge({
    super.key,
    required this.tier,
    this.compact = false,
    this.background,
    this.label,
  });

  /// Null untuk bukti tanpa level (catatan sistem).
  final HeatTier? tier;
  final bool compact;

  /// Latar pengganti, mis. putih di atas kartu yang sudah sewarna level.
  final Color? background;

  /// Pengganti nama level, mis. "SOS" untuk tombol darurat. Warnanya tetap
  /// warna level.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tier = this.tier;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 2 : 1,
      ),
      decoration: BoxDecoration(
        color: background ?? tier?.pill ?? const Color(0xFFE6E8EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label ?? tier?.label ?? 'CATATAN',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: compact ? 11.5 : 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: tier?.ink ?? const Color(0xFF45507A),
        ),
      ),
    );
  }
}
