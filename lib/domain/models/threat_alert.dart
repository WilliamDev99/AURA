import '../../core/l10n/l10n.dart';

import 'risk.dart';

/// Dari mana sebuah peringatan berasal.
enum AlertSource {
  messageScan('Pemindai Pesan'),
  childReport('Dilaporkan Anak'),
  panicButton('Tombol Darurat'),
  imageScan('Pemindai Media');

  const AlertSource(this._label);
  final String _label;

  /// Nama dalam bahasa Indonesia, untuk berkas bukti resmi.
  String get labelId => _label;

  /// Nama dalam bahasa tampilan yang sedang dipakai.
  String get label => tr(_label);

  static AlertSource fromName(String? name) => AlertSource.values.firstWhere(
    (s) => s.name == name,
    orElse: () => AlertSource.messageScan,
  );
}

/// Status penanganan oleh orang tua.
enum AlertStatus {
  unread('Baru'),
  reviewed('Sudah Dilihat'),
  escalated('Dieskalasi ke Pihak Berwajib'),
  dismissed('Ditandai Aman');

  const AlertStatus(this._label);
  final String _label;

  /// Nama dalam bahasa Indonesia, untuk berkas bukti resmi.
  String get labelId => _label;

  /// Nama dalam bahasa tampilan yang sedang dipakai.
  String get label => tr(_label);

  static AlertStatus fromName(String? name) => AlertStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => AlertStatus.unread,
  );
}

/// Satu peringatan yang sampai ke dashboard orang tua.
class ThreatAlert {
  const ThreatAlert({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.childName,
    required this.riskLevel,
    required this.categories,
    required this.source,
    required this.platform,
    required this.detectedAt,
    required this.summary,
    this.excerpt,
    this.counterpartName,
    this.status = AlertStatus.unread,
    this.evidenceIds = const [],
    this.score = 0,
    this.matchedSignals = const [],
    this.latitude,
    this.longitude,
    this.locationLabel,
  });

  final String id;
  final String familyId;
  final String childId;
  final String childName;
  final RiskLevel riskLevel;
  final List<ThreatCategory> categories;
  final AlertSource source;

  /// Aplikasi tempat pesan muncul, mis. "WhatsApp", "Chat Game".
  final String platform;
  final DateTime detectedAt;

  /// Penjelasan singkat yang dibaca orang tua.
  final String summary;

  /// Kutipan minimal: hanya bagian yang memicu deteksi, bukan seluruh chat.
  final String? excerpt;
  final String? counterpartName;
  final AlertStatus status;
  final List<String> evidenceIds;
  final double score;
  final List<String> matchedSignals;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  ThreatCategory get primaryCategory =>
      categories.isEmpty ? ThreatCategory.profanity : categories.first;

  bool get hasLocation => latitude != null && longitude != null;

  ThreatAlert copyWith({AlertStatus? status, List<String>? evidenceIds}) {
    return ThreatAlert(
      id: id,
      familyId: familyId,
      childId: childId,
      childName: childName,
      riskLevel: riskLevel,
      categories: categories,
      source: source,
      platform: platform,
      detectedAt: detectedAt,
      summary: summary,
      excerpt: excerpt,
      counterpartName: counterpartName,
      status: status ?? this.status,
      evidenceIds: evidenceIds ?? this.evidenceIds,
      score: score,
      matchedSignals: matchedSignals,
      latitude: latitude,
      longitude: longitude,
      locationLabel: locationLabel,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'familyId': familyId,
    'childId': childId,
    'childName': childName,
    'riskLevel': riskLevel.name,
    'categories': categories.map((c) => c.name).toList(),
    'source': source.name,
    'platform': platform,
    'detectedAt': detectedAt.toUtc().toIso8601String(),
    'summary': summary,
    'excerpt': excerpt,
    'counterpartName': counterpartName,
    'status': status.name,
    'evidenceIds': evidenceIds,
    'score': score,
    'matchedSignals': matchedSignals,
    'latitude': latitude,
    'longitude': longitude,
    'locationLabel': locationLabel,
  };

  factory ThreatAlert.fromMap(Map<String, dynamic> map) => ThreatAlert(
    id: map['id'] as String,
    familyId: map['familyId'] as String? ?? '',
    childId: map['childId'] as String? ?? '',
    childName: map['childName'] as String? ?? 'Anak',
    riskLevel: RiskLevel.fromName(map['riskLevel'] as String?),
    categories:
        (map['categories'] as List?)
            ?.map((c) => ThreatCategory.fromName(c as String?))
            .toList() ??
        const [],
    source: AlertSource.fromName(map['source'] as String?),
    platform: map['platform'] as String? ?? 'Tidak diketahui',
    detectedAt:
        DateTime.tryParse(map['detectedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    summary: map['summary'] as String? ?? '',
    excerpt: map['excerpt'] as String?,
    counterpartName: map['counterpartName'] as String?,
    status: AlertStatus.fromName(map['status'] as String?),
    evidenceIds:
        (map['evidenceIds'] as List?)?.cast<String>() ?? const <String>[],
    score: (map['score'] as num?)?.toDouble() ?? 0,
    matchedSignals:
        (map['matchedSignals'] as List?)?.cast<String>() ?? const <String>[],
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    locationLabel: map['locationLabel'] as String?,
  );
}
