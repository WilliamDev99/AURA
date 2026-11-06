import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/l10n/l10n.dart';

/// Tombol darurat berbentuk bola merah mengilap dengan halo titik-titik.
///
/// Widget ini murni tampilan. Logika kapan SOS terkirim — termasuk hitung
/// mundur yang bisa dibatalkan — diatur oleh halaman yang memakainya.
class PanicOrb extends StatefulWidget {
  const PanicOrb({
    super.key,
    required this.onTap,
    this.size = 220,
    this.countdown,
    this.progress = 0,
    this.sending = false,
  });

  final VoidCallback onTap;

  /// Diameter cincin luar. Halo titik-titik meluas sekitar 1,6 kali ukuran ini.
  final double size;

  /// Bila diisi, angka hitung mundur menggantikan ikon peringatan.
  final int? countdown;

  /// Kemajuan hitung mundur 0..1, digambar sebagai busur di cincin.
  final double progress;
  final bool sending;

  /// Perbandingan kotak widget terhadap [size], memberi ruang bagi halo.
  static const extent = 1.66;

  @override
  State<PanicOrb> createState() => _PanicOrbState();
}

class _PanicOrbState extends State<PanicOrb>
    with SingleTickerProviderStateMixin {
  /// Gelombang per detik: tenang saat siaga, mendesak saat SOS akan terkirim.
  static const _calmSpeed = 0.42;
  static const _urgentSpeed = 1.15;

  late final Ticker _ticker = createTicker(_advance);

  /// Fase gelombang 0..1. Dipakai langsung oleh pelukis halo, jadi hanya
  /// halo yang digambar ulang tiap frame, tanpa membangun ulang widget.
  final _phase = ValueNotifier<double>(0);
  Duration _lastTick = Duration.zero;

  bool _pressed = false;

  bool get _urgent => widget.countdown != null || widget.sending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hormati pengaturan "kurangi animasi": sebagian anak, misalnya dengan
    // sensitivitas sensorik, terganggu oleh gerakan yang terus-menerus.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _ticker.isActive) {
      _ticker.stop();
    } else if (!reduceMotion && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  /// Fase diakumulasi, bukan dihitung dari waktu, supaya kecepatan bisa
  /// berubah di tengah jalan tanpa gelombang melompat.
  void _advance(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final speed = _urgent ? _urgentSpeed : _calmSpeed;
    _phase.value = (_phase.value + seconds * speed) % 1.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * PanicOrb.extent;
    final counting = widget.countdown != null;

    return SizedBox.square(
      dimension: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lapisan sendiri: halo bergerak tiap frame, orb di atasnya tidak.
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(box),
              painter: _HalftonePainter(
                orbRadius: widget.size / 2,
                phase: _phase,
                intensity: _urgent ? 1.25 : 1,
              ),
            ),
          ),
          // Label mengikuti keadaan, dan isi visual (angka hitung mundur)
          // dikecualikan supaya tidak tercampur ke dalam label.
          Semantics(
            button: true,
            label: widget.sending
                ? tr('Mengirim SOS ke orang tua')
                : counting
                ? tr(
                    'Kirim SOS sekarang. Terkirim otomatis dalam {countdown} detik.',
                    {'countdown': widget.countdown},
                  )
                : tr('Tombol darurat. Ketuk untuk mengirim SOS ke orang tua.'),
            onTap: widget.onTap,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: AnimatedScale(
                scale: _pressed ? 0.95 : 1,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(widget.size),
                        painter: _OrbPainter(
                          showIcon: !counting && !widget.sending,
                          progress: counting ? widget.progress : 0,
                        ),
                      ),
                      if (counting)
                        Text(
                          '${widget.countdown}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: widget.size * 0.34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      if (widget.sending)
                        SizedBox.square(
                          dimension: widget.size * 0.24,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 4,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik-titik halftone merah di sekeliling orb, bergerak seperti suar SOS:
/// gelombang memancar dari orb ke tepi, sementara polanya berputar pelan.
class _HalftonePainter extends CustomPainter {
  _HalftonePainter({
    required this.orbRadius,
    required this.phase,
    required this.intensity,
  }) : super(repaint: phase);

  final double orbRadius;
  final ValueListenable<double> phase;
  final double intensity;

  /// Banyaknya puncak gelombang yang tampak sekaligus di sepanjang halo.
  static const _crests = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final p = phase.value;
    final center = size.center(Offset.zero);
    final breathe = 0.5 + 0.5 * math.sin(2 * math.pi * p);
    final start = orbRadius * 1.07;
    final end = orbRadius * (1.62 + 0.04 * breathe);
    final step = orbRadius * 0.085;

    // Cahaya merah-ungu lembut di belakang titik-titik.
    final glow = 0.85 + 0.15 * breathe;
    canvas.drawCircle(
      center,
      end,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF2E63).withValues(alpha: 0.30 * intensity * glow),
            const Color(0xFFB0207A).withValues(alpha: 0.10 * intensity * glow),
            Colors.transparent,
          ],
          stops: [orbRadius / end, (orbRadius / end + 1) / 2, 1],
        ).createShader(Rect.fromCircle(center: center, radius: end)),
    );

    // Satu cincin digambar sekali jalan dengan drawRawPoints, bukan ratusan
    // drawCircle. Semua titik dalam satu cincin memang seukuran dan sewarna,
    // dan menggambarnya satu per satu membuat frame tersendat di ponsel kelas
    // bawah — hitung mundurnya sampai tersendat.
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    var ring = 0;
    for (var r = start; r <= end; r += step, ring++) {
      final t = ((r - start) / (end - start)).clamp(0.0, 1.0);

      // Puncak gelombang berada di t = (n + p) / _crests, jadi saat fase
      // bertambah puncaknya bergeser menjauhi orb.
      final wave = 0.5 + 0.5 * math.cos(2 * math.pi * (t * _crests - p));

      final dotRadius = orbRadius * (0.036 - 0.03 * t) * (0.6 + 0.6 * wave);
      final alpha = ((1 - math.pow(t, 0.85)) * (0.5 + 0.5 * wave) * intensity)
          .clamp(0.0, 1.0)
          .toDouble();
      if (alpha <= 0.01 || dotRadius <= 0.2) continue;

      paint
        ..color = Color.lerp(
          const Color(0xFFFF4A6B),
          const Color(0xFFFF2040),
          t,
        )!.withValues(alpha: alpha)
        // Titik bundar digambar sebagai garis sepanjang nol dengan ujung
        // membulat; tebal garis menjadi diameternya.
        ..strokeWidth = dotRadius * 2;

      final count = (2 * math.pi * r / step).floor();
      final spacing = 2 * math.pi / count;
      // Berputar satu jarak titik per siklus: saat fase kembali ke nol, pola
      // tampak sama persis, sehingga putarannya mulus tanpa lompatan.
      final offset = (ring.isOdd ? spacing / 2 : 0.0) + p * spacing;

      final points = Float32List(count * 2);
      for (var i = 0; i < count; i++) {
        final angle = offset + i * spacing;
        points[i * 2] = center.dx + math.cos(angle) * r;
        points[i * 2 + 1] = center.dy + math.sin(angle) * r;
      }
      canvas.drawRawPoints(ui.PointMode.points, points, paint);
    }
  }

  @override
  bool shouldRepaint(_HalftonePainter old) =>
      old.intensity != intensity ||
      old.orbRadius != orbRadius ||
      old.phase != phase;
}

/// Bola darurat: cincin biru-ungu, celah gelap, kubah merah mengilap.
class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.showIcon, required this.progress});

  final bool showIcon;
  final double progress;

  static const _red = Color(0xFFE3212D);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final gapRadius = r * 0.835;
    final dome = r * 0.79;

    // Bayangan jatuh.
    canvas.drawCircle(
      c + Offset(0, r * 0.07),
      r * 0.98,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );

    // Cincin luar biru ke ungu.
    final ringBounds = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6E8DFF), Color(0xFF5662F2), Color(0xFF9038D6)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(ringBounds),
    );
    // Kilau tepi atas cincin.
    canvas.drawCircle(
      c,
      r - r * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(ringBounds),
    );

    // Busur hitung mundur di tengah cincin.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: (r + gapRadius) / 2),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (r - gapRadius) * 0.55
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
    }

    // Celah gelap antara cincin dan kubah.
    canvas.drawCircle(c, gapRadius, Paint()..color = const Color(0xFF2B0716));

    // Kubah merah.
    final domeBounds = Rect.fromCircle(center: c, radius: dome);
    canvas.drawCircle(
      c,
      dome,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.32),
          radius: 1.0,
          colors: [
            Color(0xFFFF6B72),
            Color(0xFFEE2935),
            Color(0xFFC8131F),
            Color(0xFF970B15),
          ],
          stops: [0.0, 0.45, 0.85, 1.0],
        ).createShader(domeBounds),
    );

    // Pantulan kaca di bagian atas kubah.
    final gloss = Rect.fromCenter(
      center: c + Offset(0, -dome * 0.5),
      width: dome * 1.32,
      height: dome * 0.72,
    );
    canvas.drawOval(
      gloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(gloss),
    );

    if (showIcon) _warning(canvas, c, dome);
  }

  /// Segitiga putih bersudut bulat dengan tanda seru merah.
  void _warning(Canvas canvas, Offset c, double dome) {
    final width = dome * 0.86;
    final height = width * 0.86;
    final top = c.dy - height * 0.5;
    final bottom = c.dy + height * 0.5;

    final triangle = Path()
      ..moveTo(c.dx, top)
      ..lineTo(c.dx + width / 2, bottom)
      ..lineTo(c.dx - width / 2, bottom)
      ..close();

    // Garis tebal bersambungan bulat membuat sudutnya membulat.
    final white = Paint()..color = Colors.white;
    canvas.drawPath(triangle, white);
    canvas.drawPath(
      triangle,
      white
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.13
        ..strokeJoin = StrokeJoin.round,
    );

    final red = Paint()..color = _red;
    final barWidth = width * 0.13;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          c.dx - barWidth / 2,
          top + height * 0.30,
          c.dx + barWidth / 2,
          top + height * 0.68,
        ),
        Radius.circular(barWidth / 2),
      ),
      red,
    );
    canvas.drawCircle(Offset(c.dx, top + height * 0.84), barWidth * 0.62, red);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.showIcon != showIcon || old.progress != progress;
}
