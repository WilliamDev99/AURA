import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/models/risk.dart';
import '../theme/aura_colors.dart';
import 'clay.dart';
import '../../core/l10n/l10n.dart';

/// Latar gradien standar seluruh aplikasi, lengkap dengan cahaya lembut.
class AuraBackdrop extends StatelessWidget {
  const AuraBackdrop({super.key, required this.child, this.accent});

  final Widget child;

  /// Warna cahaya tambahan, mis. merah saat status kritis.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AuraColors.backdrop),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _Glow(color: accent ?? AuraColors.electric, size: 320),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _Glow(
              color: accent == null
                  ? AuraColors.ember.withValues(alpha: 0.7)
                  : accent!,
              size: 300,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.38), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// Kartu kaca (glassmorphism) yang dipakai di seluruh layar.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
    this.gradient,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Gradient? gradient;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: gradient,
                  color: gradient == null
                      ? Colors.white.withValues(alpha: 0.07)
                      : null,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: borderColor ?? AuraColors.glassStroke,
                    width: 1,
                  ),
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lencana tingkat risiko.
class RiskBadge extends StatelessWidget {
  const RiskBadge({
    super.key,
    required this.level,
    this.compact = false,
    this.label,
  });

  final RiskLevel level;
  final bool compact;
  final String? label;

  @override
  Widget build(BuildContext context) {
    // Di atas kartu clay yang terang, warna aksen digelapkan supaya terbaca.
    final ink = OnClay.of(context) ? ClayColors.deep(level.color) : level.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 7),
          Text(
            label ?? level.label.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul bagian dengan aksi opsional di kanan.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Keadaan kosong yang ramah, bukan layar putih.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(color: AuraColors.glassStroke),
              ),
              child: Icon(icon, size: 34, color: AuraColors.cyan),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Baris informasi berlabel, dipakai di detail bukti dan peringatan.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool monospace;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final onClay = OnClay.of(context);
    final custom = valueColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: onClay ? ClayColors.inkMuted : AuraColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: switch ((custom, onClay)) {
                  (final c?, true) => ClayColors.deep(c),
                  (final c?, false) => c,
                  (null, true) => ClayColors.ink,
                  (null, false) => AuraColors.textPrimary,
                },
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: monospace ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar Aura: kepala maskot dalam lingkaran biru bercahaya, seperti ikon
/// aplikasinya. Untuk seluruh badan maskot, pakai `AuraRobot`.
class AuraMascot extends StatefulWidget {
  const AuraMascot({super.key, this.size = 96, this.mood = MascotMood.calm});

  final double size;
  final MascotMood mood;

  @override
  State<AuraMascot> createState() => _AuraMascotState();
}

enum MascotMood { calm, alert, happy }

class _AuraMascotState extends State<AuraMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = switch (widget.mood) {
      MascotMood.calm => AuraColors.cyan,
      MascotMood.alert => AuraColors.critical,
      MascotMood.happy => AuraColors.safe,
    };

    // Lingkaran dan gambar tidak berubah tiap frame; hanya posisi dan
    // cahayanya yang beranimasi.
    final avatar = Container(
      width: widget.size,
      height: widget.size,
      padding: EdgeInsets.fromLTRB(
        widget.size * 0.1,
        widget.size * 0.08,
        widget.size * 0.1,
        widget.size * 0.12,
      ),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A5CEB), Color(0xFF0B125C)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: widget.size > 60 ? 1.5 : 1,
        ),
      ),
      child: Image.asset(
        'assets/images/aura_mascot_head.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );

    return Semantics(
      label: tr('Aura'),
      image: true,
      child: AnimatedBuilder(
        animation: _controller,
        child: avatar,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, -4 * t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35 + 0.2 * t),
                    blurRadius: 28 + 10 * t,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
