import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/aura_repository.dart';
import '../domain/models/app_user.dart';
import '../domain/models/evidence_item.dart';
import '../domain/models/guardian_message.dart';
import '../domain/models/risk.dart';
import '../domain/models/threat_alert.dart';
import '../domain/services/chain_of_custody.dart';
import '../domain/services/emergency_call_service.dart';
import '../domain/services/guardian_brain.dart';
import '../domain/services/location_service.dart';
import '../domain/services/notification_access.dart';
import '../domain/services/threat_analyzer.dart';
import '../core/l10n/l10n.dart';

/// Hasil satu kali pemindaian yang dikembalikan ke UI anak.
class ScanOutcome {
  const ScanOutcome({required this.assessment, required this.alert});

  final ThreatAssessment assessment;
  final ThreatAlert? alert;

  bool get escalated => alert != null;
}

/// Status aplikasi yang dibagikan ke seluruh layar.
class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    this.analyzer = const ThreatAnalyzer(),
    this.brain = const LocalGuardianBrain(),
    this.locationService = const LocationService(),
    this.callService = const EmergencyCallService(),
    this.notificationAccess = const NotificationAccess(),
    this.aiChat = aiChatEnabled,
  }) {
    _userSub = repository.watchCurrentUser().listen(
      _onUserChanged,
      onError: _onStreamError,
    );
    _loadCachedEmergencyNumber();
  }

  /// Kunci penyimpanan lokal nomor darurat orang tua.
  static const _emergencyNumberKey = 'aura.emergency_number';

  static const _uuid = Uuid();
  static const _custody = ChainOfCustody();

  final AuraRepository repository;
  final ThreatAnalyzer analyzer;
  final GuardianBrain brain;
  final LocationService locationService;
  final EmergencyCallService callService;

  /// Izin membaca notifikasi pesan untuk pemindaian chat di ponsel anak.
  final NotificationAccess notificationAccess;

  /// Nomor orang tua yang ditelepon saat SOS, disimpan di perangkat.
  ///
  /// Diambil dari server saat keadaan tenang, lalu disimpan lokal, sehingga
  /// jalur darurat tidak pernah butuh internet untuk tahu siapa yang harus
  /// ditelepon.
  String? _emergencyNumber;
  String? get emergencyNumber => _emergencyNumber;

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<List<ThreatAlert>>? _alertSub;
  StreamSubscription<List<EvidenceItem>>? _evidenceSub;
  StreamSubscription<List<AppUser>>? _childrenSub;
  StreamSubscription<List<GuardianMessage>>? _chatSub;

  /// Dijalankan tepat sebelum sesi berakhir, selagi pengguna masih berwenang
  /// menulis ke dokumennya sendiri. Dipakai untuk melepas token notifikasi.
  Future<void> Function()? onBeforeSignOut;

  AppUser? _user;

  /// True sejak aplikasi dibuka sampai sesi tersimpan selesai dipulihkan.
  late bool _restoring = repository.hasStoredSession;
  List<ThreatAlert> _alerts = const [];
  List<EvidenceItem> _evidence = const [];
  List<AppUser> _children = const [];
  List<GuardianMessage> _chat = const [];
  bool _busy = false;
  String? _lastError;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  /// Sesi lama sedang dipulihkan: belum boleh menampilkan layar masuk.
  bool get isRestoring => _restoring;

  /// Selesai saat sesi tersimpan sudah dipulihkan (atau memang tidak ada).
  Future<void> untilRestored() {
    if (!_restoring) return Future.value();
    final done = Completer<void>();
    void check() {
      if (_restoring) return;
      removeListener(check);
      if (!done.isCompleted) done.complete();
    }

    addListener(check);
    return done.future;
  }

  bool get isChild => _user?.isChild ?? false;
  List<ThreatAlert> get alerts => _alerts;
  List<EvidenceItem> get evidence => _evidence;
  List<AppUser> get children => _children;
  List<GuardianMessage> get chat => _chat;
  bool get busy => _busy;
  String? get lastError => _lastError;

  List<ThreatAlert> get unreadAlerts =>
      _alerts.where((a) => a.status == AlertStatus.unread).toList();

  List<ThreatAlert> get activeThreats => _alerts
      .where(
        (a) =>
            a.status != AlertStatus.dismissed &&
            a.riskLevel.severity >= RiskLevel.medium.severity,
      )
      .toList();

  /// Tingkat risiko tertinggi yang belum ditangani — dipakai sebagai indikator
  /// besar di dashboard orang tua.
  RiskLevel get householdRisk {
    final open = _alerts.where((a) => a.status == AlertStatus.unread);
    if (open.isEmpty) return RiskLevel.safe;
    return open
        .map((a) => a.riskLevel)
        .reduce((a, b) => a.severity >= b.severity ? a : b);
  }

  /// Verifikasi rantai bukti, dari yang tertua.
  ChainVerification get chainStatus {
    final ordered = [..._evidence]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return _custody.verify(ordered);
  }

  List<EvidenceItem> evidenceForAlert(String alertId) =>
      _evidence.where((e) => e.alertId == alertId).toList();

  ThreatAlert? alertById(String id) {
    for (final alert in _alerts) {
      if (alert.id == id) return alert;
    }
    return null;
  }

  Future<void> signIn({
    required String name,
    required UserRole role,
    int? age,
    String? phone,
  }) => _guard(
    () => repository.signIn(name: name, role: role, age: age, phone: phone),
  );

  /// Akun login di perangkat ini (email atau "Facebook"); null bila belum
  /// masuk atau masih anonim.
  String? get accountLabel => repository.accountLabel;

  /// Akun orang tua lama yang masih anonim: belum bisa dipulihkan bila
  /// aplikasi dihapus. Ditawari untuk diamankan di Profil.
  bool get needsAccountSecuring =>
      !isChild && _user != null && repository.isAnonymousAccount;

  /// Mengirim kode masuk ke email. True bila terkirim.
  Future<bool> requestEmailCode(String email) async {
    await _guard(() => repository.requestEmailCode(email));
    return _lastError == null;
  }

  /// Memeriksa kode dari email. True bila berhasil masuk.
  Future<bool> verifyEmailCode(String email, String code) async {
    await _guard(() => repository.verifyEmailCode(email: email, code: code));
    return _lastError == null;
  }

  /// Membuka login Facebook di browser; sesinya datang saat kembali.
  Future<void> continueWithFacebook() =>
      _guard(repository.continueWithFacebook);

  /// True bila akun yang baru masuk sudah punya profil (orang tua lama).
  Future<bool> hasProfile() async {
    try {
      return await repository.hasProfile();
    } catch (error) {
      _lastError = humanizeError(error);
      notifyListeners();
      return false;
    }
  }

  /// Mengganti nomor HP darurat orang tua. True bila tersimpan.
  Future<bool> updatePhone(String phone) async {
    await _guard(() => repository.updatePhone(phone));
    return _lastError == null;
  }

  /// Mengganti foto profil dengan foto JPEG baru. True bila tersimpan.
  Future<bool> uploadAvatar(Uint8List jpegBytes) async {
    await _guard(() => repository.uploadAvatar(jpegBytes));
    return _lastError == null;
  }

  /// Menghapus foto profil. True bila berhasil.
  Future<bool> removeAvatar() async {
    await _guard(repository.removeAvatar);
    return _lastError == null;
  }

  /// Foto profil [user], atau null bila belum ada.
  Future<ImageProvider?> avatarImage(AppUser user) =>
      repository.avatarImage(user);

  /// Email akun yang sedang masuk; null bila belum ada.
  String? get accountEmail => repository.accountEmail;

  /// Meminta kode untuk mengganti email. True bila kode terkirim.
  Future<bool> requestEmailChange(String newEmail) async {
    await _guard(() => repository.requestEmailChange(newEmail));
    return _lastError == null;
  }

  /// Memeriksa kode penggantian email: true bila email sudah berganti,
  /// false bila masih perlu kode dari email lama, null bila gagal.
  Future<bool?> confirmEmailChange({
    required String newEmail,
    required String newCode,
    String? currentCode,
  }) async {
    bool? done;
    await _guard(() async {
      done = await repository.confirmEmailChange(
        newEmail: newEmail,
        newCode: newCode,
        currentCode: currentCode,
      );
    });
    return _lastError == null ? done : null;
  }

  /// Menghapus pesan galat lama, mis. saat orang tua mengganti email.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Menelepon orang tua dengan nomor yang tersimpan di perangkat.
  ///
  /// Diberi batas waktu: alur SOS menunggu hasil ini sebelum menampilkan
  /// konfirmasi, dan jalur darurat tidak boleh macet karena satu panggilan
  /// yang tidak pernah menjawab.
  Future<CallOutcome> callParent() => callService
      .call(_emergencyNumber)
      .timeout(const Duration(seconds: 6), onTimeout: () => CallOutcome.failed);

  Future<void> _loadCachedEmergencyNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_emergencyNumberKey);
      if (cached != null && _emergencyNumber == null) {
        _emergencyNumber = cached;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('AURA: nomor darurat tersimpan tidak terbaca ($error).');
    }
  }

  /// Mengambil nomor terbaru dari server dan menyimpannya di perangkat.
  /// Bila server tidak terjangkau, nomor lama tetap dipakai.
  Future<void> refreshEmergencyNumber() async {
    try {
      final number = await repository.emergencyNumber();
      if (number == null) return;
      _emergencyNumber = number;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emergencyNumberKey, number);
    } catch (error) {
      debugPrint('AURA: nomor darurat belum bisa diperbarui ($error).');
    }
  }

  Future<void> signOut() async {
    await onBeforeSignOut?.call();
    await repository.signOut();
    _alerts = const [];
    _evidence = const [];
    _children = const [];
    _chat = const [];
    // Nomor itu milik keluarga yang baru ditinggalkan. Kalau ponsel ini lalu
    // ditautkan ke keluarga lain saat offline, SOS tidak boleh menelepon
    // orang tua yang salah.
    _emergencyNumber = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emergencyNumberKey);
    } catch (error) {
      debugPrint('AURA: nomor darurat lama belum terhapus ($error).');
    }
  }

  Future<String?> pairingCode() async {
    final familyId = _user?.familyId;
    if (familyId == null) return null;
    return repository.pairingCode(familyId);
  }

  Future<void> joinFamilyWithCode(String code) =>
      _guard(() => repository.joinFamilyWithCode(code));

  Future<void> giveConsent() =>
      _guard(() => repository.recordConsent(DateTime.now()));

  Future<void> setProtectionActive(String childId, bool active) =>
      _guard(() => repository.setProtectionActive(childId, active));

  Future<void> markAlert(String alertId, AlertStatus status) =>
      _guard(() => repository.updateAlertStatus(alertId, status));

  /// Memindai satu pesan dan, bila perlu, mengirim peringatan ke orang tua
  /// beserta bukti tersegelnya.
  ///
  /// [childInitiated] menandai pesan yang sengaja dilaporkan anak lewat tombol
  /// "Laporkan ini", bukan hasil pemindaian otomatis. Pembedaan ini ikut
  /// tercatat di bukti karena dasar pengambilannya berbeda.
  Future<ScanOutcome> scanMessage({
    required String text,
    required String platform,
    String? counterpartName,
    bool childInitiated = false,
    ThreatAssessment? assessment,
  }) async {
    final user = _user;
    // Bisa sudah dinilai sebelumnya, mis. oleh lapisan AI pemindai chat.
    assessment ??= analyzer.assess(text);

    if (user == null) return ScanOutcome(assessment: assessment, alert: null);

    final shouldEscalate = assessment.level.notifiesParent || childInitiated;
    if (!shouldEscalate) {
      return ScanOutcome(assessment: assessment, alert: null);
    }

    final childId = user.isChild
        ? user.id
        : (_children.firstOrNull?.id ?? user.id);
    final childName = user.isChild
        ? user.name
        : (_children.firstOrNull?.name ?? 'Anak');
    final now = DateTime.now();

    final evidenceItem = await repository.appendEvidence(
      childId: childId,
      kind: EvidenceKind.messageTranscript,
      capturedAt: now,
      description: childInitiated
          ? 'Percakapan dilaporkan sendiri oleh anak dari $platform'
          : 'Transkrip percakapan terindikasi ${assessment.categories.map((c) => c.labelId).join(", ")} di $platform',
      payload: text,
      consentNote: childInitiated
          ? 'Dikirim secara sadar oleh anak melalui fitur "Laporkan ini".'
          : 'Dipindai oleh AURA atas persetujuan anak tertanggal '
                '${user.monitoringConsentAt?.toIso8601String() ?? "-"} '
                'dan kewenangan orang tua sebagai wali.',
    );

    final alert = ThreatAlert(
      id: _uuid.v4(),
      familyId: user.familyId ?? '',
      childId: childId,
      childName: childName,
      riskLevel: childInitiated && assessment.level == RiskLevel.safe
          ? RiskLevel.medium
          : assessment.level,
      categories: assessment.categories,
      source: childInitiated
          ? AlertSource.childReport
          : AlertSource.messageScan,
      platform: platform,
      detectedAt: now,
      summary: childInitiated
          ? '$childName melaporkan percakapan ini sendiri. ${assessment.summary}'
          : assessment.summary,
      excerpt: assessment.excerpt.isEmpty ? _trim(text) : assessment.excerpt,
      counterpartName: counterpartName,
      score: assessment.score,
      matchedSignals: assessment.signals,
      evidenceIds: [evidenceItem.id],
    );

    await repository.raiseAlert(alert);
    return ScanOutcome(assessment: assessment, alert: alert);
  }

  /// Menekan tombol darurat: mengirim peringatan kritis dan menyegel lokasi.
  /// [location] boleh null atau gagal; peringatan tetap dikirim.
  /// Keselamatan anak tidak boleh bergantung pada sinyal GPS.
  Future<ThreatAlert?> triggerPanic({
    LocationResult? location,
    String? locationLabel,
  }) async {
    final user = _user;
    if (user == null) return null;

    final now = DateTime.now();
    final coordinates =
        location?.describe() ??
        'Lokasi tidak tersedia: tidak diminta oleh perangkat.';

    final evidenceItem = await repository.appendEvidence(
      childId: user.id,
      kind: EvidenceKind.locationPing,
      capturedAt: now,
      description: 'Tombol darurat ditekan oleh anak',
      payload:
          // Setiap keterangan lokasi sudah diakhiri titik.
          '$coordinates${locationLabel == null ? "" : " Lokasi: $locationLabel."} '
          'Dikirim atas penekanan tombol darurat oleh anak pada '
          '${now.toIso8601String()}.',
      consentNote:
          'Diambil atas tindakan sadar anak menekan tombol darurat di aplikasi.',
    );

    final alert = ThreatAlert(
      id: _uuid.v4(),
      familyId: user.familyId ?? '',
      childId: user.id,
      childName: user.name,
      riskLevel: RiskLevel.critical,
      categories: const [ThreatCategory.violence],
      source: AlertSource.panicButton,
      platform: 'Tombol Darurat AURA',
      detectedAt: now,
      summary:
          '${user.name} menekan tombol darurat. Hubungi anak sekarang juga.',
      excerpt: null,
      latitude: location?.latitude,
      longitude: location?.longitude,
      locationLabel: locationLabel,
      score: 1,
      evidenceIds: [evidenceItem.id],
    );

    await repository.raiseAlert(alert);
    return alert;
  }

  /// Mengirim pesan anak ke AI Guardian dan menyimpan balasannya.
  /// Matikan dengan `--dart-define=AURA_AI_CHAT=false`.
  ///
  /// Penyedia AI dan batas umurnya ditentukan server (lihat
  /// `supabase/functions/aura-chat`): Gemma 4 di Cloudflare untuk semua umur,
  /// atau ChatGPT khusus 13+. Bila server menolak atau AI tidak tersedia,
  /// Aura lokal yang menjawab.
  static const aiChatEnabled = bool.fromEnvironment(
    'AURA_AI_CHAT',
    defaultValue: true,
  );

  /// Apakah obrolan AI dinyalakan (bisa diganti di test).
  final bool aiChat;

  /// Apakah obrolan anak ini dibalas AI.
  bool get usesAiChat => aiChat && (_user?.isChild ?? false);

  /// Status pemindaian chat yang sama tidak dilaporkan ulang lebih sering
  /// dari ini; cukup supaya orang tua tahu status itu masih baru.
  static const _chatScanReportEvery = Duration(hours: 6);

  /// Melaporkan apakah pemindaian chat di ponsel anak ini menyala, supaya
  /// orang tua tidak mengira chat anaknya terpantau padahal aksesnya mati.
  ///
  /// [changed] berarti Android baru saja mengabarkan aksesnya diberikan atau
  /// dicabut: selalu dilaporkan, tidak boleh dianggap pengulangan.
  Future<void> reportChatScan(bool enabled, {bool changed = false}) async {
    final user = _user;
    if (user == null || !user.isChild) return;
    final checked = user.chatScanCheckedAt;
    final fresh =
        user.chatScanEnabled == enabled &&
        checked != null &&
        DateTime.now().difference(checked) < _chatScanReportEvery;
    if (fresh && !changed) return;
    try {
      await repository.reportChatScan(enabled);
      debugPrint(
        'AURA: status pemindaian chat dilaporkan '
        '(${enabled ? 'aktif' : 'mati'}).',
      );
      // Pembaruan realtime dari server bisa terlambat atau tidak sampai
      // saat aplikasi di latar belakang. Tanpa ini, laporan berikutnya bisa
      // keliru dianggap pengulangan dari status yang sudah usang.
      final current = _user;
      if (current != null && current.id == user.id) {
        _user = current.copyWith(
          chatScanEnabled: enabled,
          chatScanCheckedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (error) {
      debugPrint('AURA: status pemindaian chat belum terkirim ($error).');
    }
  }

  /// Seberapa sering ponsel anak mengabarkan bahwa AURA masih berjalan.
  static const heartbeatEvery = Duration(minutes: 15);

  /// Membuka-tutup aplikasi berkali-kali tidak perlu menulis ke server
  /// setiap kali.
  static const _activeThrottle = Duration(minutes: 5);
  DateTime? _lastMarkedActive;

  /// Memperbarui waktu "Aktif ..." anak yang tampil di ponsel orang tua.
  /// Dipanggil saat sesi dimulai, saat aplikasi dibuka, dan berkala.
  Future<void> markActive() async {
    final user = _user;
    if (user == null || !user.isChild) return;
    final now = DateTime.now();
    final last = _lastMarkedActive;
    if (last != null && now.difference(last) < _activeThrottle) return;
    _lastMarkedActive = now;
    try {
      await repository.markActive();
    } catch (error) {
      // Dicoba lagi pada kesempatan berikutnya.
      _lastMarkedActive = null;
      debugPrint('AURA: waktu aktif belum terkirim ($error).');
    }
  }

  /// Memeriksa izin "Akses notifikasi" lalu melaporkannya. Dipanggil saat
  /// aplikasi dibuka dan saat kembali dari Pengaturan Android.
  Future<void> refreshChatScanStatus() async {
    if (!(_user?.isChild ?? false)) return;
    final granted = await notificationAccess.isGranted();
    // Bukan Android: tidak ada yang bisa dilaporkan dengan jujur.
    if (granted == null) return;
    await reportChatScan(granted);
  }

  Future<GuardianReply> sendToGuardian(String text) async {
    final user = _user;
    if (user == null) throw StateError(tr('Belum masuk.'));

    final childMessage = GuardianMessage(
      id: _uuid.v4(),
      author: MessageAuthor.child,
      text: text,
      sentAt: DateTime.now(),
    );
    await repository.saveGuardianMessage(user.id, childMessage);

    var reply = brain.respond(
      childMessage: text,
      history: _chat,
      childName: user.name,
    );

    // AI hanya untuk obrolan biasa. Pesan berbahaya tidak
    // pernah dikirim ke luar ponsel: Aura lokal yang menjawab dengan balasan
    // keselamatan yang sudah teruji, lalu orang tua diberi tahu.
    if (usesAiChat && !reply.shouldAlertParent) {
      final ai = await repository
          .aiChat(message: text, history: _chat)
          // Server berhenti menunggu AI setelah 18 detik; sisanya untuk
          // perjalanan jaringan. Lewat dari ini Aura lokal yang menjawab.
          .timeout(const Duration(seconds: 22), onTimeout: () => null);
      if (ai != null) {
        reply = GuardianReply(
          text: ai.$1,
          quickReplies: ai.$2,
          assessment: reply.assessment,
          shouldAlertParent: false,
        );
      }
    }

    await repository.saveGuardianMessage(
      user.id,
      GuardianMessage(
        id: _uuid.v4(),
        author: MessageAuthor.guardian,
        text: reply.text,
        sentAt: DateTime.now(),
        quickReplies: reply.quickReplies,
        riskLevel: reply.assessment.level,
        escalated: reply.shouldAlertParent,
      ),
    );

    if (reply.shouldAlertParent) {
      await scanMessage(
        text: text,
        platform: 'Obrolan dengan AI Guardian',
        counterpartName: 'AI Guardian',
      );
    }

    return reply;
  }

  void _onUserChanged(AppUser? user) {
    _restoring = false;
    final previousFamily = _user?.familyId;
    final previousId = _user?.id;
    _user = user;

    if (user == null) {
      _alertSub?.cancel();
      _evidenceSub?.cancel();
      _childrenSub?.cancel();
      _chatSub?.cancel();
      notifyListeners();
      return;
    }

    // Ponsel anak melaporkan status pemindaian chat dan waktu aktifnya
    // sekali saat sesi dimulai.
    if (user.isChild && user.id != previousId) {
      _lastMarkedActive = null;
      unawaited(refreshChatScanStatus());
      unawaited(markActive());
    }

    final familyId = user.familyId;
    if (familyId != null && familyId != previousFamily) {
      _alertSub?.cancel();
      _alertSub = repository.watchAlerts(familyId).listen((alerts) {
        _alerts = alerts;
        notifyListeners();
      }, onError: _onStreamError);

      _evidenceSub?.cancel();
      _evidenceSub = repository.watchEvidence(familyId).listen((evidence) {
        _evidence = evidence;
        notifyListeners();
      }, onError: _onStreamError);

      _childrenSub?.cancel();
      _childrenSub = repository.watchChildren(familyId).listen((children) {
        _children = children;
        notifyListeners();
      }, onError: _onStreamError);
    }

    if (user.isChild && user.familyId != null) {
      // Diperbarui setiap kali profil berubah: kalau orang tua mengganti
      // nomornya, perangkat anak ikut memakai nomor baru.
      refreshEmergencyNumber();
    }

    if (user.isChild && user.id != previousId) {
      _chatSub?.cancel();
      _chatSub = repository.watchGuardianChat(user.id).listen((messages) {
        _chat = messages;
        notifyListeners();
      }, onError: _onStreamError);
    }

    notifyListeners();
  }

  /// Galat dari langganan data tidak boleh menjatuhkan aplikasi.
  ///
  /// Repositori bertugas memulihkan koneksinya sendiri; di sini galat hanya
  /// dicatat. Tanpa penangan ini, satu kegagalan jaringan muncul sebagai
  /// galat tak tertangani dan langganannya ikut berhenti.
  void _onStreamError(Object error, StackTrace stackTrace) {
    debugPrint('AURA: langganan data bermasalah ($error).');
  }

  Future<void> _guard(Future<void> Function() action) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _lastError = humanizeError(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Menerjemahkan galat teknis menjadi kalimat yang berguna.
  ///
  /// Orang tua yang sedang cemas tidak terbantu oleh teks seperti
  /// `AuthApiException(statusCode: 422)`. Galat penyiapan juga diterjemahkan
  /// karena yang membacanya sedang memasang aplikasi dan perlu tahu persis
  /// langkah mana yang terlewat.
  @visibleForTesting
  static String humanizeError(Object error) {
    if (error is StateError) return error.message;
    final text = error.toString();

    if (text.contains('anonymous_provider_disabled')) {
      return tr(
        'Login anonim belum dinyalakan. Di Supabase, buka '
        'Authentication > Providers > Anonymous, lalu nyalakan.',
      );
    }
    if (text.contains('PGRST205') || text.contains('schema cache')) {
      return tr(
        'Tabel database belum dibuat. Jalankan isi '
        'supabase/schema.sql di SQL Editor Supabase.',
      );
    }
    if (text.contains('Invalid API key') || text.contains('invalid_api_key')) {
      return tr(
        'Kunci Supabase tidak cocok. Periksa lagi isi '
        'lib/supabase_options.dart.',
      );
    }
    if (text.contains('row-level security') || text.contains('PGRST301')) {
      return tr(
        'Akses ditolak oleh aturan keamanan. Pastikan seluruh isi '
        'schema.sql sudah dijalankan.',
      );
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException')) {
      return tr(
        'Tidak bisa terhubung ke internet. Periksa koneksi Anda, lalu '
        'coba lagi.',
      );
    }
    return tr(
      'Terjadi masalah saat menghubungi server. Coba lagi sebentar '
      'lagi.\n\n({text})',
      {'text': text},
    );
  }

  String _trim(String text) =>
      text.length <= 90 ? text : '${text.substring(0, 90)}...';

  @override
  void dispose() {
    _userSub?.cancel();
    _alertSub?.cancel();
    _evidenceSub?.cancel();
    _childrenSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }
}
