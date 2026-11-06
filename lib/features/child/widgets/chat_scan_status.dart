import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/aura_colors.dart';
import '../../../core/widgets/aura_widgets.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

/// Status pemindaian chat di ponsel anak, beserta tombol untuk menyalakannya.
///
/// Diperiksa ulang setiap kali aplikasi kembali ke depan, karena izinnya
/// diubah di Pengaturan Android, di luar aplikasi ini.
class ChatScanStatus extends StatefulWidget {
  const ChatScanStatus({super.key});

  @override
  State<ChatScanStatus> createState() => _ChatScanStatusState();
}

class _ChatScanStatusState extends State<ChatScanStatus>
    with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    final granted = await state.notificationAccess.isGranted();
    if (granted != null) unawaited(state.reportChatScan(granted));
    if (mounted) setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    // Bukan Android: tidak ada yang bisa ditampilkan dengan jujur.
    if (granted == null) return const SizedBox.shrink();

    return GlassCard(
      borderColor: (granted ? AuraColors.safe : AuraColors.medium).withValues(
        alpha: 0.4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                granted
                    ? Icons.mark_chat_read_rounded
                    : Icons.speaker_notes_off_rounded,
                color: granted ? AuraColors.safe : AuraColors.medium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  granted
                      ? tr('Pemindaian chat aktif')
                      : tr('Pemindaian chat belum aktif'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            granted
                ? tr(
                    'Pesan masuk dari WhatsApp, Instagram, TikTok, Telegram, SMS, '
                    'chat game Roblox, dan aplikasi chat lain diperiksa di ponsel '
                    'ini. Hanya yang berbahaya sampai ke orang tuamu.',
                  )
                : tr(
                    'Pesan yang masuk belum diperiksa. Nyalakan "Akses notifikasi" '
                    'untuk AURA supaya pesan berbahaya bisa terdeteksi.',
                  ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          if (!granted) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  context.read<AppState>().notificationAccess.openSettings(),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: Text(tr('Nyalakan di Pengaturan')),
            ),
          ],
        ],
      ),
    );
  }
}
