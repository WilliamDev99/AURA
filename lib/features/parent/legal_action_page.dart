import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/widgets/clay.dart';
import '../../domain/models/legal_article.dart';
import '../../domain/models/risk.dart';
import '../../domain/models/threat_alert.dart';
import '../../domain/services/dossier_builder.dart';
import '../../domain/services/legal_mapper.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// Halaman penuh Pusat Aksi Hukum (dibuka lewat navigasi).
class LegalActionPage extends StatelessWidget {
  const LegalActionPage({super.key, this.alertId});

  /// Bila diisi, halaman difokuskan pada satu peringatan.
  final String? alertId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pusat Aksi Hukum'))),
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        accent: AuraColors.ember,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: LegalActionBody(alertId: alertId),
          ),
        ),
      ),
    );
  }
}

/// Isi Pusat Aksi Hukum: menyiapkan berkas bukti, memetakan pasal, dan
/// menghubungkan orang tua ke kanal pelaporan resmi.
///
/// Dipakai dua kali: sebagai tab di [ParentShell] dan sebagai halaman penuh.
class LegalActionBody extends StatefulWidget {
  const LegalActionBody({
    super.key,
    this.alertId,
    this.leading = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 110),
  });

  final String? alertId;

  /// Ditampilkan di atas isi, dalam daftar gulir yang sama.
  final List<Widget> leading;
  final EdgeInsetsGeometry padding;

  @override
  State<LegalActionBody> createState() => _LegalActionBodyState();
}

class _LegalActionBodyState extends State<LegalActionBody> {
  static const _mapper = LegalMapper();
  static const _builder = DossierBuilder();
  bool _generating = false;

  Future<void> _generateDossier(List<ThreatAlert> alerts) async {
    final state = context.read<AppState>();
    final user = state.user;
    if (user == null) return;

    setState(() => _generating = true);
    try {
      final bytes = await _builder.build(
        reporter: user,
        alerts: alerts,
        evidence: state.evidence,
        verification: state.chainStatus,
        childName: alerts.firstOrNull?.childName,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'Berkas-Bukti-AURA-${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('Gagal membuat berkas: {error}', {'error': error}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _contact(EmergencyContact contact) async {
    final uri = contact.uri;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Tidak bisa membuka {value}', {'value': contact.value}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final focused = widget.alertId == null
        ? null
        : state.alertById(widget.alertId!);
    final alerts = focused != null ? [focused] : state.activeThreats;

    final categories = {for (final a in alerts) ...a.categories}.toList();
    final level = alerts.isEmpty
        ? RiskLevel.safe
        : alerts
              .map((a) => a.riskLevel)
              .reduce((a, b) => a.severity >= b.severity ? a : b);

    final steps = _mapper.stepsFor(level, categories);
    final articles = _mapper.articlesFor(categories);
    final contacts = _mapper.contactsFor(categories);

    return ListView(
      padding: widget.padding,
      children: [
        ...widget.leading,
        _DossierCard(
          alerts: alerts,
          evidenceCount: state.evidence.length,
          intact: state.chainStatus.isIntact,
          generating: _generating,
          onGenerate: () => _generateDossier(alerts),
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: tr('Langkah yang harus Anda lakukan'),
          subtitle: tr('Urut dari yang paling mendesak.'),
        ),
        ...steps.asMap().entries.map(
          (entry) => _StepTile(index: entry.key + 1, step: entry.value),
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: tr('Hubungi sekarang'),
          subtitle: tr('Kanal resmi yang menangani kasus anak.'),
        ),
        ...contacts.map(
          (contact) =>
              _ContactTile(contact: contact, onTap: () => _contact(contact)),
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: tr('Dasar hukum yang relevan'),
          subtitle: articles.isEmpty
              ? tr('Belum ada pemetaan untuk kategori ini.')
              : tr('{count} pasal dipetakan dari jenis ancaman.', {
                  'count': articles.length,
                }),
        ),
        ...articles.map((article) => _ArticleTile(article: article)),
        const SizedBox(height: 16),
        ClayCard(
          color: ClayColors.butter,
          child: Builder(
            builder: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: ClayColors.deep(AuraColors.medium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(LegalMapper.disclaimer),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DossierCard extends StatelessWidget {
  const _DossierCard({
    required this.alerts,
    required this.evidenceCount,
    required this.intact,
    required this.generating,
    required this.onGenerate,
  });

  final List<ThreatAlert> alerts;
  final int evidenceCount;
  final bool intact;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      color: ClayColors.peach,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_rounded,
                  color: ClayColors.deep(AuraColors.ember),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('Berkas Bukti Siap Lapor'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'AURA menyusun kronologi, daftar bukti bersegel waktu, hasil '
                'verifikasi integritas, dan rujukan pasal menjadi satu PDF yang '
                'bisa Anda serahkan ke penyidik.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            // Wrap, bukan Row: di layar sempit atau huruf besar, angka turun ke
            // baris berikutnya alih-alih terpotong.
            Wrap(
              spacing: 22,
              runSpacing: 8,
              children: [
                _Stat(label: tr('Kejadian'), value: '${alerts.length}'),
                _Stat(label: tr('Bukti'), value: '$evidenceCount'),
                _Stat(
                  label: tr('Integritas'),
                  value: intact ? tr('Utuh') : tr('Putus'),
                  color: ClayColors.deep(
                    intact ? AuraColors.safe : AuraColors.critical,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: generating || alerts.isEmpty ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                generating
                    ? tr('Menyusun berkas...')
                    : tr('Buat & bagikan berkas PDF'),
              ),
              style: FilledButton.styleFrom(backgroundColor: AuraColors.ember),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color ?? ClayColors.ink,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});

  final int index;
  final ReportingStep step;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Builder(
        builder: (context) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: AuraColors.cool,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(step.title),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(step.detail),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  if (step.caution != null) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AuraColors.critical.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.priority_high_rounded,
                            size: 15,
                            color: ClayColors.deep(AuraColors.critical),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(step.caution!),
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: ClayColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final EmergencyContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (contact.channel) {
      ContactChannel.phone => Icons.call_rounded,
      ContactChannel.whatsapp => Icons.chat_rounded,
      ContactChannel.web => Icons.language_rounded,
      ContactChannel.email => Icons.mail_outline_rounded,
    };
    final color = contact.isPrimary
        ? ClayColors.deep(AuraColors.critical)
        : const Color(0xFF0277BD);

    return ClayCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Builder(
        builder: (context) => Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(contact.name),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        contact.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr(contact.description),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article});

  final LegalArticle article;

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
                  Icons.gavel_rounded,
                  size: 16,
                  color: ClayColors.deep(AuraColors.ember),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    article.reference,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              tr(article.title),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0277BD),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              tr(article.summary),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3FA),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                tr(article.penalty),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: ClayColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
