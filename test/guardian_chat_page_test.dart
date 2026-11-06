import 'package:aura/core/widgets/liquid_glass.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/features/child/guardian_chat_page.dart';
import 'package:aura/features/child/widgets/aura_robot.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Ruang obrolan anak dengan Aura, sesuai desain: sapaan dalam balon besar,
/// maskot, dan pilihan cepat di panel putih.
void main() {
  Future<AppState> open(
    WidgetTester tester, {
    Size size = const Size(1080, 2400),
    double ratio = 2.75,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);

    final state = AppState(repository: DemoRepository());
    addTearDown(state.dispose);
    final signingIn = state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const GuardianChatPage(),
        ),
      ),
    );
    // Dua frame: ukuran panel diukur dulu, lalu maskot ditempatkan.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    return state;
  }

  testWidgets('pembuka sesuai desain', (tester) async {
    await open(tester);

    expect(find.text('AURA'), findsOneWidget);
    expect(find.text('Halo! Saya Aura'), findsOneWidget);
    expect(
      find.textContaining('Kamu lagi ngerasa apa hari ini?'),
      findsOneWidget,
    );
    for (final chip in [
      'Aku ada masalah di game',
      'Ada yang chat aneh...',
      'Aku merasa takut...',
      'Ceritain aja, aku disini kok!',
    ]) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('Ketik pesan...'), findsOneWidget);
    expect(find.byType(AuraRobot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pilihan cepat mengirim pesan dan Aura membalas', (tester) async {
    final state = await open(tester);

    await tester.tap(find.text('Aku merasa takut...'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final fromChild = state.chat.where((m) => m.isChild).last;
    expect(fromChild.text, 'Aku merasa takut');
    expect(state.chat.last.isChild, isFalse, reason: 'Aura membalas');
    expect(find.text('Aku merasa takut'), findsOneWidget);
    expect(find.text('Halo! Saya Aura'), findsNothing);
    // Maskot besar hanya untuk pembuka; dalam obrolan cukup avatar kecil.
    expect(find.byType(AuraRobot), findsNothing);
  });

  testWidgets('"Ceritain aja" membuka kolom ketik, tidak mengirim apa pun', (
    tester,
  ) async {
    final state = await open(tester);

    await tester.tap(find.text('Ceritain aja, aku disini kok!'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(state.chat.where((m) => m.text.startsWith('Ceritain')), isEmpty);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('layar kecil dengan huruf besar tidak berantakan', (
    tester,
  ) async {
    await open(tester, size: const Size(720, 1280), ratio: 2, textScale: 1.3);

    expect(tester.takeException(), isNull);
    // Kolom ketik selalu terlihat; pilihan cepat boleh digulir.
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(find.text('Aku ada masalah di game').hitTestable(), findsOneWidget);
  });

  testWidgets('riwayat lama tidak menutupi sapaan pembuka', (tester) async {
    final state = await open(tester);
    // Data demo sudah berisi obrolan sebelumnya.
    expect(state.chat, isNotEmpty);
    expect(find.text('Halo! Saya Aura'), findsOneWidget);
  });

  testWidgets('kepala halaman kaca: tombol kembali menutup halaman', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final state = AppState(repository: DemoRepository());
    addTearDown(state.dispose);
    final signingIn = state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuardianChatPage(),
                    ),
                  ),
                  child: const Text('beranda'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('beranda'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Tombol kembali dan judul sama-sama berupa kaca.
    expect(find.byType(LiquidGlassButton), findsOneWidget);
    expect(
      find.ancestor(of: find.text('AURA'), matching: find.byType(LiquidGlass)),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Kembali'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(GuardianChatPage), findsNothing);
    expect(find.text('beranda'), findsOneWidget);
  });

  double bubbleScale(WidgetTester tester) {
    final scale = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: find.text('Halo! Saya Aura'),
            matching: find.byType(ScaleTransition),
          )
          .last,
    );
    return scale.scale.value;
  }

  testWidgets('sapaan muncul dengan animasi lalu tampil penuh', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final state = AppState(repository: DemoRepository());
    addTearDown(state.dispose);
    final signingIn = state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: GuardianChatPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(bubbleScale(tester), lessThan(0.9), reason: 'baru mulai muncul');

    await tester.pump(const Duration(milliseconds: 1200));
    expect(bubbleScale(tester), 1.0);
  });

  testWidgets('animasi dimatikan di ponsel: sapaan langsung lengkap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final state = AppState(repository: DemoRepository());
    addTearDown(state.dispose);
    final signingIn = state.signIn(name: 'Ayu', role: UserRole.child, age: 12);
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const GuardianChatPage(),
        ),
      ),
    );
    await tester.pump();

    expect(bubbleScale(tester), 1.0);
  });
}
