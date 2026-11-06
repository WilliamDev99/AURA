import 'dart:async';

import 'package:aura/core/utils/resilient_stream.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sumber realtime tiruan: setiap pemanggilan `open` menghasilkan koneksi baru
/// yang bisa diberi data atau digagalkan dari dalam test.
class _FakeRealtime {
  final connections = <StreamController<int>>[];

  Stream<int> open() {
    final connection = StreamController<int>();
    connections.add(connection);
    return connection.stream;
  }

  StreamController<int> get latest => connections.last;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('data diteruskan apa adanya', () async {
    final realtime = _FakeRealtime();
    final received = <int>[];
    final sub = resilientStream(realtime.open).listen(received.add);

    await _settle();
    realtime.latest
      ..add(1)
      ..add(2);
    await _settle();

    expect(received, [1, 2]);
    await sub.cancel();
  });

  test('token kedaluwarsa: galat ditahan, lalu tersambung ulang', () async {
    // Skenario yang benar-benar terjadi di emulator: aplikasi dibuka setelah
    // 9 jam, langganan pertama ditolak karena token kedaluwarsa.
    final realtime = _FakeRealtime();
    final received = <int>[];
    final errors = <Object>[];

    final sub = resilientStream(
      realtime.open,
      backoff: (_) => Duration.zero,
      onRetry: (_, _) {},
    ).listen(received.add, onError: errors.add);

    await _settle();
    realtime.latest.addError('InvalidJWTToken: Token has expired');
    await _settle();

    expect(
      realtime.connections,
      hasLength(2),
      reason: 'harus tersambung ulang',
    );
    expect(errors, isEmpty, reason: 'galat tidak boleh sampai ke pendengar');

    realtime.latest.add(42);
    await _settle();
    expect(received, [42], reason: 'koneksi baru harus mengalirkan data');

    await sub.cancel();
  });

  test(
    'jeda bertambah saat gagal beruntun, kembali nol setelah pulih',
    () async {
      final realtime = _FakeRealtime();
      final attempts = <int>[];

      final sub = resilientStream(
        realtime.open,
        backoff: (attempt) {
          attempts.add(attempt);
          return Duration.zero;
        },
        onRetry: (_, _) {},
      ).listen((_) {});

      await _settle();
      realtime.latest.addError('putus');
      await _settle();
      realtime.latest.addError('putus lagi');
      await _settle();
      expect(attempts, [0, 1]);

      // Data mengalir: hitungan percobaan harus kembali ke nol.
      realtime.latest.add(1);
      await _settle();
      realtime.latest.addError('putus setelah pulih');
      await _settle();
      expect(attempts, [0, 1, 0]);

      await sub.cancel();
    },
  );

  test('berhenti mencoba setelah langganan dibatalkan', () async {
    final realtime = _FakeRealtime();
    final sub = resilientStream(
      realtime.open,
      backoff: (_) => const Duration(milliseconds: 20),
      onRetry: (_, _) {},
    ).listen((_) {});

    await _settle();
    realtime.latest.addError('putus');
    await sub.cancel();

    // Tunggu melewati jeda: tidak boleh ada koneksi baru yang dibuka.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(realtime.connections, hasLength(1));
  });

  test('jeda bawaan naik bertahap dan dibatasi 30 detik', () {
    expect(defaultBackoff(0), const Duration(seconds: 1));
    expect(defaultBackoff(1), const Duration(seconds: 2));
    expect(defaultBackoff(3), const Duration(seconds: 8));
    expect(defaultBackoff(5), const Duration(seconds: 30));
    expect(defaultBackoff(50), const Duration(seconds: 30));
  });
}
