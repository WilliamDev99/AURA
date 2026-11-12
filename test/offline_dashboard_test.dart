import 'dart:async';

import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/features/parent/parent_dashboard_page.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tanpa internet: profil tersimpan membuka AURA, tetapi peringatan keluarga
/// tidak pernah datang dari server.
class _OfflineFamilyRepository extends DemoRepository {
  final alerts = StreamController<List<ThreatAlert>>.broadcast();

  @override
  Stream<List<ThreatAlert>> watchAlerts(String familyId) => alerts.stream;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tanpa internet, beranda orang tua tidak menyebut anak aman', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1344, 2992);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repository = _OfflineFamilyRepository();
    addTearDown(repository.alerts.close);
    final state = AppState(repository: repository);
    addTearDown(state.dispose);
    final signingIn = state.signIn(
      name: 'Bunda',
      role: UserRole.parent,
      phone: '081234567890',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: ParentDashboardPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Daftar kosong di sini berarti belum tahu, bukan tidak ada apa-apa.
    expect(state.familyDataLoaded, isFalse);
    expect(find.text('Menunggu internet'), findsOneWidget);
    expect(find.textContaining('aman'), findsNothing);
    expect(find.text('BELUM ADA ANAK'), findsNothing);

    // Begitu internet kembali dan data datang, beranda biasa muncul.
    repository.alerts.add(const []);
    await tester.pump(const Duration(milliseconds: 200));
    expect(state.familyDataLoaded, isTrue);
    expect(find.text('Menunggu internet'), findsNothing);
  });
}
