import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/domain/services/location_service.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(repository: DemoRepository());
    await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    // Memberi waktu bagi langganan stream untuk mengisi data awal.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() => state.dispose());

  test('pesan aman tidak membuat peringatan baru', () async {
    final before = state.alerts.length;
    final outcome = await state.scanMessage(
      text: 'besok berangkat sekolah bareng ya',
      platform: 'WhatsApp',
    );

    expect(outcome.escalated, isFalse);
    expect(state.alerts.length, before);
  });

  test('pesan berbahaya memunculkan peringatan sekaligus bukti', () async {
    final alertsBefore = state.alerts.length;
    final evidenceBefore = state.evidence.length;

    final outcome = await state.scanMessage(
      text: 'kirim foto tanpa baju ya, jangan bilang siapa siapa',
      platform: 'Instagram DM',
      counterpartName: 'akun_asing',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(outcome.escalated, isTrue);
    expect(outcome.alert!.riskLevel, RiskLevel.critical);
    expect(state.alerts.length, alertsBefore + 1);
    expect(state.evidence.length, evidenceBefore + 1);
    expect(state.evidence.first.payload, contains('foto tanpa baju'));
  });

  test('laporan anak tetap naik walau isinya tidak memicu deteksi', () async {
    final outcome = await state.scanMessage(
      text: 'dia terus nanya aku lagi di mana',
      platform: 'TikTok',
      childInitiated: true,
    );

    expect(outcome.escalated, isTrue);
    expect(outcome.alert!.source, AlertSource.childReport);
    expect(outcome.alert!.riskLevel.notifiesParent, isTrue);
  });

  test('tombol darurat mengirim peringatan kritis beserta lokasi', () async {
    final alert = await state.triggerPanic(
      location: LocationResult.found(
        latitude: -6.2,
        longitude: 106.8,
        accuracyMetres: 12,
        fixedAt: DateTime(2026, 10, 17, 14, 30),
        isLastKnown: false,
      ),
      locationLabel: 'Jakarta Pusat',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(alert, isNotNull);
    expect(alert!.riskLevel, RiskLevel.critical);
    expect(alert.source, AlertSource.panicButton);
    expect(alert.hasLocation, isTrue);

    final payload = state.evidence.first.payload!;
    expect(payload, contains('106.8'));
    expect(payload, contains('akurasi sekitar 12 m'));
  });

  test(
    'SOS tetap terkirim walau lokasi gagal, dan buktinya menyebut alasan',
    () async {
      // Anak yang mematikan GPS tetap harus bisa minta tolong. Yang tidak boleh
      // terjadi adalah bukti yang diam-diam menyiratkan lokasi ikut terkirim.
      final alert = await state.triggerPanic(
        location: const LocationResult.failed(LocationFailure.serviceDisabled),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(alert, isNotNull);
      expect(alert!.riskLevel, RiskLevel.critical);
      expect(alert.hasLocation, isFalse);
      expect(state.evidence.first.payload, contains('GPS) sedang mati'));
    },
  );

  test('posisi lama ditandai apa adanya di bukti', () async {
    await state.triggerPanic(
      location: LocationResult.found(
        latitude: -6.2,
        longitude: 106.8,
        accuracyMetres: 40,
        fixedAt: DateTime(2026, 10, 17, 9),
        isLastKnown: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Penyidik harus bisa menilai sendiri seberapa bisa diandalkan titik ini.
    expect(state.evidence.first.payload, contains('mungkin sudah berpindah'));
  });

  test('bukti baru tetap menjaga rantai integritas', () async {
    await state.scanMessage(
      text: 'aku bunuh kamu kalau lapor',
      platform: 'SMS',
    );
    await state.triggerPanic();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final status = state.chainStatus;
    expect(status.isIntact, isTrue, reason: status.reason);
    expect(status.checked, state.evidence.length);
  });

  test(
    'risiko rumah tangga mengikuti peringatan tertinggi yang belum dibaca',
    () async {
      await state.scanMessage(
        text: 'kirim foto bugil sekarang',
        platform: 'Telegram',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(state.householdRisk, RiskLevel.critical);
    },
  );

  test('curhat berat ke AI Guardian ikut memberi tahu orang tua', () async {
    final reply = await state.sendToGuardian(
      'aku capek hidup, pengen mati aja',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(reply.shouldAlertParent, isTrue);
    expect(reply.text, contains('sendirian'));
    expect(
      state.alerts.any((a) => a.categories.contains(ThreatCategory.selfHarm)),
      isTrue,
    );
  });

  test('galat teknis diterjemahkan jadi kalimat yang berguna', () {
    // Yang membaca pesan ini sedang memasang aplikasi atau sedang cemas soal
    // anaknya; keduanya tidak terbantu oleh jejak galat mentah.
    expect(
      AppState.humanizeError(
        'AuthApiException(message: Anonymous sign-ins are disabled, '
        'statusCode: 422, code: anonymous_provider_disabled)',
      ),
      contains('Authentication > Providers > Anonymous'),
    );
    expect(
      AppState.humanizeError(
        '{"code":"PGRST205","message":"Could not find the table"}',
      ),
      contains('schema.sql'),
    );
    expect(
      AppState.humanizeError('SocketException: Failed host lookup'),
      contains('internet'),
    );
    // Pesan yang sudah ramah sejak awal diteruskan apa adanya.
    expect(
      AppState.humanizeError(StateError('Kode penautan sudah kedaluwarsa.')),
      'Kode penautan sudah kedaluwarsa.',
    );
  });

  test('token notifikasi dilepas sebelum sesi berakhir', () async {
    // Urutannya penting: pelepasan harus terjadi selagi pengguna masih
    // berwenang menulis ke dokumennya sendiri di Firestore.
    var releasedWhileSignedIn = false;
    state.onBeforeSignOut = () async {
      releasedWhileSignedIn = state.isSignedIn;
    };

    await state.signOut();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(releasedWhileSignedIn, isTrue);
    expect(state.isSignedIn, isFalse);
  });

  test('menandai peringatan mengubah statusnya', () async {
    final target = state.alerts.first;
    await state.markAlert(target.id, AlertStatus.reviewed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(state.alertById(target.id)!.status, AlertStatus.reviewed);
  });

  test(
    'HP anak menyimpan nomor orang tua untuk dipakai tanpa internet',
    () async {
      expect(state.emergencyNumber, '+6281234567890');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('aura.emergency_number'), '+6281234567890');
    },
  );
}
