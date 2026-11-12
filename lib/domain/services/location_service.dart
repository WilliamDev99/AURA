import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Kenapa lokasi tidak berhasil diambil. Dibedakan karena tindak lanjutnya
/// berbeda: izin ditolak perlu diminta ulang, GPS mati perlu dinyalakan,
/// sedangkan kehabisan waktu cukup dicoba lagi.
enum LocationFailure {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timedOut,
  unavailable,
}

/// Hasil permintaan menyalakan lokasi (GPS) di ponsel anak.
enum LocationSwitch {
  /// Lokasi menyala (sudah menyala, atau baru dinyalakan anak).
  on,

  /// Anak memilih tidak menyalakannya.
  declined,

  /// Tidak bisa ditanyakan: bukan Android, atau ponsel tanpa Play Services.
  unavailable,
}

/// Hasil pengambilan lokasi. Entah ada koordinatnya, entah ada alasannya —
/// tidak pernah keduanya kosong, supaya pemanggil tidak bisa diam-diam
/// menganggap lokasi berhasil padahal tidak.
@immutable
class LocationResult {
  const LocationResult.found({
    required this.latitude,
    required this.longitude,
    required this.accuracyMetres,
    required this.fixedAt,
    required this.isLastKnown,
  }) : failure = null;

  const LocationResult.failed(LocationFailure this.failure)
    : latitude = null,
      longitude = null,
      accuracyMetres = null,
      fixedAt = null,
      isLastKnown = false;

  final double? latitude;
  final double? longitude;
  final double? accuracyMetres;
  final DateTime? fixedAt;

  /// True bila ini posisi terakhir yang tersimpan, bukan hasil pengukuran
  /// baru. Tetap berguna saat darurat, tetapi harus dikatakan apa adanya
  /// karena anak mungkin sudah berpindah.
  final bool isLastKnown;

  final LocationFailure? failure;

  bool get hasPosition => latitude != null && longitude != null;

  /// Kalimat untuk disimpan di berkas bukti. Ditulis supaya penyidik bisa
  /// menilai sendiri seberapa bisa diandalkan titik ini.
  String describe() {
    if (!hasPosition) {
      return switch (failure!) {
        LocationFailure.permissionDenied =>
          'Lokasi tidak tersedia: izin lokasi belum diberikan di perangkat anak.',
        LocationFailure.permissionDeniedForever =>
          'Lokasi tidak tersedia: izin lokasi ditolak permanen di pengaturan '
              'perangkat anak.',
        LocationFailure.serviceDisabled =>
          'Lokasi tidak tersedia: layanan lokasi (GPS) sedang mati di '
              'perangkat anak.',
        LocationFailure.timedOut =>
          'Lokasi tidak tersedia: perangkat anak belum mendapat sinyal GPS '
              'saat peringatan dikirim.',
        LocationFailure.unavailable =>
          'Lokasi tidak tersedia: perangkat anak tidak dapat menentukan posisi.',
      };
    }

    final accuracy = accuracyMetres == null
        ? ''
        : ' (akurasi sekitar ${accuracyMetres!.round()} m)';
    final source = isLastKnown
        ? 'Posisi terakhir yang tercatat perangkat pada '
              '${fixedAt?.toIso8601String()}; anak mungkin sudah berpindah.'
        : 'Diukur saat tombol darurat ditekan.';
    return 'Lat $latitude, Lon $longitude$accuracy. $source';
  }
}

/// Mengambil lokasi perangkat anak saat tombol darurat ditekan.
///
/// Lokasi hanya diambil atas tindakan sadar anak, tidak pernah dipantau
/// terus-menerus. Itu sebabnya kelas ini tidak punya stream dan tidak
/// menyimpan riwayat apa pun.
class LocationService {
  const LocationService();

  /// Kanal ke MainActivity.kt. Dipakai di Android menggantikan
  /// `Geolocator.getCurrentPosition`, yang di geolocator_android 5.1.1 selalu
  /// mendaftarkan pendengar NMEA lewat panggilan binder di thread utama. Saat
  /// layanan GPS sistem tidak menjawab, seluruh aplikasi membeku — persis di
  /// tengah pengiriman SOS.
  static const _native = MethodChannel('id.aura/sos');

  bool get _useNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Meminta izin lokasi. Dipanggil di saat tenang (setelah anak menyetujui
  /// perlindungan), bukan saat darurat — dialog izin yang muncul di tengah
  /// keadaan panik justru memperlambat pertolongan.
  Future<bool> requestPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return _granted(permission);
    } catch (error) {
      debugPrint('AURA: permintaan izin lokasi gagal ($error).');
      return false;
    }
  }

  /// Memastikan lokasi (GPS) menyala supaya tombol darurat bisa mengirim
  /// titik lokasi. Bila mati, anak diminta menyalakannya lewat jendela resmi
  /// Google "Aktifkan lokasi?" (satu ketukan). Lokasi tetap tidak diambil di
  /// sini; ini hanya menyiapkan GPS.
  Future<LocationSwitch> ensureServiceOn() async {
    if (!_useNative) return LocationSwitch.unavailable;
    try {
      // Izin lebih dulu: GPS yang menyala tidak berguna tanpa izin lokasi.
      await requestPermission();
      if (await Geolocator.isLocationServiceEnabled()) return LocationSwitch.on;

      final answer = await _native.invokeMethod<String>('ensureLocationOn');
      return switch (answer) {
        'on' => LocationSwitch.on,
        'declined' => LocationSwitch.declined,
        _ => LocationSwitch.unavailable,
      };
    } catch (error) {
      debugPrint('AURA: lokasi tidak bisa dinyalakan ($error).');
      return LocationSwitch.unavailable;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return _granted(await Geolocator.checkPermission());
    } catch (_) {
      return false;
    }
  }

  /// Mengambil posisi saat ini, menyerah setelah [timeout].
  ///
  /// Bila sinyal GPS belum didapat dalam batas waktu, posisi terakhir yang
  /// tersimpan dipakai sebagai cadangan — titik yang agak lama tetap jauh
  /// lebih berguna daripada tidak ada titik sama sekali.
  Future<LocationResult> current({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _lastKnownOr(LocationFailure.serviceDisabled);
      }

      final permission = await Geolocator.checkPermission();
      if (!_granted(permission)) {
        return LocationResult.failed(
          permission == LocationPermission.deniedForever
              ? LocationFailure.permissionDeniedForever
              : LocationFailure.permissionDenied,
        );
      }

      if (_useNative) return await _currentNative(timeout);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      ).timeout(timeout);

      return LocationResult.found(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMetres: position.accuracy,
        fixedAt: position.timestamp,
        isLastKnown: false,
      );
    } on TimeoutException {
      return _lastKnownOr(LocationFailure.timedOut);
    } catch (error) {
      debugPrint('AURA: pengambilan lokasi gagal ($error).');
      return _lastKnownOr(LocationFailure.unavailable);
    }
  }

  Future<LocationResult> _currentNative(Duration timeout) async {
    final reply = await _native
        .invokeMapMethod<String, Object?>('currentLocation', {
          'timeoutMs': timeout.inMilliseconds,
        })
        // Batas waktu juga dijaga di sisi Dart, kalau-kalau Play Services
        // tidak pernah menjawab.
        .timeout(timeout + const Duration(seconds: 1));

    final error = reply?['error'];
    if (reply == null || error != null) {
      return _lastKnownOr(
        error == 'permission'
            ? LocationFailure.permissionDenied
            : LocationFailure.unavailable,
      );
    }

    final time = reply['time'] as int?;
    return LocationResult.found(
      latitude: (reply['latitude']! as num).toDouble(),
      longitude: (reply['longitude']! as num).toDouble(),
      accuracyMetres: (reply['accuracy'] as num?)?.toDouble(),
      fixedAt: time == null ? null : DateTime.fromMillisecondsSinceEpoch(time),
      isLastKnown: false,
    );
  }

  Future<LocationResult> _lastKnownOr(LocationFailure failure) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationResult.found(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracyMetres: last.accuracy,
          fixedAt: last.timestamp,
          isLastKnown: true,
        );
      }
    } catch (_) {
      // Cadangan pun gagal; alasan aslinya yang dilaporkan.
    }
    return LocationResult.failed(failure);
  }

  bool _granted(LocationPermission permission) =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}
