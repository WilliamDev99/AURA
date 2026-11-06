import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../core/widgets/clay.dart';
import '../../state/app_state.dart';
import 'widgets/sign_out_link.dart';
import '../../core/l10n/l10n.dart';

/// Perangkat anak memasukkan kode dari ponsel orang tua.
///
/// Tanpa langkah ini, perangkat anak tidak tahu harus mengirim peringatan ke
/// siapa. Kode sengaja dibaca dari layar orang tua, bukan dikirim lewat tautan,
/// supaya penautan hanya bisa terjadi saat keduanya berada di satu ruangan.
class ChildPairingPage extends StatefulWidget {
  const ChildPairingPage({super.key, this.relink = false});

  /// Dibuka dari Profil untuk menautkan ulang, tanpa keluar akun: ada tombol
  /// kembali, dan setelah berhasil halaman ditutup.
  final bool relink;

  @override
  State<ChildPairingPage> createState() => _ChildPairingPageState();
}

class _ChildPairingPageState extends State<ChildPairingPage> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 6 || _submitting) return;

    final state = context.read<AppState>();
    // Kode dari orang tua lain memindahkan semua peringatan berikutnya ke
    // orang tua itu. Anak (dan siapa pun yang memegang HP-nya) diberi tahu
    // dulu, supaya pemindahan tidak terjadi tanpa disadari.
    if (state.user?.familyId != null) {
      final go = await showClayConfirm(
        context: context,
        icon: Icons.link_rounded,
        accent: AuraColors.electric,
        title: tr('Ganti sambungan orang tua?'),
        message: tr(
          'HP ini sudah tersambung ke orang tua. Kalau kode ini dari orang '
          'tua lain, peringatan berikutnya dikirim ke orang tua tersebut.',
        ),
        cancelLabel: tr('Batal'),
        confirmLabel: tr('Sambungkan'),
      );
      if (!go || !mounted) return;
    }

    setState(() => _submitting = true);
    await state.joinFamilyWithCode(code);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (state.lastError == null) {
      HapticFeedback.mediumImpact();
      if (widget.relink) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(tr('Tersambung ke orang tua.'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.user?.name ?? tr('Teman');

    return Scaffold(
      appBar: widget.relink
          ? AppBar(title: Text(tr('Tautkan ke Orang Tua')))
          : null,
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(child: AuraMascot(size: 84)),
                    const SizedBox(height: 24),
                    Text(
                      widget.relink
                          ? tr('Tautkan ke orang tua')
                          : tr('Halo, {name}', {'name': name}),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'Minta kode dari ponsel orang tuamu, lalu ketik di sini supaya '
                        'kita bisa terhubung.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AuraColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                        fontFamily: 'monospace',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[a-zA-Z0-9]'),
                        ),
                        TextInputFormatter.withFunction(
                          (_, next) =>
                              next.copyWith(text: next.text.toUpperCase()),
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: '------',
                        counterText: '',
                        hintStyle: TextStyle(
                          fontSize: 30,
                          letterSpacing: 10,
                          color: AuraColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (state.lastError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.lastError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AuraColors.critical,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed:
                          _controller.text.trim().length == 6 && !_submitting
                          ? _submit
                          : null,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(tr('Hubungkan')),
                    ),
                    const SizedBox(height: 18),
                    GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: AuraColors.cyan,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr(
                                'Orang tuamu bisa melihat kodenya di aplikasi AURA mereka, pada '
                                'menu "Tautkan".',
                              ),
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dari Profil tidak perlu keluar: cukup kembali.
                    if (!widget.relink) ...[
                      const SizedBox(height: 12),
                      const SignOutLink(),
                    ],
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
