import 'package:aura/core/widgets/clay.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/features/parent/alert_detail_page.dart';
import 'package:aura/features/parent/parent_dashboard_page.dart';
import 'package:aura/features/parent/threat_radar.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Tombol "Saya sudah menangani ini" harus bertanya dulu: ancaman yang
/// ditandai selesai hilang dari daftar "menunggu tindakan".
void main() {
  Future<(AppState, String)> openDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1344, 2992);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = AppState(repository: DemoRepository());
    addTearDown(state.dispose);
    // Masuk demo memakai Future.delayed; waktu hanya maju lewat pump.
    final signingIn = state.signIn(
      name: 'Bunda',
      role: UserRole.parent,
      phone: '+6281234567890',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;
    await tester.pump(const Duration(milliseconds: 100));

    final alert = ThreatAlert(
      id: 'sos-1',
      familyId: DemoRepository.demoFamilyId,
      childId: DemoRepository.demoChildId,
      childName: 'Ayu',
      riskLevel: RiskLevel.critical,
      categories: const [ThreatCategory.violence],
      source: AlertSource.panicButton,
      platform: 'Tombol Darurat AURA',
      // Waktu sekarang supaya selalu paling atas di daftar, berapa pun
      // tanggal test dijalankan.
      detectedAt: DateTime.now(),
      summary: 'Ayu menekan tombol darurat. Hubungi anak sekarang juga.',
      excerpt: null,
      score: 1,
      evidenceIds: const [],
    );
    await state.repository.raiseAlert(alert);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.alertById(alert.id)?.status, AlertStatus.unread);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: AlertDetailPage(alertId: alert.id)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    return (state, alert.id);
  }

  Future<void> tapHandled(WidgetTester tester) async {
    final button = find.text('Saya sudah menangani ini');
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('menanyakan dulu sebelum menandai', (tester) async {
    await openDetail(tester);
    await tapHandled(tester);

    expect(
      find.text('Apakah Anda sudah benar menangani ancaman ini?'),
      findsOneWidget,
    );
    expect(find.text('Sudah'), findsOneWidget);
    expect(find.text('Belum'), findsOneWidget);

    // Dialog bergaya clay: kartu terang dengan tulisan biru tua.
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.byType(ClayCard)),
      findsWidgets,
    );
    expect(
      tester
          .widget<Text>(
            find.text('Apakah Anda sudah benar menangani ancaman ini?'),
          )
          .style
          ?.color,
      ClayColors.ink,
    );
  });

  testWidgets('menu titik tiga terang dan terbaca', (tester) async {
    await openDetail(tester);

    await tester.tap(find.byType(PopupMenuButton<AlertStatus>));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final label in [
      'Tandai sudah dilihat',
      'Tandai aman',
      'Tandai dieskalasi',
    ]) {
      expect(
        tester.widget<Text>(find.text(label)).style?.color,
        ClayColors.ink,
        reason: label,
      );
    }
  });

  testWidgets('"Belum" menutup pertanyaan tanpa mengubah apa pun', (
    tester,
  ) async {
    final (state, alertId) = await openDetail(tester);
    await tapHandled(tester);

    await tester.tap(find.text('Belum'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.alertById(alertId)!.status, AlertStatus.unread);
    expect(
      find.text('Apakah Anda sudah benar menangani ancaman ini?'),
      findsNothing,
    );
    expect(find.text('Saya sudah menangani ini'), findsOneWidget);
  });

  testWidgets('"Sudah" menandai ancaman selesai', (tester) async {
    final (state, alertId) = await openDetail(tester);
    await tapHandled(tester);

    await tester.tap(find.text('Sudah'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.alertById(alertId)!.status, AlertStatus.reviewed);
    expect(find.text('Ancaman ini ditandai sudah ditangani.'), findsOneWidget);
    expect(find.text('Sudah ditangani'), findsOneWidget);
  });

  testWidgets('yang sudah ditangani hilang dari dashboard', (tester) async {
    final (state, alertId) = await openDetail(tester);
    // Layar setinggi ini supaya radar dan daftar peringatan sama-sama
    // terbangun: daftar dashboard hanya membangun bagian yang dekat layar.
    tester.view.physicalSize = const Size(1344, 6000);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: ParentDashboardPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final before = state.unreadAlerts.length;
    expect(find.text('$before menunggu tindakan'), findsOneWidget);
    expect(find.text('Ayu - Tombol Darurat AURA'), findsOneWidget);

    await state.markAlert(alertId, AlertStatus.reviewed);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ayu - Tombol Darurat AURA'), findsNothing);
    expect(find.text('${before - 1} menunggu tindakan'), findsOneWidget);
    // Titik di radar dan angkanya ikut hilang.
    final radar = tester.widget<ThreatRadar>(find.byType(ThreatRadar));
    expect(radar.alerts.any((a) => a.id == alertId), isFalse);
    // Tidak dihapus: tetap tersimpan untuk bukti dan pelaporan.
    expect(state.alertById(alertId), isNotNull);
  });
}
