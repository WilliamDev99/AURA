import 'dart:async';
import 'dart:collection';
import 'dart:convert';

/// Mengambil ulang satu baris secara berkala dan melaporkannya bila berubah.
///
/// Cadangan untuk realtime di HP anak. Di sana AURA biasanya berjalan di
/// latar belakang tanpa layar, dan Supabase hanya memperbarui token login
/// otomatis saat aplikasi terbuka di layar. Setelah satu jam tokennya
/// kedaluwarsa, realtime berhenti, dan perubahan dari orang tua (mis. jam
/// istirahat dimatikan) tidak pernah sampai sampai anak membuka AURA.
/// Permintaan biasa memperbarui token yang kedaluwarsa dengan sendirinya,
/// jadi pengambilan berkala ini sekaligus memulihkan realtime.
class RowPoller {
  RowPoller({
    required this.fetch,
    required this.onChanged,
    this.every = const Duration(minutes: 1),
  });

  /// Null bila tidak ada yang perlu diambil (mis. belum masuk).
  final Future<Map<String, dynamic>?> Function() fetch;
  final void Function(Map<String, dynamic> row) onChanged;
  final Duration every;

  Timer? _timer;
  String? _last;
  bool _fetching = false;

  void start() => _timer ??= Timer.periodic(every, (_) => poll());

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Baris yang sudah diterima lewat jalur lain (realtime), supaya tidak
  /// dilaporkan dua kali.
  void seen(Map<String, dynamic> row) => _last = _key(row);

  Future<void> poll() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final row = await fetch();
      if (row == null) return;
      final key = _key(row);
      if (key == _last) return;
      _last = key;
      onChanged(row);
    } catch (_) {
      // Tanpa internet: dicoba lagi pada giliran berikutnya. Tidak dicatat,
      // supaya log tidak penuh setiap menit selama HP offline.
    } finally {
      _fetching = false;
    }
  }

  /// Urutan kolom dari realtime dan dari kueri biasa bisa berbeda.
  static String _key(Map<String, dynamic> row) =>
      jsonEncode(SplayTreeMap<String, dynamic>.from(row));
}
