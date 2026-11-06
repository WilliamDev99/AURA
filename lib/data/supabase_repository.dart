import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/l10n/l10n.dart';
import '../core/utils/resilient_stream.dart';
import '../domain/models/app_user.dart';
import '../domain/models/evidence_item.dart';
import '../domain/models/guardian_message.dart';
import '../domain/models/risk.dart';
import '../domain/models/threat_alert.dart';
import '../domain/services/chain_of_custody.dart';
import '../domain/services/threat_analyzer.dart';
import '../supabase_options.dart';
import 'aura_repository.dart';

/// Implementasi penyimpanan di atas Supabase (PostgreSQL + Realtime + Auth).
///
/// Skema dan kebijakan aksesnya ada di `supabase/schema.sql`. Jaminan penting
/// ditegakkan basis data, bukan aplikasi: bukti tidak bisa diubah atau dihapus
/// oleh siapa pun dari sisi klien, dan ruang curhat anak tidak bisa dibaca
/// orang tua.
class SupabaseRepository implements AuraRepository {
  SupabaseRepository({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;
  static const _custody = ChainOfCustody();

  AppUser? _cached;

  @override
  AppUser? get currentUser => _cached;

  GoTrueClient get _auth => _db.auth;

  @override
  bool get hasStoredSession => _auth.currentSession != null;

  @override
  Stream<AppUser?> watchCurrentUser() {
    // Sengaja tidak memakai `asyncExpand`: operator itu menunggu stream di
    // dalamnya selesai sebelum memproses event berikutnya, padahal stream
    // realtime tidak pernah selesai. Akibatnya `tokenRefreshed` dan
    // `signedOut` tertahan selamanya. Di sini langganan profil diganti setiap
    // kali pengguna berganti.
    StreamSubscription<AuthState>? authSub;
    StreamSubscription<List<Map<String, dynamic>>>? profileSub;
    String? watchedUid;
    late final StreamController<AppUser?> controller;

    controller = StreamController<AppUser?>(
      onListen: () {
        authSub = _auth.onAuthStateChange.listen((state) {
          final session = state.session;

          // Saat aplikasi dibuka setelah lama tidak dipakai, sesi tersimpan
          // sudah kedaluwarsa. Berlangganan dengan token itu pasti ditolak;
          // tunggu `tokenRefreshed` yang datang sesaat kemudian.
          if (state.event == AuthChangeEvent.initialSession &&
              session != null &&
              session.isExpired) {
            return;
          }

          final uid = session?.user.id;
          // Pembaruan token tidak mengganti pengguna: langganan lama tetap
          // berlaku dan klien realtime sudah memakai token barunya.
          if (uid == watchedUid && uid != null) return;
          watchedUid = uid;

          profileSub?.cancel();
          profileSub = null;

          if (uid == null) {
            _cached = null;
            controller.add(null);
            return;
          }

          profileSub =
              resilientStream(
                () => _db
                    .from('profiles')
                    .stream(primaryKey: ['id'])
                    .eq('id', uid),
              ).listen((rows) async {
                if (rows.isNotEmpty) {
                  _cached = _userFromRow(rows.first);
                  controller.add(_cached);
                  return;
                }
                // Akun email atau Facebook yang baru mendaftar belum punya
                // profil. Dipastikan dulu lewat kueri biasa, karena daftar
                // kosong sesaat juga bisa muncul sebelum data pertama tiba.
                // Tanpa kabar ini, layar memuat tertahan selamanya.
                if (await hasProfile()) return;
                if (watchedUid != uid) return;
                _cached = null;
                controller.add(null);
              });
        });
      },
      onCancel: () async {
        await profileSub?.cancel();
        await authSub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<AppUser> signIn({
    required String name,
    required UserRole role,
    int? age,
    String? phone,
  }) async {
    var session = _auth.currentSession;
    if (role == UserRole.parent) {
      // Akun orang tua harus bisa dipulihkan setelah ganti HP atau pasang
      // ulang aplikasi, jadi tidak boleh anonim.
      if (session == null || session.user.isAnonymous) {
        throw StateError(tr('Masuk dulu dengan email atau Facebook.'));
      }
    } else if (session != null && !session.user.isAnonymous) {
      // Ponsel ini sebelumnya masuk dengan akun orang tua yang belum selesai
      // mendaftar. Akun itu tidak boleh berubah menjadi akun anak.
      await _auth.signOut();
      session = null;
    }
    // Ponsel anak memakai akun anonim: penautannya lewat kode keluarga.
    session ??= (await _auth.signInAnonymously()).session;
    final uid = session?.user.id;
    if (uid == null) throw StateError(tr('Gagal membuat sesi pengguna.'));

    final existing = await _db
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    final row = await _db
        .from('profiles')
        .upsert({
          'id': uid,
          'name': name,
          // Peran dikunci setelah dibuat; kirim ulang nilai lama bila ada.
          'role': (existing?['role'] as String?) ?? role.name,
          'age': ?age,
          // Hanya ditulis bila diisi, supaya nomor yang sudah ada tidak
          // tertimpa kosong saat pengguna masuk ulang.
          'phone': ?phone,
          'family_id': existing?['family_id'],
          'device_label':
              existing?['device_label'] ??
              (role == UserRole.child ? 'Ponsel Anak' : 'Ponsel Orang Tua'),
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    _cached = _userFromRow(row);
    return _cached!;
  }

  @override
  Future<void> signOut() async {
    _cached = null;
    _linkingEmail = null;
    await _auth.signOut();
  }

  /// Alamat yang dibuka Facebook setelah login selesai. Harus terdaftar di
  /// Supabase (Authentication > URL Configuration > Redirect URLs) dan cocok
  /// dengan intent-filter di AndroidManifest.xml.
  static const authRedirect = 'id.aura.aura://login-callback';

  /// Email yang sedang menunggu kode untuk disambungkan ke akun anonim lama.
  String? _linkingEmail;

  @override
  String? get accountLabel {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    final email = user.email;
    if (email != null && email.isNotEmpty) return email;
    final providers = user.appMetadata['providers'];
    if (providers is List && providers.contains('facebook')) return 'Facebook';
    return tr('akun Anda');
  }

  @override
  bool get isAnonymousAccount => _auth.currentUser?.isAnonymous ?? false;

  /// Akun anonim yang sudah punya profil: orang tua lama yang ingin
  /// mengamankan akunnya. Akun anonim tanpa profil hanyalah sisa percobaan
  /// masuk yang tidak selesai dan boleh ditinggalkan.
  Future<bool> _isUpgradingAnonymous() async =>
      isAnonymousAccount && await hasProfile();

  @override
  Future<void> requestEmailCode(String email) async {
    final address = email.trim().toLowerCase();
    try {
      if (await _isUpgradingAnonymous()) {
        // Email disambungkan ke akun yang sama: id, keluarga, peringatan,
        // dan bukti tidak berubah.
        await _auth.updateUser(UserAttributes(email: address));
        _linkingEmail = address;
        return;
      }
      if (isAnonymousAccount) await _auth.signOut();
      _linkingEmail = null;
      await _auth.signInWithOtp(email: address, shouldCreateUser: true);
    } on AuthException catch (error) {
      throw _authError(error);
    }
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final address = email.trim().toLowerCase();
    final linking = _linkingEmail == address;
    try {
      await _auth.verifyOTP(
        email: address,
        token: code.trim(),
        type: linking ? OtpType.emailChange : OtpType.email,
      );
    } on AuthException catch (error) {
      throw _authError(error);
    }
    _linkingEmail = null;
    // Setelah email disambungkan, token lama masih menyebut akun anonim.
    if (linking) await _auth.refreshSession();
  }

  @override
  Future<void> continueWithFacebook() async {
    await _ensureProviderEnabled('facebook', 'Facebook');
    final bool launched;
    try {
      if (await _isUpgradingAnonymous()) {
        // Butuh "Manual linking" menyala di Supabase (Authentication >
        // Sign In / Providers).
        launched = await _auth.linkIdentity(
          OAuthProvider.facebook,
          redirectTo: authRedirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
      } else {
        if (isAnonymousAccount) await _auth.signOut();
        launched = await _auth.signInWithOAuth(
          OAuthProvider.facebook,
          redirectTo: authRedirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
      }
    } on AuthException catch (error) {
      throw _authError(error);
    }
    if (!launched) {
      throw StateError(
        tr(
          'Halaman Facebook tidak bisa dibuka. Pastikan ada browser di '
          'ponsel ini, lalu coba lagi.',
        ),
      );
    }
  }

  /// Memeriksa pengaturan publik Supabase sebelum membuka browser.
  ///
  /// Bila penyedia login belum dinyalakan, Supabase hanya menampilkan
  /// halaman galat teknis di browser. Lebih baik pesannya muncul di AURA.
  /// Bila pemeriksaan sendiri gagal (mis. tanpa internet), login tetap
  /// dicoba dan Supabase yang menjawab.
  Future<void> _ensureProviderEnabled(String provider, String label) async {
    Object? enabled;
    try {
      final response = await http
          .get(
            Uri.parse('${SupabaseOptions.url}/auth/v1/settings'),
            headers: {'apikey': SupabaseOptions.publishableKey},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final settings = jsonDecode(response.body);
      if (settings is! Map) return;
      final external = settings['external'];
      if (external is! Map) return;
      enabled = external[provider];
    } catch (error) {
      debugPrint('AURA: pengaturan login tidak terbaca ($error).');
      return;
    }
    if (enabled == false) {
      throw StateError(
        tr(
          'Login {label} belum dinyalakan. Di Supabase, buka '
          'Authentication > Sign In / Providers > {label}, nyalakan, '
          'lalu isi App ID dan App Secret dari developers.facebook.com.',
          {'label': label},
        ),
      );
    }
  }

  @override
  Future<bool> hasProfile() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _db
        .from('profiles')
        .select('id')
        .eq('id', uid)
        .maybeSingle();
    return row != null;
  }

  // --------------------------------------------------------------- profil

  static const _avatarBucket = 'avatars';

  /// Tautan sementara foto profil, per letak file. Foto privat: tautannya
  /// berlaku satu jam, lalu dibuat ulang.
  final _avatarUrls = <String, ({String url, DateTime expires})>{};

  @override
  Future<void> updatePhone(String phone) async {
    final uid = _requireUid();
    await _db.from('profiles').update({'phone': phone}).eq('id', uid);
  }

  @override
  Future<void> uploadAvatar(Uint8List jpegBytes) async {
    final uid = _requireUid();
    final previous = _cached?.avatarPath;
    // Nama file baru setiap kali: tautan lama yang tersimpan di perangkat
    // lain tidak menampilkan foto lama.
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _db.storage
          .from(_avatarBucket)
          .uploadBinary(
            path,
            jpegBytes,
            // Tanpa upsert: nama file selalu baru, jadi cukup izin
            // "tambah". Upsert juga butuh izin baca dan ubah.
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    } on StorageException catch (error) {
      debugPrint(
        'AURA: unggah foto ditolak Storage (status ${error.statusCode}, '
        '${error.error}): ${error.message}',
      );
      throw _storageError(error);
    }
    try {
      await _db.from('profiles').update({'avatar_path': path}).eq('id', uid);
    } on PostgrestException catch (error) {
      debugPrint(
        'AURA: foto terunggah, tetapi profil gagal diperbarui '
        '(${error.code}): ${error.message}',
      );
      rethrow;
    }
    if (previous != null && previous != path) {
      await _removeAvatarFile(previous);
    }
  }

  @override
  Future<void> removeAvatar() async {
    final uid = _requireUid();
    final previous = _cached?.avatarPath;
    await _db.from('profiles').update({'avatar_path': null}).eq('id', uid);
    if (previous != null) await _removeAvatarFile(previous);
  }

  Future<void> _removeAvatarFile(String path) async {
    _avatarUrls.remove(path);
    try {
      await _db.storage.from(_avatarBucket).remove([path]);
    } catch (error) {
      // Foto lama yang tertinggal tidak mengganggu; profil sudah menunjuk
      // foto baru.
      debugPrint('AURA: foto lama tidak terhapus ($error).');
    }
  }

  @override
  Future<ImageProvider?> avatarImage(AppUser user) async {
    final path = user.avatarPath;
    if (path == null) return null;
    final cached = _avatarUrls[path];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return NetworkImage(cached.url);
    }
    try {
      final url = await _db.storage
          .from(_avatarBucket)
          .createSignedUrl(path, 3600);
      _avatarUrls[path] = (
        url: url,
        expires: DateTime.now().add(const Duration(minutes: 55)),
      );
      return NetworkImage(url);
    } catch (error) {
      debugPrint('AURA: foto profil tidak terbaca ($error).');
      return null;
    }
  }

  static StateError _storageError(StorageException error) {
    final text = '${error.statusCode} ${error.message}'.toLowerCase();
    if (text.contains('bucket not found')) {
      return StateError(
        tr(
          'Penyimpanan foto belum disiapkan. Jalankan '
          'supabase/patch_04_profile_photo.sql di SQL Editor Supabase.',
        ),
      );
    }
    if (text.contains('payload too large') || text.contains('413')) {
      return StateError(tr('Ukuran foto terlalu besar. Pilih foto lain.'));
    }
    if (text.contains('row-level security') || text.contains('403')) {
      return StateError(
        tr(
          'Foto ditolak oleh aturan keamanan. Pastikan '
          'supabase/patch_04_profile_photo.sql sudah dijalankan.',
        ),
      );
    }
    return StateError(error.message);
  }

  // --------------------------------------------------------------- email

  @override
  String? get accountEmail {
    final email = _auth.currentUser?.email;
    return email == null || email.isEmpty ? null : email;
  }

  @override
  Future<void> requestEmailChange(String newEmail) async {
    try {
      await _auth.updateUser(
        UserAttributes(email: newEmail.trim().toLowerCase()),
      );
    } on AuthException catch (error) {
      throw _authError(error);
    }
  }

  @override
  Future<bool> confirmEmailChange({
    required String newEmail,
    required String newCode,
    String? currentCode,
  }) async {
    final target = newEmail.trim().toLowerCase();
    final currentEmail = accountEmail;
    try {
      await _auth.verifyOTP(
        email: target,
        token: newCode.trim(),
        type: OtpType.emailChange,
      );
      if (await _emailIs(target)) return true;

      // "Secure email change": email lama juga harus mengonfirmasi.
      final code = currentCode?.trim();
      if (code == null || code.isEmpty || currentEmail == null) return false;
      await _auth.verifyOTP(
        email: currentEmail,
        token: code,
        type: OtpType.emailChange,
      );
      return _emailIs(target);
    } on AuthException catch (error) {
      throw _authError(error);
    }
  }

  /// Membaca ulang akun dari server, lalu memeriksa emailnya.
  Future<bool> _emailIs(String email) async {
    try {
      await _auth.refreshSession();
    } catch (_) {}
    final user = (await _auth.getUser()).user;
    return user?.email?.toLowerCase() == email;
  }

  /// Galat login dalam bahasa yang dimengerti orang tua.
  static StateError _authError(AuthException error) {
    final code = error.code ?? '';
    final text = error.message.toLowerCase();
    if (code == 'otp_expired' ||
        text.contains('expired') ||
        text.contains('invalid')) {
      return StateError(tr(wrongCodeMessage));
    }
    if (code == 'email_exists' || code == 'identity_already_exists') {
      return StateError(
        tr(
          'Email atau akun Facebook ini sudah dipakai akun AURA lain. '
          'Keluar dulu, lalu masuk dengan akun tersebut.',
        ),
      );
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        error.statusCode == '429') {
      return StateError(
        tr(
          'Terlalu sering meminta kode. Tunggu sekitar satu menit, lalu '
          'coba lagi.',
        ),
      );
    }
    if (code == 'email_address_not_authorized') {
      return StateError(
        tr(
          'Email belum bisa dikirim ke alamat ini. Pengirim email '
          'bawaan Supabase hanya mengirim ke anggota tim proyek; '
          'sambungkan layanan email (SMTP) di Supabase > Authentication '
          '> SMTP.',
        ),
      );
    }
    if (code == 'manual_linking_disabled') {
      return StateError(
        tr(
          'Penyambungan akun belum dinyalakan. Di Supabase, buka '
          'Authentication > Sign In / Providers, lalu nyalakan "Manual '
          'linking".',
        ),
      );
    }
    if (code == 'provider_disabled' ||
        text.contains('provider is not enabled')) {
      return StateError(
        tr(
          'Cara masuk ini belum dinyalakan di Supabase (Authentication '
          '> Sign In / Providers).',
        ),
      );
    }
    if (code == 'email_address_invalid' || text.contains('email address')) {
      return StateError(
        tr('Alamat email tidak valid. Periksa lagi penulisannya.'),
      );
    }
    return StateError(error.message);
  }

  @override
  Future<String> createFamily(String familyName) async {
    final uid = _requireUid();
    final code = _generateCode();

    final family = await _db
        .from('families')
        .insert({
          'name': familyName,
          'owner_id': uid,
          'pairing_code': code,
          'pairing_expires_at': DateTime.now()
              .add(const Duration(hours: 24))
              .toUtc()
              .toIso8601String(),
        })
        .select()
        .single();

    await _db
        .from('profiles')
        .update({'family_id': family['id']})
        .eq('id', uid);

    return code;
  }

  @override
  Future<void> joinFamilyWithCode(String code) async {
    _requireUid();

    // Penautan dikerjakan fungsi `security definer` di basis data, bukan
    // dengan membaca tabel families dari sini. Anak yang belum punya keluarga
    // memang tidak boleh membaca baris keluarga mana pun: kalau dibolehkan,
    // seluruh kode penautan keluarga lain ikut terbuka.
    try {
      await _db.rpc<void>(
        'join_family_with_code',
        params: {'code': code.trim().toUpperCase()},
      );
    } on PostgrestException catch (error) {
      // Pesan dari basis data sudah ditulis untuk dibaca pengguna.
      throw StateError(error.message);
    }
  }

  @override
  Future<String?> pairingCode(String familyId) async {
    final row = await _db
        .from('families')
        .select('pairing_code')
        .eq('id', familyId)
        .maybeSingle();
    return row?['pairing_code'] as String?;
  }

  @override
  Stream<List<AppUser>> watchChildren(String familyId) {
    return resilientStream(
      () => _db
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId),
    ).map(
      (rows) => rows.map(_userFromRow).where((user) => user.isChild).toList(),
    );
  }

  @override
  Stream<List<ThreatAlert>> watchAlerts(String familyId) {
    return resilientStream(
      () => _db
          .from('alerts')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId)
          // Default stream Supabase adalah turun; ditulis eksplisit karena
          // kebanyakan API lain default-nya naik.
          .order('detected_at', ascending: false),
    ).map((rows) => rows.map(_alertFromRow).toList());
  }

  @override
  Future<void> raiseAlert(ThreatAlert alert) async {
    await _db.from('alerts').insert({
      'id': alert.id,
      'family_id': alert.familyId,
      'child_id': alert.childId,
      'child_name': alert.childName,
      'risk_level': alert.riskLevel.name,
      'categories': alert.categories.map((c) => c.name).toList(),
      'source': alert.source.name,
      'platform': alert.platform,
      'detected_at': alert.detectedAt.toUtc().toIso8601String(),
      'summary': alert.summary,
      'excerpt': alert.excerpt,
      'counterpart_name': alert.counterpartName,
      'status': AlertStatus.unread.name,
      'score': alert.score,
      'matched_signals': alert.matchedSignals,
      'latitude': alert.latitude,
      'longitude': alert.longitude,
      'location_label': alert.locationLabel,
      'evidence_ids': alert.evidenceIds,
    });
  }

  @override
  Future<void> updateAlertStatus(String alertId, AlertStatus status) async {
    await _db.from('alerts').update({'status': status.name}).eq('id', alertId);
  }

  @override
  Stream<List<EvidenceItem>> watchEvidence(String familyId) {
    return resilientStream(
      () => _db
          .from('evidence')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId)
          .order('sequence', ascending: false),
    ).map((rows) => rows.map(_evidenceFromRow).toList());
  }

  @override
  Future<EvidenceItem> appendEvidence({
    required String childId,
    required EvidenceKind kind,
    required DateTime capturedAt,
    required String description,
    required String payload,
    String? alertId,
    String? storagePath,
    String? consentNote,
  }) async {
    final familyId = _requireFamilyId();

    // Nomor urut dijaga unik oleh basis data. Bila dua bukti masuk bersamaan,
    // yang kalah mendapat galat 23505 dan mencoba lagi dengan ujung rantai
    // terbaru, alih-alih menimpa dan merusak rantainya diam-diam.
    for (var attempt = 0; attempt < 4; attempt++) {
      final tail = await _db
          .from('evidence')
          .select()
          .eq('family_id', familyId)
          .order('sequence', ascending: false)
          .limit(1)
          .maybeSingle();

      final previous = tail == null ? null : _evidenceFromRow(tail);

      final item = _custody.seal(
        id: '',
        familyId: familyId,
        childId: childId,
        kind: kind,
        capturedAt: capturedAt,
        description: description,
        payload: payload,
        previous: previous,
        alertId: alertId,
        storagePath: storagePath,
        consentNote: consentNote,
      );

      try {
        final row = await _db
            .from('evidence')
            .insert({
              'family_id': item.familyId,
              'child_id': item.childId,
              'alert_id': item.alertId,
              'kind': item.kind.name,
              'captured_at': item.capturedAt.toUtc().toIso8601String(),
              'recorded_at': item.recordedAt.toUtc().toIso8601String(),
              'description': item.description,
              'payload': item.payload,
              'content_hash': item.contentHash,
              'chain_hash': item.chainHash,
              'previous_hash': item.previousHash,
              'sequence': item.sequence,
              'storage_path': item.storagePath,
              'captured_by': item.capturedBy,
              'consent_note': item.consentNote,
            })
            .select()
            .single();

        return _evidenceFromRow(row);
      } on PostgrestException catch (error) {
        final isRace = error.code == '23505';
        if (!isRace || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
      }
    }

    throw StateError(tr('Gagal menyimpan bukti setelah beberapa percobaan.'));
  }

  @override
  Stream<List<GuardianMessage>> watchGuardianChat(String childId) {
    return resilientStream(
      () => _db
          .from('guardian_messages')
          .stream(primaryKey: ['id'])
          .eq('child_id', childId)
          // Obrolan dibaca dari atas ke bawah: pesan tertua lebih dulu.
          .order('sent_at', ascending: true),
    ).map((rows) => rows.map(_messageFromRow).toList());
  }

  @override
  Future<void> saveGuardianMessage(
    String childId,
    GuardianMessage message,
  ) async {
    await _db.from('guardian_messages').insert({
      'child_id': childId,
      'author': message.author.name,
      'text': message.text,
      'sent_at': message.sentAt.toUtc().toIso8601String(),
      'quick_replies': message.quickReplies,
      'risk_level': message.riskLevel?.name,
      'escalated': message.escalated,
    });
  }

  @override
  Future<void> recordConsent(DateTime at) async {
    final uid = _requireUid();
    await _db
        .from('profiles')
        .update({'monitoring_consent_at': at.toUtc().toIso8601String()})
        .eq('id', uid);
  }

  @override
  Future<(String, List<String>)?> aiChat({
    required String message,
    required List<GuardianMessage> history,
  }) async {
    try {
      final recent = history.length > 10
          ? history.sublist(history.length - 10)
          : history;
      final response = await _db.functions.invoke(
        'aura-chat',
        body: {
          'message': message,
          'history': [
            for (final m in recent)
              {'role': m.isChild ? 'child' : 'aura', 'text': m.text},
          ],
        },
      );
      final data = response.data;
      if (data is! Map) return null;
      final reply = (data['reply'] as String? ?? '').trim();
      if (reply.isEmpty) return null;
      final quick = data['quickReplies'];
      return (
        reply,
        quick is List ? quick.map((q) => q.toString()).toList() : <String>[],
      );
    } catch (error) {
      // Tanpa isi obrolan di log.
      debugPrint('AURA: obrolan AI tidak tersedia (${error.runtimeType}).');
      return null;
    }
  }

  @override
  Future<ThreatAssessment?> aiAssess({
    required String text,
    required String app,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'analyze-message',
        body: {'text': text, 'app': app},
      );
      final data = response.data;
      if (data is! Map) return null;
      return ThreatAssessment.fromAi(Map<String, dynamic>.from(data));
    } catch (error) {
      // Tanpa isi pesan di log.
      debugPrint('AURA: penilaian AI tidak tersedia (${error.runtimeType}).');
      return null;
    }
  }

  @override
  Future<String?> emergencyNumber() async {
    final familyId = _cached?.familyId;
    if (familyId == null) return null;
    final row = await _db
        .from('profiles')
        .select('phone')
        .eq('family_id', familyId)
        .eq('role', UserRole.parent.name)
        .not('phone', 'is', null)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    return row?['phone'] as String?;
  }

  @override
  Future<void> setProtectionActive(String childId, bool active) async {
    await _db
        .from('profiles')
        .update({'protection_active': active})
        .eq('id', childId);
  }

  @override
  Future<void> reportChatScan(bool enabled) async {
    final uid = _requireUid();
    await _db
        .from('profiles')
        .update({
          'chat_scan_enabled': enabled,
          'chat_scan_checked_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uid);
  }

  @override
  Future<void> markActive() async {
    final uid = _requireUid();
    await _db
        .from('profiles')
        .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', uid);
  }

  @override
  Future<void> registerPushToken(String token) async {
    final uid = _requireUid();
    await _db.from('device_tokens').upsert({
      'user_id': uid,
      'token': token,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> removePushToken(String token) async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;
    await _db
        .from('device_tokens')
        .delete()
        .eq('user_id', uid)
        .eq('token', token);
  }

  // ---------------------------------------------------------------------------
  // Pemetaan baris basis data ke model aplikasi.
  //
  // Ditulis terpisah dari `fromMap` milik model karena Postgres memakai
  // snake_case, sedangkan model memakai camelCase.
  // ---------------------------------------------------------------------------

  AppUser _userFromRow(Map<String, dynamic> row) => AppUser(
    id: row['id'] as String,
    name: row['name'] as String? ?? 'Pengguna',
    role: row['role'] == 'child' ? UserRole.child : UserRole.parent,
    familyId: row['family_id'] as String?,
    age: (row['age'] as num?)?.toInt(),
    deviceLabel: row['device_label'] as String?,
    monitoringConsentAt: _parseDate(row['monitoring_consent_at']),
    lastSeenAt: _parseDate(row['last_seen_at']),
    protectionActive: row['protection_active'] as bool? ?? true,
    phone: row['phone'] as String?,
    chatScanEnabled: row['chat_scan_enabled'] as bool?,
    chatScanCheckedAt: _parseDate(row['chat_scan_checked_at']),
    avatarPath: row['avatar_path'] as String?,
  );

  ThreatAlert _alertFromRow(Map<String, dynamic> row) => ThreatAlert(
    id: row['id'] as String,
    familyId: row['family_id'] as String? ?? '',
    childId: row['child_id'] as String? ?? '',
    childName: row['child_name'] as String? ?? 'Anak',
    riskLevel: RiskLevel.fromName(row['risk_level'] as String?),
    categories: _stringList(
      row['categories'],
    ).map(ThreatCategory.fromName).toList(),
    source: AlertSource.fromName(row['source'] as String?),
    platform: row['platform'] as String? ?? 'Tidak diketahui',
    detectedAt: _parseDate(row['detected_at']) ?? DateTime.now(),
    summary: row['summary'] as String? ?? '',
    excerpt: row['excerpt'] as String?,
    counterpartName: row['counterpart_name'] as String?,
    status: AlertStatus.fromName(row['status'] as String?),
    evidenceIds: _stringList(row['evidence_ids']),
    score: (row['score'] as num?)?.toDouble() ?? 0,
    matchedSignals: _stringList(row['matched_signals']),
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    locationLabel: row['location_label'] as String?,
  );

  EvidenceItem _evidenceFromRow(Map<String, dynamic> row) => EvidenceItem(
    id: row['id'] as String,
    familyId: row['family_id'] as String? ?? '',
    childId: row['child_id'] as String? ?? '',
    kind: EvidenceKind.fromName(row['kind'] as String?),
    capturedAt: _parseDate(row['captured_at']) ?? DateTime.now(),
    recordedAt: _parseDate(row['recorded_at']) ?? DateTime.now(),
    description: row['description'] as String? ?? '',
    contentHash: row['content_hash'] as String? ?? '',
    chainHash: row['chain_hash'] as String? ?? '',
    sequence: (row['sequence'] as num?)?.toInt() ?? 0,
    previousHash: row['previous_hash'] as String?,
    alertId: row['alert_id'] as String?,
    payload: row['payload'] as String?,
    storagePath: row['storage_path'] as String?,
    capturedBy: row['captured_by'] as String? ?? 'AURA',
    consentNote: row['consent_note'] as String?,
  );

  GuardianMessage _messageFromRow(Map<String, dynamic> row) => GuardianMessage(
    id: row['id'] as String,
    author: row['author'] == 'child'
        ? MessageAuthor.child
        : MessageAuthor.guardian,
    text: row['text'] as String? ?? '',
    sentAt: _parseDate(row['sent_at']) ?? DateTime.now(),
    quickReplies: _stringList(row['quick_replies']),
    riskLevel: row['risk_level'] == null
        ? null
        : RiskLevel.fromName(row['risk_level'] as String?),
    escalated: row['escalated'] as bool? ?? false,
  );

  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  List<String> _stringList(Object? value) =>
      value is List ? value.map((e) => e.toString()).toList() : const [];

  String _requireUid() {
    final uid = _auth.currentUser?.id;
    if (uid == null) throw StateError(tr('Belum masuk.'));
    return uid;
  }

  String _requireFamilyId() {
    final familyId = _cached?.familyId;
    if (familyId == null) {
      throw StateError(tr('Perangkat belum ditautkan ke keluarga.'));
    }
    return familyId;
  }

  String _generateCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
