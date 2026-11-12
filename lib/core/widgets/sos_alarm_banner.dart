import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Kartu "Alarm SOS berbunyi" di atas semua halaman orang tua.
///
/// Notifikasi alarm melayang hanya beberapa detik lalu masuk ke panel
/// notifikasi, padahal bunyinya terus. Kartu ini memberi tombol mematikan
/// alarm langsung di layar AURA, selama alarm masih berbunyi.
class SosAlarmBanner extends StatelessWidget {
  const SosAlarmBanner({
    super.key,
    required this.alarm,
    required this.onStop,
    required this.child,
  });

  /// Rute peringatan yang alarmnya sedang berbunyi; null bila senyap.
  final ValueListenable<String?> alarm;
  final VoidCallback onStop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<String?>(
            valueListenable: alarm,
            builder: (context, route, _) => route == null
                ? const SizedBox.shrink()
                : _AlarmCard(onStop: onStop),
          ),
        ),
      ],
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.onStop});

  final VoidCallback onStop;

  static const _red = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.all(12),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: _red,
          elevation: 10,
          shadowColor: _red.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Alarm SOS berbunyi'),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            tr('Berbunyi sampai Anda mematikannya.'),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Selebar kartu: mudah dikenai orang tua yang sedang panik.
                FilledButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.alarm_off_rounded),
                  label: Text(tr('Matikan alarm')),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _red,
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
