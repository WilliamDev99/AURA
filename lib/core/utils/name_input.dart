import 'package:flutter/services.dart';

import 'guarded_input.dart';

/// Peringatan saat angka atau simbol diketik di kolom nama.
const nameOnlyLettersWarning =
    'Nama hanya boleh berisi huruf, tanpa angka atau simbol.';

/// Penyaring kolom nama: hanya huruf (termasuk huruf beraksen), spasi, dan
/// tanda yang wajar dalam nama, seperti Ma'ruf, St. Aisyah, atau Anne-Marie.
/// Angka dan simbol langsung ditolak saat diketik atau ditempel;
/// [onChecked] memberi tahu bila ada yang ditolak.
List<TextInputFormatter> nameInputFormatters({
  void Function(bool rejected)? onChecked,
}) => [
  GuardedInputFormatter(
    RegExp(r"[\p{L}\p{M} '.\-]", unicode: true),
    onChecked: onChecked,
  ),
  LengthLimitingTextInputFormatter(40),
];

/// Pesan galat untuk nama, atau null bila nama bisa dipakai.
///
/// Penyaring di atas sudah menolak angka; pemeriksaan ini menjaga nama yang
/// ditempel lewat cara lain dan nama yang hanya berisi tanda baca.
String? validateName(String? value) {
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(value ?? '');
  if (letters.length < 2) return 'Isi nama minimal 2 huruf';
  if (RegExp(r'\d').hasMatch(value!)) return 'Nama tidak boleh berisi angka';
  return null;
}
