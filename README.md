# AURA — Perlindungan Anak Berbasis AI

Aplikasi Flutter + Firebase yang menghubungkan ponsel anak dengan ponsel orang
tua. Saat ada pesan mencurigakan, ancaman, atau perundungan, orang tua menerima
peringatan beserta bukti bersegel waktu dan panduan melapor ke pihak berwajib.

> **Status:** MVP berjalan. Tanpa konfigurasi Firebase pun aplikasi langsung
> bisa dicoba karena otomatis memakai data demo di memori.

---

## Prinsip yang dipegang kode ini

AURA dibangun sebagai **perlindungan yang terbuka**, bukan alat mata-mata.
Keputusan ini bukan sekadar soal etika — aplikasi dengan perilaku *stalkerware*
(ikon disembunyikan, rekaman diam-diam) ditolak kebijakan Google Play, dan bukti
yang dikumpulkan diam-diam lebih mudah dipatahkan di persidangan.

| AURA melakukan | AURA tidak melakukan |
|---|---|
| Memindai pola bahaya di pesan, atas persetujuan anak | Merekam kamera/mikrofon diam-diam |
| Mengirim kategori risiko + kutipan pemicu ke orang tua | Mengirim seluruh isi percakapan harian |
| Menampilkan indikator "perlindungan aktif" permanen | Menyembunyikan ikon aplikasi |
| Mengambil lokasi saat anak menekan tombol darurat | Melacak lokasi terus-menerus tanpa sepengetahuan anak |
| Menelepon orang tua saat anak menekan tombol darurat | Merekam suara di sekitar anak |
| Menyimpan bukti yang tak bisa diubah siapa pun | Membiarkan bukti diedit atau dihapus |

Ruang curhat anak dengan AI Guardian **tidak bisa dibaca orang tua** — hanya
peringatan bahaya yang naik. Batas ini ditegakkan di `firestore.rules`, bukan
sekadar di UI, karena anak yang merasa dibaca diam-diam akan berhenti bercerita.

---

## Menjalankan

```bash
flutter pub get
flutter run -d chrome        # atau: flutter run -d <perangkat Android>
```

Tanpa Firebase, aplikasi memakai `DemoRepository` berisi data contoh: dua anak
terhubung, tiga peringatan, dan rantai bukti yang sudah terverifikasi.

**Mencoba alurnya:**
1. Pilih **Saya Orang Tua** → isi nama → lihat dashboard, radar ancaman, vault.
2. Keluar, lalu pilih **Ini Ponsel Anak** → beranda dengan Panic Orb.
3. Buka tab **Laporkan**, tempel contoh pesan seperti
   `jangan bilang siapa siapa ya, ini rahasia kita berdua` → peringatan dini
   muncul untuk anak, dan peringatan baru masuk ke dashboard orang tua.

---

## Arsitektur

```
lib/
├── core/            tema, router, komponen UI bersama
├── domain/
│   ├── models/      AppUser, ThreatAlert, EvidenceItem, RiskLevel, ...
│   └── services/
│       ├── threat_analyzer.dart   mesin deteksi (berjalan di perangkat)
│       ├── chain_of_custody.dart  penyegelan & verifikasi bukti
│       ├── legal_mapper.dart      pemetaan pasal + kontak resmi
│       ├── dossier_builder.dart   penyusun berkas bukti PDF
│       └── guardian_brain.dart    pendamping percakapan anak
├── data/
│   ├── aura_repository.dart   kontrak penyimpanan
│   ├── demo_repository.dart   implementasi di memori (tanpa backend)
│   ├── supabase_repository.dart   Postgres + Realtime + Auth
│   └── firestore_repository.dart
├── state/app_state.dart       orkestrasi lintas layar
└── features/
    ├── child/       beranda, Panic Orb, obrolan AI, lapor, persetujuan
    ├── parent/      dashboard, vault forensik, aksi hukum, penautan
    └── shared/      pengaturan & transparansi
```

UI tidak pernah tahu repositori mana yang dipakai, sehingga seluruh alur bisa
diuji tanpa menyentuh jaringan.

### Dua lapis deteksi

1. **Di perangkat** (`threat_analyzer.dart`) — aturan leksikal Bahasa Indonesia
   termasuk ragam gaul dan penyamaran huruf (`k1r1m f0t0`, `a-n-j-i-n-g`,
   `anjjjing`). Sinyal digabung secara *noisy-OR*, bukan dijumlahkan, supaya
   satu umpatan tidak melompat ke level kritis. Mayoritas percakapan selesai di
   sini dan tidak pernah meninggalkan ponsel.
2. **Di server** (`functions/src/analyze.ts`) — opsional, untuk kasus ambigu.
   Memanggil Claude lewat Cloud Function sehingga kunci API tidak pernah ada di
   perangkat.

### Rantai bukti

Setiap bukti menyimpan SHA-256 isinya dan hash gabungan yang mengikatnya ke
bukti sebelumnya. Mengubah isi, menghapus entri, atau menyisipkan entri di
tengah akan memutus rantai dan terdeteksi saat verifikasi — lihat
`test/chain_of_custody_test.dart`. Penulisan bukti di Firestore memakai
transaksi agar dua bukti yang masuk bersamaan tidak memakai nomor urut yang sama.

---

### Jalur notifikasi ke orang tua

```
HP anak                    backend                      HP orang tua
 deteksi ancaman  ──►  tabel alerts (baris baru)
                              │
                              ▼
                       notify-parents  ──► FCM ──►  notifikasi muncul
                      (Edge Function)              ketuk ──► rincian
```

Perangkat orang tua mendaftarkan dirinya saat masuk
([push_service.dart](lib/core/services/push_service.dart)), dan melepas diri
saat keluar. Peringatan risiko rendah tidak dikirim sebagai push, hanya tampil
di dashboard, supaya orang tua tidak berhenti memperhatikan.

**Kenapa masih ada Firebase di jalur Supabase?** Supabase tidak menyediakan
layanan push, dan FCM adalah satu-satunya cara resmi mengirim notifikasi ke
perangkat Android. Jadi Supabase memegang basis data dan server, FCM hanya
bertugas sebagai kurir. Keduanya gratis: yang menuntut kartu kredit adalah
Cloud Functions milik Firebase, dan Edge Function menggantikan peran itu.

### Tombol darurat menelepon orang tua

Saat anak menekan Panic Orb, setelah hitung mundur 3 detik, AURA mengirim
peringatan beserta lokasi **dan sekaligus menelepon HP orang tua** lewat
jaringan seluler biasa
([emergency_call_service.dart](lib/domain/services/emergency_call_service.dart)).

- Nomor diisi orang tua saat masuk, lalu disimpan di HP anak
  (`shared_preferences`). Jadi telepon tetap jalan **tanpa internet**, justru
  saat peringatan lewat Supabase tidak bisa terkirim.
- Izin `CALL_PHONE` diminta di layar persetujuan anak, bukan saat darurat.
  Tanpa izin itu, aplikasi Telepon dibuka dengan nomor sudah terisi.
- Lembar konfirmasi jujur: menyebut apakah peringatan, lokasi, dan telepon
  benar-benar berhasil. Anak tidak boleh mengira orang tuanya sudah tahu
  padahal belum.
- **Telepon lewat WhatsApp.** Bila WhatsApp terpasang, lembar konfirmasi
  punya tombol "Telepon lewat WhatsApp", untuk HP tanpa pulsa atau tablet
  tanpa SIM selama ada internet. Telepon seluler tetap jalur utama; WhatsApp
  hanya saat anak menekannya. WhatsApp tidak punya cara resmi untuk memulai
  panggilan dari aplikasi lain, jadi AURA membuka baris "Panggilan suara"
  yang WhatsApp tambahkan ke Kontak
  ([WhatsAppContact.kt](android/app/src/main/kotlin/id/aura/aura/WhatsAppContact.kt)).
  Baris itu hanya ada untuk nomor yang tersimpan di Kontak, jadi AURA
  **menyimpan nomor orang tua ke Kontak** perangkat anak bila belum ada (saat
  persetujuan dan setiap kali nomornya berganti), jauh sebelum darurat supaya
  WhatsApp sempat mengenalinya. Izin Kontak diminta di layar persetujuan,
  hanya bila WhatsApp terpasang. Pengaturan anak menampilkan baris "Telepon
  WhatsApp": siap langsung menelepon, atau tombol "Siapkan". Selama belum
  siap, tombol saat SOS membuka chat WhatsApp orang tua.

### Pemindaian chat masuk

Di ponsel anak, `AuraNotificationListener`
([AuraNotificationListener.kt](android/app/src/main/kotlin/id/aura/aura/AuraNotificationListener.kt))
membaca notifikasi dari WhatsApp, Instagram, Threads, Telegram, Messenger,
Facebook, LINE, Discord, TikTok, Snapchat, X, Roblox, MiChat, WeChat, Signal,
Viber, dan SMS. Aplikasi lain tidak pernah dibaca. YouTube sengaja tidak
dipantau: notifikasinya kebanyakan video baru, sehingga judul video akan
memicu peringatan palsu.
Teksnya diperiksa **di ponsel anak** oleh `ThreatAnalyzer`; hanya pesan
berbahaya yang dikirim ke orang tua, lengkap dengan nama aplikasi dan
pengirimnya.

- Anak sendiri yang menyalakan **Akses notifikasi** untuk AURA, setelah
  menyetujui perlindungan. Statusnya terlihat di Pengaturan aplikasi anak
  **dan di dashboard orang tua**: ponsel anak melaporkannya saat aplikasi
  dibuka, saat kembali dari Pengaturan Android, dan seketika saat akses
  dicabut. Orang tua melihat "PEMINDAIAN CHAT MATI" bila aksesnya dimatikan,
  supaya tidak mengira chat anak masih terpantau.
- Dari TikTok dan Instagram hanya DM, permintaan pesan, komentar, dan sebutan
  yang dipindai. Notifikasi video baru, rekomendasi, live, dan like diabaikan
  ([ChannelFilter.kt](android/app/src/main/kotlin/id/aura/aura/ChannelFilter.kt))
  karena caption-nya memicu peringatan palsu. Kanal yang belum dikenal tetap
  dipindai, termasuk "Heytap PUSH" di ponsel realme/OPPO.
- Tidak memindai saat orang tua menjeda perlindungan, dan tidak pernah di
  ponsel orang tua.
- Layar aplikasi dan pemindai memakai **satu mesin Flutter**
  ([AuraEngine.kt](android/app/src/main/kotlin/id/aura/aura/AuraEngine.kt)).
  Dua mesin berarti dua klien Supabase yang bisa saling memperbarui token dan
  membuat Supabase mencabut sesi anak, padahal akun anak anonim dan tidak bisa
  dipulihkan.

**Lapis AI (mati secara bawaan).** Semua pemeriksaan berjalan di ponsel anak.
Kode lapis AI disimpan untuk dipakai nanti: jalankan aplikasi dengan
`--dart-define=AURA_AI_SCAN=true` dan sesuaikan teks persetujuan anak.
Jangan memakai Gemini API: syaratnya melarang aplikasi yang ditujukan atau
kemungkinan diakses pengguna di bawah 18 tahun. Bila dinyalakan, pesan yang
lolos daftar kata dinilai Claude lewat Edge Function
[analyze-message](supabase/functions/analyze-message/index.ts), dengan keluaran
JSON terstruktur. Kunci API hanya ada di server, fungsi itu hanya melayani
ponsel anak yang sudah menyetujui, dan isi pesan tidak pernah ditulis ke log.
Tanpa internet, ponsel kembali memakai daftar kata saja. Pemasangan:

1. Buat kunci API di [console.anthropic.com](https://console.anthropic.com),
   simpan sebagai rahasia `ANTHROPIC_API_KEY` di **Edge Functions → Secrets**.
2. **Deploy a new function → Via Editor**, nama `analyze-message`, tempel isi
   berkas di atas. Biarkan **Verify JWT** menyala.
3. Opsional: rahasia `AURA_CLASSIFIER_MODEL` untuk mengganti model (bawaan
   `claude-opus-5-5`).

Menguji di emulator tanpa aplikasi chat:

```bash
adb shell cmd notification allow_listener id.aura.aura/id.aura.aura.AuraNotificationListener
adb emu sms send 08123456789 "kirim foto tanpa baju dong"
```

### Obrolan Aura dengan AI

Obrolan biasa dibalas **Gemma 4** (`@cf/google/gemma-4-26b-a4b-it`, buatan
Google DeepMind) di **Cloudflare Workers AI** lewat Edge Function
[aura-chat](supabase/functions/aura-chat/index.ts). Gratis dengan kuota
harian akun Cloudflare (dibagi semua anak), isi obrolan tidak dipakai melatih
AI, dan Gemma 4 berlisensi Apache 2.0 tanpa batas umur, jadi untuk semua umur.
Bila kuota habis, internet mati, AI lebih lambat dari 18 detik, atau balasan
ditahan penyaring, Aura lokal
([guardian_dialogue.dart](lib/domain/services/guardian_dialogue.dart)) yang
menjawab.

- Pesan berbahaya tidak pernah dikirim ke AI: ponsel menanganinya sendiri
  dan memberi tahu orang tua.
- Balasan AI disaring Llama Guard 3 sebelum sampai ke anak.
- Anak diberi tahu di layar persetujuan dan di halaman obrolan bahwa Aura
  dibantu AI.

Pemasangan, di **Edge Functions → Secrets**: `CLOUDFLARE_ACCOUNT_ID` dan
`CLOUDFLARE_API_TOKEN` (izin *Workers AI*), lalu deploy `aura-chat`. Model bisa
diganti lewat `CLOUDFLARE_MODEL` tanpa memasang ulang aplikasi. Matikan dari
aplikasi dengan `--dart-define=AURA_AI_CHAT=false`.

ChatGPT juga didukung (`AURA_AI_PROVIDER=openai`, `OPENAI_API_KEY`), tetapi
berbayar dan khusus anak 13+: OpenAI mensyaratkan *Zero Data Retention* untuk
anak di bawah 13. Jangan memakai Gemini API: syaratnya melarang aplikasi yang
ditujukan atau kemungkinan diakses pengguna di bawah 18 tahun.

### Bahasa (Indonesia / English)

Bahasa tampilan dipilih di **Profil → Bahasa** dan disimpan per perangkat.
Teks di kode tetap ditulis dalam bahasa Indonesia dan dibungkus `tr('...')`
([l10n.dart](lib/core/l10n/l10n.dart)); terjemahannya ada di
[strings_en.dart](lib/core/l10n/strings_en.dart) dan
[strings_en_app.dart](lib/core/l10n/strings_en_app.dart). Saat bahasa
berganti, seluruh tampilan dibangun ulang di tempat tanpa menutup halaman.

Yang sengaja **tetap bahasa Indonesia**:

- Deteksi ancaman dan kata kunci pengenal Aura: keduanya membaca pesan
  berbahasa Indonesia.
- Data yang tersimpan dan tersegel hash: ringkasan peringatan, deskripsi
  bukti, keterangan lokasi, nama platform. Mengubahnya akan merusak bukti.
- Berkas bukti PDF untuk penyidik dan rujukan pasal.
- Nilai tombol balasan cepat Aura (labelnya diterjemahkan, yang dikirim
  tetap teks aslinya supaya dikenali).

[l10n_coverage_test.dart](test/l10n_coverage_test.dart) gagal bila ada teks
`tr()`, label kategori, konten hukum, atau tombol Aura yang belum punya
terjemahan.

### Peta lokasi anak

Bukti lokasi dari tombol darurat ditampilkan sebagai peta bergaya Leaflet
([location_map.dart](lib/core/widgets/location_map.dart)), memakai flutter_map
(pustaka Leaflet untuk Flutter) dan ubin OpenStreetMap, dengan lingkaran
akurasi. Peta bisa digeser, dicubit, dan diketuk dua kali untuk memperbesar,
dengan tombol +/- dan "kembali ke lokasi anak" di kiri atas. Mengetuk peta tidak
membuka apa pun; Google Maps hanya dibuka lewat tombol **Buka di Google Maps**
di bawah peta. Koordinat dibaca
dari teks bukti yang tersegel hash, jadi peta selalu menunjuk titik yang sama
dengan yang bisa diverifikasi penyidik.

## Menyambungkan backend

Aplikasi memilih penyimpanan secara otomatis dengan urutan: **Supabase →
Firebase → data demo**. Tanpa konfigurasi apa pun, ia tetap jalan dengan data
demo, yang terlihat di log sebagai
`AURA: belum ada backend yang dikonfigurasi`.

### Pilihan A — Supabase (disarankan, tanpa kartu kredit)

1. Buat project gratis di [supabase.com](https://supabase.com).
2. Buka **SQL Editor → New query**, tempel seluruh isi
   [supabase/schema.sql](supabase/schema.sql), lalu **Run**.
   Project yang dibuat lebih awal cukup menjalankan patch yang belum
   dijalankan, berurutan:
   [patch_02_parent_phone.sql](supabase/patch_02_parent_phone.sql) (nomor HP
   orang tua untuk telepon darurat),
   [patch_03_chat_scan_status.sql](supabase/patch_03_chat_scan_status.sql)
   (status pemindaian chat yang terlihat di HP orang tua),
   [patch_04_profile_photo.sql](supabase/patch_04_profile_photo.sql) (foto
   profil di bucket privat, dan penjagaan profil yang lebih ketat), dan
   [patch_05_fix_avatar_read.sql](supabase/patch_05_fix_avatar_read.sql)
   (perbaikan aturan baca foto untuk yang sudah menjalankan patch 04).
3. Buka **Authentication → Providers → Anonymous**, nyalakan. Ini untuk
   ponsel anak, yang ditautkan lewat kode keluarga.
4. Buka **Project Settings → API**, salin *Project URL* dan *Publishable key*
   ke [lib/supabase_options.dart](lib/supabase_options.dart).
5. Siapkan login orang tua (lihat bagian berikut).

Sampai di sini dashboard orang tua sudah bekerja lintas perangkat.

### Login orang tua: email + kode, dan Facebook

Orang tua masuk dengan email + kode 6 digit atau dengan Facebook, supaya
akunnya bisa dipulihkan setelah ganti HP atau pasang ulang aplikasi. Ponsel
anak tetap memakai akun anonim. Akun orang tua lama yang masih anonim melihat
kartu **Amankan akun Anda** di tab Profil, dan email atau Facebook
disambungkan ke akun yang sama tanpa kehilangan data.

**Email + kode**

1. **Authentication → Email Templates**: di templat *Confirm signup*,
   *Magic Link*, dan *Change Email Address*, ganti isinya agar memuat kode,
   bukan tautan, misalnya:
   `<h2>Kode masuk AURA</h2><p>Kode Anda: <strong>{{ .Token }}</strong></p>
   <p>Berlaku beberapa menit. Jangan berikan kode ini kepada siapa pun.</p>`
2. Pengirim email bawaan Supabase hanya mengirim ke email anggota tim proyek
   dan dibatasi per jam: cukup untuk mencoba, tidak untuk pengguna
   sungguhan. Untuk peluncuran, sambungkan layanan email (Resend, Brevo, dan
   lain-lain) di **Authentication → SMTP**, lalu naikkan batasnya di
   **Authentication → Rate Limits**.

**Facebook**

1. Di [developers.facebook.com](https://developers.facebook.com), buat
   aplikasi dengan produk **Facebook Login**. Isi *Valid OAuth Redirect
   URIs* dengan `https://<project-ref>.supabase.co/auth/v1/callback`.
2. Salin *App ID* dan *App Secret* ke **Authentication → Sign In / Providers
   → Facebook**, lalu nyalakan.
3. **Authentication → URL Configuration → Redirect URLs**: tambahkan
   `id.aura.aura://login-callback`. Alamat ini cocok dengan intent-filter di
   [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml).
4. **Authentication → Sign In / Providers**: nyalakan **Manual linking**,
   supaya akun lama yang anonim bisa disambungkan ke Facebook.
5. Selama aplikasi Facebook masih *Development mode*, hanya akun yang
   terdaftar sebagai admin, developer, atau tester yang bisa masuk. Ubah ke
   *Live* sebelum diluncurkan.

### Notifikasi push (semua lewat browser, tanpa CLI)

Supabase tidak punya layanan push, jadi notifikasi Android lewat Firebase Cloud
Messaging (gratis, paket Spark, tanpa kartu kredit).

**Firebase**
1. [console.firebase.google.com](https://console.firebase.google.com) →
   **Create a project** (Google Analytics boleh dimatikan).
2. **Add app → Android**, package name `id.aura.aura`. Unduh
   `google-services.json`, simpan di `android/app/`, lalu jalankan
   `python -I tool/firebase_options_from_json.py`.
3. **Project settings → Service accounts → Generate new private key.** Berkas
   JSON ini **rahasia**: jangan dimasukkan ke aplikasi atau repositori.

**Supabase**
4. **Edge Functions → Secrets**: tambah `FCM_SERVICE_ACCOUNT`, isi dengan
   seluruh isi berkas JSON dari langkah 3.
5. **Edge Functions → Deploy a new function → Via Editor**, nama
   `notify-parents`, tempel isi
   [supabase/functions/notify-parents/index.ts](supabase/functions/notify-parents/index.ts).
6. **Database → Webhooks → Create a new hook**: tabel `alerts`, event
   `Insert`, tipe *Supabase Edge Functions*, fungsi `notify-parents`, dan
   nyalakan **Add auth header with service key**.

Fungsi itu membaca ulang peringatan dari basis data berdasarkan id-nya, jadi
permintaan palsu ke alamat fungsi tidak bisa mengarang isi notifikasi.

Judul dan bunyi notifikasi (`pushMessageFor`):

| Peringatan | Judul | Kanal |
|---|---|---|
| Tombol SOS | Darurat: {anak} menekan tombol SOS | Darurat (mendesak) |
| HARD, ancaman serius | Darurat: {anak} butuh bantuan | Darurat (mendesak) |
| HARD, kata kasar saja | HARD: {anak} menerima kata kasar berat | biasa |
| MEDIUM | MEDIUM: {anak} menerima pesan berisiko | biasa |
| LOW | LOW: ada yang perlu Anda ketahui tentang {anak} | biasa |

Setiap kali `index.ts` berubah, tempel ulang isinya di **Edge Functions →
notify-parents → Code**, lalu **Deploy**.
Perangkat dialamatkan lewat Firebase Installation ID (`fid`), sesuai
`FirebaseMessaging.register()` di firebase_messaging 17.

### Memeriksa project Supabase

```bash
python tool/verify_supabase.py
```

Menjalankan 17 pemeriksaan terhadap project sungguhan memakai sesi anonim
biasa, termasuk **mencoba mengubah dan menghapus bukti** untuk memastikan
penguncinya bekerja. Catatan: skrip ini meninggalkan satu keluarga uji di basis
data, dan bukti di dalamnya memang tidak bisa dihapus — itu justru yang diuji.

### Pilihan B — Firebase penuh

Butuh paket Blaze karena Cloud Functions tidak tersedia di paket gratis.

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli

firebase login
dart pub global run flutterfire_cli:flutterfire configure
firebase deploy --only functions:onAlertCreated,firestore:rules,firestore:indexes
```

| Fungsi | Jenis | Kegunaan |
|---|---|---|
| `onAlertCreated` | Pemicu Firestore | Mengirim push ke perangkat orang tua |
| `analyzeMessage` | Callable | Analisis lapis kedua dengan Claude untuk pesan ambigu |

Berjalan di region `asia-southeast2` (Jakarta). `analyzeMessage` memakai
`claude-opus-5-5` dan butuh `firebase functions:secrets:set ANTHROPIC_API_KEY`.
Karena classifier ini jalan per pesan, biayanya naik seiring volume — bila
perlu lebih murah, ganti konstanta `MODEL` ke `claude-haiku-5-5` lalu ukur
ulang akurasinya.

### Catatan untuk FCM

Apa pun pilihan backend-nya, notifikasi Android tetap lewat FCM.
`lib/firebase_options.dart` bisa diisi dengan `flutterfire configure` atau,
tanpa CLI, dengan `tool/firebase_options_from_json.py` (lihat di atas).

---

## Maskot dan ikon aplikasi

Gambar maskot asli (`design/aura_mascot_original.png`) berlatar putih,
sedangkan robotnya sendiri didominasi warna putih. Karena itu latarnya
dihapus dengan skrip, bukan dengan "hapus semua putih":

```bash
python -I tool/make_mascot_assets.py   # latar dihapus, kepala dipotong, bahan ikon dibuat
dart run flutter_launcher_icons        # ikon Android, web, Windows
```

| Berkas | Dipakai untuk |
|---|---|
| `assets/images/aura_mascot.png` | Maskot seluruh badan di beranda anak |
| `assets/images/aura_mascot_head.png` | Avatar bulat (`AuraMascot`) di layar lain |
| `design/app_icon*.png` | Bahan ikon aplikasi dan ikon adaptif Android |

Skripnya memanfaatkan dua fakta terukur pada gambar asli: latarnya putih murni
(tepat 255), sedangkan tepi plastik robot bernilai 244–251. Latar disapu dari
tepi gambar hanya melewati piksel bernilai tepat 255, jadi badan robot tidak
ikut terhapus. Kepala dipotong di leher, yaitu baris tersempit antara kepala
dan bahu.

Mengganti maskot cukup dengan menimpa `design/aura_mascot_original.png` lalu
menjalankan dua perintah di atas. Untuk hasil paling tajam, pakai gambar
minimal 1024 piksel; gambar sekarang 540 × 540.

## Pengujian

```bash
flutter test          # 482 test
cd android && ./gradlew :app:testDebugUnitTest   # 13 test Kotlin (saringan kanal, judul notifikasi, kontak WhatsApp)
cd functions && npm run build
```

| Berkas | Cakupan |
|---|---|
| `test/threat_analyzer_test.dart` | Deteksi per kategori, normalisasi penyamaran huruf, kalibrasi skor, peredaman alarm palsu |
| `test/chain_of_custody_test.dart` | Integritas bukti: perubahan isi, penghapusan di tengah, pemindahan antar-rantai |
| `test/app_state_test.dart` | Alur ujung-ke-ujung: pemindaian, laporan anak, tombol darurat, eskalasi dari obrolan AI |
| `test/app_smoke_test.dart` | Render UI dan perpindahan antar-peran |
| `test/resilient_stream_test.dart` | Langganan realtime pulih sendiri setelah token kedaluwarsa atau jaringan putus |
| `test/panic_countdown_test.dart` | Panic Orb: terkirim setelah 3 detik, bisa dibatalkan, ketukan kedua langsung mengirim; menelepon orang tua, termasuk tanpa internet, tanpa nomor, dan tanpa izin telepon |
| `test/notification_scanner_test.dart` | Pesan dari notifikasi: berbahaya diteruskan, aman tidak, tanpa duplikat, berhenti saat dijeda |
| `test/alert_handled_test.dart` | Konfirmasi "sudah ditangani" dan hilangnya peringatan dari dashboard |
| `test/geo_point_test.dart` | Pembacaan koordinat dari bukti lokasi, peta tetap tampil tanpa internet, tombol zoom, peta bisa digeser |
| `test/phone_number_test.dart` | Validasi dan normalisasi nomor HP Indonesia orang tua |

---

## Yang belum dikerjakan

Ini MVP; sebelum dipakai keluarga sungguhan, bagian berikut perlu diselesaikan:

- **Pengungkapan izin untuk Play Store.** `NotificationListenerService` butuh
  formulir deklarasi dan alasan fitur inti sebelum bisa dirilis di Play Store.
- **Autentikasi sungguhan.** Masuk saat ini memakai nama + anonymous auth. Ganti
  dengan surel/sandi atau nomor telepon untuk orang tua.
- **Enkripsi ujung-ke-ujung** untuk isi bukti sebelum diunggah.
- **Kepastian telepon diangkat.** Android tidak memberi tahu aplikasi apakah
  panggilan dijawab, jadi AURA belum bisa beralih otomatis ke orang tua kedua.
- **Penyedia ubin peta.** Peta memakai server ubin publik OpenStreetMap, yang
  hanya boleh untuk pemakaian ringan. Sebelum rilis, pindah ke penyedia dengan
  paket gratis/berbayar (mis. MapTiler atau Stadia Maps).
- **Validasi pemetaan pasal oleh advokat.** Isi `legal_mapper.dart` disusun dari
  teks undang-undang, tetapi belum ditinjau praktisi hukum.

---

## Catatan hukum

Pemetaan pasal di aplikasi bersifat informasi umum untuk membantu orang tua
menyiapkan laporan, bukan nasihat hukum. Penetapan pasal adalah kewenangan
penyidik. Untuk pendampingan: **SAPA 129**, **Polisi 110**, **UPTD PPA** daerah.
