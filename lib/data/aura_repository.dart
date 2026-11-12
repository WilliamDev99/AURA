import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../domain/models/app_user.dart';
import '../domain/models/evidence_item.dart';
import '../domain/models/guardian_message.dart';
import '../domain/models/lock_schedule.dart';
import '../domain/models/threat_alert.dart';
import '../domain/services/threat_analyzer.dart';

/// Pesan bila kode dari email salah atau kedaluwarsa.
const wrongCodeMessage =
    'Kode salah atau sudah kedaluwarsa. Periksa lagi, atau minta kode baru.';

/// Kontrak penyimpanan AURA.
///
/// Dua implementasi memakai kontrak ini: [DemoRepository] yang berjalan di
/// memori untuk uji coba tanpa backend, dan `FirestoreRepository` yang memakai
/// Firebase. UI tidak pernah tahu yang mana sedang dipakai.
abstract interface class AuraRepository {
  /// Pengguna yang sedang masuk, null bila belum.
  Stream<AppUser?> watchCurrentUser();

  AppUser? get currentUser;

  /// True bila perangkat menyimpan sesi dari pemakaian sebelumnya.
  ///
  /// Dipakai untuk membedakan "belum pernah masuk" dari "sedang memulihkan
  /// sesi". Tanpa pembedaan ini, layar pilihan peran sempat muncul beberapa
  /// detik setiap kali aplikasi dibuka — dan anak bisa mengetuknya.
  bool get hasStoredSession;

  /// Membuat atau memperbarui profil untuk sesi yang sedang masuk.
  ///
  /// Orang tua harus sudah masuk lewat email atau Facebook lebih dulu, supaya
  /// akunnya bisa dipulihkan setelah ganti HP atau pasang ulang aplikasi.
  /// Ponsel anak memakai akun anonim yang ditautkan lewat kode keluarga.
  Future<AppUser> signIn({
    required String name,
    required UserRole role,
    int? age,
    String? phone,
  });

  /// Akun login di perangkat ini: alamat email, atau "Facebook". Null bila
  /// belum masuk atau masih akun anonim.
  String? get accountLabel;

  /// True bila perangkat ini memakai akun anonim: ponsel anak, atau akun
  /// orang tua lama yang belum diamankan dengan email atau Facebook.
  bool get isAnonymousAccount;

  /// Mengirim kode masuk ke [email].
  ///
  /// Untuk akun orang tua lama yang masih anonim, email disambungkan ke akun
  /// itu, sehingga datanya tetap utuh.
  Future<void> requestEmailCode(String email);

  /// Memeriksa kode dari email; berhasil berarti sudah masuk.
  Future<void> verifyEmailCode({required String email, required String code});

  /// Membuka halaman login Facebook. Sesi datang belakangan, saat Facebook
  /// mengarahkan kembali ke aplikasi.
  Future<void> continueWithFacebook();

  /// True bila akun yang sedang masuk sudah punya profil AURA, yaitu orang
  /// tua lama yang masuk lagi, bukan pendaftar baru.
  Future<bool> hasProfile();

  /// Mengganti nomor HP darurat orang tua (format +62...).
  Future<void> updatePhone(String phone);

  /// Mengunggah foto profil baru (JPEG) dan menghapus foto lama.
  Future<void> uploadAvatar(Uint8List jpegBytes);

  /// Menghapus foto profil.
  Future<void> removeAvatar();

  /// Foto profil [user], atau null bila belum ada atau tidak terbaca.
  Future<ImageProvider?> avatarImage(AppUser user);

  /// Email akun yang sedang masuk; null bila belum ada (mis. akun anonim).
  String? get accountEmail;

  /// Meminta penggantian email. Kode dikirim ke email baru, dan juga ke
  /// email lama bila Supabase memakai "Secure email change".
  Future<void> requestEmailChange(String newEmail);

  /// Memeriksa kode penggantian email. True bila email sudah berganti;
  /// false bila masih menunggu kode dari email lama.
  Future<bool> confirmEmailChange({
    required String newEmail,
    required String newCode,
    String? currentCode,
  });

  Future<void> signOut();

  /// Membuat keluarga baru dan mengembalikan kode penautan 6 karakter.
  Future<String> createFamily(String familyName);

  /// Menautkan perangkat anak ke keluarga lewat kode dari perangkat orang tua.
  Future<void> joinFamilyWithCode(String code);

  /// Kode penautan aktif milik keluarga ini.
  Future<String?> pairingCode(String familyId);

  Stream<List<AppUser>> watchChildren(String familyId);

  Stream<List<ThreatAlert>> watchAlerts(String familyId);

  Future<void> raiseAlert(ThreatAlert alert);

  Future<void> updateAlertStatus(String alertId, AlertStatus status);

  Stream<List<EvidenceItem>> watchEvidence(String familyId);

  /// Menambah bukti ke ujung rantai; implementasi mengurus penyegelan hash.
  Future<EvidenceItem> appendEvidence({
    required String childId,
    required EvidenceKind kind,
    required DateTime capturedAt,
    required String description,
    required String payload,
    String? alertId,
    String? storagePath,
    String? consentNote,
  });

  Stream<List<GuardianMessage>> watchGuardianChat(String childId);

  Future<void> saveGuardianMessage(String childId, GuardianMessage message);

  /// Mencatat persetujuan anak atas pemindaian pesan.
  Future<void> recordConsent(DateTime at);

  /// Mendaftarkan token notifikasi perangkat ini agar bisa menerima peringatan.
  ///
  /// Disimpan sebagai larik karena satu orang tua sering memakai lebih dari
  /// satu perangkat, dan semuanya harus berbunyi saat anak dalam bahaya.
  Future<void> registerPushToken(String token);

  /// Melepas token saat pengguna keluar, supaya perangkat yang sudah bukan
  /// miliknya berhenti menerima peringatan keluarga ini.
  Future<void> removePushToken(String token);

  /// Nomor HP yang bisa ditelepon anak bila SOS-nya tidak terkirim: orang
  /// tua pertama di keluarga ini yang sudah mengisi nomor.
  Future<String?> emergencyNumber();

  /// Penilaian lapis kedua oleh AI untuk pesan yang lolos daftar kata.
  ///
  /// Null bila tidak tersedia (mode demo, tanpa internet, atau layanan
  /// menolak); pemindai lalu memakai hasil daftar kata saja.
  /// Balasan obrolan Aura dari AI (Qwen di Cloudflare, atau ChatGPT).
  ///
  /// Null bila tidak tersedia (mode demo, tanpa internet, fungsi belum
  /// dipasang, atau balasan ditahan penyaring); Aura lokal yang menjawab.
  Future<(String, List<String>)?> aiChat({
    required String message,
    required List<GuardianMessage> history,
  });

  Future<ThreatAssessment?> aiAssess({
    required String text,
    required String app,
  });

  /// Menyalakan atau mematikan perlindungan untuk satu anak.
  Future<void> setProtectionActive(String childId, bool active);

  /// Mengatur jam istirahat anak. Hanya orang tua sekeluarga.
  Future<void> setLockSchedule(String childId, LockSchedule schedule);

  /// Ponsel anak melaporkan apakah izin untuk mengunci aplikasi sudah ada.
  Future<void> reportLockReady(bool ready);

  /// Ponsel anak mengambil ulang profilnya sekarang juga (mis. layar baru
  /// menyala), tanpa menunggu realtime, supaya jam istirahat yang baru diubah
  /// orang tua langsung berlaku.
  Future<void> refreshProfile();

  /// Ponsel anak melaporkan apakah pemindaian chat ("Akses notifikasi")
  /// sedang menyala, supaya terlihat di ponsel orang tua.
  Future<void> reportChatScan(bool enabled);

  /// Mencatat bahwa AURA di ponsel ini sedang berjalan dan tersambung
  /// (tampil sebagai "Aktif ..." di ponsel orang tua).
  Future<void> markActive();
}
