import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:uuid/uuid.dart';

import '../core/l10n/l10n.dart';
import '../domain/models/app_user.dart';
import '../domain/models/lock_schedule.dart';
import '../domain/models/evidence_item.dart';
import '../domain/models/guardian_message.dart';
import '../domain/models/risk.dart';
import '../domain/models/threat_alert.dart';
import '../domain/services/chain_of_custody.dart';
import '../domain/services/threat_analyzer.dart';
import 'aura_repository.dart';

/// Penyimpanan di memori dengan data contoh.
///
/// Dipakai saat Firebase belum dikonfigurasi, untuk demo, dan untuk pengujian
/// alur tanpa menyentuh jaringan. Datanya hilang saat aplikasi ditutup.
class DemoRepository implements AuraRepository {
  DemoRepository() {
    _seed();
  }

  static const _uuid = Uuid();
  static const _custody = ChainOfCustody();
  static const demoFamilyId = 'fam-demo';
  static const demoChildId = 'child-ayu';

  final _userController = StreamController<AppUser?>.broadcast();
  final _alertsController = StreamController<List<ThreatAlert>>.broadcast();
  final _evidenceController = StreamController<List<EvidenceItem>>.broadcast();
  final _childrenController = StreamController<List<AppUser>>.broadcast();
  final _chatControllers = <String, StreamController<List<GuardianMessage>>>{};

  AppUser? _currentUser;
  final _alerts = <ThreatAlert>[];
  final _evidence = <EvidenceItem>[];
  final _children = <AppUser>[];
  final _chats = <String, List<GuardianMessage>>{};
  final _pairingCodes = <String, String>{};

  /// Nomor orang tua contoh, diganti bila orang tua masuk dengan nomornya.
  String? _parentPhone = '+6281234567890';

  @override
  AppUser? get currentUser => _currentUser;

  // Data demo hidup di memori; tidak ada sesi yang bertahan antar-peluncuran.
  @override
  bool get hasStoredSession => false;

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    yield _currentUser;
    yield* _userController.stream;
  }

  @override
  Future<AppUser> signIn({
    required String name,
    required UserRole role,
    int? age,
    String? phone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final user = AppUser(
      id: role == UserRole.child ? demoChildId : 'parent-${_uuid.v4()}',
      name: name,
      role: role,
      familyId: demoFamilyId,
      age: age,
      deviceLabel: role == UserRole.child ? 'Ponsel Anak' : 'Ponsel Orang Tua',
      monitoringConsentAt: role == UserRole.child
          ? DateTime.now().subtract(const Duration(days: 12))
          : null,
      lastSeenAt: DateTime.now(),
      phone: phone,
    );
    if (phone != null) _parentPhone = phone;
    _currentUser = user;
    _userController.add(user);

    if (role == UserRole.child && !_children.any((c) => c.id == user.id)) {
      _children.add(user);
      _childrenController.add(List.unmodifiable(_children));
    }
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _accountLabel = null;
    _pendingEmail = null;
    _userController.add(null);
  }

  // Mode demo tidak mengirim email sungguhan: kode 6 digit apa pun diterima,
  // supaya alur masuk bisa dicoba tanpa backend.
  String? _accountLabel;
  String? _pendingEmail;

  @override
  String? get accountLabel => _accountLabel;

  @override
  bool get isAnonymousAccount => _currentUser != null && _accountLabel == null;

  @override
  Future<void> requestEmailCode(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _pendingEmail = email.trim().toLowerCase();
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_pendingEmail != email.trim().toLowerCase()) {
      throw StateError(tr('Minta kode untuk email ini lebih dulu.'));
    }
    if (!RegExp(r'^\d{6,10}$').hasMatch(code.trim())) {
      throw StateError(tr(wrongCodeMessage));
    }
    _accountLabel = _pendingEmail;
    _pendingEmail = null;
  }

  @override
  Future<void> continueWithFacebook() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _accountLabel = 'Facebook';
  }

  @override
  Future<bool> hasProfile() async => _currentUser != null;

  // Foto profil demo disimpan di memori, per pengguna.
  final _avatars = <String, Uint8List>{};
  String? _pendingNewEmail;

  void _replaceCurrentUser(AppUser user) {
    _currentUser = user;
    _userController.add(user);
  }

  @override
  Future<void> updatePhone(String phone) async {
    final user = _currentUser;
    if (user == null) return;
    _parentPhone = phone;
    _replaceCurrentUser(user.copyWith(phone: phone));
  }

  @override
  Future<void> uploadAvatar(Uint8List jpegBytes) async {
    final user = _currentUser;
    if (user == null) return;
    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    _avatars[path] = jpegBytes;
    _replaceCurrentUser(user.copyWith(avatarPath: path));
  }

  @override
  Future<void> removeAvatar() async {
    final user = _currentUser;
    if (user == null) return;
    _replaceCurrentUser(user.copyWith(removeAvatar: true));
  }

  @override
  Future<ImageProvider?> avatarImage(AppUser user) async {
    final bytes = _avatars[user.avatarPath];
    return bytes == null ? null : MemoryImage(bytes);
  }

  @override
  String? get accountEmail =>
      _accountLabel != null && _accountLabel!.contains('@')
      ? _accountLabel
      : null;

  @override
  Future<void> requestEmailChange(String newEmail) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _pendingNewEmail = newEmail.trim().toLowerCase();
  }

  @override
  Future<bool> confirmEmailChange({
    required String newEmail,
    required String newCode,
    String? currentCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_pendingNewEmail != newEmail.trim().toLowerCase()) {
      throw StateError(tr('Minta kode untuk email ini lebih dulu.'));
    }
    if (!RegExp(r'^\d{6,10}$').hasMatch(newCode.trim())) {
      throw StateError(tr(wrongCodeMessage));
    }
    _accountLabel = _pendingNewEmail;
    _pendingNewEmail = null;
    return true;
  }

  @override
  Future<String> createFamily(String familyName) async {
    final code = _generateCode();
    _pairingCodes[demoFamilyId] = code;
    return code;
  }

  @override
  Future<void> joinFamilyWithCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final user = _currentUser;
    if (user == null) throw StateError(tr('Belum masuk.'));
    _currentUser = user.copyWith(familyId: demoFamilyId);
    _userController.add(_currentUser);
  }

  @override
  Future<String?> pairingCode(String familyId) async =>
      _pairingCodes[familyId] ??= _generateCode();

  @override
  Stream<List<AppUser>> watchChildren(String familyId) async* {
    yield List.unmodifiable(_children);
    yield* _childrenController.stream;
  }

  @override
  Stream<List<ThreatAlert>> watchAlerts(String familyId) async* {
    yield _sortedAlerts();
    yield* _alertsController.stream;
  }

  @override
  Future<void> raiseAlert(ThreatAlert alert) async {
    _alerts.add(alert);
    _alertsController.add(_sortedAlerts());
  }

  @override
  Future<void> updateAlertStatus(String alertId, AlertStatus status) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index < 0) return;
    _alerts[index] = _alerts[index].copyWith(status: status);
    _alertsController.add(_sortedAlerts());
  }

  @override
  Stream<List<EvidenceItem>> watchEvidence(String familyId) async* {
    yield _sortedEvidence();
    yield* _evidenceController.stream;
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
    final chain = _evidence.where((e) => e.familyId == demoFamilyId).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final item = _custody.seal(
      id: _uuid.v4(),
      familyId: demoFamilyId,
      childId: childId,
      kind: kind,
      capturedAt: capturedAt,
      description: description,
      payload: payload,
      previous: chain.isEmpty ? null : chain.last,
      alertId: alertId,
      storagePath: storagePath,
      consentNote: consentNote,
    );

    _evidence.add(item);
    _evidenceController.add(_sortedEvidence());
    return item;
  }

  @override
  Stream<List<GuardianMessage>> watchGuardianChat(String childId) async* {
    yield List.unmodifiable(_chats[childId] ?? const <GuardianMessage>[]);
    yield* _chatController(childId).stream;
  }

  @override
  Future<void> saveGuardianMessage(
    String childId,
    GuardianMessage message,
  ) async {
    final list = _chats.putIfAbsent(childId, () => <GuardianMessage>[])
      ..add(message);
    _chatController(childId).add(List.unmodifiable(list));
  }

  @override
  Future<void> recordConsent(DateTime at) async {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = user.copyWith(monitoringConsentAt: at);
    _userController.add(_currentUser);

    final index = _children.indexWhere((c) => c.id == user.id);
    if (index >= 0) {
      _children[index] = _children[index].copyWith(monitoringConsentAt: at);
      _childrenController.add(List.unmodifiable(_children));
    }
  }

  // Mode demo berjalan di satu perangkat tanpa server, jadi tidak ada token
  // yang perlu dicatat. Dibiarkan kosong, bukan melempar galat, supaya alur
  // aplikasi tetap sama persis dengan mode Firebase.
  @override
  Future<void> registerPushToken(String token) async {}

  @override
  Future<void> removePushToken(String token) async {}

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
  Future<String?> emergencyNumber() async => _parentPhone;

  @override
  Future<void> setProtectionActive(String childId, bool active) async {
    final index = _children.indexWhere((c) => c.id == childId);
    if (index >= 0) {
      _children[index] = _children[index].copyWith(protectionActive: active);
      _childrenController.add(List.unmodifiable(_children));
    }
    if (_currentUser?.id == childId) {
      _currentUser = _currentUser!.copyWith(protectionActive: active);
      _userController.add(_currentUser);
    }
  }

  @override
  Future<void> setLockSchedule(String childId, LockSchedule schedule) async {
    final index = _children.indexWhere((c) => c.id == childId);
    if (index >= 0) {
      _children[index] = _children[index].copyWith(lockSchedule: schedule);
      _childrenController.add(List.unmodifiable(_children));
    }
    if (_currentUser?.id == childId) {
      _currentUser = _currentUser!.copyWith(lockSchedule: schedule);
      _userController.add(_currentUser);
    }
  }

  /// Data demo selalu terbaru: tidak ada yang perlu diambil ulang.
  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> reportLockReady(bool ready) async {
    final user = _currentUser;
    if (user == null) return;
    _updateCurrentUser(user.copyWith(lockReady: ready));
  }

  @override
  Future<void> reportChatScan(bool enabled) async {
    final user = _currentUser;
    if (user == null) return;
    _updateCurrentUser(
      user.copyWith(
        chatScanEnabled: enabled,
        chatScanCheckedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> markActive() async {
    final user = _currentUser;
    if (user == null) return;
    _updateCurrentUser(user.copyWith(lastSeenAt: DateTime.now()));
  }

  /// Menyimpan perubahan profil sendiri; anak juga tampil di daftar orang tua.
  void _updateCurrentUser(AppUser updated) {
    _currentUser = updated;
    _userController.add(updated);
    final index = _children.indexWhere((c) => c.id == updated.id);
    if (index >= 0) {
      _children[index] = updated;
      _childrenController.add(List.unmodifiable(_children));
    }
  }

  StreamController<List<GuardianMessage>> _chatController(String childId) =>
      _chatControllers.putIfAbsent(
        childId,
        () => StreamController<List<GuardianMessage>>.broadcast(),
      );

  List<ThreatAlert> _sortedAlerts() {
    final sorted = [..._alerts]
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    return List.unmodifiable(sorted);
  }

  List<EvidenceItem> _sortedEvidence() {
    final sorted = [..._evidence]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    return List.unmodifiable(sorted);
  }

  String _generateCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  /// Mengisi data contoh supaya dashboard tidak kosong saat pertama dibuka.
  void _seed() {
    final now = DateTime.now();

    _children.addAll([
      AppUser(
        id: demoChildId,
        name: 'Ayu',
        role: UserRole.child,
        familyId: demoFamilyId,
        age: 12,
        deviceLabel: 'Redmi Note 12',
        monitoringConsentAt: now.subtract(const Duration(days: 12)),
        lastSeenAt: now.subtract(const Duration(minutes: 4)),
        chatScanEnabled: true,
        chatScanCheckedAt: now.subtract(const Duration(minutes: 4)),
      ),
      AppUser(
        id: 'child-bima',
        name: 'Bima',
        role: UserRole.child,
        familyId: demoFamilyId,
        age: 9,
        deviceLabel: 'Samsung A14',
        monitoringConsentAt: now.subtract(const Duration(days: 12)),
        lastSeenAt: now.subtract(const Duration(hours: 2)),
        chatScanEnabled: false,
        chatScanCheckedAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);

    final samples = <(EvidenceKind, DateTime, String, String)>[
      (
        EvidenceKind.messageTranscript,
        now.subtract(const Duration(hours: 3, minutes: 12)),
        'Transkrip percakapan terindikasi grooming di Instagram DM',
        'Kak_Rio: kamu kelas berapa dek?\n'
            'Ayu: kelas 6\n'
            'Kak_Rio: jangan bilang siapa siapa ya, ini rahasia kita berdua',
      ),
      (
        EvidenceKind.systemEvent,
        now.subtract(const Duration(hours: 3, minutes: 11)),
        'AURA mengirim peringatan ke perangkat orang tua',
        'Peringatan tingkat TINGGI dikirim ke 1 perangkat orang tua. '
            'Status pengiriman: terkirim.',
      ),
      (
        EvidenceKind.messageTranscript,
        now.subtract(const Duration(days: 1, hours: 5)),
        'Perundungan di grup chat sekolah',
        'Grup "Kelas 6B": "gendut banget sih lo", "gak ada yang suka kamu"',
      ),
      (
        EvidenceKind.locationPing,
        now.subtract(const Duration(days: 2, hours: 1)),
        'Titik lokasi saat tombol darurat ditekan',
        'Lat -6.21462, Lon 106.84513 (akurasi 12 m) - Jakarta Pusat. '
            'Dikirim atas penekanan tombol darurat oleh anak.',
      ),
    ];

    EvidenceItem? previous;
    for (final (kind, at, description, payload) in samples) {
      final item = _custody.seal(
        id: _uuid.v4(),
        familyId: demoFamilyId,
        childId: demoChildId,
        kind: kind,
        capturedAt: at,
        description: description,
        payload: payload,
        previous: previous,
        recordedAt: at.add(const Duration(seconds: 2)),
        consentNote:
            'Diambil oleh AURA atas persetujuan anak tertanggal '
            '${now.subtract(const Duration(days: 12)).toIso8601String()} '
            'dan kewenangan orang tua sebagai wali.',
      );
      _evidence.add(item);
      previous = item;
    }

    _alerts.addAll([
      ThreatAlert(
        id: 'alert-1',
        familyId: demoFamilyId,
        childId: demoChildId,
        childName: 'Ayu',
        riskLevel: RiskLevel.high,
        categories: const [
          ThreatCategory.grooming,
          ThreatCategory.personalData,
        ],
        source: AlertSource.messageScan,
        platform: 'Instagram DM',
        detectedAt: now.subtract(const Duration(hours: 3, minutes: 12)),
        summary:
            'Ancaman terdeteksi: lawan bicara memakai pola pendekatan predator: '
            'meminta kerahasiaan dan menjauhkan anak dari orang tua.',
        excerpt: 'jangan bilang siapa siapa ya, ini rahasia kita berdua',
        counterpartName: 'Kak_Rio (akun baru, 2 hari)',
        score: 0.72,
        matchedSignals: const ['jangan bilang siapa siapa', 'rahasia kita'],
        evidenceIds: [_evidence[0].id],
      ),
      ThreatAlert(
        id: 'alert-2',
        familyId: demoFamilyId,
        childId: demoChildId,
        childName: 'Ayu',
        riskLevel: RiskLevel.medium,
        categories: const [ThreatCategory.cyberbullying],
        source: AlertSource.messageScan,
        platform: 'WhatsApp Grup',
        detectedAt: now.subtract(const Duration(days: 1, hours: 5)),
        summary:
            'Pola mencurigakan: anak menerima perundungan dan perendahan yang '
            'berulang.',
        excerpt: 'gak ada yang suka kamu',
        counterpartName: 'Grup "Kelas 6B"',
        status: AlertStatus.reviewed,
        score: 0.48,
        matchedSignals: const ['gak ada yang suka kamu', 'gendut banget'],
        evidenceIds: [_evidence[2].id],
      ),
      ThreatAlert(
        id: 'alert-3',
        familyId: demoFamilyId,
        childId: 'child-bima',
        childName: 'Bima',
        riskLevel: RiskLevel.low,
        categories: const [ThreatCategory.profanity],
        source: AlertSource.messageScan,
        platform: 'Chat Game',
        detectedAt: now.subtract(const Duration(days: 3)),
        summary: 'Perlu diperhatikan: percakapan memuat kata kasar.',
        excerpt: 'dasar bego main gitu doang',
        counterpartName: 'Pemain lain',
        status: AlertStatus.dismissed,
        score: 0.22,
        matchedSignals: const ['bego'],
      ),
    ]);

    _chats[demoChildId] = [
      GuardianMessage(
        id: 'm1',
        author: MessageAuthor.guardian,
        text:
            'Halo, Ayu. Aku Aura. Kalau ada yang bikin kamu bingung atau takut, '
            'cerita aja ke aku ya.',
        sentAt: now.subtract(const Duration(hours: 4)),
        quickReplies: const [
          'Ada yang chat aku terus',
          'Aku dibully di sekolah',
          'Aku lagi sedih',
        ],
      ),
    ];
  }
}
