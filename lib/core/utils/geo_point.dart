/// Titik lokasi yang dibaca dari teks bukti.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude, {this.accuracyMetres});

  final double latitude;
  final double longitude;
  final double? accuracyMetres;
}

final _coordinates = RegExp(
  r'Lat (-?\d+(?:\.\d+)?), Lon (-?\d+(?:\.\d+)?)'
  r'(?: \(akurasi sekitar (\d+(?:\.\d+)?) m\))?',
);

/// Membaca koordinat dari isi bukti lokasi, mis.
/// "Lat -6.1753924, Lon 106.8271528 (akurasi sekitar 20 m). ...".
///
/// Koordinat sengaja dibaca dari teks, bukan disimpan di kolom terpisah:
/// teks itulah yang tersegel hash, jadi peta selalu menunjuk titik yang
/// sama dengan yang bisa diverifikasi penyidik.
GeoPoint? parseEvidenceLocation(String? payload) {
  if (payload == null) return null;
  final match = _coordinates.firstMatch(payload);
  if (match == null) return null;
  final latitude = double.parse(match.group(1)!);
  final longitude = double.parse(match.group(2)!);
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  final accuracy = match.group(3);
  return GeoPoint(
    latitude,
    longitude,
    accuracyMetres: accuracy == null ? null : double.parse(accuracy),
  );
}
