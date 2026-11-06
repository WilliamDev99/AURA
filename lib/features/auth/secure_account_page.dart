import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../state/app_state.dart';
import 'parent_account_step.dart';
import '../../core/l10n/l10n.dart';

/// Mengamankan akun orang tua lama yang masih anonim dengan email atau
/// Facebook.
///
/// Akunnya tetap sama (anak, peringatan, dan bukti tidak berubah); bedanya,
/// setelah ini akun bisa dipulihkan bila aplikasi dihapus atau HP diganti.
class SecureAccountPage extends StatelessWidget {
  const SecureAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final secured = !state.needsAccountSecuring;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Amankan Akun'))),
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 90, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: secured
                      ? _done(context, state.accountLabel)
                      : _form(context, state),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    return [
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AuraColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('Supaya data tidak hilang'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'Sambungkan akun ini ke email atau Facebook. Data anak, '
                'peringatan, dan bukti tetap sama. Setelah ini, kalau aplikasi '
                'dihapus atau HP diganti, Anda cukup masuk lagi dengan email '
                'atau Facebook yang sama.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const ParentAccountStep(),
      if (state.lastError != null) ...[
        const SizedBox(height: 14),
        Text(
          state.lastError!,
          style: const TextStyle(color: AuraColors.critical, fontSize: 13),
        ),
      ],
    ];
  }

  List<Widget> _done(BuildContext context, String? account) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 20),
      const Icon(Icons.verified_user_rounded, color: AuraColors.safe, size: 64),
      const SizedBox(height: 16),
      Text(
        tr('Akun sudah aman'),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        account == null
            ? tr('Akun ini sudah tersambung.')
            : tr(
                'Akun ini sudah tersambung ke {account}. Masuk lagi dengan akun '
                'itu kapan pun, dan semua data kembali.',
                {'account': account},
              ),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: () => context.pop(),
        style: FilledButton.styleFrom(backgroundColor: AuraColors.ember),
        child: Text(tr('Kembali')),
      ),
    ];
  }
}
