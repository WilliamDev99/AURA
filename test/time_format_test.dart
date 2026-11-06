import 'package:aura/core/utils/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waktu di peringatan dan berkas bukti: bahasa Indonesia, dengan zona waktu
/// ponsel yang menampilkannya, bukan selalu "WIB".
void main() {
  test('zona waktu Indonesia dikenali dari selisih UTC', () {
    expect(zoneLabelFor(const Duration(hours: 7)), 'WIB');
    expect(zoneLabelFor(const Duration(hours: 8)), 'WITA');
    expect(zoneLabelFor(const Duration(hours: 9)), 'WIT');
  });

  test('di luar Indonesia ditulis sebagai UTC', () {
    expect(zoneLabelFor(Duration.zero), 'UTC');
    expect(zoneLabelFor(const Duration(hours: -5)), 'UTC-5');
    expect(zoneLabelFor(const Duration(hours: 5, minutes: 30)), 'UTC+5:30');
  });

  test('nama hari dan bulan dalam bahasa Indonesia, lengkap dengan zona', () {
    final time = DateTime(2026, 10, 29, 6, 33);

    expect(
      formatWithZone(time, 'EEEE, d MMMM yyyy, HH:mm'),
      'Kamis, 29 Oktober 2026, 06:33 ${zoneLabel(time)}',
    );
    expect(formatLocal(time, 'd MMM'), '29 Okt');
  });

  test('waktu UTC dari server ditampilkan dalam waktu ponsel', () {
    final utc = DateTime.utc(2026, 10, 29, 14, 33);
    final local = utc.toLocal();

    expect(
      formatWithZone(utc, 'HH:mm'),
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')} ${zoneLabel(local)}',
    );
  });
}
