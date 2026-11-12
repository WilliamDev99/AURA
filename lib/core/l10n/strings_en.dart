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
  'Nomor orang tua': "Parents' number",
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
  'Kalau SOS anak tidak terkirim karena internetnya mati, anak bisa '
          'menelepon nomor ini.':
      "If your child's SOS can't be sent because their internet is down, "
      'they can call this number.',
  'Isi nama dan nomor HP Anda. Kalau SOS anak tidak terkirim karena '
          'internetnya mati, anak bisa menelepon nomor ini.':
      "Enter your name and phone number. If your child's SOS can't be sent "
      'because their internet is down, they can call this number.',
  'Cadangan bila SOS anak tidak terkirim.':
      "A backup for when your child's SOS can't be sent.",
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

  // ------------------------------------------------- alarm SOS (orang tua)
  'Alarm SOS': 'SOS alarm',
  'Berbunyi dan bergetar terus saat anak menekan tombol SOS, sampai Anda '
          'mematikannya.':
      'Rings and vibrates nonstop when your child presses the SOS button, '
      'until you turn it off.',
  'Tes alarm SOS': 'SOS alarm test',
  'Begini bunyinya saat anak menekan tombol SOS. Tekan "Matikan alarm" '
          'untuk berhenti.':
      'This is how it sounds when your child presses the SOS button. Tap '
      '"Turn off alarm" to stop it.',
  'Darurat: {child} menekan tombol SOS':
      'Emergency: {child} pressed the SOS button',
  'Alarm berbunyi sampai Anda mematikannya. Ketuk untuk melihat lokasi '
          '{child}.':
      "The alarm rings until you turn it off. Tap to see {child}'s location.",
  'Matikan alarm': 'Turn off alarm',
  'Alarm SOS berbunyi': 'SOS alarm ringing',
  'Berbunyi sampai Anda mematikannya.': 'It rings until you turn it off.',
  'Coba bunyikan': 'Test the sound',
  'Notifikasi AURA dimatikan, jadi alarm SOS tidak bisa berbunyi. '
          'Nyalakan di Pengaturan Android.':
      "AURA notifications are turned off, so the SOS alarm can't ring. Turn "
      'them on in Android Settings.',

  // --------------------------------------------------- tombol SOS (anak)
  'Membunyikan alarm di HP orang tuamu kalau kamu menekan tombol darurat':
      "Sounds an alarm on your parents' phone when you press the emergency "
      'button',
  'HP orang tuamu berbunyi dan bergetar terus sampai mereka mematikannya, '
          'walau sedang dalam mode senyap. Ponselmu sendiri tidak berbunyi. '
          'Alarm butuh internet; kalau internetmu mati, kamu bisa menelepon '
          'orang tuamu dari layar yang sama.':
      "Your parents' phone rings and vibrates until they turn it off, even "
      'on silent. Your own phone stays quiet. The alarm needs internet; if '
      'yours is down, you can call your parents from the same screen.',
  'Peringatan belum terkirim': "The alert wasn't sent",
  'Tetap di tempat yang ramai dan terang kalau bisa.':
      'Stay somewhere busy and well-lit if you can.',
  'HP orang tuamu akan berbunyi alarm dan bergetar sampai mereka '
          'mematikannya.':
      "Your parents' phone will ring an alarm and vibrate until they turn it "
      'off.',
  'Alarm di HP orang tuamu belum berbunyi, karena peringatannya belum '
          'terkirim.':
      "The alarm on your parents' phone hasn't rung, because the alert "
      "wasn't sent.",
  'Lokasimu belum terkirim karena internet sedang tidak tersambung. Kalau '
          'kamu menelepon orang tuamu, sebutkan kamu di mana.':
      "Your location wasn't sent because the internet isn't connected. If "
      'you call your parents, tell them where you are.',
  'Internet sedang tidak tersambung. Coba kirim lagi, atau telepon orang '
          'tuamu.':
      "The internet isn't connected. Try sending again, or call your "
      'parents.',
  'Internet sedang tidak tersambung. Coba kirim lagi, atau minta tolong '
          'orang dewasa di dekatmu.':
      "The internet isn't connected. Try sending again, or ask an adult near "
      'you for help.',
  'Coba kirim lagi': 'Try sending again',
  'Telepon orang tua': 'Call your parents',
  'Tutup': 'Close',

  // ------------------------------------------------ tanpa internet
  'Menunggu internet': 'Waiting for internet',
  'Peringatan dan status anak belum bisa dimuat. Begitu internet '
          'tersambung, semuanya muncul di sini, termasuk alarm SOS yang '
          'tertunda.':
      "Alerts and your child's status can't load yet. They will appear here "
      "once you're online, including any delayed SOS alarm.",

  // ------------------------------------------------ jam istirahat
  'Sen': 'Mon',
  'Sel': 'Tue',
  'Rab': 'Wed',
  'Kam': 'Thu',
  'Jum': 'Fri',
  'Sab': 'Sat',
  'Min': 'Sun',
  'Tidak aktif': 'Off',
  'setiap hari': 'every day',
  'Senin – Jumat': 'Monday – Friday',
  'akhir pekan': 'weekends',
  'Mengunci aplikasi pada jam istirahat dari orang tuamu':
      'Locks apps during the rest time your parents set',
  'Misalnya pukul 22.00 sampai 09.00, pada hari yang dipilih orang tuamu. '
          'AURA, telepon, dan jam alarm tetap bisa dibuka, jadi kamu selalu '
          'bisa minta tolong.':
      'For example 22.00 to 09.00, on the days your parents choose. AURA, '
      'phone calls, and your alarm clock still work, so you can always ask '
      'for help.',
  'Jam istirahat': 'Rest time',
  'Tidak diatur': 'Not set',
  'Pengunci': 'Lock',
  'Siap': 'Ready',
  'Akses penggunaan': 'Usage access',
  'Supaya AURA tahu aplikasi apa yang sedang dibuka.':
      'So AURA knows which app is open.',
  'Tampil di atas aplikasi lain': 'Display over other apps',
  'Supaya AURA bisa menutup aplikasi saat jam istirahat.':
      'So AURA can cover apps during rest time.',
  'Izinkan': 'Allow',
  'Belum siap: di HP {childName}, buka AURA > Pengaturan > Jam istirahat, '
          'lalu izinkan semuanya.':
      "Not ready: on {childName}'s phone, open AURA > Settings > Rest time, "
      'then allow everything.',
  'Tetap aktif di latar belakang': 'Keep running in the background',
  'Supaya HP tidak mematikan AURA saat jam istirahat.':
      "So the phone doesn't close AURA during rest time.",
  'Menunggu HP {childName} membuka AURA untuk memeriksa izinnya.':
      "Waiting for {childName}'s phone to open AURA and check its "
      'permissions.',
  'Belum diatur': 'Not set',
  'Mati · {when}': 'Off · {when}',
  'Ketuk untuk mengatur jam dan hari.': 'Tap to set the hours and days.',
  'Simpan dan nyalakan': 'Save and turn on',
  'Jam istirahat {childName} disimpan: {when}.':
      "{childName}'s rest time saved: {when}.",
  'Jam istirahat {childName} dimatikan.': "{childName}'s rest time is off.",
  'Jam istirahat {childName}': "{childName}'s rest time",
  'Semua aplikasi di HP anak terkunci pada jam ini. AURA (tombol SOS), '
          'telepon, dan jam alarm tetap bisa dibuka.':
      "All apps on your child's phone are locked during these hours. AURA "
      '(the SOS button), phone calls, and the alarm clock still work.',
  'Mulai': 'Start',
  'Selesai': 'End',
  'Jam mulai dan selesai tidak boleh sama.':
      "Start and end time can't be the same.",
  'Hari': 'Days',
  'Pilih minimal satu hari.': 'Choose at least one day.',
  'Hari adalah malam mulainya kunci: Senin 22.00 sampai Selasa 09.00 '
          'termasuk hari Senin.':
      'A day is the night the lock starts: Monday 22.00 to Tuesday 09.00 '
      'counts as Monday.',
  'Menyimpan...': 'Saving...',
  'Belum tersimpan. {error}': 'Not saved. {error}',
};
