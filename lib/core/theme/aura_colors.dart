import 'package:flutter/material.dart';

/// Palet warna AURA — diturunkan dari identitas visual kunci:
/// langit malam biru tua, aksen oranye-merah "guardian", dan cyan teknologi.
abstract final class AuraColors {
  // Latar
  static const deepNavy = Color(0xFF050B2E);
  static const midnight = Color(0xFF0A1340);
  static const royal = Color(0xFF13277A);
  static const ocean = Color(0xFF1E4FD8);

  // Aksen
  static const ember = Color(0xFFFF7A2F);
  static const flame = Color(0xFFE8452C);
  static const cyan = Color(0xFF4FC3F7);
  static const electric = Color(0xFF2F6BFF);

  // Status risiko
  static const safe = Color(0xFF2ECC71);
  static const low = Color(0xFF4FC3F7);
  static const medium = Color(0xFFFFB020);
  static const high = Color(0xFFFF6B35);
  static const critical = Color(0xFFFF2D55);

  // Netral
  static const surface = Color(0xFF111C44);
  static const glass = Color(0x1AFFFFFF);
  static const glassStroke = Color(0x33FFFFFF);
  static const textPrimary = Color(0xFFF5F8FF);
  static const textSecondary = Color(0xB3F5F8FF);
  static const textMuted = Color(0x80F5F8FF);

  /// Gradien latar utama aplikasi.
  static const backdrop = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepNavy, midnight, royal],
    stops: [0.0, 0.5, 1.0],
  );

  /// Gradien tombol darurat (Panic Orb).
  static const panic = RadialGradient(
    center: Alignment(-0.3, -0.4),
    radius: 1.1,
    colors: [Color(0xFFFF8A5C), flame, Color(0xFF8E1B10)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gradien aksen hangat untuk highlight.
  static const warm = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [ember, flame],
  );

  /// Gradien dingin untuk elemen AI.
  static const cool = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, electric],
  );
}
