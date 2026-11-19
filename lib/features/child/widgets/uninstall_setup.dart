import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/widgets/aura_widgets.dart';
import '../../../domain/models/uninstall_permission.dart';
import '../../../state/app_state.dart';

/// Pengaturan anak: perlindungan hapus, dan menghapus AURA dengan PIN dari
/// orang tua.
///
/// Terus terang kepada anak: AURA hanya bisa dihapus dengan PIN dari orang
/// tuanya. PIN-nya dikirim ke HP orang tua, tidak pernah ke HP ini.
class UninstallSetup extends StatefulWidget {
  const UninstallSetup({super.key});

  @override
  State<UninstallSetup> createState() => _UninstallSetupState();
}

class _UninstallSetupState extends State<UninstallSetup> {
  final _pin = TextEditingController();
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _say(String? text, {bool error = false}) => setState(() {
    _message = text;
    _messageIsError = error;
  });

  Future<void> _request(AppState state) async {
    await state.requestUninstallPin();
    if (!mounted) return;
    final error = state.lastError;
    _pin.clear();
    _say(
      error ??
          tr(
            'PIN dikirim ke HP orang tuamu. Kalau orang tuamu mengizinkan, '
            'minta PIN-nya lalu masukkan di sini.',
          ),
      error: error != null,
    );
  }

  Future<void> _enter(AppState state) async {
    final check = await state.enterUninstallPin(_pin.text);
    if (!mounted) return;
    switch (check) {
      case PinCheck.ok:
        _pin.clear();
        _say(tr('PIN benar. Ikuti dialog untuk menghapus AURA.'));
      case PinCheck.wrong:
        _say(tr('PIN salah. Coba lagi.'), error: true);
      case PinCheck.locked:
        _say(tr('Terlalu sering salah. Minta PIN baru.'), error: true);
      case PinCheck.expired:
        _say(tr('PIN sudah kedaluwarsa. Minta PIN baru.'), error: true);
      case PinCheck.none:
        _say(tr('Belum ada PIN yang berlaku. Tekan Minta PIN.'), error: true);
      case null:
        _say(state.lastError, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    if (user == null) return const SizedBox.shrink();
    final protected = user.uninstallProtected == true;
    final requested = user.uninstallRequestedAt;
    // Kolom PIN tampil selama PIN terakhir mungkin masih berlaku.
    final waiting =
        requested != null &&
        DateTime.now().difference(requested) < UninstallPin.lifetime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoRow(
          label: tr('Perlindungan hapus'),
          value: protected
              ? tr('Aktif')
              : tr('Belum aktif. AURA bisa terhapus tanpa izin orang tuamu.'),
          valueColor: protected ? AuraColors.safe : AuraColors.medium,
        ),
        if (!protected)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: state.protectFromUninstall,
              icon: const Icon(Icons.shield_rounded, size: 18),
              label: Text(tr('Aktifkan')),
            ),
          ),
        InfoRow(
          label: tr('Hapus AURA'),
          value: tr('Butuh PIN dari orang tuamu.'),
        ),
        if (waiting) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: tr('PIN dari orang tua'),
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: _messageIsError ? AuraColors.high : AuraColors.safe,
              ),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              onPressed: state.busy ? null : () => _request(state),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(waiting ? tr('Minta PIN baru') : tr('Minta PIN')),
            ),
            if (waiting)
              TextButton.icon(
                onPressed: state.busy || _pin.text.length != 6
                    ? null
                    : () => _enter(state),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(tr('Hapus AURA')),
              ),
          ],
        ),
      ],
    );
  }
}
