import '../../core/l10n/l10n.dart';

/// Jam istirahat: semua aplikasi di HP anak terkunci pada jam yang diatur
/// orang tua, kecuali AURA, telepon, dan jam alarm.
///
/// Penguncinya sendiri berjalan di Android (LockSchedule.kt dan
/// ScreenLock.kt). Aturan "kapan terkunci" di sini dan di sana harus sama;
/// test di kedua sisi memakai contoh yang sama.
class LockSchedule {
  const LockSchedule({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.days,
  });

  /// Bawaan saat orang tua pertama kali membuka pengaturannya:
  /// 22.00 sampai 09.00, setiap hari.
  static const standard = LockSchedule(
    enabled: true,
    startMinutes: 22 * 60,
    endMinutes: 9 * 60,
    days: {1, 2, 3, 4, 5, 6, 7},
  );

  final bool enabled;

  /// Menit sejak tengah malam, mis. 22.00 = 1320.
  final int startMinutes;
  final int endMinutes;

  /// Hari mulainya kunci, memakai [DateTime.weekday]: 1 = Senin ... 7 =
  /// Minggu. Kunci yang mulai Senin 22.00 dan berakhir Selasa 09.00 adalah
  /// kunci hari Senin.
  final Set<int> days;

  /// Melewati tengah malam, mis. 22.00 sampai 09.00.
  bool get overnight => startMinutes > endMinutes;

  /// Jadwal yang benar-benar bisa mengunci.
  bool get active => enabled && days.isNotEmpty && startMinutes != endMinutes;

  bool isLockedAt(DateTime time) {
    if (!active) return false;
    final minute = time.hour * 60 + time.minute;
    final today = time.weekday;
    final yesterday = today == 1 ? 7 : today - 1;
    if (overnight) {
      return (minute >= startMinutes && days.contains(today)) ||
          (minute < endMinutes && days.contains(yesterday));
    }
    return days.contains(today) &&
        minute >= startMinutes &&
        minute < endMinutes;
  }

  LockSchedule copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
    Set<int>? days,
  }) => LockSchedule(
    enabled: enabled ?? this.enabled,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    days: days ?? this.days,
  );

  /// Bentuk yang disimpan di Supabase (kolom `lock_schedule`) dan dibaca
  /// Android dari penyimpanan HP anak.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': clock(startMinutes),
    'end': clock(endMinutes),
    'days': (days.toList()..sort()),
  };

  static LockSchedule? fromJson(Object? value) {
    if (value is! Map) return null;
    final start = _minutes(value['start']);
    final end = _minutes(value['end']);
    if (start == null || end == null) return null;
    final days = <int>{
      for (final d in (value['days'] as List?) ?? const [])
        if (d is num && d >= 1 && d <= 7) d.toInt(),
    };
    return LockSchedule(
      enabled: value['enabled'] == true,
      startMinutes: start,
      endMinutes: end,
      days: days,
    );
  }

  static int? _minutes(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final h = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    if (h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  /// "22:00": dipakai untuk penyimpanan.
  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  /// "22.00": cara Indonesia menulis jam.
  static String display(int minutes) => clock(minutes).replaceAll(':', '.');

  /// Nama hari singkat, Senin dulu.
  static List<String> get dayNames => [
    tr('Sen'),
    tr('Sel'),
    tr('Rab'),
    tr('Kam'),
    tr('Jum'),
    tr('Sab'),
    tr('Min'),
  ];

  /// Ringkasan untuk dibaca orang tua dan anak, mis.
  /// "22.00 – 09.00, setiap hari".
  String describe() {
    if (!active) return tr('Tidak aktif');
    final hours = '${display(startMinutes)} – ${display(endMinutes)}';
    final sorted = days.toList()..sort();
    final String when;
    if (sorted.length == 7) {
      when = tr('setiap hari');
    } else if (_same(sorted, [1, 2, 3, 4, 5])) {
      when = tr('Senin – Jumat');
    } else if (_same(sorted, [6, 7])) {
      when = tr('akhir pekan');
    } else {
      when = sorted.map((d) => dayNames[d - 1]).join(', ');
    }
    return '$hours, $when';
  }

  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);

  @override
  bool operator ==(Object other) =>
      other is LockSchedule &&
      other.enabled == enabled &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hash(
    enabled,
    startMinutes,
    endMinutes,
    Object.hashAllUnordered(days),
  );
}
