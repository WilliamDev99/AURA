import 'package:aura/core/widgets/clay.dart';
import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/evidence_item.dart';
import 'package:aura/features/parent/forensics_timeline_page.dart';
import 'package:aura/core/widgets/heat_tier.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Seperti Supabase: tautan bukti ke peringatan hanya tersimpan di peringatan
/// (`evidence_ids`), bukti sendiri tidak membawa `alertId`.
class _SupabaseLikeRepo extends DemoRepository {
  @override
  Stream<List<EvidenceItem>> watchEvidence(String familyId) => super
      .watchEvidence(familyId)
      .map(
        (items) => [
          for (final e in items)
            EvidenceItem(
              id: e.id,
              familyId: e.familyId,
              childId: e.childId,
              kind: e.kind,
              capturedAt: e.capturedAt,
              recordedAt: e.recordedAt,
              description: e.description,
              contentHash: e.contentHash,
              chainHash: e.chainHash,
              sequence: e.sequence,
              previousHash: e.previousHash,
              payload: e.payload,
              storagePath: e.storagePath,
              capturedBy: e.capturedBy,
              consentNote: e.consentNote,
            ),
        ],
      );
}

/// Log bukti: setiap bukti tampil dengan level peringatannya (LOW, MEDIUM,
/// HARD), dan bisa disaring per jenis.
void main() {
  Future<AppState> open(WidgetTester tester, {DemoRepository? repo}) async {
    // Layar tinggi supaya semua entri ikut dibangun.
    tester.view.physicalSize = const Size(1344, 9000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = AppState(repository: repo ?? DemoRepository());
    addTearDown(state.dispose);
    final signingIn = state.signIn(
      name: 'Bunda',
      role: UserRole.parent,
      phone: '+6281234567890',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await signingIn;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: ForensicsTimelinePage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    return state;
  }

  /// Label level yang diharapkan untuk tiap bukti.
  List<String> expectedLabels(AppState state, bool Function(EvidenceItem) f) {
    final viaAlert = {
      for (final a in state.alerts)
        for (final id in a.evidenceIds) id: a,
    };
    return [
      for (final item in state.evidence.where(f))
        switch (viaAlert[item.id] ??
            (item.alertId == null ? null : state.alertById(item.alertId!))) {
          final alert? => HeatTier.of(alert.riskLevel).label,
          null => 'CATATAN',
        },
    ];
  }

  int shown(WidgetTester tester, String label) =>
      find.text(label).evaluate().length;

  testWidgets('tampilan sesuai desain', (tester) async {
    await open(tester);

    expect(find.text('Forensik Timeline'), findsOneWidget);
    // Saringan per level, sesuai permintaan orang tua.
    for (final chip in ['Semua', 'Low', 'Medium', 'Hard']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.textContaining('Rantai bukti utuh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rincian bukti terbuka di lembar clay yang terang', (
    tester,
  ) async {
    final state = await open(tester);
    final newest = state.evidence.first;

    // Label level pertama milik bukti paling atas (paling baru).
    const labels = {'HARD', 'MEDIUM', 'LOW', 'CATATAN'};
    await tester.tap(
      find.byWidgetPredicate((w) => w is Text && labels.contains(w.data)).first,
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      const Color(0xFFF2F0FB),
    );
    final title = find.text('Bukti #${newest.sequence}');
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).style?.color, ClayColors.ink);
    expect(find.text('Metadata integritas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level tiap bukti mengikuti peringatannya', (tester) async {
    final state = await open(tester);
    final labels = expectedLabels(state, (_) => true);
    expect(labels, isNotEmpty);

    for (final label in ['HARD', 'MEDIUM', 'LOW', 'CATATAN']) {
      expect(
        shown(tester, label),
        labels.where((l) => l == label).length,
        reason: 'jumlah label $label',
      );
    }
  });

  testWidgets('bukti tanpa alertId tetap dapat level dari peringatannya', (
    tester,
  ) async {
    final state = await open(tester, repo: _SupabaseLikeRepo());
    expect(state.evidence.every((e) => e.alertId == null), isTrue);

    final linked = {for (final a in state.alerts) ...a.evidenceIds};
    final orphans = state.evidence.where((e) => !linked.contains(e.id));

    expect(shown(tester, 'CATATAN'), orphans.length);
    expect(
      shown(tester, 'HARD') + shown(tester, 'MEDIUM') + shown(tester, 'LOW'),
      state.evidence.length - orphans.length,
    );
  });

  for (final (chip, label) in [
    ('Low', 'LOW'),
    ('Medium', 'MEDIUM'),
    ('Hard', 'HARD'),
  ]) {
    testWidgets('saringan $chip hanya menampilkan bukti $label', (
      tester,
    ) async {
      final state = await open(tester);
      final expected = expectedLabels(
        state,
        (_) => true,
      ).where((l) => l == label).length;

      await tester.tap(find.text(chip));
      await tester.pump(const Duration(milliseconds: 200));

      expect(shown(tester, label), expected);
      for (final other in ['HARD', 'MEDIUM', 'LOW', 'CATATAN']) {
        if (other != label) {
          expect(shown(tester, other), 0, reason: '$other ikut tampil');
        }
      }
      if (expected == 0) {
        expect(find.text('Belum ada bukti dengan level ini.'), findsOneWidget);
      }
    });
  }

  testWidgets('kembali ke Semua menampilkan semua bukti lagi', (tester) async {
    final state = await open(tester);

    await tester.tap(find.text('Hard'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Semua'));
    await tester.pump(const Duration(milliseconds: 200));

    final total = [
      'HARD',
      'MEDIUM',
      'LOW',
      'CATATAN',
    ].map((l) => shown(tester, l)).fold(0, (a, b) => a + b);
    expect(total, state.evidence.length);
  });
}
