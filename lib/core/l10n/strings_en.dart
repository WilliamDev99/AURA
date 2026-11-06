import 'strings_en_app.dart';

/// Terjemahan bahasa Inggris untuk teks AURA.
///
/// Kuncinya adalah teks bahasa Indonesia persis seperti di kode, termasuk
/// isian `{nama}`. Test `l10n_coverage_test.dart` memastikan setiap teks yang
/// dibungkus `tr()` punya terjemahan di sini.
const englishStrings = <String, String>{
  ...englishAppStrings,

  // ---------------------------------------------------------------- umum
  'Batal': 'Cancel',
  'Simpan': 'Save',
  'Kembali': 'Back',
  'Keluar': 'Sign out',
  'Aktif': 'Active',
  'Dijeda': 'Paused',
  'Belum ada': 'None yet',
  'Belum diisi': 'Not set',
  'Pengguna': 'User',
  'Email': 'Email',

  // ---------------------------------------------------------------- bahasa
  'Bahasa': 'Language',
  'Pilih bahasa': 'Choose language',
  'Bahasa tampilan AURA. Deteksi ancaman tetap membaca pesan berbahasa '
          'Indonesia.':
      'AURA display language. Threat detection still reads messages in '
      'Indonesian.',

  // ---------------------------------------------------------------- profil
  'Pengaturan': 'Settings',
  'Akun': 'Account',
  'Perangkat anak': "Child's phone",
  'Perangkat orang tua': "Parent's phone",
  'Masuk dengan {account}': 'Signed in with {account}',
  'Transparansi': 'Transparency',
  'Apa yang AURA lakukan, apa adanya.': 'What AURA does, plainly.',
  'Status pemindaian': 'Scanning status',
  'Persetujuan anak': "Child's consent",
  'Belum diberikan': 'Not given yet',
  'Ditelepon saat darurat': 'Called in an emergency',
  'Peringatan terkirim': 'Alerts sent',
  '{count} sejak awal': '{count} so far',
  'Bukti tersimpan': 'Evidence stored',
  '{count} entri': '{count} entries',
  'Integritas bukti': 'Evidence integrity',
  'Utuh': 'Intact',
  'Terputus': 'Broken',
  'Yang tidak pernah AURA lakukan': 'What AURA never does',
  'Menyalakan kamera atau mikrofon diam-diam.':
      'Turn on the camera or microphone secretly.',
  'Menyembunyikan ikon aplikasi dari anak.':
      'Hide the app icon from the child.',
  'Meneruskan obrolan yang tidak berbahaya ke orang tua.':
      'Forward harmless chats to parents.',
  'Menjual atau membagikan data anak ke pihak ketiga.':
      "Sell or share a child's data with third parties.",
  'AURA v1.0.0 - dibuat untuk melindungi, bukan mengawasi.':
      'AURA v1.0.0 - built to protect, not to spy.',
  'Akun belum diamankan': 'Account not secured yet',
  'Kalau keluar sekarang, Anda tidak bisa masuk lagi ke akun ini dan data '
          'anak tidak bisa dibuka. Amankan dulu dengan email atau Facebook.':
      "If you sign out now, you can't get back into this account and your "
      "child's data can't be opened. Secure it with email or Facebook "
      'first.',
  'Tetap keluar': 'Sign out anyway',
  'Amankan akun Anda': 'Secure your account',
  'Belum tersambung ke email atau Facebook. Kalau aplikasi dihapus, data '
          'tidak bisa dibuka lagi.':
      "Not linked to email or Facebook yet. If the app is deleted, the data "
      "can't be opened again.",

  // ---------------------------------------------------------------- foto
  'Ganti foto profil': 'Change profile photo',
  'Foto profil': 'Profile photo',
  'Pilih dari galeri': 'Choose from gallery',
  'Ambil foto': 'Take a photo',
  'Hapus foto': 'Remove photo',
  'Foto tidak bisa dibuka. Coba lagi.':
      "The photo couldn't be opened. "
      'Try again.',
  'Foto profil dihapus.': 'Profile photo removed.',
  'Foto profil diperbarui.': 'Profile photo updated.',
  'Foto profil belum bisa disimpan.': "The profile photo couldn't be saved.",
  'Penyimpanan foto belum disiapkan. Jalankan '
          'supabase/patch_04_profile_photo.sql di SQL Editor Supabase.':
      'Photo storage is not set up yet. Run '
      'supabase/patch_04_profile_photo.sql in the Supabase SQL Editor.',
  'Ukuran foto terlalu besar. Pilih foto lain.':
      'The photo is too large. Choose another one.',
  'Foto ditolak oleh aturan keamanan. Pastikan '
          'supabase/patch_04_profile_photo.sql sudah dijalankan.':
      'The photo was blocked by security rules. Make sure '
      'supabase/patch_04_profile_photo.sql has been run.',

  // ---------------------------------------------------------------- nomor HP
  'Nomor HP darurat': 'Emergency phone number',
  'Nomor HP': 'Phone number',
  'Ubah nomor HP': 'Change phone number',
  'Nomor ini ditelepon otomatis saat anak menekan tombol darurat.':
      'This number is called automatically when your child presses the '
      'emergency button.',
  'Isi nomor HP Indonesia, mis. 0812 3456 7890':
      'Enter an Indonesian phone number, e.g. 0812 3456 7890',
  'Nomor HP darurat diperbarui.': 'Emergency phone number updated.',
  'Nomor HP hanya boleh berisi angka.':
      'Phone numbers can only contain digits.',
  'Nama hanya boleh berisi huruf, tanpa angka atau simbol.':
      'Names can only contain letters, no digits or symbols.',

  // ---------------------------------------------------------------- anak
  'Tautkan ke orang tua': 'Link to parent',
  'Tautkan ke Orang Tua': 'Link to Parent',
  'Sudah tersambung': 'Connected',
  'Belum tersambung': 'Not connected',
  'Ganti sambungan orang tua?': 'Change parent connection?',
  'HP ini sudah tersambung ke orang tua. Kalau kode ini dari orang tua lain, '
          'peringatan berikutnya dikirim ke orang tua tersebut.':
      'This phone is already connected to a parent. If this code is from '
      'another parent, future alerts will go to that parent.',
  'Sambungkan': 'Connect',
  'Tersambung ke orang tua.': 'Connected to parent.',

  // ---------------------------------------------------------------- email
  'Ubah Email': 'Change Email',
  'Email baru': 'New email',
  'Tambahkan email untuk masuk ke akun ini. Kode masuk akan dikirim ke '
          'email tersebut.':
      'Add an email to sign in to this account. Sign-in codes will be sent '
      'to that address.',
  'Email sekarang: {email}. Setelah diganti, masuk ke AURA memakai email '
          'baru.':
      'Current email: {email}. After the change, sign in to AURA with the '
      'new email.',
  'Isi alamat email yang benar, mis. nama@gmail.com':
      'Enter a valid email address, e.g. name@gmail.com',
  'Ini sudah email Anda sekarang.': 'This is already your current email.',
  'Kirim kode': 'Send code',
  'Kode dikirim ke {email}. Cek juga folder Spam.':
      'A code was sent to {email}. Check your Spam folder too.',
  'Kode dikirim ke email baru ({new}). Email lama ({old}) mungkin juga '
          'menerima kode. Cek juga folder Spam.':
      'A code was sent to the new email ({new}). The old email ({old}) may '
      'also receive a code. Check your Spam folder too.',
  'Kode dari email baru': 'Code from the new email',
  'Kode dari email lama': 'Code from the old email',
  'Isi bila email lama juga menerima kode.':
      'Fill this in if the old email also received a code.',
  'Masukkan juga kode yang dikirim ke {email}.':
      'Also enter the code sent to {email}.',
  'Simpan email baru': 'Save new email',
  'Ganti email': 'Change email',
  'Kirim ulang ({time})': 'Resend ({time})',
  'Kirim ulang kode': 'Resend code',
  'Kode terdiri dari 6 angka': 'The code has 6 digits',
  'Email berhasil diganti': 'Email changed',
  'Mulai sekarang, masuk ke AURA memakai {email}.':
      'From now on, sign in to AURA with {email}.',
  'Minta kode untuk email ini lebih dulu.':
      'Request a code for this email first.',
  'Kode salah atau sudah kedaluwarsa. Periksa lagi, atau minta kode baru.':
      'The code is wrong or has expired. Check it again, or request a new '
      'one.',
};
