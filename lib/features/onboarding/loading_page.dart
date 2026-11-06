import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/l10n/l10n.dart';

/// Ditampilkan sementara sesi tersimpan dipulihkan saat aplikasi dibuka.
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  /// Setelah selama ini, kemungkinan besar masalahnya jaringan. Pemulihan
  /// tetap berjalan di belakang; pesan ini hanya menjelaskan kenapa lama.
  static const _slowAfter = Duration(seconds: 8);

  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuraBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuraMascot(size: 92),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AuraColors.cyan,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _slow ? tr('Masih menyambungkan...') : tr('Memuat AURA...'),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: _slow
                      ? Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            tr(
                              'Periksa koneksi internet. AURA akan tersambung sendiri begitu '
                              'jaringan kembali.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              height: 1.5,
                              color: AuraColors.textSecondary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
