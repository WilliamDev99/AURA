import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/utils/guarded_input.dart';
import '../../core/utils/name_input.dart';
import '../../core/utils/phone_number.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../domain/models/app_user.dart';
import '../../state/app_state.dart';
import 'parent_account_step.dart';
import '../../core/l10n/l10n.dart';

/// Halaman masuk.
///
/// Orang tua: (1) masuk atau daftar dengan Facebook atau email + kode, lalu
/// (2) bila akunnya baru, mengisi nama dan nomor HP. Akun lama langsung
/// dibawa ke dashboard dengan datanya utuh.
///
/// Anak: nama dan usia; ponselnya ditautkan lewat kode keluarga.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.asChild});

  final bool asChild;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  // Peringatan yang muncul begitu diketik karakter yang tidak boleh, dan
  // hilang lagi saat ketikan berikutnya sudah benar.
  String? _nameWarning;
  String? _phoneWarning;
  String? _ageWarning;

  /// Akun yang profilnya sudah diperiksa, dan hasilnya.
  String? _checkedAccount;
  bool? _accountHasProfile;

  void Function(bool) _warn(
    String message,
    String? Function() current,
    void Function(String?) set,
  ) {
    return (rejected) {
      final next = rejected ? message : null;
      if (next != current()) setState(() => set(next));
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Memeriksa sekali per akun apakah orang tua ini pendaftar baru.
  void _checkProfile(AppState state, String account) {
    if (_checkedAccount == account) return;
    _checkedAccount = account;
    _accountHasProfile = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final has = await state.hasProfile();
      if (!mounted || _checkedAccount != account) return;
      setState(() => _accountHasProfile = has);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    await state.signIn(
      name: _nameController.text.trim(),
      role: widget.asChild ? UserRole.child : UserRole.parent,
      age: int.tryParse(_ageController.text.trim()),
      phone: widget.asChild
          ? null
          : normalizeIndonesianPhone(_phoneController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isChild = widget.asChild;
    final account = isChild ? null : state.accountLabel;
    if (account != null) _checkProfile(state, account);

    final List<Widget> content;
    if (isChild) {
      content = _profileForm(state, isChild: true);
    } else if (account == null) {
      content = [
        _IntroCard(
          icon: Icons.family_restroom_rounded,
          title: tr('Masuk atau daftar'),
          text: tr(
            'Pakai email atau Facebook supaya akun Anda aman. Ganti HP atau '
            'pasang ulang aplikasi? Masuk lagi dengan akun yang sama, dan '
            'semua data tetap ada.',
          ),
        ),
        const SizedBox(height: 20),
        const ParentAccountStep(),
        ..._error(state),
      ];
    } else if (_accountHasProfile != false) {
      // Orang tua lama: dashboard terbuka sendiri begitu profilnya termuat.
      content = [
        _AccountBanner(account: account),
        const SizedBox(height: 28),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 14),
        Text(
          tr('Membuka akun Anda...'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ..._error(state),
      ];
    } else {
      content = [
        _AccountBanner(account: account),
        const SizedBox(height: 14),
        _IntroCard(
          icon: Icons.badge_outlined,
          title: tr('Satu langkah lagi'),
          text: tr(
            'Isi nama dan nomor HP Anda. Kalau SOS anak tidak terkirim karena '
            'internetnya mati, anak bisa menelepon nomor ini.',
          ),
        ),
        const SizedBox(height: 20),
        ..._profileForm(state, isChild: false),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isChild ? tr('Daftarkan Anak') : tr('Masuk sebagai Orang Tua'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        child: SafeArea(
          // Form diletakkan tepat di bawah app bar, bukan di tengah layar:
          // pada ponsel tinggi, pemusatan vertikal meninggalkan ruang kosong
          // besar yang membuat halaman tampak belum selesai dimuat.
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 90, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _error(AppState state) => [
    if (state.lastError != null) ...[
      const SizedBox(height: 14),
      Text(
        state.lastError!,
        style: const TextStyle(color: AuraColors.critical, fontSize: 13),
      ),
    ],
  ];

  /// Nama dan nomor HP (orang tua baru), atau nama dan usia (anak).
  List<Widget> _profileForm(AppState state, {required bool isChild}) {
    return [
      if (isChild) ...[
        _IntroCard(
          icon: Icons.child_care_rounded,
          title: tr('Ponsel ini akan dilindungi AURA'),
          text: tr(
            'Anak akan diminta menyetujui perlindungan ini di langkah '
            'berikutnya. Tanpa persetujuan, pemindaian tidak berjalan.',
          ),
        ),
        const SizedBox(height: 20),
      ],
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              inputFormatters: nameInputFormatters(
                onChecked: _warn(
                  nameOnlyLettersWarning,
                  () => _nameWarning,
                  (w) => _nameWarning = w,
                ),
              ),
              decoration: InputDecoration(
                labelText: isChild ? tr('Nama anak') : tr('Nama Anda'),
                hintText: isChild ? tr('Ayu') : tr('Bunda'),
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _nameWarning,
              ),
              validator: validateName,
            ),
            const SizedBox(height: 14),
            if (!isChild)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: phoneInputFormatters(
                  onChecked: _warn(
                    phoneOnlyDigitsWarning,
                    () => _phoneWarning,
                    (w) => _phoneWarning = w,
                  ),
                ),
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: tr('Nomor HP Anda'),
                  hintText: '0812 3456 7890',
                  helperText: tr('Cadangan bila SOS anak tidak terkirim.'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _phoneWarning,
                ),
                // Wajib: tanpa internet, SOS anak tidak membunyikan alarm,
                // dan nomor ini satu-satunya jalan menghubungi orang tua.
                validator: (value) =>
                    normalizeIndonesianPhone(value ?? '') == null
                    ? tr('Isi nomor HP Indonesia, mis. 0812 3456 7890')
                    : null,
              )
            else
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  GuardedInputFormatter(
                    RegExp(r'[0-9]'),
                    onChecked: _warn(
                      tr('Usia hanya boleh berisi angka.'),
                      () => _ageWarning,
                      (w) => _ageWarning = w,
                    ),
                  ),
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: tr('Usia anak'),
                  hintText: '12',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  errorText: _ageWarning,
                ),
                validator: (value) {
                  final age = int.tryParse(value?.trim() ?? '');
                  if (age == null) return tr('Isi usia dengan angka');
                  if (age < 3 || age > 17) {
                    return tr('AURA ditujukan untuk anak usia 3-17 tahun');
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
      ..._error(state),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: state.busy ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: isChild ? AuraColors.electric : AuraColors.ember,
        ),
        child: state.busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(isChild ? tr('Lanjut') : tr('Masuk')),
      ),
    ];
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AuraColors.cyan),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// "Masuk sebagai ..." dengan pilihan mengganti akun.
class _AccountBanner extends StatelessWidget {
  const _AccountBanner({required this.account});

  final String account;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Row(
      children: [
        const Icon(
          Icons.verified_user_outlined,
          color: AuraColors.safe,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr('Masuk sebagai {account}', {'account': account}),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(onPressed: state.signOut, child: Text(tr('Ganti akun'))),
      ],
    );
  }
}
