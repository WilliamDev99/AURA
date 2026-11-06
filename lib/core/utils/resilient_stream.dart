import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Jeda bawaan sebelum mencoba lagi: 1, 2, 4, 8, 16, lalu 30 detik.
Duration defaultBackoff(int attempt) =>
    Duration(seconds: min(30, 1 << min(attempt, 5)));

/// Membungkus langganan realtime agar pulih sendiri saat terputus.
///
/// Koneksi realtime bisa gagal karena token sedang diperbarui, jaringan
/// berganti dari Wi-Fi ke data seluler, atau ponsel bangun dari tidur. Tanpa
/// pembungkus ini, satu kegagalan membuat dashboard orang tua berhenti
/// menerima peringatan baru sampai aplikasi ditutup dan dibuka ulang —
/// persis kegagalan yang tidak boleh terjadi di aplikasi ini.
///
/// [open] dipanggil ulang setiap kali mencoba lagi, sehingga langganan baru
/// selalu memakai token dan koneksi terkini. Galat tidak pernah diteruskan ke
/// pendengar; hitungan percobaan kembali ke nol begitu data mengalir lagi.
Stream<T> resilientStream<T>(
  Stream<T> Function() open, {
  Duration Function(int attempt) backoff = defaultBackoff,
  void Function(Object error, Duration retryIn)? onRetry,
}) {
  StreamSubscription<T>? subscription;
  Timer? retry;
  var attempt = 0;
  var cancelled = false;
  late final StreamController<T> controller;

  void connect() {
    if (cancelled) return;
    subscription = open().listen(
      (value) {
        attempt = 0;
        controller.add(value);
      },
      onError: (Object error) {
        subscription?.cancel();
        if (cancelled) return;
        final delay = backoff(attempt);
        attempt++;
        (onRetry ?? _logRetry)(error, delay);
        retry = Timer(delay, connect);
      },
    );
  }

  controller = StreamController<T>(
    onListen: connect,
    onCancel: () async {
      cancelled = true;
      retry?.cancel();
      await subscription?.cancel();
    },
  );

  return controller.stream;
}

void _logRetry(Object error, Duration retryIn) {
  debugPrint(
    'AURA: realtime terputus, mencoba lagi dalam '
    '${retryIn.inSeconds} detik ($error).',
  );
}
