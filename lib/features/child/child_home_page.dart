import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/aura_colors.dart';
import '../../domain/services/location_service.dart';
import '../../state/app_state.dart';
import 'help_sheet.dart';
import 'panic_orb.dart';
import 'widgets/aura_robot.dart';
import 'widgets/kawung_backdrop.dart';
import '../../core/l10n/l10n.dart';

/// Beranda anak: satu tombol besar, satu teman bicara, tanpa gangguan lain.
///
/// Tata letaknya mengikuti desain AURA yang dirancang pada kanvas 780 × 1688.
/// Semua ukuran diturunkan dari skala [_k] supaya proporsinya tetap sama di
/// ponsel kecil maupun besar.
class ChildHomePage extends StatefulWidget {
  const ChildHomePage({super.key});

  @override
  State<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends State<ChildHomePage> {
  /// Batas menunggu lokasi setelah orb diketuk. SOS terkirim begitu orb
  /// diketuk, tanpa hitung mundur; lokasi yang belum didapat dalam waktu ini
  /// tidak boleh menahan peringatan.
  static const _locationWait = Duration(seconds: 3);

  bool _sending = false;

  /// Benar sejak orb diketuk sampai lembar konfirmasinya ditutup. Lebih
  /// panjang dari [_sending]: di antara SOS selesai terkirim dan lembar
  /// konfirmasi menutupi orb ada sela sesaat, dan ketukan beruntun anak yang
  /// panik dulu sempat mengirim SOS kedua lewat sela itu.
  bool _busy = false;

  /// Satu ketukan langsung mengirim SOS. Tidak ada hitung mundur: anak yang
  /// sedang dalam bahaya tidak boleh dibuat menunggu.
  Future<void> _send() async {
    if (_busy) return;
    _busy = true;
    try {
      await _sendAndConfirm();
    } finally {
      _busy = false;
    }
  }

  Future<void> _sendAndConfirm() async {
    // Diambil sekarang, sebelum menunggu apa pun: kalau halaman sempat
    // tertutup selagi menunggu lokasi, SOS-nya tetap berangkat.
    final state = context.read<AppState>();

    setState(() => _sending = true);
    HapticFeedback.heavyImpact();

    // Titik yang baru diukur dalam 30 detik terakhir langsung dipakai (lihat
    // MainActivity.currentLocation), jadi biasanya ini tidak terasa.
    final location = await state.locationService
        .current(timeout: const Duration(seconds: 6))
        .timeout(
          _locationWait,
          onTimeout: () =>
              const LocationResult.failed(LocationFailure.timedOut),
        );

    // Peringatan inilah yang membunyikan alarm di HP orang tua.
    final alertSent = await _sendAlert(state, location, state.newSosId());

    if (!mounted) return;
    setState(() => _sending = false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Anak yang panik mengetuk berulang kali. Ketukan berikutnya tidak boleh
      // menutup lembar ini tanpa terbaca, lalu mengirim SOS lagi lewat orb di
      // belakangnya: lembar ini hanya ditutup lewat tombolnya sendiri.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PanicSentSheet(
        alertSent: alertSent,
        location: location,
        // Ulangan memakai ID baru: kiriman pertama bisa saja sudah sampai
        // dan tercatat, dan ID yang sama akan ditolak server.
        onRetry: () => _sendAlert(state, location, state.newSosId()),
        onCallParent: state.emergencyNumber == null ? null : state.dialParent,
      ),
    );
  }

  /// Mengirim peringatan SOS lewat internet; true bila sampai ke server.
  ///
  /// Tanpa internet, pengiriman bisa menggantung lama sebelum gagal. Batas
  /// waktunya menjaga layar tidak macet di "Mengirim SOS..." selamanya, dan
  /// galatnya ditangkap supaya anak diberi tahu terus terang.
  static Future<bool> _sendAlert(
    AppState state,
    LocationResult? location,
    String sosId,
  ) => state
      .triggerPanic(location: location, id: sosId)
      .timeout(const Duration(seconds: 10))
      .then(
        (alert) => alert != null,
        onError: (Object error) {
          debugPrint('AURA: peringatan SOS gagal terkirim ($error).');
          return false;
        },
      );

  @override
  Widget build(BuildContext context) {
    final protected = context.select<AppState, bool>(
      (state) => state.user?.protectionActive ?? false,
    );

    // Huruf boleh membesar mengikuti pengaturan aksesibilitas, tetapi dibatasi
    // supaya teks tidak menabrak orb pada tata letak berbasis koordinat ini.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: _page(context, protected),
    );
  }

  Widget _page(BuildContext context, bool protected) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: KawungBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => _layout(context, box.biggest, protected),
          ),
        ),
      ),
    );
  }

  /// Menempatkan setiap elemen pada koordinat desain.
  ///
  /// Kanvas desain 780 × 1688 dengan bilah status setinggi 80, jadi area di
  /// bawah bilah status adalah 780 × 1608. Posisi direntangkan mengikuti layar
  /// ([sx], [sy]); ukuran elemen memakai skala terkecil ([k]) supaya tidak
  /// pernah terpotong di ponsel yang lebih pendek.
  Widget _layout(BuildContext context, Size box, bool protected) {
    final sx = box.width / 780;
    final sy = box.height / 1608;
    final k = math.min(sx, sy);

    final orbSize = 380 * k;
    final orbBox = orbSize * PanicOrb.extent;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Orb di belakang robot, supaya halo tidak menutupi kakinya.
        Positioned(
          left: 390 * sx - orbBox / 2,
          top: 910 * sy - orbBox / 2,
          child: PanicOrb(size: orbSize, onTap: _send, sending: _sending),
        ),
        Positioned(
          left: 55 * sx,
          top: 28 * sy,
          child: Text(
            tr('Meet The'),
            // Logo kata: diperlakukan seperti gambar, tidak ikut membesar.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 86 * k,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1,
              letterSpacing: -1.2 * k,
            ),
          ),
        ),
        Positioned(
          left: 50 * sx,
          top: 122 * sy,
          child: Text(
            tr('AURA!'),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 146 * k,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
              letterSpacing: -3 * k,
            ),
          ),
        ),
        Positioned(
          left: 53 * sx,
          top: 325 * sy,
          child: _GlassButton(
            k: k,
            label: tr('Butuh bantuan?'),
            onTap: () => context.push(Routes.childChat),
          ),
        ),
        // Setinggi robot di desain (y 225-620); maskot ini sedikit lebih
        // gempal sehingga lebarnya 224, bukan 205.
        Positioned(
          left: 510 * sx,
          top: 225 * sy,
          child: RepaintBoundary(
            child: AuraRobot(width: 395 * AuraRobot.aspectRatio * k),
          ),
        ),
        Positioned(
          top: 6 * sy,
          right: 24 * sx,
          child: Row(
            children: [
              _ProtectionChip(active: protected, k: k),
              SizedBox(width: 6 * k),
              _HeadsetButton(k: k, onTap: () => showHelpSheet(context)),
            ],
          ),
        ),
        Positioned(
          left: 390 * sx - 190 * k,
          top: 1243 * sy,
          child: _OrbLabel(k: k, sending: _sending),
        ),
      ],
    );
  }
}

/// Tanda bahwa perlindungan sedang berjalan.
///
/// Tidak ada di gambar desain, tetapi tercantum di rancangan fitur ("indikator
/// proteksi secara real-time") dan dijanjikan di layar persetujuan anak:
/// AURA tidak pernah bekerja diam-diam.
class _ProtectionChip extends StatelessWidget {
  const _ProtectionChip({required this.active, required this.k});

  final bool active;
  final double k;

  @override
  Widget build(BuildContext context) {
    final color = active ? AuraColors.safe : AuraColors.medium;
    return Semantics(
      label: active ? tr('Perlindungan aktif') : tr('Perlindungan dijeda'),
      excludeSemantics: true,
      child: Container(
        height: 52 * k,
        padding: EdgeInsets.symmetric(horizontal: 18 * k),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, size: 26 * k, color: color),
            SizedBox(width: 8 * k),
            Text(
              active ? tr('Aktif') : tr('Dijeda'),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 23 * k,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadsetButton extends StatelessWidget {
  const _HeadsetButton({required this.k, required this.onTap});

  final double k;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('Pusat bantuan'),
      child: IconButton(
        onPressed: onTap,
        iconSize: 56 * k,
        color: Colors.white,
        icon: const Icon(Icons.headset_mic_outlined),
      ),
    );
  }
}

/// Tombol kaca "Butuh bantuan?" di bawah judul.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.k,
    required this.label,
    required this.onTap,
  });

  final double k;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24 * k);
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        // Lebar mengikuti teks, seperti pada desain. (Container dengan
        // `alignment` akan melebar memenuhi ruang yang tersedia.)
        child: Container(
          constraints: BoxConstraints(minHeight: 90 * k),
          padding: EdgeInsets.symmetric(horizontal: 38 * k, vertical: 12 * k),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 33 * k,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu "Panic Orb" di bawah tombol.
class _OrbLabel extends StatelessWidget {
  const _OrbLabel({required this.k, required this.sending});

  final double k;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = sending
        ? (tr('Mengirim SOS...'), tr('Orang tuamu segera tahu'))
        : (tr('Panic Orb'), tr('Tekan sekali untuk SOS'));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 380 * k,
      constraints: BoxConstraints(minHeight: 128 * k),
      padding: EdgeInsets.symmetric(vertical: 14 * k, horizontal: 16 * k),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: sending
            ? const Color(0xFF3A0B2E).withValues(alpha: 0.92)
            : const Color(0xFF1A1A5C).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(34 * k),
        border: Border.all(
          color: sending
              ? const Color(0xFFFF6B8A)
              : const Color(0xFF6E6BD8).withValues(alpha: 0.8),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 46 * k,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 23 * k,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanicSentSheet extends StatefulWidget {
  const _PanicSentSheet({
    required this.alertSent,
    required this.onRetry,
    this.onCallParent,
    this.location,
  });

  /// Apakah peringatan berhasil sampai ke server.
  final bool alertSent;
  final LocationResult? location;

  /// Mengirim ulang peringatan yang sama; true bila kali ini sampai.
  final Future<bool> Function() onRetry;

  /// Membuka aplikasi Telepon dengan nomor orang tua. Null bila orang tua
  /// belum mengisi nomor HP.
  final Future<bool> Function()? onCallParent;

  @override
  State<_PanicSentSheet> createState() => _PanicSentSheetState();
}

class _PanicSentSheetState extends State<_PanicSentSheet> {
  late bool _sent = widget.alertSent;
  bool _retrying = false;

  /// Hasil tombol "Telepon orang tua"; null selama belum ditekan.
  bool? _dialerOpened;

  LocationResult? get location => widget.location;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final sent = await widget.onRetry();
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _sent = sent;
    });
  }

  Future<void> _callParent() async {
    final open = widget.onCallParent;
    if (open == null) return;
    final opened = await open();
    if (mounted) setState(() => _dialerOpened = opened);
  }

  /// Apa yang dikatakan ke anak soal lokasinya.
  ///
  /// Tidak pernah mengaku lokasi terkirim kalau sebenarnya tidak. Anak yang
  /// mengira orang tuanya tahu posisinya bisa memilih diam dan menunggu di
  /// tempat berbahaya, padahal seharusnya ia mencari tempat ramai.
  (IconData, Color, String) get _locationNote {
    final result = location;
    if (!_sent) {
      // Lokasi menumpang pada peringatan; kalau peringatan tidak sampai,
      // lokasinya pun tidak.
      return (
        Icons.location_off_rounded,
        AuraColors.medium,
        tr(
          'Lokasimu belum terkirim karena internet sedang tidak tersambung. '
          'Kalau kamu menelepon orang tuamu, sebutkan kamu di mana.',
        ),
      );
    }
    if (result != null && result.hasPosition) {
      return result.isLastKnown
          ? (
              Icons.location_searching_rounded,
              AuraColors.medium,
              tr(
                'Lokasi terakhirmu ikut terkirim. Kalau kamu sudah pindah, beri '
                'tahu orang tuamu kamu di mana.',
              ),
            )
          : (
              Icons.location_on_rounded,
              AuraColors.safe,
              tr('Lokasimu ikut terkirim.'),
            );
    }

    final reason = switch (result?.failure) {
      LocationFailure.serviceDisabled => tr(
        'Lokasimu belum terkirim karena GPS di ponsel sedang mati.',
      ),
      LocationFailure.permissionDenied ||
      LocationFailure.permissionDeniedForever => tr(
        'Lokasimu belum terkirim karena izin lokasi belum dinyalakan.',
      ),
      _ => tr('Lokasimu belum terkirim karena sinyal GPS belum didapat.'),
    };
    return (
      Icons.location_off_rounded,
      AuraColors.medium,
      tr('{reason} Kalau bisa, kabari orang tuamu kamu di mana.', {
        'reason': reason,
      }),
    );
  }

  /// Apa yang dikatakan ke anak soal alarm di HP orang tuanya.
  ///
  /// "Akan berbunyi", bukan "sedang berbunyi": yang pasti hanya peringatannya
  /// sudah sampai ke server.
  (IconData, Color, String) get _alarmNote => _sent
      ? (
          Icons.notifications_active_rounded,
          AuraColors.safe,
          tr(
            'HP orang tuamu akan berbunyi alarm dan bergetar sampai mereka '
            'mematikannya.',
          ),
        )
      : (
          Icons.notifications_off_rounded,
          AuraColors.critical,
          tr(
            'Alarm di HP orang tuamu belum berbunyi, karena peringatannya '
            'belum terkirim.',
          ),
        );

  /// Apa yang dikatakan ke anak setelah menekan "Telepon orang tua".
  (IconData, Color, String)? get _callNote => switch (_dialerOpened) {
    null => null,
    true => (
      Icons.phone_forwarded_rounded,
      AuraColors.medium,
      tr(
        'Nomor orang tuamu sudah disiapkan di aplikasi Telepon. Tekan '
        'tombol panggil hijau kalau belum.',
      ),
    ),
    false => (
      Icons.phone_disabled_rounded,
      AuraColors.critical,
      tr(
        'Ponsel ini tidak bisa menelepon. Kalau bisa, minta tolong orang '
        'dewasa di dekatmu.',
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final callNote = _callNote;
    final canCall = widget.onCallParent != null;
    final headline = _sent
        ? tr('Pesan daruratmu terkirim')
        : tr('Peringatan belum terkirim');
    final body = _sent
        ? tr('Tetap di tempat yang ramai dan terang kalau bisa.')
        : canCall
        ? tr(
            'Internet sedang tidak tersambung. Coba kirim lagi, atau telepon '
            'orang tuamu.',
          )
        : tr(
            'Internet sedang tidak tersambung. Coba kirim lagi, atau minta '
            'tolong orang dewasa di dekatmu.',
          );
    final accent = _sent ? AuraColors.safe : AuraColors.medium;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.18),
            ),
            child: Icon(
              _sent ? Icons.check_rounded : Icons.priority_high_rounded,
              color: accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.5,
              color: AuraColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _Note(note: _alarmNote),
          const SizedBox(height: 10),
          _Note(note: _locationNote),
          if (callNote != null) ...[
            const SizedBox(height: 10),
            _Note(note: callNote),
          ],
          const SizedBox(height: 22),
          if (!_sent) ...[
            FilledButton.icon(
              onPressed: _retrying ? null : _retry,
              icon: _retrying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _retrying ? tr('Mengirim SOS...') : tr('Coba kirim lagi'),
              ),
            ),
            const SizedBox(height: 10),
            if (canCall) ...[
              // Telepon seluler tetap jalan tanpa internet.
              OutlinedButton.icon(
                onPressed: _callParent,
                icon: const Icon(Icons.call_rounded),
                label: Text(tr('Telepon orang tua')),
              ),
              const SizedBox(height: 10),
            ],
          ],
          _sent
              ? FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('Oke')),
                )
              : TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('Tutup')),
                ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.note});

  final (IconData, Color, String) note;

  @override
  Widget build(BuildContext context) {
    final (icon, colour, message) = note;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
