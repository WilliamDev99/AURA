import '../../core/l10n/l10n.dart';

/// Jenis barang bukti yang disimpan di Vault Forensik.
enum EvidenceKind {
  messageTranscript('Transkrip Pesan'),
  screenshot('Tangkapan Layar'),
  audioClip('Rekaman Audio'),
  locationPing('Titik Lokasi'),
  systemEvent('Catatan Sistem');

  const EvidenceKind(this._label);
  final String _label;

  /// Nama dalam bahasa Indonesia, untuk berkas bukti resmi.
  String get labelId => _label;

  /// Nama dalam bahasa tampilan yang sedang dipakai.
  String get label => tr(_label);

  static EvidenceKind fromName(String? name) => EvidenceKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => EvidenceKind.systemEvent,
  );
}

/// Satu entri bukti dengan rantai integritas (chain of custody).
///
/// [contentHash] adalah SHA-256 dari isi bukti; [chainHash] mengikat entri ini
/// ke entri sebelumnya, sehingga penghapusan atau penyisipan di tengah rantai
/// bisa dibuktikan saat verifikasi.
class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.kind,
    required this.capturedAt,
    required this.recordedAt,
    required this.description,
    required this.contentHash,
    required this.chainHash,
    required this.sequence,
    this.previousHash,
    this.alertId,
    this.payload,
    this.storagePath,
    this.capturedBy = 'AURA',
    this.consentNote,
  });

  final String id;
  final String familyId;
  final String childId;
  final EvidenceKind kind;

  /// Waktu kejadian aslinya.
  final DateTime capturedAt;

  /// Waktu entri masuk ke vault (stempel waktu server).
  final DateTime recordedAt;
  final String description;
  final String contentHash;
  final String chainHash;
  final int sequence;
  final String? previousHash;
  final String? alertId;

  /// Isi tekstual bukti (transkrip, metadata lokasi, dan sejenisnya).
  final String? payload;
  final String? storagePath;
  final String capturedBy;

  /// Dasar pengambilan bukti: penting saat berkas dibawa ke penyidik.
  final String? consentNote;

  String get shortHash => contentHash.length > 16
      ? '${contentHash.substring(0, 8)}...${contentHash.substring(contentHash.length - 8)}'
      : contentHash;

  Map<String, dynamic> toMap() => {
    'id': id,
    'familyId': familyId,
    'childId': childId,
    'kind': kind.name,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'description': description,
    'contentHash': contentHash,
    'chainHash': chainHash,
    'sequence': sequence,
    'previousHash': previousHash,
    'alertId': alertId,
    'payload': payload,
    'storagePath': storagePath,
    'capturedBy': capturedBy,
    'consentNote': consentNote,
  };

  factory EvidenceItem.fromMap(Map<String, dynamic> map) => EvidenceItem(
    id: map['id'] as String,
    familyId: map['familyId'] as String? ?? '',
    childId: map['childId'] as String? ?? '',
    kind: EvidenceKind.fromName(map['kind'] as String?),
    capturedAt:
        DateTime.tryParse(map['capturedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    recordedAt:
        DateTime.tryParse(map['recordedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    description: map['description'] as String? ?? '',
    contentHash: map['contentHash'] as String? ?? '',
    chainHash: map['chainHash'] as String? ?? '',
    sequence: (map['sequence'] as num?)?.toInt() ?? 0,
    previousHash: map['previousHash'] as String?,
    alertId: map['alertId'] as String?,
    payload: map['payload'] as String?,
    storagePath: map['storagePath'] as String?,
    capturedBy: map['capturedBy'] as String? ?? 'AURA',
    consentNote: map['consentNote'] as String?,
  );
}
