import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/aura_colors.dart';
import '../../domain/services/emergency_call_service.dart';
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

class _ChildHomePageState extends State<ChildHomePage>
    with SingleTickerProviderStateMixin {
  /// Jeda sebelum SOS terkirim. Cukup untuk membatalkan sentuhan tak sengaja,
  /// cukup singkat untuk anak yang sedang panik.
  static const _countdownSeconds = 3;

  /// Hanya tampilan: angka dan busur hitung mundur.
  ///
  /// Pengiriman SOS *tidak* menunggu animasi ini selesai. Animasi bergantung
  /// pada frame layar; kalau layar tersendat atau membeku karena sebab apa
  /// pun, animasi berhenti — dan dulu SOS-nya ikut tidak pernah berangkat.
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _countdownSeconds),
  );

  /// Yang benar-benar mengirim SOS. Timer berjalan di isolate Dart, tidak
  /// bergantung pada frame, sehingga tetap berangkat tepat waktu.
  Timer? _sosTimer;

  /// Lokasi mulai diambil begitu anak mengetuk orb, berjalan bersamaan dengan
  /// hitung mundur. Biasanya titiknya sudah siap sebelum hitungan habis, jadi
  /// tidak ada jeda tambahan sama sekali bagi anak yang sedang panik.
  Future<LocationResult>? _locationRequest;

  int? _lastTick;
  bool _sending = false;

  bool get _counting => _sosTimer != null;

  int get _secondsLeft =>
      (_countdownSeconds * (1 - _countdown.value)).ceil().clamp(1, 3);

  @override
  void initState() {
    super.initState();
    _countdown.addListener(_onTick);
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  /// Hanya getaran per detik yang dikerjakan di sini.
  ///
  /// Dulu memanggil setState tiap frame, sehingga seluruh halaman — latar
  /// batik, maskot, dan orb — digambar ulang 60 kali per detik. Di ponsel
  /// kelas bawah, yang justru paling mungkin dipakai anak, hitung mundurnya
  /// macet. Sekarang hanya orb dan kartunya yang ikut berubah.
  void _onTick() {
    final seconds = _secondsLeft;
    if (seconds != _lastTick) {
      _lastTick = seconds;
      HapticFeedback.selectionClick();
    }
  }

  void _onOrbTap() {
    if (_sending) return;
    // Ketukan kedua saat menghitung mundur berarti anak benar-benar butuh
    // bantuan sekarang: kirim langsung tanpa menunggu.
    if (_counting) {
      _send();
      return;
    }
    HapticFeedback.heavyImpact();
    _lastTick = null;
    _locationRequest = context.read<AppState>().locationService.current(
      timeout: const Duration(seconds: 6),
    );
    _sosTimer = Timer(const Duration(seconds: _countdownSeconds), _send);
    _countdown.forward(from: 0);
    setState(() {});
  }

  void _cancel() {
    _sosTimer?.cancel();
    _sosTimer = null;
    _countdown
      ..stop()
      ..reset();
    // Hasil yang sedang diambil dibuang supaya tidak terpakai di SOS lain.
    _locationRequest = null;
    HapticFeedback.lightImpact();
    setState(() {});
  }

  Future<void> _send() async {
    if (_sending) return;
    _sosTimer?.cancel();
    _sosTimer = null;

    // Diambil sekarang, sebelum menunggu apa pun. Dulu diambil setelah
    // menunggu lokasi dengan `if (!mounted) return` di depannya — kalau
    // halaman sempat tertutup, SOS-nya batal tanpa ada yang tahu.
    final state = context.read<AppState>();

    _countdown
      ..stop()
      ..reset();
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();

    // Lokasi sudah diambil sejak hitung mundur dimulai. Kalau belum selesai,
    // ditunggu sebentar saja: peringatan harus tetap berangkat.
    final location = await _locationRequest?.timeout(
      const Duration(seconds: 2),
      onTimeout: () => const LocationResult.failed(LocationFailure.timedOut),
    );
    _locationRequest = null;

    // Peringatan dimulai tanpa ditunggu, lalu telepon langsung dilakukan.
    // Tanpa internet, pengiriman peringatan bisa menggantung lama sebelum
    // gagal; telepon lewat jaringan seluler tidak boleh ikut menunggu.
    // Penangkap galat dipasang seketika: kalau peringatan gagal selagi
    // telepon masih berjalan, galatnya tidak boleh lolos tanpa penangan.
    // Dulu galat ini tidak ditangkap sama sekali: tanpa internet layar macet
    // di "Mengirim SOS..." selamanya.
    final alertSentFuture = state
        .triggerPanic(location: location)
        .timeout(const Duration(seconds: 10))
        .then(
          (alert) => alert != null,
          onError: (Object error) {
            debugPrint('AURA: peringatan SOS gagal terkirim ($error).');
            return false;
          },
        );
    final callFuture = state.callParent();
    // Diperiksa bersamaan, bukan setelah telepon selesai: telepon yang macet
    // sampai batas waktunya tidak boleh menunda lembar konfirmasi lebih lama
    // lagi. Perintah telepon tetap berangkat lebih dulu.
    final whatsAppFuture = state.canCallParentViaWhatsApp();
    final call = await callFuture;
    final alertSent = await alertSentFuture;
    final canUseWhatsApp = await whatsAppFuture;

    if (!mounted) return;
    setState(() => _sending = false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PanicSentSheet(
        alertSent: alertSent,
        call: call,
        location: location,
        onCallAgain: state.emergencyNumber == null
            ? null
            : () => state.callParent(),
        onCallViaWhatsApp: canUseWhatsApp ? state.callParentViaWhatsApp : null,
      ),
    );
  }

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
          child: AnimatedBuilder(
            animation: _countdown,
            builder: (context, _) => PanicOrb(
              size: orbSize,
              onTap: _onOrbTap,
              countdown: _counting ? _secondsLeft : null,
              progress: _countdown.value,
              sending: _sending,
            ),
          ),
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
          child: AnimatedBuilder(
            animation: _countdown,
            builder: (context, _) => _OrbLabel(
              k: k,
              counting: _counting,
              sending: _sending,
              secondsLeft: _secondsLeft,
              onCancel: _cancel,
            ),
          ),
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

/// Kartu "Panic Orb" di bawah tombol. Saat menghitung mundur, kartu ini
/// berubah menjadi tombol batal yang besar dan mudah dikenai.
class _OrbLabel extends StatelessWidget {
  const _OrbLabel({
    required this.k,
    required this.counting,
    required this.sending,
    required this.secondsLeft,
    required this.onCancel,
  });

  final double k;
  final bool counting;
  final bool sending;
  final int secondsLeft;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = sending
        ? (tr('Mengirim SOS...'), tr('Orang tuamu segera tahu'))
        : counting
        ? (
            tr('Batalkan'),
            tr('SOS terkirim dalam {secondsLeft} detik', {
              'secondsLeft': secondsLeft,
            }),
          )
        : (tr('Panic Orb'), tr('Tekan sekali untuk SOS'));

    final radius = BorderRadius.circular(34 * k);

    return Semantics(
      button: counting,
      label: counting ? tr('Batalkan SOS') : null,
      child: GestureDetector(
        onTap: counting ? onCancel : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 380 * k,
          constraints: BoxConstraints(minHeight: 128 * k),
          padding: EdgeInsets.symmetric(vertical: 14 * k, horizontal: 16 * k),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: counting
                ? const Color(0xFF3A0B2E).withValues(alpha: 0.92)
                : const Color(0xFF1A1A5C).withValues(alpha: 0.86),
            borderRadius: radius,
            border: Border.all(
              color: counting
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
        ),
      ),
    );
  }
}

class _PanicSentSheet extends StatefulWidget {
  const _PanicSentSheet({
    required this.alertSent,
    required this.call,
    required this.onCallAgain,
    this.onCallViaWhatsApp,
    this.location,
  });

  /// Apakah peringatan berhasil sampai ke server.
  final bool alertSent;
  final CallOutcome call;
  final LocationResult? location;

  /// Null bila tidak ada nomor yang bisa ditelepon.
  final VoidCallback? onCallAgain;

  /// Null bila WhatsApp tidak terpasang atau tidak ada nomor.
  final Future<WhatsAppCallOutcome> Function()? onCallViaWhatsApp;

  @override
  State<_PanicSentSheet> createState() => _PanicSentSheetState();
}

class _PanicSentSheetState extends State<_PanicSentSheet> {
  /// Hasil tombol "Telepon lewat WhatsApp"; null selama belum ditekan.
  WhatsAppCallOutcome? _whatsApp;
  bool _callingWhatsApp = false;

  bool get alertSent => widget.alertSent;
  CallOutcome get call => widget.call;
  LocationResult? get location => widget.location;

  Future<void> _callViaWhatsApp() async {
    final start = widget.onCallViaWhatsApp;
    if (start == null || _callingWhatsApp) return;
    setState(() => _callingWhatsApp = true);
    final outcome = await start();
    if (!mounted) return;
    setState(() {
      _callingWhatsApp = false;
      _whatsApp = outcome;
    });
  }

  /// Apa yang dikatakan ke anak soal lokasinya.
  ///
  /// Tidak pernah mengaku lokasi terkirim kalau sebenarnya tidak. Anak yang
  /// mengira orang tuanya tahu posisinya bisa memilih diam dan menunggu di
  /// tempat berbahaya, padahal seharusnya ia mencari tempat ramai.
  (IconData, Color, String) get _locationNote {
    final result = location;
    if (!alertSent) {
      // Lokasi menumpang pada peringatan; kalau peringatan tidak sampai,
      // lokasinya pun tidak.
      return (
        Icons.location_off_rounded,
        AuraColors.medium,
        tr(
          'Lokasimu belum terkirim karena internet sedang tidak '
          'tersambung. Sebutkan kamu di mana saat orang tuamu mengangkat '
          'telepon.',
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

  /// Apa yang dikatakan ke anak soal telepon ke orang tuanya.
  (IconData, Color, String) get _callNote => switch (call) {
    CallOutcome.called => (
      Icons.call_rounded,
      AuraColors.safe,
      tr('Kami sudah menelepon orang tuamu.'),
    ),
    CallOutcome.dialerOpened => (
      Icons.phone_forwarded_rounded,
      AuraColors.medium,
      tr(
        'Nomor orang tuamu sudah disiapkan di aplikasi Telepon. Tekan '
        'tombol panggil hijau kalau belum.',
      ),
    ),
    CallOutcome.noNumber => (
      Icons.phone_disabled_rounded,
      AuraColors.medium,
      tr(
        'Nomor HP orang tuamu belum diisi, jadi kami belum bisa '
        'menelepon. Minta orang tuamu mengisinya di aplikasi AURA mereka.',
      ),
    ),
    CallOutcome.failed when widget.onCallViaWhatsApp != null => (
      Icons.phone_disabled_rounded,
      AuraColors.medium,
      tr(
        'Ponsel ini tidak bisa menelepon biasa. Coba telepon orang tuamu '
        'lewat WhatsApp di bawah.',
      ),
    ),
    CallOutcome.failed => (
      Icons.phone_disabled_rounded,
      AuraColors.critical,
      tr(
        'Ponsel ini tidak bisa menelepon. Kalau bisa, minta tolong orang '
        'dewasa di dekatmu.',
      ),
    ),
  };

  /// Apa yang dikatakan ke anak setelah menekan "Telepon lewat WhatsApp".
  ///
  /// WhatsApp butuh internet. Kalau peringatan saja tidak sampai, anak tidak
  /// boleh dibuat yakin panggilannya pasti tersambung.
  (IconData, Color, String)? get _whatsAppNote => switch (_whatsApp) {
    null => null,
    WhatsAppCallOutcome.called when !alertSent => (
      Icons.wifi_calling_3_rounded,
      AuraColors.medium,
      tr(
        'Kami mencoba menelepon orang tuamu lewat WhatsApp, tapi internet '
        'sepertinya sedang tidak tersambung. Kalau panggilannya tidak masuk, '
        'minta tolong orang dewasa di dekatmu.',
      ),
    ),
    WhatsAppCallOutcome.called => (
      Icons.wifi_calling_3_rounded,
      AuraColors.safe,
      tr('Kami sudah menelepon orang tuamu lewat WhatsApp.'),
    ),
    WhatsAppCallOutcome.chatOpened => (
      Icons.wifi_calling_3_rounded,
      AuraColors.medium,
      tr(
        'Chat WhatsApp orang tuamu sudah dibuka. Tekan ikon telepon di '
        'pojok kanan atas untuk menelepon.',
      ),
    ),
    WhatsAppCallOutcome.failed => (
      Icons.phone_disabled_rounded,
      AuraColors.critical,
      tr(
        'WhatsApp tidak bisa dibuka. Coba telepon biasa, atau minta tolong '
        'orang dewasa di dekatmu.',
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final whatsAppNote = _whatsAppNote;
    final reached = alertSent || call == CallOutcome.called;
    final headline = alertSent
        ? tr('Pesan daruratmu terkirim')
        : tr('Peringatan belum terkirim');
    final body = alertSent
        ? tr(
            'Orang tuamu sudah menerima peringatanmu. Tetap di tempat yang '
            'ramai dan terang kalau bisa.',
          )
        : tr(
            'Internet sedang tidak tersambung, jadi peringatan belum sampai. '
            'Tetap di tempat yang ramai dan terang kalau bisa.',
          );
    final accent = reached ? AuraColors.safe : AuraColors.medium;

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
              reached ? Icons.check_rounded : Icons.priority_high_rounded,
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
          _Note(note: _callNote),
          if (whatsAppNote != null) ...[
            const SizedBox(height: 10),
            _Note(note: whatsAppNote),
          ],
          const SizedBox(height: 10),
          _Note(note: _locationNote),
          const SizedBox(height: 22),
          if (widget.onCallAgain != null) ...[
            OutlinedButton.icon(
              onPressed: widget.onCallAgain,
              icon: const Icon(Icons.call_rounded),
              label: Text(tr('Telepon orang tua lagi')),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.onCallViaWhatsApp != null) ...[
            // Untuk HP tanpa pulsa atau tablet tanpa SIM, selama ada internet.
            OutlinedButton.icon(
              onPressed: _callingWhatsApp ? null : _callViaWhatsApp,
              icon: const Icon(Icons.wifi_calling_3_rounded),
              label: Text(tr('Telepon lewat WhatsApp')),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Oke')),
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
