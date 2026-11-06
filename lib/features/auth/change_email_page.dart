import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../state/app_state.dart';
import 'parent_account_step.dart';

/// Mengganti email akun orang tua.
///
/// Kode dikirim ke email baru. Bila Supabase memakai "Secure email change"
/// (bawaannya menyala), email lama juga menerima kode, dan keduanya harus
/// dimasukkan: orang yang meminjam HP sebentar tidak bisa mengambil alih
/// akun hanya dengan mengganti emailnya.
class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _emailKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newCodeController = TextEditingController();
  final _oldCodeController = TextEditingController();

  /// Email baru yang sudah dikirimi kode.
  String? _sentTo;

  /// Email lama saat penggantian dimulai.
  String? _oldEmail;

  bool _needsOldCode = false;
  bool _done = false;
  int _secondsLeft = 0;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _emailController.dispose();
    _newCodeController.dispose();
    _oldCodeController.dispose();
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

  Future<void> _send() async {
    if (!_emailKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final email = _emailController.text.trim().toLowerCase();
    final oldEmail = state.accountEmail;
    if (await state.requestEmailChange(email) && mounted) {
      setState(() {
        _sentTo = email;
        _oldEmail = oldEmail;
        _needsOldCode = false;
      });
      _startCountdown();
    }
  }

  Future<void> _confirm() async {
    final email = _sentTo;
    if (email == null || !_codeKey.currentState!.validate()) return;
    final done = await context.read<AppState>().confirmEmailChange(
      newEmail: email,
      newCode: _newCodeController.text,
      currentCode: _oldCodeController.text,
    );
    if (!mounted || done == null) return;
    setState(() {
      _done = done;
      _needsOldCode = !done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sentTo = _sentTo;

    final List<Widget> content;
    if (_done) {
      content = _doneView(sentTo!);
    } else if (sentTo == null) {
      content = _emailView(state);
    } else {
      content = _codeView(state, sentTo);
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Ubah Email'))),
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
                  children: [
                    ...content,
                    if (state.lastError != null && !_done) ...[
                      const SizedBox(height: 14),
                      Text(
                        state.lastError!,
                        style: const TextStyle(
                          color: AuraColors.critical,
                          fontSize: 13,
                        ),
                      ),
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

  List<Widget> _emailView(AppState state) {
    final theme = Theme.of(context);
    final current = state.accountEmail;
    return [
      GlassCard(
        child: Text(
          current == null
              ? tr(
                  'Tambahkan email untuk masuk ke akun ini. Kode masuk akan '
                  'dikirim ke email tersebut.',
                )
              : tr(
                  'Email sekarang: {email}. Setelah diganti, masuk ke AURA '
                  'memakai email baru.',
                  {'email': current},
                ),
          style: theme.textTheme.bodySmall,
        ),
      ),
      const SizedBox(height: 20),
      Form(
        key: _emailKey,
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: tr('Email baru'),
            hintText: 'nama@gmail.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
          validator: (value) {
            final email = value?.trim().toLowerCase() ?? '';
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
              return tr('Isi alamat email yang benar, mis. nama@gmail.com');
            }
            if (email == current?.toLowerCase()) {
              return tr('Ini sudah email Anda sekarang.');
            }
            return null;
          },
        ),
      ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: state.busy ? null : _send,
        style: FilledButton.styleFrom(backgroundColor: AuraColors.ember),
        child: Text(tr('Kirim kode')),
      ),
    ];
  }

  List<Widget> _codeView(AppState state, String sentTo) {
    final theme = Theme.of(context);
    final oldEmail = _oldEmail;
    final waiting = _secondsLeft > 0;
    return [
      Text(
        oldEmail == null
            ? tr('Kode dikirim ke {email}. Cek juga folder Spam.', {
                'email': sentTo,
              })
            : tr(
                'Kode dikirim ke email baru ({new}). Email lama ({old}) '
                'mungkin juga menerima kode. Cek juga folder Spam.',
                {'new': sentTo, 'old': oldEmail},
              ),
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      Form(
        key: _codeKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _codeField(
              controller: _newCodeController,
              label: tr('Kode dari email baru'),
              autofocus: true,
              required: true,
            ),
            if (oldEmail != null) ...[
              const SizedBox(height: 14),
              _codeField(
                controller: _oldCodeController,
                label: tr('Kode dari email lama'),
                helper: _needsOldCode
                    ? null
                    : tr('Isi bila email lama juga menerima kode.'),
                error: _needsOldCode
                    ? tr('Masukkan juga kode yang dikirim ke {email}.', {
                        'email': oldEmail,
                      })
                    : null,
                required: _needsOldCode,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: state.busy ? null : _confirm,
        style: FilledButton.styleFrom(backgroundColor: AuraColors.ember),
        child: Text(tr('Simpan email baru')),
      ),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: state.busy
                ? null
                : () {
                    _countdown?.cancel();
                    state.clearError();
                    setState(() {
                      _sentTo = null;
                      _secondsLeft = 0;
                    });
                  },
            child: Text(tr('Ganti email')),
          ),
          TextButton(
            onPressed: state.busy || waiting ? null : _send,
            child: Text(
              waiting
                  ? tr('Kirim ulang ({time})', {
                      'time': '0:${_secondsLeft.toString().padLeft(2, '0')}',
                    })
                  : tr('Kirim ulang kode'),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _codeField({
    required TextEditingController controller,
    required String label,
    String? helper,
    String? error,
    bool autofocus = false,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: '123456',
        helperText: helper,
        helperMaxLines: 2,
        errorText: error,
        errorMaxLines: 3,
      ),
      validator: (value) {
        final length = value?.trim().length ?? 0;
        if (length == 0 && !required) return null;
        return length < 6 ? tr('Kode terdiri dari 6 angka') : null;
      },
    );
  }

  List<Widget> _doneView(String email) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 20),
      const Icon(
        Icons.mark_email_read_rounded,
        color: AuraColors.safe,
        size: 64,
      ),
      const SizedBox(height: 16),
      Text(
        tr('Email berhasil diganti'),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        tr('Mulai sekarang, masuk ke AURA memakai {email}.', {'email': email}),
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
