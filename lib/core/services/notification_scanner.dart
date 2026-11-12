import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';

/// Menerima pesan yang dibaca dari notifikasi ponsel anak (lihat
/// `AuraNotificationListener.kt`) dan memeriksanya dengan pemindai AURA.
///
/// Semua pemeriksaan terjadi di ponsel anak. Yang dikirim ke orang tua hanya
/// pesan yang terdeteksi berbahaya, lewat [AppState.scanMessage] yang sama
/// dengan fitur "Laporkan chat aneh".
class NotificationScanner {
  NotificationScanner(
    this.state, {
    this.channel = const MethodChannel('id.aura/scan'),
    this.clock = DateTime.now,
    this.useAi = aiEnabled,
  });

  /// Lapis AI (Edge Function `analyze-message`) mati secara bawaan: keputusan
  /// pemilik AURA adalah semua pemeriksaan terjadi di ponsel anak saja.
  /// Nyalakan dengan `--dart-define=AURA_AI_SCAN=true` setelah fungsi itu
  /// dipasang, lalu sesuaikan teks persetujuan anak.
  static const aiEnabled = bool.fromEnvironment('AURA_AI_SCAN');

  /// Apakah pesan yang lolos daftar kata dikirim ke lapis AI.
  final bool useAi;

  final AppState state;
  final MethodChannel channel;

  /// Bisa diganti di test untuk memajukan waktu.
  final DateTime Function() clock;

  /// Pesan yang sama dalam rentang ini dianggap satu kejadian. Android sudah
  /// menyaring pengulangan, tetapi ingatannya hilang bila layanannya
  /// dinyalakan ulang.
  static const _duplicateWindow = Duration(minutes: 10);
  static const _memoryLimit = 300;
  final _seen = <String, DateTime>{};

  /// Pesan yang terlalu panjang dipotong sebelum dipindai dan disimpan.
  static const _maxLength = 2000;

  /// Penilaian AI yang lebih lama dari ini dilewati; pesan berikutnya tidak
  /// boleh tertahan menunggu.
  static const aiTimeout = Duration(seconds: 20);

  void start() {
    channel.setMethodCallHandler(_handle);
    // Memberi tahu Android bahwa Dart siap; pesan yang sempat mengantre
    // selama aplikasi dinyalakan akan dikirim setelah ini.
    channel.invokeMethod<void>('ready').catchError((Object error) {
      // Bukan Android, atau sedang dijalankan di test.
      debugPrint('AURA: pemindai notifikasi tidak tersedia ($error).');
    });
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method == 'accessChanged') {
      // "Akses notifikasi" baru saja diberikan atau dicabut.
      await state.untilRestored();
      await state.reportChatScan(call.arguments == true, changed: true);
      return null;
    }
    if (call.method == 'refreshProfile') {
      // Layar HP anak baru menyala: jam istirahat terbaru diambil saat itu
      // juga, tanpa menunggu realtime tersambung lagi.
      await state.untilRestored();
      await state.refreshProfile();
      return null;
    }
    if (call.method != 'message') return null;
    final args = Map<String, Object?>.from(call.arguments as Map);
    await onMessage(
      app: args['app'] as String? ?? 'Aplikasi chat',
      text: args['text'] as String? ?? '',
      sender: args['sender'] as String?,
    );
    return null;
  }

  /// Memindai satu pesan masuk. Mengembalikan null bila pesan diabaikan.
  @visibleForTesting
  Future<ScanOutcome?> onMessage({
    required String app,
    required String text,
    String? sender,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Pesan bisa tiba saat aplikasi baru menyala, sebelum sesi pulih.
    await state.untilRestored();

    final user = state.user;
    // Hanya di ponsel anak yang sudah menyetujui, dan selama orang tua tidak
    // sedang menjeda perlindungan.
    if (user == null ||
        !user.isChild ||
        !user.hasConsented ||
        !user.protectionActive) {
      // Tanpa isi pesan: log ini bisa terbaca siapa pun yang memegang kabel.
      debugPrint('AURA: pesan dari $app tidak dipindai di perangkat ini.');
      return null;
    }

    final key = '$app|$sender|$trimmed';
    final now = clock();
    final last = _seen[key];
    if (last != null && now.difference(last) < _duplicateWindow) return null;
    _seen[key] = now;
    if (_seen.length > _memoryLimit) _seen.remove(_seen.keys.first);

    final message = trimmed.length > _maxLength
        ? trimmed.substring(0, _maxLength)
        : trimmed;

    try {
      // Daftar kata di ponsel lebih dulu: cepat, gratis, dan tidak perlu
      // internet. Bila lapis AI dinyalakan, hanya pesan yang lolos dari situ
      // yang dinilai AI.
      var assessment = state.analyzer.assess(message);
      if (!useAi && !assessment.level.notifiesParent) {
        return ScanOutcome(assessment: assessment, alert: null);
      }
      if (!assessment.level.notifiesParent) {
        final ai = await state.repository
            .aiAssess(text: message, app: app)
            .timeout(aiTimeout, onTimeout: () => null);
        if (ai == null || !ai.level.notifiesParent) {
          return ScanOutcome(assessment: ai ?? assessment, alert: null);
        }
        assessment = ai;
      }

      final outcome = await state.scanMessage(
        text: message,
        platform: app,
        counterpartName: sender,
        assessment: assessment,
      );
      if (outcome.escalated) {
        debugPrint(
          'AURA: pesan berbahaya dari $app terdeteksi, orang tua diberi tahu.',
        );
      }
      return outcome;
    } catch (error) {
      // Gagal mengirim (mis. tanpa internet) tidak boleh menghentikan
      // pemindaian pesan berikutnya.
      debugPrint('AURA: pesan dari $app gagal diproses ($error).');
      // Dihapus dari ingatan supaya pesan yang sama bisa dicoba lagi.
      _seen.remove(key);
      return null;
    }
  }
}
