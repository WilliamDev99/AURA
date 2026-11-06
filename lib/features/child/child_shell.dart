import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../state/app_state.dart';
import 'child_home_page.dart';
import 'child_pairing_page.dart';
import 'widgets/location_guard.dart';
import 'widgets/sign_out_link.dart';
import '../../core/l10n/l10n.dart';

/// Kerangka antarmuka anak.
///
/// Sengaja tanpa navigasi bawah, sesuai desain: anak yang panik hanya perlu
/// melihat satu tombol. Obrolan dengan Aura dibuka dari "Butuh bantuan?",
/// dan laporan chat dari ikon headset.
class ChildShell extends StatelessWidget {
  const ChildShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;

    // Tanpa keluarga, perangkat ini tidak tahu harus mengirim peringatan ke
    // siapa. Penautan harus lebih dulu dari persetujuan.
    if (user != null && user.familyId == null) {
      return const ChildPairingPage();
    }

    // Sebelum anak menyetujui, tidak ada pemindaian apa pun yang berjalan.
    if (user != null && !user.hasConsented) {
      return const _ConsentGate();
    }

    // GPS diminta menyala setiap kali AURA dibuka, supaya tombol darurat
    // selalu bisa mengirim lokasi.
    return const Scaffold(body: LocationGuard(child: ChildHomePage()));
  }
}

/// Dinding persetujuan: anak harus memahami dan menyetujui sebelum lanjut.
class _ConsentGate extends StatelessWidget {
  const _ConsentGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuraBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AuraMascot(size: 92),
                    const SizedBox(height: 24),
                    Text(
                      tr('Satu hal dulu sebelum mulai'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'Kami perlu menjelaskan apa yang AURA lakukan di ponsel ini, dan '
                        'meminta persetujuanmu.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AuraColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () => context.push(Routes.childConsent),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(tr('Baca dan putuskan')),
                    ),
                    const SizedBox(height: 12),
                    const SignOutLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
