import 'package:aura/core/utils/geo_point.dart';
import 'package:aura/core/widgets/location_map.dart';
import 'package:aura/domain/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membaca koordinat dan akurasi dari isi bukti', () {
    final point = parseEvidenceLocation(
      'Lat -6.1753924, Lon 106.8271528 (akurasi sekitar 20 m). Diukur saat '
      'tombol darurat ditekan. Dikirim atas penekanan tombol darurat oleh '
      'anak pada 2026-10-17T23:41:27.499075.',
    );

    expect(point, isNotNull);
    expect(point!.latitude, -6.1753924);
    expect(point.longitude, 106.8271528);
    expect(point.accuracyMetres, 20);
  });

  test('sejalan dengan teks yang ditulis LocationResult', () {
    // Kalau format describe() berubah, peta diam-diam hilang. Test ini
    // menjaga keduanya tetap sepakat.
    const result = LocationResult.found(
      latitude: -6.2,
      longitude: 106.8166,
      accuracyMetres: 12.6,
      fixedAt: null,
      isLastKnown: false,
    );

    final point = parseEvidenceLocation(result.describe());

    expect(point?.latitude, -6.2);
    expect(point?.longitude, 106.8166);
    expect(point?.accuracyMetres, 13);
  });

  test('tanpa akurasi tetap terbaca', () {
    final point = parseEvidenceLocation('Lat 1.5, Lon 2.25. Lainnya.');
    expect(point?.latitude, 1.5);
    expect(point?.accuracyMetres, isNull);
  });

  test('bukti tanpa lokasi tidak memunculkan peta', () {
    expect(parseEvidenceLocation(null), isNull);
    expect(
      parseEvidenceLocation(
        'Lokasi tidak tersedia: layanan lokasi (GPS) sedang mati di '
        'perangkat anak.',
      ),
      isNull,
    );
    expect(parseEvidenceLocation('Pesan: "kirim foto kamu"'), isNull);
  });

  test('koordinat mustahil ditolak', () {
    expect(parseEvidenceLocation('Lat 95.0, Lon 10.0'), isNull);
    expect(parseEvidenceLocation('Lat 10.0, Lon 190.0'), isNull);
  });

  testWidgets(
    'peta tampil dengan tombol Google Maps, walau ubin gagal dimuat',
    (tester) async {
      // Di lingkungan test semua permintaan jaringan gagal, sama seperti HP
      // orang tua yang sedang tanpa internet: halaman tidak boleh rusak.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocationMap(
              latitude: -6.1753924,
              longitude: 106.8271528,
              accuracyMetres: 20,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Buka di Google Maps'), findsOneWidget);
      // Wajib menurut ketentuan pemakaian OpenStreetMap.
      expect(find.text('© OpenStreetMap'), findsOneWidget);
    },
  );

  testWidgets('tombol +/- bergaya Leaflet mengubah zoom, dan bisa kembali', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocationMap(latitude: -6.1753924, longitude: 106.8271528),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    double zoom() => MapCamera.of(tester.element(find.byType(TileLayer))).zoom;
    expect(zoom(), 16);

    await tester.tap(find.bySemanticsLabel('Perbesar peta'));
    await tester.pump();
    expect(zoom(), 17);

    await tester.tap(find.bySemanticsLabel('Perkecil peta'));
    await tester.tap(find.bySemanticsLabel('Perkecil peta'));
    await tester.pump();
    expect(zoom(), 15);

    await tester.tap(find.bySemanticsLabel('Kembali ke lokasi anak'));
    await tester.pump();
    expect(zoom(), 16);
  });

  testWidgets('peta bisa digeser, dan mengetuk peta tidak membuka apa pun', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocationMap(latitude: -6.1753924, longitude: 106.8271528),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    // Google Maps hanya lewat tombol di bawah peta.
    expect(map.options.onTap, isNull);
    final flags = map.options.interactionOptions.flags;
    expect(flags & InteractiveFlag.drag, isNot(0));
    expect(flags & InteractiveFlag.pinchZoom, isNot(0));

    final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
    final before = camera.center;
    await tester.drag(find.byType(FlutterMap), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 500));
    final after = MapCamera.of(tester.element(find.byType(TileLayer))).center;
    expect(after.longitude, isNot(before.longitude));
  });

  testWidgets(
    'layar sempit dengan huruf besar: keterangan peta tidak meluber',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                child: LocationMap(
                  latitude: -6.1753924,
                  longitude: 106.8271528,
                  accuracyMetres: 20,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    },
  );
}
