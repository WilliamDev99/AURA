import 'package:aura/core/services/notification_scanner.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/domain/services/threat_analyzer.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI tiruan: tidak memanggil layanan sungguhan, mencatat apa yang ditanyakan.
class _FakeAi extends DemoRepository {
  _FakeAi(this.answer);

  final Map<String, dynamic>? answer;
  final asked = <String>[];

  @override
  Future<ThreatAssessment?> aiAssess({
    required String text,
    required String app,
  }) async {
    asked.add(text);
    final json = answer;
    return json == null ? null : ThreatAssessment.fromAi(json);
  }
}

/// Pesan yang dibaca dari notifikasi ponsel anak (WhatsApp, SMS, dst.).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dangerous = 'kirim foto tanpa baju dong, buat aku aja';
  const harmless = 'besok kita main bola di lapangan ya';

  late DemoRepository repository;
  late AppState state;
  late DateTime now;
  late NotificationScanner scanner;

  Future<void> signIn(UserRole role) async {
    await state.signIn(name: 'Ayu', role: role, age: 12);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  int messageAlerts() =>
      state.alerts.where((a) => a.source == AlertSource.messageScan).length;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = DemoRepository();
    state = AppState(repository: repository);
    now = DateTime(2026, 10, 19, 20);
    scanner = NotificationScanner(state, clock: () => now);
  });

  tearDown(() => state.dispose());

  test('pesan berbahaya dari WhatsApp sampai ke orang tua', () async {
    await signIn(UserRole.child);
    final before = messageAlerts();

    final outcome = await scanner.onMessage(
      app: 'WhatsApp',
      text: dangerous,
      sender: 'Om Budi',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(outcome?.escalated, isTrue);
    expect(outcome!.alert!.platform, 'WhatsApp');
    expect(outcome.alert!.counterpartName, 'Om Budi');
    expect(messageAlerts(), before + 1);
  });

  test('obrolan biasa tidak dikirim ke siapa pun', () async {
    await signIn(UserRole.child);
    final before = messageAlerts();

    final outcome = await scanner.onMessage(
      app: 'WhatsApp',
      text: harmless,
      sender: 'Rina',
    );

    expect(outcome?.escalated, isFalse);
    expect(messageAlerts(), before);
  });

  test('pesan yang sama tidak memicu peringatan dua kali', () async {
    await signIn(UserRole.child);

    final first = await scanner.onMessage(
      app: 'SMS',
      text: dangerous,
      sender: '0812',
    );
    now = now.add(const Duration(minutes: 1));
    final again = await scanner.onMessage(
      app: 'SMS',
      text: dangerous,
      sender: '0812',
    );

    expect(first?.escalated, isTrue);
    expect(again, isNull);
  });

  test('pesan yang sama lama kemudian dianggap kejadian baru', () async {
    await signIn(UserRole.child);
    await scanner.onMessage(app: 'SMS', text: dangerous, sender: '0812');

    now = now.add(const Duration(minutes: 30));
    final later = await scanner.onMessage(
      app: 'SMS',
      text: dangerous,
      sender: '0812',
    );

    expect(later?.escalated, isTrue);
  });

  test('tidak memindai saat orang tua menjeda perlindungan', () async {
    await signIn(UserRole.child);
    await repository.setProtectionActive(state.user!.id, false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(state.user!.protectionActive, isFalse);

    final outcome = await scanner.onMessage(app: 'WhatsApp', text: dangerous);

    expect(outcome, isNull);
  });

  test('tidak memindai di ponsel orang tua', () async {
    await signIn(UserRole.parent);

    final outcome = await scanner.onMessage(app: 'WhatsApp', text: dangerous);

    expect(outcome, isNull);
  });

  test('tidak memindai sebelum ada yang masuk', () async {
    final outcome = await scanner.onMessage(app: 'WhatsApp', text: dangerous);
    expect(outcome, isNull);
  });

  test('pesan dari Android diterima lewat kanal id.aura/scan', () async {
    await signIn(UserRole.child);
    final before = messageAlerts();
    scanner.start();

    // Meniru Android yang mengirim pesan ke Dart.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage(
      'id.aura/scan',
      codec.encodeMethodCall(
        const MethodCall('message', {
          'app': 'Instagram',
          'text': dangerous,
          'sender': 'akun_baru123',
          'postedAt': 0,
        }),
      ),
      (_) {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(messageAlerts(), before + 1);
    expect(
      state.alerts
          .firstWhere((a) => a.source == AlertSource.messageScan)
          .platform,
      'Instagram',
    );
  });

  group('lapisan AI', () {
    Future<(AppState, _FakeAi, NotificationScanner)> childWithAi(
      Map<String, dynamic>? answer,
    ) async {
      final ai = _FakeAi(answer);
      final aiState = AppState(repository: ai);
      addTearDown(aiState.dispose);
      await aiState.signIn(name: 'Ayu', role: UserRole.child, age: 12);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return (aiState, ai, NotificationScanner(aiState, useAi: true));
    }

    const subtle = 'aku sayang kamu lebih dari orang tuamu';
    const danger = {
      'dangerous': true,
      'category': 'grooming',
      'level': 'high',
      'reason': 'Pengirim menjauhkan anak dari orang tuanya.',
      'excerpt': 'lebih dari orang tuamu',
    };

    test('pesan halus yang lolos daftar kata tertangkap AI', () async {
      final (aiState, ai, scanner) = await childWithAi(danger);

      final outcome = await scanner.onMessage(
        app: 'WhatsApp',
        text: subtle,
        sender: 'Om',
      );

      expect(ai.asked, [subtle]);
      expect(outcome?.escalated, isTrue);
      expect(outcome!.alert!.categories, [ThreatCategory.grooming]);
      expect(outcome.alert!.riskLevel, RiskLevel.high);
      expect(outcome.alert!.excerpt, 'lebih dari orang tuamu');
    });

    test(
      'pesan yang sudah tertangkap daftar kata tidak dikirim ke AI',
      () async {
        final (_, ai, scanner) = await childWithAi(danger);

        final outcome = await scanner.onMessage(
          app: 'WhatsApp',
          text: dangerous,
        );

        expect(outcome?.escalated, isTrue);
        expect(
          ai.asked,
          isEmpty,
          reason: 'hemat biaya dan tetap jalan offline',
        );
      },
    );

    test('AI menilai aman: tidak ada peringatan', () async {
      final (_, ai, scanner) = await childWithAi({
        'dangerous': false,
        'category': 'none',
        'level': 'safe',
        'reason': '',
        'excerpt': '',
      });

      final outcome = await scanner.onMessage(app: 'WhatsApp', text: harmless);

      expect(ai.asked, [harmless]);
      expect(outcome?.escalated, isFalse);
    });

    test('AI tidak tersedia: tetap memakai daftar kata tanpa galat', () async {
      final (_, ai, scanner) = await childWithAi(null);

      final outcome = await scanner.onMessage(app: 'WhatsApp', text: subtle);

      expect(ai.asked, hasLength(1));
      expect(outcome?.escalated, isFalse);
    });

    test('jawaban AI yang aneh tidak menjatuhkan aplikasi', () {
      expect(
        ThreatAssessment.fromAi({'dangerous': true, 'level': 'entah'}).level,
        RiskLevel.safe,
      );
      final unknown = ThreatAssessment.fromAi({
        'dangerous': true,
        'level': 'medium',
        'category': 'kategori_baru',
      });
      expect(unknown.level, RiskLevel.medium);
      expect(unknown.categories, isEmpty);
    });
  });

  test('bawaan: tanpa AI, tidak ada pesan yang keluar dari ponsel', () async {
    final ai = _FakeAi({
      'dangerous': true,
      'category': 'grooming',
      'level': 'high',
      'reason': 'x',
      'excerpt': 'x',
    });
    final offline = AppState(repository: ai);
    addTearDown(offline.dispose);
    await offline.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final outcome = await NotificationScanner(
      offline,
    ).onMessage(app: 'WhatsApp', text: harmless);

    expect(NotificationScanner.aiEnabled, isFalse);
    expect(ai.asked, isEmpty);
    expect(outcome?.escalated, isFalse);
  });
}
