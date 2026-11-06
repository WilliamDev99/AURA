/// Rujukan pasal perundang-undangan Indonesia untuk satu jenis ancaman.
class LegalArticle {
  const LegalArticle({
    required this.law,
    required this.article,
    required this.title,
    required this.summary,
    required this.penalty,
  });

  /// Nama undang-undang, mis. "UU No. 35 Tahun 2014".
  final String law;

  /// Pasal yang dirujuk, mis. "Pasal 76E".
  final String article;
  final String title;
  final String summary;

  /// Ancaman pidana ringkas sebagaimana tertulis dalam UU.
  final String penalty;

  String get reference => '$article $law';
}

/// Kontak resmi untuk pelaporan dan pendampingan korban anak.
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.organization,
    required this.channel,
    required this.value,
    required this.description,
    this.isPrimary = false,
  });

  final String name;
  final String organization;

  /// Jenis kanal: telepon, WhatsApp, situs web, atau surel.
  final ContactChannel channel;

  /// Nomor atau alamat yang dihubungi.
  final String value;
  final String description;
  final bool isPrimary;

  /// URI siap pakai untuk `url_launcher`.
  Uri get uri => switch (channel) {
    ContactChannel.phone => Uri(scheme: 'tel', path: value),
    // wa.me hanya menerima format internasional: 0811... menjadi 62811...
    ContactChannel.whatsapp => Uri.parse(
      'https://wa.me/${value.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0'), '62')}',
    ),
    ContactChannel.web => Uri.parse(
      value.startsWith('http') ? value : 'https://$value',
    ),
    ContactChannel.email => Uri(scheme: 'mailto', path: value),
  };
}

enum ContactChannel { phone, whatsapp, web, email }
