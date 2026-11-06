/// Konfigurasi Supabase.
///
/// LANGKAH ANDA: tempel dua nilai di bawah ini dari
/// Supabase Dashboard > Project Settings > API.
///
/// Selama masih kosong, aplikasi otomatis berjalan dengan data demo di memori,
/// sehingga tetap bisa dijalankan dan diuji tanpa backend.
///
/// Kunci publik ini memang dirancang untuk ikut dibundel ke dalam aplikasi
/// dan tidak bersifat rahasia. Yang menjaga data bukan kerahasiaan kunci ini,
/// melainkan kebijakan Row Level Security di `supabase/schema.sql`. Yang tidak
/// boleh ditempel di sini adalah kunci `service_role`, karena kunci itu
/// melewati seluruh RLS dan membuka seluruh basis data.
abstract final class SupabaseOptions {
  /// Contoh: 'https://abcdefghijklmnop.supabase.co'
  static const _url = 'https://fkjdfpbqwaasbabterrd.supabase.co';

  /// Kunci publik project. Di dashboard terbaru namanya "Publishable key";
  /// pada project lama tertulis "anon public". Keduanya sama.
  static const _publishableKey =
      'sb_publishable_YNMkRajPMUK1ZEDV6KoYNA_h7A7kM5a';

  /// Nilai dari `--dart-define` menang bila diisi, berguna untuk CI atau
  /// saat ingin memisahkan project uji coba dan project sungguhan.
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: _url);

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: _publishableKey,
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
