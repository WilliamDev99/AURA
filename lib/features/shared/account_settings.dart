import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/app_router.dart';
import '../../core/services/push_service.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/utils/phone_number.dart';
import '../../core/widgets/clay.dart';
import '../../core/widgets/user_avatar.dart';
import '../../state/app_state.dart';

/// Foto profil yang bisa diketuk untuk diganti, dengan lencana kamera kecil.
class EditableAvatar extends StatelessWidget {
  const EditableAvatar({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return Semantics(
      button: true,
      label: tr('Ganti foto profil'),
      // Huruf inisial hanya hiasan; pembaca layar cukup membaca labelnya.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => showAvatarOptions(context),
        child: SizedBox.square(
          dimension: size + 6,
          child: Stack(
            children: [
              UserAvatar(user: user, size: size, radius: size * 0.32),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AuraColors.ember,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 13,
                    color: Colors.white,
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

/// Pilihan foto profil: galeri, kamera, atau hapus.
Future<void> showAvatarOptions(BuildContext context) async {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final hasPhoto = state.user?.avatarPath != null;

  final choice = await showClaySheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTitle(tr('Foto profil')),
            const SizedBox(height: 14),
            ClayButton(
              icon: Icons.photo_library_outlined,
              label: tr('Pilih dari galeri'),
              onPressed: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            const SizedBox(height: 10),
            ClayButton(
              icon: Icons.photo_camera_outlined,
              label: tr('Ambil foto'),
              onPressed: () => Navigator.of(sheetContext).pop('camera'),
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 10),
              ClayButton(
                icon: Icons.delete_outline_rounded,
                label: tr('Hapus foto'),
                foreground: ClayColors.deep(AuraColors.critical),
                onPressed: () => Navigator.of(sheetContext).pop('remove'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (choice == null) return;

  final bool ok;
  if (choice == 'remove') {
    ok = await state.removeAvatar();
  } else {
    final XFile? picked;
    try {
      // Diperkecil sebelum diunggah: foto profil tidak butuh resolusi
      // kamera penuh, dan kuota penyimpanan tetap hemat.
      picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Foto tidak bisa dibuka. Coba lagi.'))),
      );
      return;
    }
    if (picked == null) return;
    ok = await state.uploadAvatar(await picked.readAsBytes());
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? (choice == 'remove'
                  ? tr('Foto profil dihapus.')
                  : tr('Foto profil diperbarui.'))
            : (state.lastError ?? tr('Foto profil belum bisa disimpan.')),
      ),
    ),
  );
}

/// Bagian "Akun": nomor HP, email, dan bahasa.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.card});

  /// Pembungkus kartu: clay untuk orang tua, kaca untuk anak.
  final Widget Function(WidgetBuilder build) card;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final isParent = !state.isChild;

    return card(
      (context) => Column(
        children: [
          if (isParent) ...[
            SettingRow(
              icon: Icons.phone_outlined,
              label: tr('Nomor HP darurat'),
              value: switch (user?.phone) {
                final number? => formatIndonesianPhone(number),
                null => tr('Belum diisi'),
              },
              onTap: () => showPhoneEditor(context),
            ),
            // Orang tua memastikan HP-nya benar-benar berbunyi sebelum ada
            // keadaan darurat: volume alarm, izin notifikasi, Jangan Ganggu.
            SettingRow(
              icon: Icons.alarm_rounded,
              label: tr('Alarm SOS'),
              value: tr('Coba bunyikan'),
              onTap: () => testSosAlarm(context),
            ),
            SettingRow(
              icon: Icons.mail_outline_rounded,
              label: tr('Email'),
              value: state.accountEmail ?? tr('Belum ada'),
              onTap: () => context.push(
                state.needsAccountSecuring
                    ? Routes.secureAccount
                    : Routes.changeEmail,
              ),
            ),
          ],
          if (!isParent)
            SettingRow(
              icon: Icons.link_rounded,
              label: tr('Tautkan ke orang tua'),
              value: user?.familyId != null
                  ? tr('Sudah tersambung')
                  : tr('Belum tersambung'),
              onTap: () => context.push(Routes.childRelink),
            ),
          SettingRow(
            icon: Icons.translate_rounded,
            label: tr('Bahasa'),
            value: Lang.instance.current.nativeName,
            onTap: () => showLanguagePicker(context),
          ),
        ],
      ),
    );
  }
}

/// Membunyikan alarm SOS sungguhan di HP ini, supaya orang tua tahu bunyinya
/// dan yakin HP-nya akan berbunyi. Selama berbunyi, kartu "Matikan alarm"
/// muncul di layar (lihat SosAlarmBanner); yang perlu dikabarkan di sini
/// hanya bila alarm tidak bisa berbunyi sama sekali.
Future<void> testSosAlarm(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await PushService.instance.testSosAlarm()) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        tr(
          'Notifikasi AURA dimatikan, jadi alarm SOS tidak bisa berbunyi. '
          'Nyalakan di Pengaturan Android.',
        ),
      ),
    ),
  );
}

/// Satu baris pengaturan yang bisa diketuk.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Memilih bahasa tampilan.
Future<void> showLanguagePicker(BuildContext context) {
  return showClaySheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTitle(tr('Pilih bahasa')),
            const SizedBox(height: 6),
            Text(
              tr(
                'Bahasa tampilan AURA. Deteksi ancaman tetap membaca pesan '
                'berbahasa Indonesia.',
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: ClayColors.inkSoft,
              ),
            ),
            const SizedBox(height: 14),
            for (final language in AppLanguage.values) ...[
              ClayButton(
                label: language.nativeName,
                icon: language == Lang.instance.current
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: language == Lang.instance.current
                    ? ClayColors.lavender
                    : Colors.white,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Lang.instance.set(language);
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Mengganti nomor HP darurat orang tua.
Future<void> showPhoneEditor(BuildContext context) {
  return showClaySheet<void>(
    context: context,
    builder: (_) => const _PhoneEditor(),
  );
}

class _PhoneEditor extends StatefulWidget {
  const _PhoneEditor();

  @override
  State<_PhoneEditor> createState() => _PhoneEditorState();
}

class _PhoneEditorState extends State<_PhoneEditor> {
  late final _controller = TextEditingController(
    text: switch (context.read<AppState>().user?.phone) {
      final phone? => formatIndonesianPhone(phone),
      null => '',
    },
  );
  String? _warning;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = normalizeIndonesianPhone(_controller.text);
    if (phone == null) {
      setState(
        () => _error = tr('Isi nomor HP Indonesia, mis. 0812 3456 7890'),
      );
      return;
    }
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await state.updatePhone(phone);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = state.lastError);
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Nomor HP darurat diperbarui.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppState>().busy;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTitle(tr('Ubah nomor HP')),
            const SizedBox(height: 6),
            Text(
              tr(
                'Kalau SOS anak tidak terkirim karena internetnya mati, anak '
                'bisa menelepon nomor ini.',
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: ClayColors.inkSoft,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneInputFormatters(
                onChecked: (rejected) {
                  final next = rejected ? tr(phoneOnlyDigitsWarning) : null;
                  if (next != _warning) setState(() => _warning = next);
                },
              ),
              style: const TextStyle(color: ClayColors.ink, fontSize: 16),
              decoration: clayInputDecoration(
                label: tr('Nomor HP'),
                hint: '0812 3456 7890',
                icon: Icons.phone_outlined,
                error: _warning ?? _error,
              ),
              onSubmitted: (_) => busy ? null : _save(),
            ),
            const SizedBox(height: 16),
            ClayButton(
              label: tr('Simpan'),
              color: AuraColors.ember,
              foreground: Colors.white,
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom isian putih untuk lembar clay yang terang. Tema bawaan aplikasi
/// berlatar gelap; tanpa ini, tulisan gelap jatuh di kolom gelap.
InputDecoration clayInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
  String? error,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: 1.4),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    errorMaxLines: 3,
    filled: true,
    fillColor: Colors.white,
    prefixIcon: icon == null ? null : Icon(icon, color: ClayColors.inkSoft),
    labelStyle: const TextStyle(color: ClayColors.inkSoft),
    floatingLabelStyle: const TextStyle(color: ClayColors.ink),
    hintStyle: const TextStyle(color: ClayColors.inkMuted),
    errorStyle: TextStyle(color: ClayColors.deep(AuraColors.critical)),
    enabledBorder: border(ClayColors.inkMuted.withValues(alpha: 0.35)),
    focusedBorder: border(const Color(0xFF0277BD)),
    errorBorder: border(ClayColors.deep(AuraColors.critical)),
    focusedErrorBorder: border(ClayColors.deep(AuraColors.critical)),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: ClayColors.ink,
      ),
    );
  }
}
