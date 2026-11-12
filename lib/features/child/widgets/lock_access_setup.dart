import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/widgets/aura_widgets.dart';
import '../../../state/app_state.dart';

/// Jam istirahat di Pengaturan anak: jadwalnya (transparansi: anak tahu
/// kapan aplikasinya terkunci) dan izin yang dibutuhkan untuk menguncinya.
class LockAccessSetup extends StatelessWidget {
  const LockAccessSetup({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final schedule = state.user?.lockSchedule;
    final on = schedule?.active ?? false;
    final access = state.lockAccessStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoRow(
          label: tr('Jam istirahat'),
          value: on ? schedule!.describe() : tr('Tidak diatur'),
        ),
        if (on && access != null) ...[
          if (access.ready)
            InfoRow(
              label: tr('Pengunci'),
              value: tr('Siap'),
              valueColor: AuraColors.safe,
            )
          else ...[
            if (!access.usage)
              _Permission(
                label: tr('Akses penggunaan'),
                hint: tr('Supaya AURA tahu aplikasi apa yang sedang dibuka.'),
                onAllow: state.lockAccess.openUsageAccessSettings,
              ),
            if (!access.overlay)
              _Permission(
                label: tr('Tampil di atas aplikasi lain'),
                hint: tr(
                  'Supaya AURA bisa menutup aplikasi saat jam istirahat.',
                ),
                onAllow: state.lockAccess.openOverlaySettings,
              ),
            if (!access.battery)
              _Permission(
                label: tr('Tetap aktif di latar belakang'),
                hint: tr('Supaya HP tidak mematikan AURA saat jam istirahat.'),
                onAllow: state.lockAccess.openBatterySettings,
              ),
          ],
        ],
      ],
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({
    required this.label,
    required this.hint,
    required this.onAllow,
  });

  final String label;
  final String hint;
  final Future<void> Function() onAllow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoRow(label: label, value: hint, valueColor: AuraColors.medium),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onAllow,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(tr('Izinkan')),
          ),
        ),
      ],
    );
  }
}
