import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_en.dart';

/// Bahasa tampilan AURA.
///
/// Teks di kode ditulis dalam bahasa Indonesia dan dibungkus [tr]; terjemahan
/// bahasa Inggrisnya ada di [englishStrings]. Deteksi ancaman tetap membaca
/// pesan berbahasa Indonesia apa pun bahasa tampilannya.
enum AppLanguage {
  id('Bahasa Indonesia', 'id'),
  en('English', 'en');

  const AppLanguage(this.nativeName, this.code);

  /// Nama bahasa dalam bahasanya sendiri, supaya selalu bisa dikenali.
  final String nativeName;
  final String code;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLanguage.id,
  );
}

/// Bahasa yang sedang dipakai, disimpan di perangkat ini.
class Lang extends ChangeNotifier {
  Lang._();

  static final instance = Lang._();

  static const _prefsKey = 'aura.language';

  AppLanguage _current = AppLanguage.id;
  AppLanguage get current => _current;

  bool get isEnglish => _current == AppLanguage.en;

  /// Membaca pilihan bahasa yang tersimpan. Dipanggil sekali saat mulai.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _current = AppLanguage.fromCode(prefs.getString(_prefsKey));
      notifyListeners();
    } catch (error) {
      debugPrint('AURA: pilihan bahasa tidak terbaca ($error).');
    }
  }

  Future<void> set(AppLanguage language) async {
    if (language == _current) return;
    _current = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language.code);
    } catch (error) {
      debugPrint('AURA: pilihan bahasa tidak tersimpan ($error).');
    }
  }

  /// Untuk test: kembali ke bahasa Indonesia tanpa menyentuh penyimpanan.
  @visibleForTesting
  void resetForTest([AppLanguage language = AppLanguage.id]) {
    _current = language;
    notifyListeners();
  }
}

final _placeholder = RegExp(r'\{(\w+)\}');

/// Teks [id] (bahasa Indonesia) dalam bahasa yang sedang dipakai.
///
/// Isian ditulis `{nama}` dan diisi dari [args], mis.
/// `tr('Halo {name},', {'name': user.name})`. Bila terjemahan belum ada,
/// teks Indonesianya yang tampil, jadi aplikasi tidak pernah kosong.
String tr(String id, [Map<String, Object?> args = const {}]) {
  final text = Lang.instance.isEnglish ? (englishStrings[id] ?? id) : id;
  if (args.isEmpty) return text;
  return text.replaceAllMapped(
    _placeholder,
    (m) => args.containsKey(m[1]) ? '${args[m[1]]}' : m[0]!,
  );
}

/// Membangun ulang seluruh tampilan di bawah [context] tanpa mengulang
/// halaman, supaya pergantian bahasa langsung terlihat di mana-mana.
void rebuildAllChildren(BuildContext context) {
  void rebuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(rebuild);
  }

  (context as Element).visitChildren(rebuild);
}
