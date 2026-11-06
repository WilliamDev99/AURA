import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/utils/phone_number.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/widgets/clay.dart';
import '../child/widgets/chat_scan_status.dart';
import '../../state/app_state.dart';
import 'account_settings.dart';

/// Pengaturan dan transparansi.
///
/// Anak melihat halaman ini juga: ia bisa memeriksa apa saja yang pernah
/// dikirim ke orang tuanya. Itu bagian dari janji "terbuka, bukan memata-matai".
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pengaturan'))),
      extendBodyBehindAppBar: true,
      body: const AuraBackdrop(
        child: SafeArea(
          child: SettingsBody(padding: EdgeInsets.fromLTRB(20, 60, 20, 32)),
        ),
      ),
    );
  }
}

/// Isi halaman pengaturan. Dipakai juga sebagai tab "Profil" orang tua.
class SettingsBody extends StatelessWidget {
  const SettingsBody({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 120),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    // Kartu clay untuk orang tua; ponsel anak tetap memakai kartu kaca.
    // Isi kartu dibangun di dalam kartu, supaya Theme.of(context) membaca
    // tema kartu clay (tulisan gelap).
    Widget card(WidgetBuilder build) => state.isChild
        ? GlassCard(child: Builder(builder: build))
        : ClayCard(child: Builder(builder: build));

    return ListView(
      padding: padding,
      children: [
        card(
          (context) => Row(
            children: [
              const EditableAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? tr('Pengguna'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.isChild
                          ? tr('Perangkat anak')
                          : tr('Perangkat orang tua'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!state.isChild && state.accountLabel != null)
                      Text(
                        tr('Masuk dengan {account}', {
                          'account': state.accountLabel,
                        }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (state.isChild) ...[
          const SizedBox(height: 16),
          const ChatScanStatus(),
        ],
        if (state.needsAccountSecuring) ...[
          const SizedBox(height: 16),
          const _SecureAccountCard(),
        ],
        const SizedBox(height: 20),
        SectionHeader(title: tr('Akun')),
        AccountSection(card: card),
        const SizedBox(height: 16),
        card(
          (context) => Column(
            children: [
              // Dua baris ini tentang ponsel anak sendiri. Di ponsel orang
              // tua statusnya ada per anak di Beranda.
              if (state.isChild) ...[
                InfoRow(
                  label: tr('Status pemindaian'),
                  value: (user?.protectionActive ?? false)
                      ? tr('Aktif')
                      : tr('Dijeda'),
                  valueColor: (user?.protectionActive ?? false)
                      ? AuraColors.safe
                      : AuraColors.medium,
                ),
                InfoRow(
                  label: tr('Persetujuan anak'),
                  value: user?.monitoringConsentAt == null
                      ? tr('Belum diberikan')
                      : formatWithZone(
                          user!.monitoringConsentAt!,
                          'd MMMM yyyy, HH:mm',
                        ),
                ),
                // Transparansi: anak tahu siapa yang akan ditelepon. Orang
                // tua melihat nomornya sendiri di bagian Akun.
                InfoRow(
                  label: tr('Ditelepon saat darurat'),
                  value: switch (state.emergencyNumber) {
                    final number? => formatIndonesianPhone(number),
                    null => tr('Belum diisi'),
                  },
                ),
              ],
              InfoRow(
                label: tr('Peringatan terkirim'),
                value: tr('{count} sejak awal', {'count': state.alerts.length}),
              ),
              InfoRow(
                label: tr('Bukti tersimpan'),
                value: tr('{count} entri', {'count': state.evidence.length}),
              ),
              InfoRow(
                label: tr('Integritas bukti'),
                value: state.chainStatus.isIntact ? tr('Utuh') : tr('Terputus'),
                valueColor: state.chainStatus.isIntact
                    ? AuraColors.safe
                    : AuraColors.critical,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: tr('Yang tidak pernah AURA lakukan')),
        _Never(text: tr('Menyalakan kamera atau mikrofon diam-diam.')),
        _Never(text: tr('Menyembunyikan ikon aplikasi dari anak.')),
        _Never(
          text: tr('Meneruskan obrolan yang tidak berbahaya ke orang tua.'),
        ),
        _Never(text: tr('Menjual atau membagikan data anak ke pihak ketiga.')),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            // Akun anonim tidak bisa dimasuki lagi setelah keluar: datanya
            // tetap ada di server, tetapi tidak ada jalan kembali ke sana.
            if (state.needsAccountSecuring) {
              final leave = await showClayConfirm(
                context: context,
                icon: Icons.warning_amber_rounded,
                accent: AuraColors.critical,
                title: tr('Akun belum diamankan'),
                message: tr(
                  'Kalau keluar sekarang, Anda tidak bisa masuk lagi ke '
                  'akun ini dan data anak tidak bisa dibuka. Amankan dulu '
                  'dengan email atau Facebook.',
                ),
                cancelLabel: tr('Batal'),
                confirmLabel: tr('Tetap keluar'),
              );
              if (!leave) return;
            }
            await state.signOut();
            if (context.mounted) context.go('/');
          },
          icon: const Icon(Icons.logout_rounded),
          label: Text(tr('Keluar')),
          style: OutlinedButton.styleFrom(
            foregroundColor: AuraColors.critical,
            side: BorderSide(color: AuraColors.critical.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            tr('AURA v1.0.0 - dibuat untuk melindungi, bukan mengawasi.'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AuraColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// Ajakan mengamankan akun orang tua lama yang masih anonim.
class _SecureAccountCard extends StatelessWidget {
  const _SecureAccountCard();

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      color: ClayColors.peach,
      onTap: () => context.push(Routes.secureAccount),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            color: ClayColors.deep(AuraColors.ember),
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Amankan akun Anda'),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: ClayColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr(
                    'Belum tersambung ke email atau Facebook. Kalau aplikasi '
                    'dihapus, data tidak bisa dibuka lagi.',
                  ),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: ClayColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: ClayColors.inkSoft),
        ],
      ),
    );
  }
}

class _Never extends StatelessWidget {
  const _Never({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, size: 16, color: AuraColors.safe),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AuraColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
