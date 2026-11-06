import 'package:flutter/material.dart';
import '../../../core/l10n/l10n.dart';

/// Maskot AURA: robot putih bertanjak merah, melayang pelan.
///
/// Gambarnya dibuat oleh `tool/make_mascot_assets.py` dari
/// `design/aura_mascot_original.png`, dengan latar putih yang sudah dihapus.
class AuraRobot extends StatefulWidget {
  const AuraRobot({super.key, this.width = 120, this.floating = true});

  final double width;
  final bool floating;

  static const assetPath = 'assets/images/aura_mascot.png';

  /// Lebar : tinggi gambar maskot (608 × 1072).
  static const aspectRatio = 608 / 1072;

  @override
  State<AuraRobot> createState() => _AuraRobotState();
}

class _AuraRobotState extends State<AuraRobot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.floating) _float.repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width / AuraRobot.aspectRatio;

    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_float.value);
        return Transform.translate(offset: Offset(0, -7 * t), child: child);
      },
      child: Semantics(
        label: tr('Aura, robot penjaga'),
        image: true,
        child: Image.asset(
          AuraRobot.assetPath,
          width: widget.width,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
