import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/clay.dart';
import '../../core/widgets/heat_tier.dart';
import '../../domain/models/threat_alert.dart';
import '../../core/l10n/l10n.dart';

/// Ringkasan satu peringatan dalam daftar.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, this.onTap});

  final ThreatAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = alert.status == AlertStatus.dismissed;
    // Sama dengan heatmap dan Log: LOW hijau, MEDIUM kuning, HARD merah.
    final tier = HeatTier.of(alert.riskLevel);
    final color = dimmed ? ClayColors.inkMuted : tier.ink;

    return ClayCard(
      onTap: onTap,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(alert.headlineIcon, size: 19, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.headline,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${alert.childName} - ${alert.platform}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                HeatBadge(tier: tier, compact: true, label: alert.badgeLabel),
              ],
            ),
            const SizedBox(height: 12),
            if (alert.excerpt != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3FA),
                  borderRadius: BorderRadius.circular(11),
                  border: Border(
                    left: BorderSide(
                      color: dimmed ? color : tier.color,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  '"${alert.excerpt}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: ClayColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: ClayColors.inkMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  formatLocal(alert.detectedAt, 'd MMM, HH:mm'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (alert.status != AlertStatus.unread)
                  Text(
                    alert.status.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: alert.status == AlertStatus.escalated
                          ? ClayColors.deep(AuraColors.ember)
                          : ClayColors.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    tr('Belum ditinjau'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF0277BD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
