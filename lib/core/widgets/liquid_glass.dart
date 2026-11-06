import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Permukaan kaca bergaya "Liquid Glass" iOS: latar di belakangnya diburamkan
/// dan warnanya dihidupkan, dilapisi putih tipis, dengan kilau cahaya di tepi.
///
/// Dibangun dari BackdropFilter dan gradien biasa, bukan shader, supaya
/// tampil sama di semua ponsel Android, termasuk yang belum memakai Impeller.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 999,
    this.padding = EdgeInsets.zero,
    this.blur = 16,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  /// Kekuatan buram latar di belakang kaca.
  final double blur;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return DecoratedBox(
      // Bayangan lembut membuat kaca tampak melayang di atas latar.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            inner: _saturation(1.7),
          ),
          child: CustomPaint(
            painter: _GlassBodyPainter(borderRadius),
            foregroundPainter: _GlassRimPainter(borderRadius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }

  /// Menaikkan saturasi latar yang terlihat lewat kaca, seperti efek
  /// "vibrancy" pada iOS.
  static ColorFilter _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final inv = 1 - s;
    return ColorFilter.matrix(<double>[
      r * inv + s, g * inv, b * inv, 0, 0, //
      r * inv, g * inv + s, b * inv, 0, 0, //
      r * inv, g * inv, b * inv + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }
}

/// Isi kaca: putih tipis yang rata, dengan cahaya lembut yang menempel di
/// sudut kiri atas dan kanan bawah, seperti cahaya yang terbias di tepi kaca
/// tebal. Sengaja tanpa garis kilap di tengah: itu gaya tombol iOS lama.
class _GlassBodyPainter extends CustomPainter {
  const _GlassBodyPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2EFFFFFF), Color(0x14FFFFFF), Color(0x1AFFFFFF)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Cahaya terbias di sudut kiri atas (kuat) dan kanan bawah (samar).
    for (final (center, color) in const [
      (Alignment(-0.85, -1.0), Color(0x38FFFFFF)),
      (Alignment(0.85, 1.0), Color(0x1FFFFFFF)),
    ]) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = RadialGradient(
            center: center,
            radius: 1.1,
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_GlassBodyPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// Tepi kaca yang menangkap cahaya: terang di kiri atas dan kanan bawah,
/// samar di tengah, seperti lengkung kaca tebal.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final rim = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xF2FFFFFF),
            Color(0x26FFFFFF),
            Color(0x1AFFFFFF),
            Color(0x99FFFFFF),
          ],
          stops: [0.0, 0.38, 0.62, 1.0],
        ).createShader(rect),
    );

    // Garis cahaya kedua yang lebih tipis di dalam, memberi kesan tebal.
    final inner = RRect.fromRectAndRadius(
      rect.deflate(2.5),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59FFFFFF), Color(0x00FFFFFF), Color(0x26FFFFFF)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// Tombol kaca bundar. Sedikit membesar saat ditekan, seperti tombol
/// Liquid Glass di iPhone.
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.size = 48,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;
  final double size;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 1.12 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: LiquidGlass(
            borderRadius: widget.size / 2,
            child: SizedBox.square(
              dimension: widget.size,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
