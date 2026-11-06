import 'package:flutter/material.dart';
import '../../core/l10n/l10n.dart';

/// Warna untuk kartu clay: permukaan terang dengan tulisan biru tua.
abstract final class ClayColors {
  static const ink = Color(0xFF14215A);
  static const inkSoft = Color(0xFF45507A);
  static const inkMuted = Color(0xFF7A85A3);

  static const lavender = Color(0xFFE7E4FC);
  static const sky = Color(0xFFE3EAFF);
  static const peach = Color(0xFFFFE9DC);
  static const butter = Color(0xFFFFF4D6);

  /// Versi gelap sebuah warna aksen supaya terbaca di atas permukaan clay.
  static Color deep(Color accent) => Color.lerp(accent, Colors.black, 0.35)!;

  /// Versi pastel sebuah warna aksen untuk permukaan kartu.
  static Color pastel(Color accent) => Color.lerp(accent, Colors.white, 0.82)!;
}

/// Menandai bahwa sebuah widget berada di atas kartu clay yang terang, supaya
/// widget bersama (InfoRow, RiskBadge) memilih warna tulisan yang gelap.
class OnClay extends InheritedWidget {
  const OnClay({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnClay>() != null;

  @override
  bool updateShouldNotify(OnClay oldWidget) => false;
}

/// Gaya tulisan untuk permukaan clay yang terang: tulisan dan ikon biru tua.
class ClayTheme extends StatelessWidget {
  const ClayTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final text = base.textTheme.apply(
      bodyColor: ClayColors.ink,
      displayColor: ClayColors.ink,
    );
    return OnClay(
      child: Theme(
        data: base.copyWith(
          textTheme: text.copyWith(
            bodySmall: text.bodySmall?.copyWith(color: ClayColors.inkSoft),
          ),
          iconTheme: base.iconTheme.copyWith(color: ClayColors.ink),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: ClayColors.ink),
          child: IconTheme.merge(
            data: const IconThemeData(color: ClayColors.ink),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Latar lembar bawah bergaya clay.
const _sheetColor = Color(0xFFF2F0FB);

/// Lembar bawah bergaya clay: latar terang, sudut atas bulat, tulisan gelap.
///
/// Lembar bawah Flutter mewarisi tema dari tempat ia dibuka. Bila dibuka dari
/// dalam kartu clay, lembar biasa yang gelap akan berisi tulisan gelap juga.
/// Lembar ini selalu memakai temanya sendiri.
Future<T?> showClaySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Lembar yang tinggi berhenti di bawah bilah status.
    useSafeArea: true,
    backgroundColor: _sheetColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => ClayTheme(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pegangan kecil di atas lembar.
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: ClayColors.inkMuted.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(child: Builder(builder: builder)),
        ],
      ),
    ),
  );
}

/// Tombol bergaya clay: tebal dan empuk seperti kartunya.
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Colors.white,
    this.foreground = ClayColors.ink,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: ClayCard(
        color: color,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog konfirmasi bergaya clay: ikon dalam lingkaran pastel, pertanyaan,
/// penjelasan, lalu dua tombol berdampingan. Mengembalikan true bila
/// [confirmLabel] dipilih.
Future<bool> showClayConfirm({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  Color accent = const Color(0xFF1E8E3E),
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ClayTheme(
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: ClayCard(
          color: _sheetColor,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: ClayColors.pastel(accent),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(icon, size: 34, color: accent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: ClayColors.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  color: ClayColors.inkSoft,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ClayButton(
                      label: cancelLabel ?? tr('Batal'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClayButton(
                      label: confirmLabel,
                      color: accent,
                      foreground: Colors.white,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return answer ?? false;
}

/// Kartu bergaya claymorphism: tebal, empuk, sudut sangat bulat, dengan
/// bayangan jatuh yang lembut dan bayangan dalam di tepi bawah-kanan.
///
/// Tulisan di dalamnya otomatis berwarna gelap. Warna yang ditulis langsung
/// (mis. `Colors.white`) tetap dipakai apa adanya.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.gradient,
    this.radius = 28,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Gradient? gradient;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content = ClayTheme(
      child: Padding(padding: padding, child: child),
    );

    // Bayangan tebal untuk latar gelap. Di atas permukaan clay yang terang
    // (lembar, dialog, panel), bayangan setebal itu tampak seperti lempengan
    // abu-abu, jadi dibuat lebih lembut dan bernada biru tua.
    final onLight = OnClay.of(context);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: onLight
            ? const [
                BoxShadow(
                  color: Color(0x2914215A),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
                BoxShadow(
                  color: Color(0x1414215A),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
          ),
          child: InkWell(
            onTap: onTap,
            child: CustomPaint(
              foregroundPainter: _ClayInnerPainter(
                radius: radius,
                shade: ClayColors.deep(color),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );

    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// Bayangan di dalam kartu: kilau di tepi kiri-atas dan bayangan di tepi
/// kanan-bawah, yang membuat kartu tampak menggembung seperti tanah liat.
class _ClayInnerPainter extends CustomPainter {
  const _ClayInnerPainter({required this.radius, required this.shade});

  final double radius;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);

    void inner(Color color, Offset shift, double blur) {
      // Semua area di luar kartu yang digeser: setelah dipotong ke bentuk
      // kartu, yang tersisa hanya pita di satu sisi tepinya.
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(blur * 4))
        ..addRRect(rrect.shift(shift));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    inner(Colors.white.withValues(alpha: 0.85), const Offset(5, 6), 7);
    inner(shade.withValues(alpha: 0.22), const Offset(-7, -9), 11);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClayInnerPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.shade != shade;
}
