import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/widgets/clay.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// Membuat kode penautan agar perangkat anak bisa bergabung ke keluarga.
class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  String? _code;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    var code = await state.pairingCode();
    code ??= await state.repository.createFamily(
      tr('Keluarga {name}', {'name': state.user?.name ?? ""}).trim(),
    );
    if (mounted) {
      setState(() {
        _code = code;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tautkan Perangkat Anak'))),
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
            children: [
              ClayCard(
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      const AuraMascot(size: 72),
                      const SizedBox(height: 18),
                      Text(
                        tr('Kode penautan'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: CircularProgressIndicator(),
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _code ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('Kode disalin'))),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: AuraColors.cool,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _code ?? '------',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 9,
                                fontFamily: 'monospace',
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        tr('Ketuk kode untuk menyalin. Berlaku 24 jam.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: tr('Cara menautkan')),
              _Step(
                number: 1,
                text: tr(
                  'Pasang AURA di ponsel anak lewat Play Store, lalu buka aplikasinya.',
                ),
              ),
              _Step(
                number: 2,
                text: tr(
                  'Di ponsel anak, pilih "Handphone Anak" dan isi namanya.',
                ),
              ),
              _Step(number: 3, text: tr('Masukkan kode di atas saat diminta.')),
              _Step(
                number: 4,
                text: tr(
                  'Dampingi anak membaca layar persetujuan. Jelaskan bahwa ini '
                  'untuk melindunginya, bukan untuk memata-matai.',
                ),
              ),
              const SizedBox(height: 18),
              ClayCard(
                color: ClayColors.sky,
                child: Builder(
                  builder: (context) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        color: Color(0xFF0277BD),
                        size: 19,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(
                            'Anak yang tahu dan setuju jauh lebih mungkin bercerita saat ada '
                            'masalah. Perlindungan yang disembunyikan justru merusak '
                            'kepercayaan yang Anda butuhkan.',
                          ),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AuraColors.electric.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AuraColors.electric.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AuraColors.cyan,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
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
