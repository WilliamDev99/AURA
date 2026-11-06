import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../state/app_state.dart';
import 'intervention_sheet.dart';
import '../../core/l10n/l10n.dart';

/// Anak melaporkan percakapan mencurigakan secara sadar.
///
/// Ini jalur utama pengumpulan bukti di AURA: anak menempelkan isi chat dari
/// aplikasi lain, bukan aplikasi yang diam-diam membaca semua layar. Cara ini
/// menghormati privasi anak, memenuhi kebijakan toko aplikasi, dan menghasilkan
/// bukti dengan dasar pengambilan yang jelas.
class ReportChatPage extends StatefulWidget {
  const ReportChatPage({super.key});

  @override
  State<ReportChatPage> createState() => _ReportChatPageState();
}

class _ReportChatPageState extends State<ReportChatPage> {
  final _textController = TextEditingController();
  final _counterpartController = TextEditingController();
  String _platform = 'WhatsApp';
  bool _sending = false;

  // Nilai yang disimpan tetap bahasa Indonesia; yang tampil diterjemahkan.
  static const _platforms = [
    'WhatsApp',
    'Instagram DM',
    'TikTok',
    'Telegram',
    'Chat Game',
    'SMS',
    'Discord',
    'Lainnya',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _counterpartController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    final state = context.read<AppState>();

    try {
      final outcome = await state.scanMessage(
        text: text,
        platform: _platform,
        counterpartName: _counterpartController.text.trim().isEmpty
            ? null
            : _counterpartController.text.trim(),
        childInitiated: true,
      );

      if (!mounted) return;
      _textController.clear();
      _counterpartController.clear();

      if (outcome.assessment.level.interruptsChild) {
        await showInterventionSheet(context, outcome.assessment);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Terima kasih. Laporanmu sudah tersimpan dan orang tuamu diberi tahu.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Laporkan chat yang aneh'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Salin pesannya, tempel di sini. Aku akan periksa dan simpan '
              'buktinya dengan aman.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Dari aplikasi mana?'),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _platforms.map((platform) {
                    final selected = platform == _platform;
                    return ChoiceChip(
                      label: Text(tr(platform)),
                      selected: selected,
                      onSelected: (_) => setState(() => _platform = platform),
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      selectedColor: AuraColors.electric.withValues(alpha: 0.3),
                      side: BorderSide(
                        color: selected
                            ? AuraColors.electric
                            : AuraColors.glassStroke,
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 12.5,
                        color: AuraColors.textPrimary,
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _counterpartController,
            decoration: InputDecoration(
              labelText: tr('Siapa yang mengirim? (boleh dikosongkan)'),
              hintText: tr('Nama akun atau grup'),
              prefixIcon: Icon(Icons.account_circle_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: tr('Tempel isi pesannya di sini'),
              hintText: tr('Contoh:\nDia: jangan bilang siapa-siapa ya...'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: AuraColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    'Isi laporan ini disimpan sebagai bukti bersegel waktu dan hanya '
                    'bisa dibuka orang tuamu.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shield_rounded),
            label: Text(_sending ? tr('Mengirim...') : tr('Kirim ke AURA')),
            style: FilledButton.styleFrom(backgroundColor: AuraColors.ember),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('Laporkan'))),
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        child: SafeArea(
          child: Padding(padding: const EdgeInsets.only(top: 50), child: body),
        ),
      ),
    );
  }
}
