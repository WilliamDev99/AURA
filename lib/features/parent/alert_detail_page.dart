import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/utils/geo_point.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/widgets/clay.dart';
import '../../core/widgets/heat_tier.dart';
import '../../core/widgets/location_map.dart';
import '../../domain/models/evidence_item.dart';
import '../../domain/models/threat_alert.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// Rincian satu peringatan beserta bukti yang menyertainya.
class AlertDetailPage extends StatelessWidget {
  const AlertDetailPage({super.key, required this.alertId});

  final String alertId;

  /// Ditanyakan dulu: sekali ditandai, ancaman hilang dari daftar "menunggu
  /// tindakan", dan ketukan tak sengaja bisa membuat ancaman nyata terlewat.
  Future<void> _confirmHandled(BuildContext context, String alertId) async {
    final handled = await showClayConfirm(
      context: context,
      icon: Icons.task_alt_rounded,
      title: tr('Apakah Anda sudah benar menangani ancaman ini?'),
      message: tr(
        'Kalau sudah, peringatan ini ditandai selesai dan tidak lagi '
        'muncul sebagai ancaman yang menunggu tindakan. Bukti tetap '
        'tersimpan utuh.',
      ),
      cancelLabel: tr('Belum'),
      confirmLabel: tr('Sudah'),
    );
    if (!handled || !context.mounted) return;

    final state = context.read<AppState>();
    await state.markAlert(alertId, AlertStatus.reviewed);
    if (!context.mounted) return;

    final failed = state.lastError != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.lastError ?? tr('Ancaman ini ditandai sudah ditangani.'),
        ),
      ),
    );
    // Kembali ke dashboard, tempat peringatan ini kini sudah hilang.
    if (!failed) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alert = state.alertById(alertId);

    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Peringatan'))),
        body: AuraBackdrop(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: tr('Peringatan tidak ditemukan'),
            message: tr('Peringatan ini mungkin sudah dihapus.'),
          ),
        ),
      );
    }

    final evidence = state.evidence
        .where((e) => alert.evidenceIds.contains(e.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Rincian Peringatan')),
        actions: [
          // Menu terang bergaya clay, seperti kartu-kartunya.
          PopupMenuButton<AlertStatus>(
            tooltip: tr('Tandai peringatan'),
            color: const Color(0xFFF2F0FB),
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            shadowColor: const Color(0x66000000),
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            onSelected: (status) => state.markAlert(alert.id, status),
            itemBuilder: (context) => [
              for (final (status, icon, label) in [
                (
                  AlertStatus.reviewed,
                  Icons.visibility_rounded,
                  tr('Tandai sudah dilihat'),
                ),
                (
                  AlertStatus.dismissed,
                  Icons.verified_user_rounded,
                  tr('Tandai aman'),
                ),
                (
                  AlertStatus.escalated,
                  Icons.priority_high_rounded,
                  tr('Tandai dieskalasi'),
                ),
              ])
                PopupMenuItem(
                  value: status,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: ClayColors.inkSoft),
                      const SizedBox(width: 12),
                      // Menyusut di huruf besar, tidak meluber.
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ClayColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        accent: HeatTier.of(alert.riskLevel).color,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
            children: [
              _Header(alert: alert),
              const SizedBox(height: 18),
              if (alert.excerpt != null) ...[
                SectionHeader(
                  title: tr('Kutipan pemicu'),
                  subtitle: tr(
                    'Hanya bagian yang memicu deteksi yang disimpan.',
                  ),
                ),
                ClayCard(
                  child: Builder(
                    builder: (context) => Text(
                      '"${alert.excerpt}"',
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              SectionHeader(title: tr('Rincian deteksi')),
              ClayCard(
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      InfoRow(
                        label: tr('Waktu'),
                        value: formatWithZone(
                          alert.detectedAt,
                          'EEEE, d MMMM yyyy, HH:mm',
                        ),
                      ),
                      InfoRow(label: tr('Anak'), value: alert.childName),
                      InfoRow(label: tr('Aplikasi'), value: alert.platform),
                      if (alert.counterpartName != null)
                        InfoRow(
                          label: tr('Lawan bicara'),
                          value: alert.counterpartName!,
                        ),
                      InfoRow(label: tr('Sumber'), value: alert.source.label),
                      InfoRow(
                        label: tr('Skor risiko'),
                        value: tr('{toStringAsFixed} dari 100', {
                          'toStringAsFixed': (alert.score * 100)
                              .toStringAsFixed(0),
                        }),
                        valueColor: HeatTier.of(alert.riskLevel).color,
                      ),
                      InfoRow(
                        label: tr('Kategori'),
                        value: alert.categories.map((c) => c.label).join(', '),
                      ),
                      if (alert.matchedSignals.isNotEmpty)
                        InfoRow(
                          label: tr('Pola terdeteksi'),
                          value: alert.matchedSignals
                              .map((s) => '"$s"')
                              .join(', '),
                        ),
                      if (alert.hasLocation)
                        InfoRow(
                          label: tr('Lokasi'),
                          value:
                              '${alert.latitude}, ${alert.longitude}'
                              '${alert.locationLabel == null ? "" : " (${alert.locationLabel})"}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: tr('Bukti tersegel'),
                subtitle: tr('{count} entri terkait peringatan ini.', {
                  'count': evidence.length,
                }),
              ),
              if (evidence.isEmpty)
                ClayCard(
                  child: Text(
                    tr('Tidak ada bukti yang tertaut ke peringatan ini.'),
                    style: TextStyle(fontSize: 13.5),
                  ),
                )
              else
                ...evidence.map((item) => _EvidenceSummary(item: item)),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () =>
                    context.push('${Routes.legal}?peringatan=${alert.id}'),
                icon: const Icon(Icons.gavel_rounded),
                label: Text(tr('Buka langkah hukum')),
                style: FilledButton.styleFrom(
                  backgroundColor: AuraColors.ember,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: alert.status == AlertStatus.reviewed
                    ? null
                    : () => _confirmHandled(context, alert.id),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  alert.status == AlertStatus.reviewed
                      ? tr('Sudah ditangani')
                      : tr('Saya sudah menangani ini'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.alert});

  final ThreatAlert alert;

  @override
  Widget build(BuildContext context) {
    final tier = HeatTier.of(alert.riskLevel);
    return ClayCard(
      color: tier.pill,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tier.color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(alert.headlineIcon, color: tier.ink, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.headline,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      // Kartunya sudah sewarna level; labelnya dibuat putih.
                      HeatBadge(
                        tier: tier,
                        compact: true,
                        background: Colors.white,
                        label: alert.badgeLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              alert.summary,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceSummary extends StatelessWidget {
  const _EvidenceSummary({required this.item});

  final EvidenceItem item;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 15,
                  color: ClayColors.deep(AuraColors.safe),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '#${item.sequence} - ${item.kind.label}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
            if (item.payload != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.payload!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: ClayColors.inkSoft,
                  ),
                ),
              ),
              if (parseEvidenceLocation(item.payload) case final point?) ...[
                const SizedBox(height: 10),
                LocationMap(
                  latitude: point.latitude,
                  longitude: point.longitude,
                  accuracyMetres: point.accuracyMetres,
                ),
              ],
            ],
            const SizedBox(height: 8),
            InfoRow(
              label: tr('SHA-256'),
              value: item.shortHash,
              monospace: true,
            ),
          ],
        ),
      ),
    );
  }
}
