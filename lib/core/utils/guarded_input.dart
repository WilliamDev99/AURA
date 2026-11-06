import 'package:flutter/services.dart';

/// Penyaring kolom isian yang juga memberi tahu bila ada karakter ditolak,
/// supaya halaman bisa menampilkan peringatan seperti "Nomor HP hanya boleh
/// berisi angka" alih-alih diam-diam membuang ketikan.
class GuardedInputFormatter extends TextInputFormatter {
  GuardedInputFormatter(this.allowed, {this.onChecked});

  /// Pola satu karakter yang boleh diketik.
  final Pattern allowed;

  /// Dipanggil setiap isi kolom berubah: true bila ada karakter yang
  /// ditolak, false bila semua ketikan diterima.
  final void Function(bool rejected)? onChecked;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Memindah kursor atau memilih teks bukan ketikan baru; peringatan yang
    // sedang tampil dibiarkan.
    if (oldValue.text == newValue.text) return newValue;

    final filtered = FilteringTextInputFormatter.allow(
      allowed,
    ).formatEditUpdate(oldValue, newValue);
    onChecked?.call(filtered.text != newValue.text);
    return filtered;
  }
}
