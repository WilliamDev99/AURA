import 'package:flutter/services.dart';

import 'guarded_input.dart';

/// Peringatan saat huruf atau simbol diketik di kolom nomor HP.
const phoneOnlyDigitsWarning = 'Nomor HP hanya boleh berisi angka.';

/// Penyaring kolom nomor HP: hanya angka, tanda +, spasi, dan tanda hubung
/// yang bisa diketik atau ditempel. Huruf langsung ditolak, tidak menunggu
/// tombol Lanjut ditekan; [onChecked] memberi tahu bila ada yang ditolak.
List<TextInputFormatter> phoneInputFormatters({
  void Function(bool rejected)? onChecked,
}) => [
  GuardedInputFormatter(RegExp(r'[0-9+\- ]'), onChecked: onChecked),
  // +62 812-3456-7890 dengan spasi dan tanda hubung masih muat.
  LengthLimitingTextInputFormatter(20),
];

/// Menormalkan nomor HP Indonesia ke format internasional `+62...`.
///
/// Menerima bentuk yang biasa diketik orang tua: `0812-3456-7890`,
/// `0812 3456 7890`, `62812...`, atau `+62 812...`. Mengembalikan null bila
/// bukan nomor seluler Indonesia yang masuk akal — nomor darurat yang salah
/// lebih berbahaya daripada tidak ada nomor sama sekali, karena anak mengira
/// orang tuanya sedang ditelepon.
String? normalizeIndonesianPhone(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s\-().]'), '');

  String? national;
  if (cleaned.startsWith('+62')) {
    national = cleaned.substring(3);
  } else if (cleaned.startsWith('62')) {
    national = cleaned.substring(2);
  } else if (cleaned.startsWith('0')) {
    national = cleaned.substring(1);
  }
  if (national == null) return null;

  // Nomor seluler Indonesia diawali 8 dan panjangnya 9-13 digit setelah 0.
  if (!RegExp(r'^8\d{8,12}$').hasMatch(national)) return null;
  return '+62$national';
}

/// Tampilan ramah untuk dibaca manusia: `+62 812-3456-7890`.
String formatIndonesianPhone(String normalized) {
  if (!normalized.startsWith('+62')) return normalized;
  final n = normalized.substring(3);
  if (n.length < 7) return normalized;
  final head = n.substring(0, 3);
  final rest = n.substring(3);
  final middle = rest.substring(0, rest.length ~/ 2);
  final tail = rest.substring(rest.length ~/ 2);
  return '+62 $head-$middle-$tail';
}
