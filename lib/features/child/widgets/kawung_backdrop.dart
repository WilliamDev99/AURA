import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Latar beranda anak: biru terang di atas, malam di tengah, lalu cahaya
/// merah-oranye di bawah, dihiasi motif batik kawung.
///
/// Kawung dipilih sebagai identitas: motif Nusantara yang dikenal anak, dan
/// maknanya — empat buah aren yang mengelilingi pusat — cocok dengan gagasan
/// AURA sebagai penjaga yang mengelilingi anak.
class KawungBackdrop extends StatelessWidget {
  const KawungBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2A5CEB),
                Color(0xFF1D41CF),
                Color(0xFF0E1C78),
                Color(0xFF0A0E42),
                Color(0xFF1B0A33),
              ],
              stops: [0.0, 0.36, 0.56, 0.72, 1.0],
            ),
          ),
        ),
        // Sisi kiri tetap biru lebih lama, seperti pada desain.
        const _Glow(
          center: Alignment(-1.25, 0.05),
          radius: 1.05,
          color: Color(0xFF2149DD),
          opacity: 0.75,
        ),
        // Pantulan cahaya di kanan atas, di belakang maskot.
        const _Glow(
          center: Alignment(0.9, -0.75),
          radius: 0.8,
          color: Color(0xFF3B78F7),
          opacity: 0.55,
        ),
        // Bara merah di kiri bawah dan jingga di kanan bawah.
        const _Glow(
          center: Alignment(-0.95, 1.12),
          radius: 0.95,
          color: Color(0xFFEE1E2D),
          opacity: 1,
        ),
        const _Glow(
          center: Alignment(1.05, 1.08),
          radius: 0.72,
          color: Color(0xFFF2782A),
          opacity: 0.95,
        ),
        const RepaintBoundary(child: CustomPaint(painter: _KawungPainter())),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.center,
    required this.radius,
    required this.color,
    required this.opacity,
  });

  final Alignment center;
  final double radius;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Menggambar motif kawung: empat kelopak lonjong mengelilingi satu pusat,
/// berulang dalam kisi, dengan lingkaran kecil di antara motif.
class _KawungPainter extends CustomPainter {
  const _KawungPainter();

  static const _cell = 92.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = Colors.white.withValues(alpha: 0.085);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.06);

    final columns = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final center = Offset(column * _cell, row * _cell);
        _motif(canvas, center, stroke, inner);
        // Lingkaran kecil di titik antara empat motif.
        canvas.drawCircle(
          center + const Offset(_cell / 2, _cell / 2),
          _cell * 0.07,
          stroke,
        );
      }
    }
  }

  void _motif(Canvas canvas, Offset center, Paint stroke, Paint inner) {
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 + i * math.pi / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // Kelopak lonjong menjauh dari pusat, dengan garis dalam.
      final petal = Rect.fromCenter(
        center: const Offset(_cell * 0.24, 0),
        width: _cell * 0.4,
        height: _cell * 0.22,
      );
      canvas.drawOval(petal, stroke);
      canvas.drawOval(
        Rect.fromCenter(
          center: petal.center,
          width: petal.width * 0.55,
          height: petal.height * 0.5,
        ),
        inner,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_KawungPainter oldDelegate) => false;
}
