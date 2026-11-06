import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/l10n/l10n.dart';

/// Pilihan bantuan yang tidak darurat, dibuka dari ikon headset di beranda.
Future<void> showHelpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // Tanpa ini tinggi lembar dibatasi 9/16 layar: di ponsel yang lebih
    // pendek, atau dengan huruf diperbesar, pilihan terakhir terpotong.
    isScrollControlled: true,
    builder: (sheetContext) => const _HelpSheet(),
  );
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    void open(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D3FCB), Color(0xFF0B1257)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('Butuh bantuan?'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('Nggak harus darurat. Pilih yang paling cocok buatmu.'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 20),
              _Option(
                icon: Icons.forum_rounded,
                title: tr('Ngobrol dengan Aura'),
                subtitle: tr('Ceritain apa yang bikin kamu nggak nyaman.'),
                onTap: () => open(Routes.childChat),
              ),
              const SizedBox(height: 12),
              _Option(
                icon: Icons.flag_rounded,
                title: tr('Laporkan chat aneh'),
                subtitle: tr('Salin pesannya ke sini, nanti Aura periksa.'),
                onTap: () => open(Routes.childReport),
              ),
              const SizedBox(height: 12),
              // Anak berhak melihat apa saja yang dikirim ke orang tuanya, dan
              // keluar dari perangkat ini. Dulu halaman ini tak terjangkau dari
              // sisi anak.
              _Option(
                icon: Icons.settings_rounded,
                title: tr('Pengaturan'),
                subtitle: tr(
                  'Lihat apa yang dikirim ke orang tuamu, atau keluar.',
                ),
                onTap: () => open(Routes.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
