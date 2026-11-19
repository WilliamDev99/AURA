import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/widgets/clay.dart';
import '../../domain/models/app_user.dart';
import '../../state/app_state.dart';

const _poppins = 'Poppins';

/// "Hapus AURA" untuk orang tua: perlindungan hapus di HP anak, dan PIN bila
/// anak sedang meminta izin menghapus AURA.
///
/// PIN yang sama juga dikirim sebagai notifikasi. Orang tua memberikannya ke
/// anak hanya bila mengizinkan; "Batalkan PIN" berarti tidak mengizinkan.
/// Tampil di lembar rincian anak, dan di atas Beranda selama PIN-nya aktif.
class UninstallCard extends StatefulWidget {
  const UninstallCard({super.key, required this.child});

  final AppUser child;

  @override
  State<UninstallCard> createState() => _UninstallCardState();
}

class _UninstallCardState extends State<UninstallCard> {
  bool _saving = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final state = context.read<AppState>();
    await state.cancelUninstallPin(widget.child.id);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = state.lastError;
    });
  }

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}.'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final name = child.name;
    final pin = context.watch<AppState>().uninstallPinFor(child.id);
    final protected = child.uninstallProtected;

    final String body;
    String? warning;
    if (pin != null) {
      body = tr(
        '{childName} minta izin menghapus AURA. Kalau Anda mengizinkan, '
        'berikan PIN ini ke {childName}:',
        {'childName': name},
      );
    } else {
      switch (protected) {
        case true:
          body = tr(
            'Terlindung: {childName} tidak bisa menghapus AURA tanpa PIN '
            'dari Anda.',
            {'childName': name},
          );
        case false:
          body = tr('Perlindungan hapus mati.');
          warning = tr(
            '{childName} bisa menghapus AURA tanpa izin. Di HP '
            '{childName}: AURA > Pengaturan > Perlindungan hapus > '
            'Aktifkan.',
            {'childName': name},
          );
        case null:
          body = tr(
            'Menunggu HP {childName} membuka AURA untuk memeriksa '
            'perlindungannya.',
            {'childName': name},
          );
      }
    }

    final unprotected = protected == false && pin == null;
    return ClayCard(
      color: pin != null ? ClayColors.peach : Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                unprotected ? Icons.gpp_maybe_rounded : Icons.shield_rounded,
                color: unprotected ? AuraColors.high : ClayColors.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Hapus AURA'),
                      style: const TextStyle(
                        fontFamily: _poppins,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ClayColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        fontFamily: _poppins,
                        fontSize: 12.5,
                        height: 1.4,
                        color: ClayColors.inkSoft,
                      ),
                    ),
                    if (warning != null || _error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error != null
                            ? tr('Belum tersimpan. {error}', {'error': _error!})
                            : warning!,
                        style: const TextStyle(
                          fontFamily: _poppins,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: AuraColors.high,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (pin != null) ...[
            const SizedBox(height: 10),
            Center(
              child: SelectableText(
                pin.spaced,
                style: const TextStyle(
                  fontFamily: _poppins,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: ClayColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Berlaku sampai pukul {time}, sekali pakai.', {
                'time': _clock(pin.expiresAt),
              }),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _poppins,
                fontSize: 12,
                color: ClayColors.inkMuted,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: AuraColors.high),
                onPressed: _saving ? null : _cancel,
                child: Text(tr('Batalkan PIN')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
