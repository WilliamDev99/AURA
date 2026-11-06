import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/evidence_item.dart';

/// Hasil verifikasi integritas satu rantai bukti.
class ChainVerification {
  const ChainVerification({
    required this.isIntact,
    required this.checked,
    required this.brokenAt,
    required this.reason,
    this.timeShifts = const {},
  });

  final bool isIntact;
  final int checked;

  /// Nomor urut entri pertama yang gagal diverifikasi.
  final int? brokenAt;
  final String reason;

  /// Entri yang isinya utuh tetapi waktu simpannya tercatat bergeser,
  /// beserta besar pergeserannya. Lihat [ChainOfCustody.verify].
  final Map<int, Duration> timeShifts;
}

/// Membangun dan memverifikasi rantai integritas bukti.
///
/// Setiap entri menyimpan SHA-256 isinya dan SHA-256 gabungan
/// (hash sebelumnya + hash isi + waktu + urutan). Mengubah, menghapus, atau
/// menyisipkan entri akan memutus rantai dan terdeteksi saat verifikasi.
class ChainOfCustody {
  const ChainOfCustody();

  static const genesis =
      '0000000000000000000000000000000000000000000000000000000000000000';

  String hashContent(String content) =>
      sha256.convert(utf8.encode(content)).toString();

  String linkHash({
    required String previousHash,
    required String contentHash,
    required DateTime recordedAt,
    required int sequence,
  }) {
    final payload =
        '$previousHash|$contentHash|${recordedAt.toUtc().toIso8601String()}|$sequence';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Menyiapkan entri bukti berikutnya yang tersambung ke [previous].
  EvidenceItem seal({
    required String id,
    required String familyId,
    required String childId,
    required EvidenceKind kind,
    required DateTime capturedAt,
    required String description,
    required String payload,
    EvidenceItem? previous,
    String? alertId,
    String? storagePath,
    String capturedBy = 'AURA',
    String? consentNote,
    DateTime? recordedAt,
  }) {
    final now = recordedAt ?? DateTime.now();
    final sequence = (previous?.sequence ?? 0) + 1;
    final previousHash = previous?.chainHash ?? genesis;
    final contentHash = hashContent(payload);

    return EvidenceItem(
      id: id,
      familyId: familyId,
      childId: childId,
      kind: kind,
      capturedAt: capturedAt,
      recordedAt: now,
      description: description,
      contentHash: contentHash,
      chainHash: linkHash(
        previousHash: previousHash,
        contentHash: contentHash,
        recordedAt: now,
        sequence: sequence,
      ),
      sequence: sequence,
      previousHash: previousHash,
      alertId: alertId,
      payload: payload,
      storagePath: storagePath,
      capturedBy: capturedBy,
      consentNote: consentNote,
    );
  }

  /// Memeriksa seluruh rantai dari entri tertua ke terbaru.
  ChainVerification verify(List<EvidenceItem> chainOldestFirst) {
    if (chainOldestFirst.isEmpty) {
      return const ChainVerification(
        isIntact: true,
        checked: 0,
        brokenAt: null,
        reason: 'Belum ada bukti tersimpan.',
      );
    }

    var expectedPrevious = genesis;
    var expectedSequence = 1;
    final shifts = <int, Duration>{};

    for (final item in chainOldestFirst) {
      if (item.sequence != expectedSequence) {
        return ChainVerification(
          isIntact: false,
          checked: expectedSequence - 1,
          brokenAt: item.sequence,
          reason:
              'Urutan bukti melompat: diharapkan #$expectedSequence, ditemukan #${item.sequence}. '
              'Ada entri yang dihapus atau disisipkan.',
        );
      }
      if (item.previousHash != expectedPrevious) {
        return ChainVerification(
          isIntact: false,
          checked: expectedSequence - 1,
          brokenAt: item.sequence,
          reason:
              'Entri #${item.sequence} tidak tersambung ke bukti sebelumnya.',
        );
      }
      if (item.payload != null &&
          hashContent(item.payload!) != item.contentHash) {
        return ChainVerification(
          isIntact: false,
          checked: expectedSequence - 1,
          brokenAt: item.sequence,
          reason: 'Isi bukti #${item.sequence} berubah setelah disimpan.',
        );
      }

      final recomputed = linkHash(
        previousHash: item.previousHash ?? genesis,
        contentHash: item.contentHash,
        recordedAt: item.recordedAt,
        sequence: item.sequence,
      );
      final shift = recomputed == item.chainHash ? null : _timeShift(item);
      if (shift != null) shifts[item.sequence] = shift;
      if (recomputed != item.chainHash && shift == null) {
        return ChainVerification(
          isIntact: false,
          checked: expectedSequence - 1,
          brokenAt: item.sequence,
          reason: 'Stempel integritas bukti #${item.sequence} tidak cocok.',
        );
      }

      expectedPrevious = item.chainHash;
      expectedSequence++;
    }

    final intact =
        '${chainOldestFirst.length} bukti terverifikasi utuh dan berurutan.';
    return ChainVerification(
      isIntact: true,
      checked: chainOldestFirst.length,
      brokenAt: null,
      reason: shifts.isEmpty ? intact : '$intact ${_shiftNote(shifts)}',
      timeShifts: Map.unmodifiable(shifts),
    );
  }

  /// Mencari pergeseran zona waktu yang membuat stempel [item] cocok kembali.
  ///
  /// Versi awal AURA mengirim waktu lokal ke Supabase tanpa keterangan zona
  /// waktu, sehingga tersimpan seolah-olah UTC: di WITA bergeser 8 jam. Stempel
  /// dibuat dari waktu yang benar, jadi saat dihitung ulang dari waktu yang
  /// tersimpan hasilnya tidak cocok, padahal isinya tidak pernah berubah.
  ///
  /// Hanya waktu yang dilonggarkan, dan hanya sebesar zona waktu yang ada di
  /// dunia (kelipatan 15 menit, -12 sampai +14 jam). Isi, urutan, dan
  /// sambungan ke entri sebelumnya tetap harus cocok persis dengan hash-nya,
  /// jadi kecocokan di sini tetap membuktikan isi bukti tidak diubah.
  Duration? _timeShift(EvidenceItem item) {
    for (var minutes = -12 * 60; minutes <= 14 * 60; minutes += 15) {
      if (minutes == 0) continue;
      final shift = Duration(minutes: minutes);
      final candidate = linkHash(
        previousHash: item.previousHash ?? genesis,
        contentHash: item.contentHash,
        recordedAt: item.recordedAt.subtract(shift),
        sequence: item.sequence,
      );
      if (candidate == item.chainHash) return shift;
    }
    return null;
  }

  /// Catatan jujur untuk penyidik: waktu bergeser, isi tetap utuh.
  String _shiftNote(Map<int, Duration> shifts) {
    final numbers = shifts.keys.toList()..sort();
    final contiguous = numbers.last - numbers.first == numbers.length - 1;
    final which = numbers.length == 1
        ? '#${numbers.single}'
        : contiguous
        ? '#${numbers.first}-#${numbers.last}'
        : numbers.map((n) => '#$n').join(', ');
    final distinct = shifts.values.toSet();
    final amount = distinct.length == 1
        ? _formatShift(distinct.single)
        : 'beberapa jam';
    return 'Catatan: waktu simpan bukti $which tercatat bergeser $amount '
        'akibat galat zona waktu pada versi lama aplikasi; isi dan urutannya '
        'tetap terbukti utuh.';
  }

  String _formatShift(Duration shift) {
    final sign = shift.isNegative ? '-' : '+';
    final minutes = shift.inMinutes.abs();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$sign$hours jam' : '$sign$hours jam $rest menit';
  }
}
