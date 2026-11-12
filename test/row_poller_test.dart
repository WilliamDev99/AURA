import 'dart:io';

import 'package:aura/core/utils/row_poller.dart';
import 'package:flutter_test/flutter_test.dart';

/// HP anak mengambil ulang profilnya tiap menit, karena realtime berhenti
/// setelah token login kedaluwarsa saat AURA berjalan tanpa layar.
void main() {
  Map<String, dynamic> profile({required bool locked}) => {
    'id': 'ayu',
    'role': 'child',
    'lock_schedule': {
      'enabled': locked,
      'start': '23:00',
      'end': '09:00',
      'days': [1, 2, 3, 4, 5, 6, 7],
    },
  };

  test(
    'jam istirahat dimatikan orang tua sampai walau realtime mati',
    () async {
      var server = profile(locked: true);
      final seen = <Map<String, dynamic>>[];
      final poller = RowPoller(fetch: () async => server, onChanged: seen.add);

      await poller.poll();
      expect(seen, hasLength(1));

      // Tidak berubah: tidak dilaporkan lagi.
      await poller.poll();
      expect(seen, hasLength(1));

      server = profile(locked: false);
      await poller.poll();
      expect(seen, hasLength(2));
      expect((seen.last['lock_schedule'] as Map)['enabled'], isFalse);
    },
  );

  test('yang sudah datang lewat realtime tidak dilaporkan dua kali, '
      'walau urutan kolomnya berbeda', () async {
    final fromRealtime = profile(locked: false);
    final fromQuery = {
      'lock_schedule': fromRealtime['lock_schedule'],
      'role': 'child',
      'id': 'ayu',
    };
    final seen = <Map<String, dynamic>>[];
    final poller = RowPoller(fetch: () async => fromQuery, onChanged: seen.add)
      ..seen(fromRealtime);
    await poller.poll();
    expect(seen, isEmpty);
  });

  test('tanpa internet: diam, lalu pulih saat online lagi', () async {
    var online = false;
    final seen = <Map<String, dynamic>>[];
    final poller = RowPoller(
      fetch: () async {
        if (!online) throw const SocketException('Failed host lookup');
        return profile(locked: false);
      },
      onChanged: seen.add,
    );
    await poller.poll();
    expect(seen, isEmpty);
    online = true;
    await poller.poll();
    expect(seen, hasLength(1));
  });

  test('berjalan sendiri secara berkala sampai dihentikan', () async {
    var calls = 0;
    final poller = RowPoller(
      fetch: () async {
        calls++;
        return null;
      },
      onChanged: (_) {},
      every: const Duration(milliseconds: 10),
    )..start();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    poller.stop();
    final stopped = calls;
    expect(stopped, greaterThanOrEqualTo(3));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(calls, stopped);
  });

  test('profil HP anak memakai pengambilan berkala', () {
    final repository = File(
      'lib/data/supabase_repository.dart',
    ).readAsStringSync();
    expect(repository, contains('RowPoller('));
    expect(repository, contains('poller.start()'));
    expect(repository, contains('poller.stop()'));
  });
}
