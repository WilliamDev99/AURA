import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// Format waktu untuk bukti dan peringatan: bahasa Indonesia, dengan label
/// zona waktu yang sesuai dengan ponsel yang menampilkannya.
///
/// Label tidak boleh ditulis tetap "WIB": orang tua di Makassar atau Jayapura
/// akan salah membaca jam kejadian, padahal jam itu bisa menjadi bukti.

/// Label zona waktu Indonesia dari selisih terhadap UTC.
String zoneLabelFor(Duration offset) {
  final minutes = offset.inMinutes;
  switch (minutes) {
    case 420: // UTC+7
      return 'WIB';
    case 480: // UTC+8
      return 'WITA';
    case 540: // UTC+9
      return 'WIT';
    case 0:
      return 'UTC';
  }
  final sign = minutes < 0 ? '-' : '+';
  final hours = minutes.abs() ~/ 60;
  final rest = minutes.abs() % 60;
  return rest == 0
      ? 'UTC$sign$hours'
      : 'UTC$sign$hours:${rest.toString().padLeft(2, '0')}';
}

/// Label zona waktu ponsel ini pada saat [time].
String zoneLabel(DateTime time) => zoneLabelFor(time.toLocal().timeZoneOffset);

bool _localeReady = false;

/// Data nama hari dan bulan bahasa Indonesia. Dipanggil sekali saat aplikasi
/// mulai; pemanggilan berikutnya tidak berbuat apa-apa.
void ensureIndonesianDates() {
  if (_localeReady) return;
  // Datanya sudah ada di dalam paket intl dan dipasang seketika; Future-nya
  // hanya formalitas.
  initializeDateFormatting('id');
  _localeReady = true;
}

/// Waktu lokal dalam bahasa Indonesia beserta zonanya, mis.
/// "Kamis, 29 Oktober 2026, 22:33 WITA".
String formatWithZone(DateTime time, String pattern) {
  ensureIndonesianDates();
  final local = time.toLocal();
  return '${DateFormat(pattern, _dateLocale).format(local)} '
      '${zoneLabel(local)}';
}

/// Nama hari dan bulan mengikuti bahasa tampilan ("Okt" atau "Oct").
String get _dateLocale => Lang.instance.current.code;

/// Waktu lokal dalam bahasa Indonesia tanpa zona, mis. "29 Okt, 22:33".
String formatLocal(DateTime time, String pattern) {
  ensureIndonesianDates();
  return DateFormat(pattern, _dateLocale).format(time.toLocal());
}
