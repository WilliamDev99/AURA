import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../domain/models/app_user.dart';
import '../domain/models/evidence_item.dart';
import '../domain/models/guardian_message.dart';
import '../domain/models/threat_alert.dart';
import '../domain/services/chain_of_custody.dart';
import '../domain/services/threat_analyzer.dart';
import 'aura_repository.dart';

/// Implementasi penyimpanan di atas Firebase Auth + Cloud Firestore.
///
/// Struktur koleksi:
/// ```
/// users/{uid}
/// families/{familyId}
/// families/{familyId}/alerts/{alertId}
/// families/{familyId}/evidence/{evidenceId}     // rantai bukti, urut naik
/// families/{familyId}/chats/{childId}/messages/{messageId}
/// ```
/// Aturan aksesnya ada di `firestore.rules`: anak hanya bisa menulis, orang
/// tua hanya bisa membaca, dan bukti tidak bisa diubah atau dihapus siapa pun
/// dari sisi klien.
class FirestoreRepository implements AuraRepository {
  FirestoreRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const _custody = ChainOfCustody();

  AppUser? _cached;

  @override
  AppUser? get currentUser => _cached;

  @override
  bool get hasStoredSession => _auth.currentUser != null;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        _cached = null;
        return Stream<AppUser?>.value(null);
      }
      return _db.collection('users').doc(user.uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) return null;
        _cached = AppUser.fromMap({...data, 'id': snapshot.id});
        return _cached;
      });
    });
  }

  // Login email dan Facebook baru dibuat untuk backend Supabase.
  static StateError _loginUnsupported() => StateError(
    'Masuk dengan email atau Facebook baru tersedia di backend Supabase.',
  );

  @override
  String? get accountLabel => null;

  @override
  bool get isAnonymousAccount => false;

  @override
  Future<void> requestEmailCode(String email) async =>
      throw _loginUnsupported();

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async => throw _loginUnsupported();

  @override
  Future<void> continueWithFacebook() async => throw _loginUnsupported();

  @override
  Future<bool> hasProfile() async => false;

  @override
  Future<void> updatePhone(String phone) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'phone': phone});
  }

  @override
  Future<void> uploadAvatar(Uint8List jpegBytes) async =>
      throw _loginUnsupported();

  @override
  Future<void> removeAvatar() async => throw _loginUnsupported();

  @override
  Future<ImageProvider?> avatarImage(AppUser user) async => null;

  @override
  String? get accountEmail => _auth.currentUser?.email;

  @override
  Future<void> requestEmailChange(String newEmail) async =>
      throw _loginUnsupported();

  @override
  Future<bool> confirmEmailChange({
    required String newEmail,
    required String newCode,
    String? currentCode,
  }) async => throw _loginUnsupported();

  @override
  Future<AppUser> signIn({
    required String name,
    required UserRole role,
    int? age,
    String? phone,
  }) async {
    final credential =
        _auth.currentUser ?? (await _auth.signInAnonymously()).user!;

    final doc = _db.collection('users').doc(credential.uid);
    final existing = await doc.get();

    final user = AppUser(
      id: credential.uid,
      name: name,
      role: role,
      familyId: existing.data()?['familyId'] as String?,
      age: age,
      deviceLabel: existing.data()?['deviceLabel'] as String?,
      monitoringConsentAt: AppUser.fromMap({
        ...?existing.data(),
        'id': credential.uid,
      }).monitoringConsentAt,
      lastSeenAt: DateTime.now(),
      // Nomor lama dipertahankan bila kali ini tidak diisi.
      phone: phone ?? existing.data()?['phone'] as String?,
    );

    await doc.set(user.toMap(), SetOptions(merge: true));
    _cached = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _cached = null;
    await _auth.signOut();
  }

  @override
  Future<String> createFamily(String familyName) async {
    final uid = _requireUid();
    final code = _generateCode();
    final family = _db.collection('families').doc();

    await family.set({
      'name': familyName,
      'ownerId': uid,
      'memberIds': [uid],
      'pairingCode': code,
      'pairingExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(uid).set({
      'familyId': family.id,
    }, SetOptions(merge: true));

    return code;
  }

  @override
  Future<void> joinFamilyWithCode(String code) async {
    final uid = _requireUid();
    final matches = await _db
        .collection('families')
        .where('pairingCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (matches.docs.isEmpty) {
      throw StateError('Kode penautan tidak ditemukan atau sudah kedaluwarsa.');
    }

    final family = matches.docs.first;
    final expiresAt = (family.data()['pairingExpiresAt'] as Timestamp?)
        ?.toDate();
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      throw StateError('Kode penautan sudah kedaluwarsa. Minta kode baru.');
    }

    await family.reference.update({
      'memberIds': FieldValue.arrayUnion([uid]),
    });
    await _db.collection('users').doc(uid).set({
      'familyId': family.id,
    }, SetOptions(merge: true));
  }

  @override
  Future<String?> pairingCode(String familyId) async {
    final snapshot = await _db.collection('families').doc(familyId).get();
    return snapshot.data()?['pairingCode'] as String?;
  }

  @override
  Stream<List<AppUser>> watchChildren(String familyId) {
    return _db
        .collection('users')
        .where('familyId', isEqualTo: familyId)
        .where('role', isEqualTo: UserRole.child.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => AppUser.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  @override
  Stream<List<ThreatAlert>> watchAlerts(String familyId) {
    return _alerts(familyId)
        .orderBy('detectedAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => ThreatAlert.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  @override
  Future<void> raiseAlert(ThreatAlert alert) async {
    await _alerts(alert.familyId).doc(alert.id).set(alert.toMap());
  }

  @override
  Future<void> updateAlertStatus(String alertId, AlertStatus status) async {
    final familyId = _requireFamilyId();
    await _alerts(familyId).doc(alertId).update({
      'status': status.name,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<EvidenceItem>> watchEvidence(String familyId) {
    return _evidence(familyId)
        .orderBy('sequence', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => EvidenceItem.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
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
    final collection = _evidence(familyId);
    final doc = collection.doc();

    // Transaksi agar dua bukti yang masuk bersamaan tidak memakai nomor urut
    // dan hash sebelumnya yang sama, yang akan memutus rantai.
    return _db.runTransaction((transaction) async {
      final tail = await collection
          .orderBy('sequence', descending: true)
          .limit(1)
          .get();

      final previous = tail.docs.isEmpty
          ? null
          : EvidenceItem.fromMap({
              ...tail.docs.first.data(),
              'id': tail.docs.first.id,
            });

      final item = _custody.seal(
        id: doc.id,
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

      transaction.set(doc, {
        ...item.toMap(),
        'serverRecordedAt': FieldValue.serverTimestamp(),
      });
      return item;
    });
  }

  @override
  Stream<List<GuardianMessage>> watchGuardianChat(String childId) {
    final familyId = _cached?.familyId;
    if (familyId == null) return Stream.value(const []);

    return _db
        .collection('families')
        .doc(familyId)
        .collection('chats')
        .doc(childId)
        .collection('messages')
        .orderBy('sentAt')
        .limit(300)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => GuardianMessage.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  @override
  Future<void> saveGuardianMessage(
    String childId,
    GuardianMessage message,
  ) async {
    final familyId = _requireFamilyId();
    await _db
        .collection('families')
        .doc(familyId)
        .collection('chats')
        .doc(childId)
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());
  }

  @override
  Future<void> recordConsent(DateTime at) async {
    final uid = _requireUid();
    await _db.collection('users').doc(uid).set({
      'monitoringConsentAt': at.toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> registerPushToken(String token) async {
    final uid = _requireUid();
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removePushToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  @override
  Future<(String, List<String>)?> aiChat({
    required String message,
    required List<GuardianMessage> history,
  }) async => null;

  @override
  Future<ThreatAssessment?> aiAssess({
    required String text,
    required String app,
  }) async => null;

  @override
  Future<String?> emergencyNumber() async {
    final familyId = _cached?.familyId;
    if (familyId == null) return null;
    final parents = await _db
        .collection('users')
        .where('familyId', isEqualTo: familyId)
        .where('role', isEqualTo: UserRole.parent.name)
        .get();
    for (final doc in parents.docs) {
      final phone = doc.data()['phone'] as String?;
      if (phone != null && phone.isNotEmpty) return phone;
    }
    return null;
  }

  @override
  Future<void> setProtectionActive(String childId, bool active) async {
    await _db.collection('users').doc(childId).set({
      'protectionActive': active,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> reportChatScan(bool enabled) async {
    await _db.collection('users').doc(_requireUid()).set({
      'chatScanEnabled': enabled,
      'chatScanCheckedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> markActive() async {
    await _db.collection('users').doc(_requireUid()).set({
      'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> _alerts(String familyId) =>
      _db.collection('families').doc(familyId).collection('alerts');

  CollectionReference<Map<String, dynamic>> _evidence(String familyId) =>
      _db.collection('families').doc(familyId).collection('evidence');

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Belum masuk.');
    return uid;
  }

  String _requireFamilyId() {
    final familyId = _cached?.familyId;
    if (familyId == null) {
      throw StateError('Perangkat belum ditautkan ke keluarga.');
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
