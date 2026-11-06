import 'risk.dart';

enum MessageAuthor { child, guardian }

/// Satu gelembung percakapan antara anak dan AI Guardian.
class GuardianMessage {
  const GuardianMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.sentAt,
    this.quickReplies = const [],
    this.riskLevel,
    this.escalated = false,
  });

  final String id;
  final MessageAuthor author;
  final String text;
  final DateTime sentAt;

  /// Pilihan jawaban cepat yang ditawarkan AI agar anak tidak perlu mengetik.
  final List<String> quickReplies;

  /// Terisi bila pesan anak ini ikut dinilai oleh pemindai.
  final RiskLevel? riskLevel;

  /// True bila percakapan ini memicu peringatan ke orang tua.
  final bool escalated;

  bool get isChild => author == MessageAuthor.child;

  Map<String, dynamic> toMap() => {
    'id': id,
    'author': author.name,
    'text': text,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'quickReplies': quickReplies,
    'riskLevel': riskLevel?.name,
    'escalated': escalated,
  };

  factory GuardianMessage.fromMap(Map<String, dynamic> map) => GuardianMessage(
    id: map['id'] as String,
    author: map['author'] == 'child'
        ? MessageAuthor.child
        : MessageAuthor.guardian,
    text: map['text'] as String? ?? '',
    sentAt:
        DateTime.tryParse(map['sentAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    quickReplies:
        (map['quickReplies'] as List?)?.cast<String>() ?? const <String>[],
    riskLevel: map['riskLevel'] == null
        ? null
        : RiskLevel.fromName(map['riskLevel'] as String?),
    escalated: map['escalated'] as bool? ?? false,
  );
}
