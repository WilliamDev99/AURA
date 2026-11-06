import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/services/location_service.dart';
import 'package:aura/features/child/widgets/location_guard.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// GPS tiruan yang mencatat berapa kali anak diminta menyalakannya.
class _FakeGps extends LocationService {
  _FakeGps(this.answer);

  LocationSwitch answer;
  int asked = 0;

  @override
  Future<LocationSwitch> ensureServiceOn() async {
    asked++;
    return answer;
  }
}

/// Setiap AURA dibuka di ponsel anak, GPS diminta menyala supaya tombol
/// darurat selalu bisa mengirim lokasi.
void main() {
  Future<_FakeGps> open(WidgetTester tester, LocationSwitch answer) async {
    final gps = _FakeGps(answer);
    final state = AppState(repository: DemoRepository(), locationService: gps);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(body: LocationGuard(child: Text('beranda anak'))),
        ),
      ),
    );
    await tester.pump();
    return gps;
  }

  Future<void> lifecycle(WidgetTester tester, List<AppLifecycleState> steps) {
    for (final step in steps) {
      tester.binding.handleAppLifecycleStateChanged(step);
    }
    return tester.pump();
  }

  testWidgets('GPS diminta menyala saat AURA dibuka', (tester) async {
    final gps = await open(tester, LocationSwitch.on);
    expect(gps.asked, 1);
    expect(find.text('beranda anak'), findsOneWidget);
  });

  testWidgets('jendela lokasi tertutup: tidak ditanya ulang', (tester) async {
    final gps = await open(tester, LocationSwitch.declined);

    // Jendela "Aktifkan lokasi?" hanya membuat AURA sebentar tidak aktif.
    await lifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(gps.asked, 1);
  });

  testWidgets('dibuka lagi setelah ditinggal: ditanya lagi', (tester) async {
    final gps = await open(tester, LocationSwitch.on);

    await lifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await lifecycle(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(gps.asked, 2);
  });

  testWidgets('anak menolak: diberi tahu akibatnya', (tester) async {
    await open(tester, LocationSwitch.declined);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('GPS masih mati'), findsOneWidget);
  });

  testWidgets('GPS menyala: tidak ada peringatan', (tester) async {
    await open(tester, LocationSwitch.on);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('GPS masih mati'), findsNothing);
  });

  testWidgets('bukan Android: tidak ada yang ditampilkan', (tester) async {
    await open(tester, LocationSwitch.unavailable);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsNothing);
  });
}
