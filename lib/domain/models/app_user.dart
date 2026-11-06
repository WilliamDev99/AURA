/// Peran pengguna dalam satu keluarga AURA.
enum UserRole { parent, child }

/// Profil pengguna — dipakai bersama oleh perangkat anak dan orang tua.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.familyId,
    this.age,
    this.avatarSeed = 0,
    this.deviceLabel,
    this.monitoringConsentAt,
    this.lastSeenAt,
    this.protectionActive = true,
    this.phone,
    this.chatScanEnabled,
    this.chatScanCheckedAt,
    this.avatarPath,
  });

  final String id;
  final String name;
  final UserRole role;
  final String? familyId;
  final int? age;
  final int avatarSeed;
  final String? deviceLabel;

  /// Kapan anak menyetujui pemindaian. Null artinya scanner belum boleh jalan.
  final DateTime? monitoringConsentAt;
  final DateTime? lastSeenAt;
  final bool protectionActive;

  /// Nomor HP orang tua dalam format +62..., ditelepon otomatis saat anak
  /// menekan tombol darurat. Kosong untuk anak.
  final String? phone;

  /// Dilaporkan ponsel anak: apakah "Akses notifikasi" untuk AURA menyala.
  /// Null bila belum pernah dilaporkan (mis. aplikasi anak versi lama).
  final bool? chatScanEnabled;

  /// Kapan status di atas terakhir diperiksa ponsel anak.
  final DateTime? chatScanCheckedAt;

  /// Letak foto profil di penyimpanan; null bila belum ada foto.
  final String? avatarPath;

  bool get hasConsented => monitoringConsentAt != null;
  bool get isChild => role == UserRole.child;

  AppUser copyWith({
    String? name,
    String? familyId,
    int? age,
    String? deviceLabel,
    DateTime? monitoringConsentAt,
    DateTime? lastSeenAt,
    bool? protectionActive,
    String? phone,
    bool? chatScanEnabled,
    DateTime? chatScanCheckedAt,
    String? avatarPath,
    bool removeAvatar = false,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      role: role,
      familyId: familyId ?? this.familyId,
      age: age ?? this.age,
      avatarSeed: avatarSeed,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      monitoringConsentAt: monitoringConsentAt ?? this.monitoringConsentAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      protectionActive: protectionActive ?? this.protectionActive,
      phone: phone ?? this.phone,
      chatScanEnabled: chatScanEnabled ?? this.chatScanEnabled,
      chatScanCheckedAt: chatScanCheckedAt ?? this.chatScanCheckedAt,
      avatarPath: removeAvatar ? null : avatarPath ?? this.avatarPath,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'role': role.name,
    'familyId': familyId,
    'age': age,
    'avatarSeed': avatarSeed,
    'deviceLabel': deviceLabel,
    'monitoringConsentAt': monitoringConsentAt?.toUtc().toIso8601String(),
    'lastSeenAt': lastSeenAt?.toUtc().toIso8601String(),
    'protectionActive': protectionActive,
    'phone': phone,
    'chatScanEnabled': chatScanEnabled,
    'chatScanCheckedAt': chatScanCheckedAt?.toUtc().toIso8601String(),
    'avatarPath': avatarPath,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    name: map['name'] as String? ?? 'Pengguna',
    role: map['role'] == 'child' ? UserRole.child : UserRole.parent,
    familyId: map['familyId'] as String?,
    age: (map['age'] as num?)?.toInt(),
    avatarSeed: (map['avatarSeed'] as num?)?.toInt() ?? 0,
    deviceLabel: map['deviceLabel'] as String?,
    monitoringConsentAt: _date(map['monitoringConsentAt']),
    lastSeenAt: _date(map['lastSeenAt']),
    protectionActive: map['protectionActive'] as bool? ?? true,
    phone: map['phone'] as String?,
    chatScanEnabled: map['chatScanEnabled'] as bool?,
    chatScanCheckedAt: _date(map['chatScanCheckedAt']),
    avatarPath: map['avatarPath'] as String?,
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
