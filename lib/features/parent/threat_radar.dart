import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../domain/models/threat_alert.dart';

/// Peta visual ancaman: cincin radar dengan titik per peringatan.
///
/// Jarak titik dari pusat mewakili seberapa lama kejadiannya (makin ke tepi
/// makin lama), dan warnanya mewakili tingkat risiko. Seperti layar radar
/// sungguhan, titik baru muncul saat jarum melewatinya, lalu memudar sampai
/// jarum datang lagi.
class ThreatRadar extends StatefulWidget {
  const ThreatRadar({
    super.key,
    required this.alerts,
    this.size = 190,
    this.dotColor,
  });

  final List<ThreatAlert> alerts;
  final double size;

  /// Warna titik per peringatan. Bawaan: warna tingkat risikonya.
  final Color Function(ThreatAlert alert)? dotColor;

  /// Kecerahan titik (0..1) saat jarum berada di [handAngle].
  ///
  /// Menyala penuh tepat setelah jarum melewatinya, memudar sepanjang
  /// [fadeTurns] putaran, lalu tidak terlihat sampai jarum datang lagi.
  @visibleForTesting
  static double blipStrength(
    double handAngle,
    double dotAngle, {
    double fadeTurns = 0.8,
  }) {
    const turn = 2 * math.pi;
    // Sudut sejak jarum melewati titik; 0 berarti baru saja dilewati.
    final since = (handAngle - dotAngle) % turn;
    final t = 1 - since / (fadeTurns * turn);
    if (t <= 0) return 0;
    return math.pow(t, 1.5).toDouble();
  }

  @override
  State<ThreatRadar> createState() => _ThreatRadarState();
}

class _ThreatRadarState extends State<ThreatRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  /// Animasi dimatikan di pengaturan ponsel: jarum diam, semua titik tampil.
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _RadarPainter(
          alerts: widget.alerts,
          sweep: _sweep.value,
          dotColor: widget.dotColor,
          revealAll: _still,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.alerts,
    required this.sweep,
    this.dotColor,
    this.revealAll = false,
  });

  final List<ThreatAlert> alerts;
  final double sweep;
  final Color Function(ThreatAlert alert)? dotColor;

  /// Tampilkan semua titik penuh, tanpa efek sapuan.
  final bool revealAll;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Garis tebal: cincin terluar digambar sedikit ke dalam supaya tidak
    // terpotong di tepi kanvas.
    final stroke = size.width * 0.028;
    final radius = size.width / 2 - stroke / 2;

    // Cincin dan garis silang putih tebal.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.95);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, ring);
    }
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ring,
    );

    // Jejak sapuan di belakang jarum.
    final handAngle = sweep * 2 * math.pi + math.pi * 0.75;
    const trail = math.pi / 2.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      handAngle - trail,
      trail,
      true,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(handAngle - trail),
          endAngle: trail,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.22),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Jarum radar dengan kenop di ujungnya.
    final direction = Offset(math.cos(handAngle), math.sin(handAngle));
    canvas.drawLine(center, center + direction * radius * 1.12, ring);
    final knob = center + direction * radius * 0.8;
    canvas.drawCircle(knob, stroke * 1.6, Paint()..color = Colors.white);
    canvas.drawCircle(
      knob,
      stroke * 1.05,
      Paint()..color = const Color(0xFFFFD3DF),
    );

    // Titik ancaman.
    final now = DateTime.now();
    for (var i = 0; i < alerts.length && i < 12; i++) {
      final alert = alerts[i];
      final ageHours = now.difference(alert.detectedAt).inMinutes / 60;
      final distance = (0.28 + (ageHours / 72).clamp(0.0, 0.66)) * radius;

      // Sudut ditentukan dari id agar posisinya stabil antar-penggambaran.
      final angle = (alert.id.hashCode % 360) * math.pi / 180;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;

      final color = alert.status == AlertStatus.dismissed
          ? AuraColors.textMuted
          : dotColor?.call(alert) ?? alert.riskLevel.color;

      // Titik baru muncul saat dilewati jarum, lalu memudar.
      final strength = revealAll
          ? 1.0
          : ThreatRadar.blipStrength(handAngle, angle);
      if (strength <= 0.01) continue;

      // Sesaat setelah dilewati: titik sedikit membesar dan memancarkan
      // denyut, supaya kemunculannya terlihat.
      const pulse = 0.45; // radian
      final since = (handAngle - angle) % (2 * math.pi);
      final fresh = revealAll ? 0.0 : math.max(0.0, 1 - since / pulse);
      final dot = size.width * 0.042 * (1 + 0.35 * fresh);
      if (fresh > 0) {
        canvas.drawCircle(
          point,
          dot * (1.3 + 1.7 * (1 - fresh)),
          Paint()..color = color.withValues(alpha: 0.5 * fresh),
        );
      }

      // Titik berwarna dengan tepi putih, seperti pin di peta.
      canvas.drawCircle(
        point,
        dot + stroke * 0.55,
        Paint()..color = Colors.white.withValues(alpha: strength),
      );
      canvas.drawCircle(
        point,
        dot,
        Paint()..color = color.withValues(alpha: strength),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.sweep != sweep ||
      oldDelegate.alerts != alerts ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.revealAll != revealAll;
}
