import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/widgets/clay.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/threat_alert.dart';
import '../../state/app_state.dart';
import 'alert_card.dart';
import 'lock_schedule_sheet.dart';
import '../../core/widgets/heat_tier.dart';
import 'threat_radar.dart';
import '../../core/l10n/l10n.dart';

const _poppins = 'Poppins';

/// Data keluarga belum termuat, biasanya karena tanpa internet. Sengaja
/// tidak menampilkan "aman" atau "belum ada anak": daftar kosong di sini
/// berarti belum tahu, bukan tidak ada apa-apa.
class _WaitingForDataCard extends StatelessWidget {
  const _WaitingForDataCard();

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: AuraColors.medium),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('Menunggu internet'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Peringatan dan status anak belum bisa dimuat. Begitu '
                'internet tersambung, semuanya muncul di sini, termasuk alarm '
                'SOS yang tertunda.',
              ),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beranda orang tua.
class ParentDashboardPage extends StatelessWidget {
  const ParentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Yang sudah ditangani tidak ditampilkan lagi di sini: beranda hanya
    // berisi hal yang masih menunggu tindakan. Peringatannya tidak dihapus;
    // buktinya tetap utuh di Log dan tetap bisa dilaporkan.
    final alerts = state.unreadAlerts;

    if (!state.familyDataLoaded) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: const [_WaitingForDataCard()],
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          Future<void>.delayed(const Duration(milliseconds: 400)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _Greeting(
            name: state.user?.name ?? tr('Bunda'),
            waiting: alerts.length,
          ),
          const SizedBox(height: 18),
          _HeatmapCard(alerts: alerts),
          const SizedBox(height: 14),
          _ProtectionStatusCard(children: state.children),
          const SizedBox(height: 14),
          _ChildrenCard(children: state.children),
          const SizedBox(height: 26),
          SectionHeader(
            title: tr('Peringatan terbaru'),
            subtitle: alerts.isEmpty
                ? tr('Tidak ada yang menunggu tindakan')
                : tr('{count} menunggu tindakan', {'count': alerts.length}),
          ),
          if (alerts.isEmpty)
            ClayCard(
              child: Builder(
                builder: (context) => Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AuraColors.safe,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        state.alerts.isEmpty
                            ? tr(
                                'Tidak ada yang mencurigakan sejauh ini. Kami tetap berjaga.',
                              )
                            : tr(
                                'Semua peringatan sudah Anda tangani. Kami tetap berjaga.',
                              ),
                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...alerts
                .take(6)
                .map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AlertCard(
                      alert: alert,
                      onTap: () => context.push(Routes.alertDetail(alert.id)),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.waiting});

  final String name;
  final int waiting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Halo {name},', {'name': name}),
            style: const TextStyle(
              fontFamily: _poppins,
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            // Kalimat menenangkan hanya bila memang tidak ada yang menunggu.
            waiting == 0
                ? tr('Anakmu aman, kita pantau bersama!')
                : tr('Ada {waiting} hal yang perlu Anda lihat.', {
                    'waiting': waiting,
                  }),
            style: const TextStyle(
              fontFamily: _poppins,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu radar ancaman dengan jumlah per tingkat.
class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.alerts});

  final List<ThreatAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final counts = <HeatTier, int>{};
    for (final alert in alerts) {
      counts.update(
        HeatTier.of(alert.riskLevel),
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8C1430), Color(0xFF5A1B6E), Color(0xFF1C2C96)],
          stops: [0, 0.5, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            tr('AICyber Threat Heatmap'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _poppins,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final radar = math.min(160.0, constraints.maxWidth * 0.5);
              return Row(
                children: [
                  ThreatRadar(
                    alerts: alerts,
                    size: radar,
                    dotColor: (alert) => HeatTier.of(alert.riskLevel).color,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tier in HeatTier.values)
                          _LevelCount(tier: tier, count: counts[tier] ?? 0),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LevelCount extends StatelessWidget {
  const _LevelCount({required this.tier, required this.count});

  final HeatTier tier;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('heat-${tier.name}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lingkaran bertepi warna dengan titik di tengah.
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: tier.color, width: 3.5),
            ),
            child: Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: tier.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tier.pill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tier.label,
                    style: TextStyle(
                      fontFamily: _poppins,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: tier.ink,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan apakah perlindungan semua anak benar-benar berjalan.
class _ProtectionStatusCard extends StatelessWidget {
  const _ProtectionStatusCard({required this.children});

  final List<AppUser> children;

  @override
  Widget build(BuildContext context) {
    final status = _ProtectionStatus.of(children);
    final ink = ClayColors.deep(status.color);

    // Clay pastel sewarna status: hijau saat aman, oranye saat bermasalah.
    return ClayCard(
      color: ClayColors.pastel(status.color),
      onTap: children.isEmpty ? () => context.push(Routes.pairing) : null,
      padding: EdgeInsets.zero,
      child: Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Status Proteksi'),
                style: TextStyle(
                  fontFamily: _poppins,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: ink.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      status.badge,
                      style: TextStyle(
                        fontFamily: _poppins,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  if (status.headline case final headline?) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        headline,
                        style: const TextStyle(
                          fontFamily: _poppins,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ClayColors.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (status.detail case final detail?) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 12.5,
                    height: 1.5,
                    color: ClayColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Keadaan perlindungan keluarga, dari yang paling perlu ditindaklanjuti.
class _ProtectionStatus {
  const _ProtectionStatus(this.color, this.badge, {this.headline, this.detail});

  final Color color;
  final String badge;
  final String? headline;
  final String? detail;

  static _ProtectionStatus of(List<AppUser> children) {
    if (children.isEmpty) {
      return _ProtectionStatus(
        AuraColors.electric,
        tr('BELUM ADA ANAK'),
        detail: tr(
          'Ketuk di sini untuk menautkan HP anak dan mulai melindungi.',
        ),
      );
    }

    // Orang tua harus tahu bila chat anak sedang tidak dipindai, bukan
    // mengira semuanya terpantau.
    final scanOff = children
        .where((c) => c.hasConsented && c.chatScanEnabled == false)
        .toList();
    if (scanOff.isNotEmpty) {
      return _ProtectionStatus(
        AuraColors.high,
        tr('PEMINDAIAN CHAT MATI'),
        detail: [
          for (final c in scanOff)
            tr(
              'Akses notifikasi di HP {cName} dimatikan, jadi chat-nya tidak '
              'dipindai. Minta {cName} menyalakannya lagi di AURA, menu '
              'Pengaturan.',
              {'cName': c.name},
            ),
        ].join('\n'),
      );
    }

    final paused = children.where((c) => !c.protectionActive).toList();
    if (paused.isNotEmpty) {
      return _ProtectionStatus(
        AuraColors.medium,
        'DIJEDA',
        headline: tr('Perlindungan dijeda'),
        detail: tr(
          'Anda sedang menjeda perlindungan untuk {paused}. Ketuk namanya '
          'di bawah untuk menyalakannya lagi.',
          {'paused': _names(paused)},
        ),
      );
    }

    final waiting = children.where((c) => !c.hasConsented).toList();
    if (waiting.isNotEmpty) {
      return _ProtectionStatus(
        AuraColors.medium,
        'MENUNGGU',
        headline: tr('Persetujuan anak'),
        detail: tr(
          '{waiting} belum menyetujui perlindungan di HP-nya. Pemindaian '
          'dimulai setelah anak setuju.',
          {'waiting': _names(waiting)},
        ),
      );
    }

    final unknown = children.where((c) => c.chatScanEnabled == null).toList();
    return _ProtectionStatus(
      AuraColors.safe,
      'AKTIF',
      headline: tr('Virtual AI Shield berjalan'),
      detail: unknown.isEmpty
          ? null
          : tr(
              'Status pemindaian chat di HP {unknown} belum diketahui. '
              'Perbarui aplikasi AURA di HP tersebut.',
              {'unknown': _names(unknown)},
            ),
    );
  }

  static String _names(List<AppUser> children) {
    final names = children.map((c) => c.name).toList();
    if (names.length == 1) return names.first;
    return tr('{first} dan {last}', {
      'first': names.sublist(0, names.length - 1).join(', '),
      'last': names.last,
    });
  }
}

/// Daftar anak yang terhubung, di atas kaca lavender.
class _ChildrenCard extends StatelessWidget {
  const _ChildrenCard({required this.children});

  final List<AppUser> children;

  static const _navy = ClayColors.ink;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      color: ClayColors.lavender,
      padding: EdgeInsets.zero,
      child: Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Anak terhubung'),
                      style: TextStyle(
                        fontFamily: _poppins,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(Routes.pairing),
                    style: TextButton.styleFrom(foregroundColor: _navy),
                    icon: const Icon(Icons.add_link_rounded, size: 18),
                    label: Text(
                      tr('Tautkan'),
                      style: TextStyle(
                        fontFamily: _poppins,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 8, 6),
                  child: Text(
                    tr(
                      'Belum ada HP anak yang ditautkan. Ketuk "Tautkan" untuk membuat '
                      'kode penautan.',
                    ),
                    style: TextStyle(
                      fontFamily: _poppins,
                      fontSize: 13,
                      height: 1.45,
                      color: _navy.withValues(alpha: 0.8),
                    ),
                  ),
                )
              else
                for (final child in children) _ChildRow(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child});

  final AppUser child;

  /// Ponsel anak mengabari setiap 15 menit (AppState.heartbeatEvery).
  static const _onlineWindow = Duration(minutes: 20);

  @override
  Widget build(BuildContext context) {
    final lastSeen = child.lastSeenAt;
    final online =
        lastSeen != null && DateTime.now().difference(lastSeen) < _onlineWindow;
    final seen = online
        ? tr('Sedang Online')
        : lastSeen == null
        ? tr('Belum pernah aktif')
        : tr('Aktif {lastSeen}', {'lastSeen': _relative(lastSeen)});
    final issue = !child.hasConsented
        ? tr('Menunggu persetujuan')
        : child.chatScanEnabled == false
        ? tr('Chat tidak dipindai')
        : !child.protectionActive
        ? tr('Perlindungan dijeda')
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _ChildSheet.show(context, child.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AuraColors.cool,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  child.name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(
                      fontFamily: _poppins,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ClayColors.ink,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (child.age != null)
                          TextSpan(
                            text: tr('{age} Tahun | ', {'age': child.age}),
                          ),
                        TextSpan(
                          text: seen,
                          style: TextStyle(
                            color: online
                                ? const Color(0xFF12893F)
                                : ClayColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: _poppins,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ClayColors.inkSoft,
                    ),
                  ),
                  if (issue != null)
                    Text(
                      issue,
                      style: const TextStyle(
                        fontFamily: _poppins,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB3261E),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: ClayColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Rincian satu anak dalam lembar clay, termasuk tombol untuk menjeda
/// perlindungan.
class _ChildSheet extends StatelessWidget {
  const _ChildSheet({required this.childId});

  final String childId;

  static Future<void> show(BuildContext context, String childId) =>
      showClaySheet<void>(
        context: context,
        builder: (_) => _ChildSheet(childId: childId),
      );

  static const _green = Color(0xFF12893F);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final child = state.children.where((c) => c.id == childId).firstOrNull;
    if (child == null) return const SizedBox.shrink();

    final lastSeen = child.lastSeenAt;
    final online =
        lastSeen != null &&
        DateTime.now().difference(lastSeen) < _ChildRow._onlineWindow;
    final active = child.protectionActive;
    final details = [
      if (child.age != null) tr('{age} Tahun', {'age': child.age}),
      child.deviceLabel ?? tr('Perangkat'),
    ].join(' · ');

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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AuraColors.cool,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      child.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: _poppins,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontFamily: _poppins,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ClayColors.ink,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        details,
                        style: const TextStyle(
                          fontFamily: _poppins,
                          fontSize: 13,
                          color: ClayColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: online ? _green : ClayColors.inkMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            online
                                ? tr('Sedang Online')
                                : lastSeen == null
                                ? tr('Belum pernah aktif')
                                : tr('Aktif {lastSeen}', {
                                    'lastSeen': _relative(lastSeen),
                                  }),
                            style: TextStyle(
                              fontFamily: _poppins,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: online ? _green : ClayColors.inkMuted,
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
            ClayCard(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Column(
                children: [
                  InfoRow(
                    label: tr('Persetujuan anak'),
                    value: child.hasConsented ? tr('Sudah') : tr('Belum'),
                    valueColor: child.hasConsented
                        ? AuraColors.safe
                        : AuraColors.medium,
                  ),
                  InfoRow(
                    label: tr('Pemindaian chat'),
                    value: switch (child.chatScanEnabled) {
                      true => tr('Aktif'),
                      false => tr('Mati'),
                      null => tr('Belum diketahui'),
                    },
                    valueColor: switch (child.chatScanEnabled) {
                      true => AuraColors.safe,
                      false => AuraColors.high,
                      null => null,
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ClayCard(
              color: active
                  ? ClayColors.pastel(AuraColors.safe)
                  : ClayColors.butter,
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              onTap: () => state.setProtectionActive(child.id, !active),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active
                              ? tr('Perlindungan aktif')
                              : tr('Perlindungan dijeda'),
                          style: const TextStyle(
                            fontFamily: _poppins,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ClayColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active
                              ? tr(
                                  'Matikan untuk menjeda pemindaian di HP {childName} sementara.',
                                  {'childName': child.name},
                                )
                              : tr(
                                  'Chat {childName} sedang tidak dipindai. Nyalakan lagi kapan saja.',
                                  {'childName': child.name},
                                ),
                          style: const TextStyle(
                            fontFamily: _poppins,
                            fontSize: 12.5,
                            height: 1.4,
                            color: ClayColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    value: active,
                    onChanged: (value) =>
                        state.setProtectionActive(child.id, value),
                    activeTrackColor: const Color(0xFF34C759),
                    activeThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFD5D8DE),
                    inactiveThumbColor: Colors.white,
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LockScheduleCard(child: child),
          ],
        ),
      ),
    );
  }
}

String _relative(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return tr('baru saja');
  if (diff.inMinutes < 60) {
    return tr('{count} menit lalu', {'count': diff.inMinutes});
  }
  if (diff.inHours < 24) {
    return tr('{count} jam lalu', {'count': diff.inHours});
  }
  if (diff.inDays < 7) return tr('{count} hari lalu', {'count': diff.inDays});
  return formatLocal(time, 'd MMM');
}
