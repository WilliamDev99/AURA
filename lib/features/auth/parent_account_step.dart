import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// Warna resmi tombol Facebook.
const _facebookBlue = Color(0xFF1877F2);

/// Jeda sebelum kode baru boleh diminta; sama dengan batas Supabase.
const resendCooldown = Duration(seconds: 60);

/// Pola alamat email yang wajar: ada nama, @, dan domain bertitik.
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Langkah pertama orang tua: masuk atau daftar dengan Facebook, atau dengan
/// email dan kode 6 digit.
///
/// Akun ini yang membuat data orang tua bisa dipulihkan: setelah ganti HP
/// atau pasang ulang aplikasi, masuk lagi dengan email atau Facebook yang
/// sama dan semua data kembali.
class ParentAccountStep extends StatelessWidget {
  const ParentAccountStep({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: state.busy ? null : state.continueWithFacebook,
          icon: const Icon(Icons.facebook_rounded, size: 22),
          label: Text(tr('Lanjutkan dengan Facebook')),
          style: FilledButton.styleFrom(
            backgroundColor: _facebookBlue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        const _OrDivider(),
        const SizedBox(height: 18),
        const EmailCodeLogin(),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: AuraColors.textMuted.withValues(alpha: 0.4)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            tr('atau dengan email'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        line,
      ],
    );
  }
}

/// Masuk dengan email: minta kode, lalu ketik kode dari email.
class EmailCodeLogin extends StatefulWidget {
  const EmailCodeLogin({super.key, this.onVerified});

  /// Dipanggil setelah kode benar, mis. untuk menutup lembar di Profil.
  final VoidCallback? onVerified;

  @override
  State<EmailCodeLogin> createState() => _EmailCodeLoginState();
}

class _EmailCodeLoginState extends State<EmailCodeLogin> {
  final _emailKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  /// Alamat yang sudah dikirimi kode; null selama masih mengisi email.
  String? _sentTo;
  int _secondsLeft = 0;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = resendCooldown.inSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (!_emailKey.currentState!.validate()) return;
    final email = _emailController.text.trim().toLowerCase();
    final sent = await context.read<AppState>().requestEmailCode(email);
    if (!mounted || !sent) return;
    setState(() => _sentTo = email);
    _codeController.clear();
    _startCountdown();
  }

  Future<void> _resend() async {
    final email = _sentTo;
    if (email == null) return;
    final sent = await context.read<AppState>().requestEmailCode(email);
    if (mounted && sent) _startCountdown();
  }

  Future<void> _verify() async {
    final email = _sentTo;
    if (email == null || !_codeKey.currentState!.validate()) return;
    final ok = await context.read<AppState>().verifyEmailCode(
      email,
      _codeController.text.trim(),
    );
    if (mounted && ok) widget.onVerified?.call();
  }

  void _changeEmail() {
    _countdown?.cancel();
    context.read<AppState>().clearError();
    setState(() {
      _sentTo = null;
      _secondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppState>().busy;
    final sentTo = _sentTo;
    return sentTo == null ? _emailForm(busy) : _codeForm(sentTo, busy);
  }

  Widget _emailForm(bool busy) {
    return Form(
      key: _emailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => busy ? null : _sendCode(),
            decoration: InputDecoration(
              labelText: tr('Email Anda'),
              hintText: tr('nama@gmail.com'),
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) => _emailPattern.hasMatch(value?.trim() ?? '')
                ? null
                : tr('Isi alamat email yang benar, mis. nama@gmail.com'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : _sendCode,
            style: FilledButton.styleFrom(backgroundColor: AuraColors.ember),
            child: Text(tr('Kirim kode ke email')),
          ),
        ],
      ),
    );
  }

  Widget _codeForm(String sentTo, bool busy) {
    final theme = Theme.of(context);
    final waiting = _secondsLeft > 0;
    return Form(
      key: _codeKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: tr('Kode masuk dikirim ke ')),
                TextSpan(
                  text: sentTo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: tr('. Tidak ada di kotak masuk? Cek folder ')),
                TextSpan(
                  text: tr('Spam'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            autofocus: true,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => busy ? null : _verify(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: tr('Kode dari email'),
              hintText: '123456',
            ),
            validator: (value) => (value?.trim().length ?? 0) < 6
                ? tr('Kode terdiri dari 6 angka')
                : null,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : _verify,
            style: FilledButton.styleFrom(backgroundColor: AuraColors.ember),
            child: Text(tr('Masuk')),
          ),
          const SizedBox(height: 6),
          // Wrap, bukan Row: di layar sempit atau huruf besar, kedua tombol
          // turun ke baris berikutnya alih-alih meluber.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: busy ? null : _changeEmail,
                child: Text(tr('Ganti email')),
              ),
              TextButton(
                onPressed: busy || waiting ? null : _resend,
                child: Text(
                  waiting
                      ? tr('Kirim ulang ({time})', {
                          'time':
                              '0:${_secondsLeft.toString().padLeft(2, '0')}',
                        })
                      : tr('Kirim ulang kode'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
