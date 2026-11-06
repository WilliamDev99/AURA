import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

/// Jalan keluar di layar penautan dan persetujuan.
///
/// Tanpa ini, perangkat yang salah memilih "Handphone Anak" terkunci di
/// layar itu: belum ada beranda, jadi belum ada jalan ke Pengaturan.
class SignOutLink extends StatelessWidget {
  const SignOutLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        await context.read<AppState>().signOut();
        if (context.mounted) context.go(Routes.welcome);
      },
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: Text(tr('Keluar')),
      style: TextButton.styleFrom(foregroundColor: AuraColors.textSecondary),
    );
  }
}
