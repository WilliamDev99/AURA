import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/geo_point.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/widgets/clay.dart';
import '../../core/widgets/location_map.dart';
import '../../domain/models/evidence_item.dart';
import '../../domain/models/threat_alert.dart';
import '../../state/app_state.dart';
import '../../core/widgets/heat_tier.dart';
import '../../core/l10n/l10n.dart';

const _poppins = 'Poppins';

/// Saringan di atas garis waktu, per level ancaman.
enum _Filter {
  all('Semua', null),
  low('Low', HeatTier.low),
  medium('Medium', HeatTier.medium),
  hard('Hard', HeatTier.hard);

  const _Filter(this._label, this.tier);
  final String _label;
  String get label => tr(_label);

  /// Null untuk "Semua".
  final HeatTier? tier;

  /// Bukti tanpa level (catatan sistem) hanya tampil di "Semua".
  bool accepts(HeatTier? level) => tier == null || level == tier;
}

/// Log bukti: kronologi semua yang terdeteksi, lengkap dengan levelnya.
/// Entri tidak bisa diubah; ketuk satu entri untuk melihat isi dan hash-nya.
class ForensicsTimelinePage extends StatefulWidget {
  const ForensicsTimelinePage({super.key});

  @override
  State<ForensicsTimelinePage> createState() => _ForensicsTimelinePageState();
}

class _ForensicsTimelinePageState extends State<ForensicsTimelinePage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final evidence = state.evidence;

    if (evidence.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: tr('Log masih kosong'),
        message: tr(
          'Setiap peringatan yang muncul akan otomatis menyimpan buktinya '
          'di sini, lengkap dengan stempel waktu dan sidik digital.',
        ),
      );
    }

    final radius = BorderRadius.circular(32);

    // Di Supabase, tautannya disimpan di peringatan (`evidence_ids`), bukan
    // di bukti. Keduanya dipakai supaya setiap bukti mendapat levelnya.
    final alertOf = <String, ThreatAlert>{
      for (final alert in state.alerts)
        for (final id in alert.evidenceIds) id: alert,
    };
    ThreatAlert? sourceOf(EvidenceItem item) =>
        alertOf[item.id] ??
        switch (item.alertId) {
          final id? => state.alertById(id),
          null => null,
        };

    final shown = evidence.where((item) {
      final alert = sourceOf(item);
      return _filter.accepts(
        alert == null ? null : HeatTier.of(alert.riskLevel),
      );
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          sliver: DecoratedSliver(
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      filter: _filter,
                      onFilter: (f) => setState(() => _filter = f),
                      total: evidence.length,
                      intact: state.chainStatus.isIntact,
                      reason: state.chainStatus.reason,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  DecoratedSliver(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    sliver: SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      sliver: shown.isEmpty
                          ? const SliverToBoxAdapter(child: _NothingHere())
                          : SliverList.builder(
                              itemCount: shown.length,
                              itemBuilder: (context, i) {
                                final item = shown[i];
                                return _LogEntry(
                                  item: item,
                                  alert: sourceOf(item),
                                  isFirst: i == 0,
                                  isLast: i == shown.length - 1,
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.onFilter,
    required this.total,
    required this.intact,
    required this.reason,
  });

  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final int total;
  final bool intact;
  final String reason;

  @override
  Widget build(BuildContext context) {
    const okColor = Color(0xFF1F9A40);
    const brokenColor = Color(0xFFB3122E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Forensik Timeline'),
          style: TextStyle(
            fontFamily: _poppins,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: ClayColors.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _Filter.values)
              _FilterChip(
                label: f.label,
                dot: f.tier?.color,
                selected: f == filter,
                onTap: () => onFilter(f),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Integritas rantai bukti tetap terlihat: itu yang membuat log ini
        // bisa dipakai di kepolisian.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              intact ? Icons.verified_rounded : Icons.gpp_bad_rounded,
              size: 17,
              color: intact ? okColor : brokenColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                intact
                    ? tr('Rantai bukti utuh - {total} bukti tersegel', {
                        'total': total,
                      })
                    : tr('Rantai bukti terputus. {reason}', {'reason': reason}),
                style: TextStyle(
                  fontFamily: _poppins,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: intact ? okColor : brokenColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Titik warna level di depan label (hijau, kuning, merah).
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? ClayColors.ink : const Color(0xFFD5D8DE),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot case final color?) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: _poppins,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : ClayColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NothingHere extends StatelessWidget {
  const _NothingHere();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        tr('Belum ada bukti dengan level ini.'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _poppins,
          fontSize: 13,
          color: ClayColors.inkMuted,
        ),
      ),
    );
  }
}

/// Satu baris di garis waktu: titik berwarna, level, judul, dan kutipan.
class _LogEntry extends StatelessWidget {
  const _LogEntry({
    required this.item,
    required this.alert,
    required this.isFirst,
    required this.isLast,
  });

  final EvidenceItem item;

  /// Peringatan asal bukti ini; menentukan level dan judulnya.
  final ThreatAlert? alert;
  final bool isFirst;
  final bool isLast;

  static const _line = Color(0xFFD9DCE3);

  HeatTier? get _tier => switch (alert) {
    final a? => HeatTier.of(a.riskLevel),
    null => null,
  };

  String get _title => alert?.headline ?? item.kind.label;

  /// Kutipan pesan bila ada; selain itu keterangan buktinya.
  String get _subtitle {
    final excerpt = alert?.excerpt?.trim();
    if (item.kind == EvidenceKind.messageTranscript &&
        excerpt != null &&
        excerpt.isNotEmpty) {
      return '"${excerpt.replaceAll('\n', ' ')}"';
    }
    return item.description;
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tier;
    final dot = tier?.color ?? ClayColors.inkMuted;

    return InkWell(
      onTap: () => _showEvidenceDetail(context, item, tier, alert?.badgeLabel),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Garis waktu dengan titik bercahaya.
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 14,
                    color: isFirst ? Colors.transparent : _line,
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: dot.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : _line,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(bottom: BorderSide(color: _line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HeatBadge(tier: tier, label: alert?.badgeLabel),
                        const Spacer(),
                        Text(
                          formatLocal(item.capturedAt, 'd MMM HH:mm'),
                          style: const TextStyle(
                            fontFamily: _poppins,
                            fontSize: 11,
                            color: ClayColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _title,
                      style: const TextStyle(
                        fontFamily: _poppins,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ClayColors.ink,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: _poppins,
                        fontSize: 13,
                        color: ClayColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rincian satu bukti dalam lembar clay: isi, peta lokasi, dan metadata
/// integritas.
void _showEvidenceDetail(
  BuildContext context,
  EvidenceItem item,
  HeatTier? tier,
  String? badgeLabel,
) {
  showClaySheet<void>(
    context: context,
    builder: (_) =>
        _EvidenceSheet(item: item, tier: tier, badgeLabel: badgeLabel),
  );
}

class _EvidenceSheet extends StatelessWidget {
  const _EvidenceSheet({
    required this.item,
    required this.tier,
    this.badgeLabel,
  });

  final EvidenceItem item;
  final HeatTier? tier;
  final String? badgeLabel;

  static const _label = TextStyle(
    fontFamily: _poppins,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: ClayColors.inkMuted,
  );

  IconData get _icon => switch (item.kind) {
    EvidenceKind.messageTranscript => Icons.chat_bubble_outline_rounded,
    EvidenceKind.screenshot => Icons.image_outlined,
    EvidenceKind.audioClip => Icons.mic_none_rounded,
    EvidenceKind.locationPing => Icons.location_on_outlined,
    EvidenceKind.systemEvent => Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final tier = this.tier;
    final payload = item.payload;
    final consentNote = item.consentNote;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: tier?.pill ?? const Color(0xFFE6E8EE),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: Icon(
                    _icon,
                    size: 26,
                    color: tier?.ink ?? ClayColors.inkSoft,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Bukti #{sequence}', {'sequence': item.sequence}),
                        style: const TextStyle(
                          fontFamily: _poppins,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: ClayColors.ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          HeatBadge(
                            tier: tier,
                            compact: true,
                            background: Colors.white,
                            label: badgeLabel,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.kind.label,
                              style: const TextStyle(
                                fontFamily: _poppins,
                                fontSize: 13,
                                color: ClayColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (payload != null) ...[
              Text(tr('Isi bukti'), style: _label),
              const SizedBox(height: 8),
              ClayCard(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  payload,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    fontFamily: 'monospace',
                    color: ClayColors.ink,
                  ),
                ),
              ),
              if (parseEvidenceLocation(payload) case final point?) ...[
                const SizedBox(height: 12),
                LocationMap(
                  latitude: point.latitude,
                  longitude: point.longitude,
                  accuracyMetres: point.accuracyMetres,
                  height: 220,
                ),
              ],
              const SizedBox(height: 18),
            ],
            Text(tr('Metadata integritas'), style: _label),
            const SizedBox(height: 8),
            ClayCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Column(
                children: [
                  InfoRow(label: tr('Nomor urut'), value: '#${item.sequence}'),
                  InfoRow(
                    label: tr('Waktu kejadian'),
                    value: formatWithZone(
                      item.capturedAt,
                      'd MMMM yyyy, HH:mm:ss',
                    ),
                  ),
                  InfoRow(
                    label: tr('Waktu tersimpan'),
                    value: formatWithZone(
                      item.recordedAt,
                      'd MMMM yyyy, HH:mm:ss',
                    ),
                  ),
                  InfoRow(label: tr('Diambil oleh'), value: item.capturedBy),
                  _CopyableRow(label: tr('Hash isi'), value: item.contentHash),
                  _CopyableRow(label: tr('Hash rantai'), value: item.chainHash),
                  if (item.previousHash case final previous?)
                    _CopyableRow(label: tr('Hash sebelumnya'), value: previous),
                ],
              ),
            ),
            if (consentNote != null) ...[
              const SizedBox(height: 18),
              Text(tr('Dasar perolehan'), style: _label),
              const SizedBox(height: 8),
              ClayCard(
                color: ClayColors.butter,
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Text(
                  consentNote,
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 12.5,
                    height: 1.5,
                    color: ClayColors.ink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu nilai hash yang bisa disalin dengan sekali ketuk.
class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('{label} disalin', {'label': label}))),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 116,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ClayColors.inkMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  fontFamily: 'monospace',
                  color: ClayColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.copy_rounded,
              size: 14,
              color: ClayColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
