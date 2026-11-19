/// PIN dari orang tua untuk menghapus AURA dari HP anak.
///
/// Di HP anak, AURA dilindungi sebagai admin perangkat, sehingga Android
/// menolak menghapusnya. Anak meminta PIN; PIN dibuat di basis data dan hanya
/// bisa dibaca orang tua (notifikasi dan aplikasi orang tua). Anak memasukkan
/// PIN itu, basis data memeriksanya, dan bila benar AURA melepas
/// perlindungannya lalu membuka dialog hapus aplikasi.
class UninstallPin {
  const UninstallPin({
    required this.childId,
    required this.pin,
    required this.expiresAt,
    this.attempts = 0,
    this.closedAt,
    this.closedBy,
  });

  /// Lama PIN berlaku.
  static const lifetime = Duration(minutes: 30);

  /// Salah sebanyak ini, PIN tidak bisa dipakai lagi.
  static const maxAttempts = 5;

  final String childId;
  final String pin;
  final DateTime expiresAt;
  final int attempts;

  /// Saat PIN dipakai anak ('used') atau dibatalkan orang tua ('cancelled').
  final DateTime? closedAt;
  final String? closedBy;

  /// Masih bisa dipakai anak.
  bool activeAt(DateTime now) =>
      closedAt == null && expiresAt.isAfter(now) && attempts < maxAttempts;

  /// "482 913": lebih mudah dibacakan.
  String get spaced =>
      pin.length == 6 ? '${pin.substring(0, 3)} ${pin.substring(3)}' : pin;

  static UninstallPin? fromRow(Map<String, dynamic> row) {
    final childId = row['child_id'];
    final pin = row['pin'];
    final expires = _date(row['expires_at']);
    if (childId is! String || pin is! String || expires == null) return null;
    return UninstallPin(
      childId: childId,
      pin: pin,
      expiresAt: expires,
      attempts: (row['attempts'] as num?)?.toInt() ?? 0,
      closedAt: _date(row['closed_at']),
      closedBy: row['closed_by'] as String?,
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

/// Hasil memeriksa PIN yang dimasukkan anak.
enum PinCheck {
  /// Benar: AURA boleh dihapus.
  ok,

  /// Salah; masih bisa dicoba lagi.
  wrong,

  /// Terlalu sering salah: minta PIN baru.
  locked,

  /// Sudah lewat 30 menit: minta PIN baru.
  expired,

  /// Belum meminta PIN, atau PIN-nya sudah dipakai/dibatalkan.
  none;

  static PinCheck fromName(Object? value) => PinCheck.values.firstWhere(
    (check) => check.name == value,
    orElse: () => PinCheck.none,
  );
}
