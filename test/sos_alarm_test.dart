import 'dart:io';

import 'package:aura/core/services/sos_alarm.dart';
import 'package:aura/core/widgets/sos_alarm_banner.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alarm SOS di HP orang tua: sirene dan getar berulang sampai dimatikan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/id/aura/aura';

  test('hanya pesan bertanda sos yang membunyikan alarm', () {
    expect(SosAlarm.isSos({'sos': 'true'}), isTrue);
    expect(SosAlarm.isSos({'sos': 'false', 'urgent': 'true'}), isFalse);
    // Server versi lama belum mengirim tanda ini: notifikasinya tetap biasa.
    expect(SosAlarm.isSos({'riskLevel': 'critical'}), isFalse);
  });

  group('diputar layanan alarm, seperti jam alarm', () {
    // Android hanya memutar satu suara notifikasi dalam satu waktu: alarm
    // yang memakai suara notifikasi dibungkam SMS atau chat yang masuk.
    // Terbukti di emulator: SMS SOS-nya sendiri membungkam alarm itu.
    final service = read('$kotlin/SosAlarmService.kt');
    final alarm = read('$kotlin/SosAlarm.kt');

    test('sirene berulang lewat volume alarm, tetap berbunyi saat senyap', () {
      expect(service, contains('MediaPlayer()'));
      expect(service, contains('isLooping = true'));
      expect(service, contains('setAudioAttributes(SosAlarm.audio)'));
      expect(alarm, contains('.setUsage(AudioAttributes.USAGE_ALARM)'));
      expect(alarm, contains('raw/aura_sos_alarm'));
    });

    test('getar berulang sampai dimatikan', () {
      expect(service, contains('createWaveform(SosAlarm.VIBRATION, 0)'));
    });

    test('notifikasinya sendiri tidak bersuara, supaya tidak dobel', () {
      expect(alarm, contains('setSound(null, null)'));
      expect(alarm, contains('enableVibration(false)'));
    });

    test('tombol Matikan alarm, bisa ditekan dari layar kunci', () {
      expect(alarm, contains('SosAlarmStopReceiver'));
      expect(alarm, contains('VISIBILITY_PUBLIC'));
    });

    test('pesan SOS yang terantar dua kali hanya berbunyi sekali', () {
      expect(alarm, contains('wasHandled(context, id)'));
      expect(alarm, contains('markHandled(context, id)'));
    });
  });

  test('manifest: layanan dan penerimanya terpasang', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('android:name=".SosAlarmService"'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
    );
    // SOS lewat internet: langsung dari pesan FCM, tanpa menunggu Flutter.
    expect(manifest, contains('android:name=".SosPushReceiver"'));
    expect(manifest, contains('com.google.android.c2dm.permission.SEND'));
    expect(manifest, contains('com.google.android.c2dm.intent.RECEIVE'));
  });

  test('sejalan dengan notify-parents', () {
    final server = read('supabase/functions/notify-parents/index.ts');
    final receiver = read('$kotlin/SosPushReceiver.kt');
    // Data yang dibaca SosPushReceiver.kt.
    for (final key in [
      'sos',
      'familyId',
      'alertId',
      'childName',
      'route',
      'detectedAt',
    ]) {
      expect(server, contains('$key:'), reason: key);
      expect(receiver, contains('"$key"'), reason: key);
    }
    // SOS di Android: pesan data saja, tanpa notifikasi FCM yang bersuara
    // sendiri di samping alarm.
    expect(server, contains('if (sos) return { priority: "high" };'));
    expect(
      server,
      contains('...(sos ? {} : { notification: { title, body } })'),
    );
  });

  test('sumber daya Android untuk sirenenya ada', () {
    expect(
      File('android/app/src/main/res/raw/aura_sos_alarm.wav').existsSync(),
      isTrue,
    );
    expect(
      read('android/app/src/main/res/raw/keep.xml'),
      contains('@raw/aura_sos_alarm'),
    );
  });

  test('tidak meminta izin telepon, Kontak, atau SMS', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    for (final permission in [
      'CALL_PHONE',
      'READ_CONTACTS',
      'WRITE_CONTACTS',
      'SEND_SMS',
      'RECEIVE_SMS',
    ]) {
      expect(
        manifest,
        isNot(contains('android.permission.$permission')),
        reason: permission,
      );
    }
  });

  group('keluarga untuk alarm, di HP orang tua', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<String?> saved() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppState.alarmFamilyKey);
    }

    test('dibaca penerima pesan di Android dengan nama yang sama', () {
      expect(
        read('$kotlin/SosPushReceiver.kt'),
        contains('"flutter.${AppState.alarmFamilyKey}"'),
      );
    });

    test(
      'orang tua menyimpannya; HP-nya hanya berbunyi untuk keluarga itu',
      () async {
        final state = AppState(repository: DemoRepository());
        addTearDown(state.dispose);
        await state.signIn(
          name: 'Bunda',
          role: UserRole.parent,
          phone: '081234567890',
        );
        expect(await saved(), DemoRepository.demoFamilyId);

        // Setelah keluar, HP ini tidak lagi berbunyi untuk keluarga itu.
        await state.signOut();
        expect(await saved(), isNull);
      },
    );

    test('HP anak tidak pernah menyimpannya', () async {
      final state = AppState(repository: DemoRepository());
      addTearDown(state.dispose);
      await state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
      expect(await saved(), isNull);
    });
  });

  group('jembatan ke Android', () {
    const channel = MethodChannel('id.aura/sos');
    final calls = <String>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return switch (call.method) {
              'testSosAlarm' => true,
              'sosAlarmState' => {
                'ringing': true,
                'route': '/orangtua/peringatan/a1',
              },
              'takeSosRoute' => '/orangtua/peringatan/a1',
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('tes, keadaan, dan mematikan alarm', () async {
      expect(await SosAlarm.test(), isTrue);
      final state = await SosAlarm.state();
      expect(state.ringing, isTrue);
      expect(state.route, '/orangtua/peringatan/a1');
      expect(await SosAlarm.takeOpenedRoute(), '/orangtua/peringatan/a1');
      await SosAlarm.stop();
      expect(calls, [
        'testSosAlarm',
        'sosAlarmState',
        'takeSosRoute',
        'stopSosAlarm',
      ]);
    });

    test('tanpa Android: senyap, tidak galat', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect((await SosAlarm.state()).ringing, isFalse);
      expect(await SosAlarm.test(), isFalse);
    });
  });

  group('kartu alarm di layar', () {
    Future<void> pump(
      WidgetTester tester,
      ValueNotifier<String?> alarm,
      VoidCallback onStop,
    ) => tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            SosAlarmBanner(alarm: alarm, onStop: onStop, child: child!),
        home: const Scaffold(body: Center(child: Text('Beranda'))),
      ),
    );

    testWidgets('muncul selama alarm berbunyi, dan bisa mematikannya', (
      tester,
    ) async {
      final alarm = ValueNotifier<String?>(null);
      addTearDown(alarm.dispose);
      var stopped = 0;
      await pump(tester, alarm, () => stopped++);

      expect(find.text('Alarm SOS berbunyi'), findsNothing);

      alarm.value = '/orangtua/peringatan/a1';
      await tester.pump();
      expect(find.text('Alarm SOS berbunyi'), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget, reason: 'halaman tetap ada');

      await tester.tap(find.text('Matikan alarm'));
      expect(stopped, 1);

      alarm.value = null;
      await tester.pump();
      expect(find.text('Alarm SOS berbunyi'), findsNothing);
    });

    testWidgets('layar sempit dengan huruf besar: tidak meluber', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final alarm = ValueNotifier<String?>('');
      addTearDown(alarm.dispose);
      await pump(tester, alarm, () {});

      expect(find.text('Matikan alarm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
