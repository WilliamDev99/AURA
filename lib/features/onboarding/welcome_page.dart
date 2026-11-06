import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/l10n/l10n.dart';

/// Layar pembuka: memilih peran perangkat ini.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuraBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                    maxWidth: 520,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          const AuraMascot(size: 104),
                          const SizedBox(height: 28),
                          Text(
                            tr('Meet The'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AuraColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AuraColors.warm.createShader(bounds),
                            child: Text(
                              tr('AURA'),
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    fontSize: 56,
                                    color: Colors.white,
                                    letterSpacing: -2,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr(
                              'Perlindungan anak bertenaga AI dan pendamping langkah hukum.',
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AuraColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _Promise(
                            icon: Icons.security_rounded,
                            text: tr(
                              'Aman di dunia maya, tenang di dunia nyata.',
                            ),
                          ),
                          _Promise(
                            icon: Icons.smart_toy_outlined,
                            text: tr(
                              'AI yang selalu waspada, 24/7 untuk mereka.',
                            ),
                          ),
                          _Promise(
                            icon: Icons.web_outlined,
                            text: tr('Satu aplikasi, sejuta perlindungan.'),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () =>
                                context.push('${Routes.signIn}?peran=ortu'),
                            icon: const Icon(Icons.phone_android_rounded),
                            label: Text(tr('Handphone Orang Tua')),
                            style: FilledButton.styleFrom(
                              backgroundColor: AuraColors.ember,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.push('${Routes.signIn}?peran=anak'),
                            icon: const Icon(Icons.smartphone_rounded),
                            label: Text(tr('Handphone Anak')),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              tr(
                                'Dengan melanjutkan, Anda menyetujui bahwa AURA dipasang secara '
                                'terbuka dan diketahui anak.',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AuraColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AuraColors.glassStroke),
            ),
            child: Icon(icon, size: 17, color: AuraColors.cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AuraColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
