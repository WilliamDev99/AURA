import '../models/legal_article.dart';
import '../models/risk.dart';

/// Langkah pelaporan yang dipandu aplikasi.
class ReportingStep {
  const ReportingStep({
    required this.title,
    required this.detail,
    this.caution,
  });

  final String title;
  final String detail;

  /// Hal yang sering keliru dilakukan orang tua pada tahap ini.
  final String? caution;
}

/// Memetakan kategori ancaman ke dasar hukum Indonesia, langkah pelaporan,
/// dan kontak lembaga resmi.
///
/// Catatan: keluaran modul ini adalah informasi hukum umum untuk membantu
/// orang tua menyiapkan laporan, bukan nasihat hukum. Penentuan pasal akhir
/// tetap kewenangan penyidik dan penuntut umum.
class LegalMapper {
  const LegalMapper();

  static const disclaimer =
      'Informasi hukum di bawah ini bersifat umum dan disusun untuk membantu '
      'Anda menyiapkan laporan. Penetapan pasal sepenuhnya merupakan '
      'kewenangan penyidik. Untuk pendampingan, hubungi UPTD PPA di daerah '
      'Anda atau layanan SAPA 129.';

  static const _articles = <ThreatCategory, List<LegalArticle>>{
    ThreatCategory.grooming: [
      LegalArticle(
        law: 'UU No. 35 Tahun 2014',
        article: 'Pasal 76E',
        title: 'Perbuatan Cabul terhadap Anak',
        summary:
            'Melarang setiap orang melakukan kekerasan, ancaman, tipu muslihat, '
            'atau membujuk anak untuk melakukan atau membiarkan dilakukan '
            'perbuatan cabul.',
        penalty:
            'Pidana penjara 5-15 tahun dan denda hingga Rp5 miliar (Pasal 82).',
      ),
      LegalArticle(
        law: 'UU No. 12 Tahun 2022 (TPKS)',
        article: 'Pasal 14',
        title: 'Kekerasan Seksual Berbasis Elektronik',
        summary:
            'Menjerat perbuatan merekam, mengirim, atau memperdaya korban '
            'melalui sarana elektronik yang bermuatan seksual.',
        penalty:
            'Pidana penjara hingga 6 tahun dan/atau denda hingga Rp300 juta.',
      ),
    ],
    ThreatCategory.sextortion: [
      LegalArticle(
        law: 'UU No. 12 Tahun 2022 (TPKS)',
        article: 'Pasal 14 ayat (2)',
        title: 'Pemerasan Seksual Berbasis Elektronik',
        summary:
            'Menjerat pelaku yang memakai konten seksual korban untuk memeras, '
            'mengancam, atau memaksa korban melakukan sesuatu.',
        penalty:
            'Pidana penjara hingga 6 tahun dan/atau denda hingga Rp300 juta.',
      ),
      LegalArticle(
        law: 'UU No. 44 Tahun 2008',
        article: 'Pasal 4 jo. Pasal 37',
        title: 'Pornografi yang Melibatkan Anak',
        summary:
            'Melarang memproduksi dan menyebarluaskan pornografi; pidana '
            'ditambah sepertiga bila melibatkan anak.',
        penalty:
            'Pidana penjara 6 bulan-12 tahun, ditambah 1/3 bila korbannya anak.',
      ),
      LegalArticle(
        law: 'UU No. 1 Tahun 2024 (perubahan UU ITE)',
        article: 'Pasal 27 ayat (1)',
        title: 'Distribusi Konten Melanggar Kesusilaan',
        summary:
            'Melarang mendistribusikan atau membuat dapat diaksesnya informasi '
            'elektronik bermuatan melanggar kesusilaan.',
        penalty:
            'Pidana penjara hingga 6 tahun dan/atau denda hingga Rp1 miliar.',
      ),
    ],
    ThreatCategory.sexualHarassment: [
      LegalArticle(
        law: 'UU No. 12 Tahun 2022 (TPKS)',
        article: 'Pasal 5',
        title: 'Pelecehan Seksual Nonfisik',
        summary:
            'Menjerat perbuatan seksual nonfisik, termasuk ucapan atau pesan '
            'yang ditujukan pada tubuh atau keinginan seksual, yang merendahkan '
            'harkat dan martabat korban.',
        penalty:
            'Pidana penjara hingga 9 bulan dan/atau denda hingga Rp10 juta.',
      ),
      LegalArticle(
        law: 'UU No. 12 Tahun 2022 (TPKS)',
        article: 'Pasal 15 ayat (1)',
        title: 'Pemberatan bila Korbannya Anak',
        summary:
            'Pidana tindak pidana kekerasan seksual ditambah sepertiga bila '
            'dilakukan terhadap anak.',
        penalty: 'Ancaman pidana pokok ditambah 1/3.',
      ),
    ],
    ThreatCategory.gambling: [
      LegalArticle(
        law: 'UU No. 1 Tahun 2024 (perubahan UU ITE)',
        article: 'Pasal 27 ayat (2) jo. Pasal 45 ayat (3)',
        title: 'Distribusi Muatan Perjudian',
        summary:
            'Melarang menyiarkan, mendistribusikan, atau membuat dapat '
            'diaksesnya informasi elektronik yang bermuatan perjudian.',
        penalty:
            'Pidana penjara hingga 10 tahun dan/atau denda hingga Rp10 miliar.',
      ),
    ],
    ThreatCategory.cyberbullying: [
      LegalArticle(
        law: 'UU No. 1 Tahun 2024 (perubahan UU ITE)',
        article: 'Pasal 27A',
        title: 'Penyerangan Kehormatan atau Nama Baik',
        summary:
            'Menjerat penyerangan kehormatan atau nama baik orang lain melalui '
            'sarana elektronik agar diketahui umum.',
        penalty:
            'Pidana penjara hingga 2 tahun dan/atau denda hingga Rp400 juta.',
      ),
      LegalArticle(
        law: 'UU No. 35 Tahun 2014',
        article: 'Pasal 76C',
        title: 'Kekerasan terhadap Anak',
        summary:
            'Melarang setiap orang menempatkan, membiarkan, melakukan, atau '
            'turut serta melakukan kekerasan terhadap anak, termasuk kekerasan '
            'psikis.',
        penalty:
            'Pidana penjara hingga 3 tahun 6 bulan dan/atau denda Rp72 juta (Pasal 80).',
      ),
    ],
    ThreatCategory.violence: [
      LegalArticle(
        law: 'UU No. 1 Tahun 2024 (perubahan UU ITE)',
        article: 'Pasal 29',
        title: 'Ancaman Kekerasan melalui Sarana Elektronik',
        summary:
            'Melarang pengiriman informasi elektronik yang berisi ancaman '
            'kekerasan yang ditujukan secara pribadi.',
        penalty:
            'Pidana penjara hingga 4 tahun dan/atau denda hingga Rp750 juta.',
      ),
      LegalArticle(
        law: 'UU No. 35 Tahun 2014',
        article: 'Pasal 76C jo. Pasal 80',
        title: 'Kekerasan dan Ancaman Kekerasan terhadap Anak',
        summary:
            'Menjerat kekerasan fisik maupun ancamannya yang ditujukan kepada anak.',
        penalty:
            'Pidana penjara hingga 3 tahun 6 bulan dan/atau denda Rp72 juta.',
      ),
    ],
    ThreatCategory.meetup: [
      LegalArticle(
        law: 'UU No. 35 Tahun 2014',
        article: 'Pasal 76F',
        title: 'Penculikan dan Perdagangan Anak',
        summary:
            'Melarang menempatkan, membiarkan, melakukan, menyuruh, atau turut '
            'serta dalam penculikan, penjualan, atau perdagangan anak.',
        penalty:
            'Pidana penjara 3-15 tahun dan denda hingga Rp300 juta (Pasal 83).',
      ),
      LegalArticle(
        law: 'UU No. 21 Tahun 2007',
        article: 'Pasal 6',
        title: 'Tindak Pidana Perdagangan Orang terhadap Anak',
        summary:
            'Menjerat pengiriman anak ke dalam atau ke luar negeri dengan cara '
            'apa pun yang mengakibatkan anak tereksploitasi.',
        penalty: 'Pidana penjara 3-15 tahun dan denda Rp120-600 juta.',
      ),
    ],
    ThreatCategory.financial: [
      LegalArticle(
        law: 'KUHP',
        article: 'Pasal 368',
        title: 'Pemerasan',
        summary:
            'Menjerat pemaksaan dengan kekerasan atau ancaman agar korban '
            'menyerahkan barang atau memberi utang.',
        penalty: 'Pidana penjara hingga 9 tahun.',
      ),
      LegalArticle(
        law: 'UU No. 1 Tahun 2024 (perubahan UU ITE)',
        article: 'Pasal 28 ayat (1)',
        title: 'Berita Bohong yang Merugikan Konsumen',
        summary:
            'Menjerat penyebaran berita bohong yang menimbulkan kerugian materiel '
            'dalam transaksi elektronik.',
        penalty:
            'Pidana penjara hingga 6 tahun dan/atau denda hingga Rp1 miliar.',
      ),
    ],
    ThreatCategory.personalData: [
      LegalArticle(
        law: 'UU No. 27 Tahun 2022 (PDP)',
        article: 'Pasal 65 ayat (1)',
        title: 'Pengumpulan Data Pribadi Secara Melawan Hukum',
        summary:
            'Melarang setiap orang memperoleh atau mengumpulkan data pribadi '
            'yang bukan miliknya untuk menguntungkan diri sendiri atau orang lain '
            'yang dapat merugikan subjek data.',
        penalty:
            'Pidana penjara hingga 5 tahun dan/atau denda hingga Rp5 miliar.',
      ),
    ],
    ThreatCategory.substance: [
      LegalArticle(
        law: 'UU No. 35 Tahun 2009',
        article: 'Pasal 111-127',
        title: 'Penyalahgunaan Narkotika',
        summary:
            'Menjerat kepemilikan, peredaran, dan penyalahgunaan narkotika; '
            'pidana diperberat bila melibatkan anak di bawah umur.',
        penalty:
            'Bervariasi menurut golongan; melibatkan anak diperberat (Pasal 133).',
      ),
      LegalArticle(
        law: 'UU No. 35 Tahun 2014',
        article: 'Pasal 76I',
        title: 'Pelibatan Anak dalam Penyalahgunaan Narkotika',
        summary:
            'Melarang menempatkan, membiarkan, melibatkan, menyuruh melibatkan '
            'anak dalam penyalahgunaan atau produksi narkotika.',
        penalty:
            'Pidana penjara 5-20 tahun dan denda Rp200 juta-Rp20 miliar (Pasal 89).',
      ),
    ],
    ThreatCategory.selfHarm: [],
    ThreatCategory.profanity: [
      LegalArticle(
        law: 'UU No. 1 Tahun 2024 (perubahan UU ITE)',
        article: 'Pasal 27A',
        title: 'Penyerangan Kehormatan atau Nama Baik',
        summary:
            'Dapat dipakai bila kata kasar ditujukan untuk merendahkan kehormatan '
            'anak dan disebarkan agar diketahui umum.',
        penalty:
            'Pidana penjara hingga 2 tahun dan/atau denda hingga Rp400 juta.',
      ),
    ],
  };

  static const _contacts = <EmergencyContact>[
    EmergencyContact(
      name: 'Polisi (Panggilan Darurat)',
      organization: 'Polri',
      channel: ContactChannel.phone,
      value: '110',
      description:
          'Untuk ancaman yang sedang berlangsung atau anak dalam bahaya langsung.',
      isPrimary: true,
    ),
    EmergencyContact(
      name: 'SAPA 129',
      organization: 'Kementerian PPPA',
      channel: ContactChannel.phone,
      value: '129',
      description:
          'Layanan pengaduan kekerasan terhadap perempuan dan anak, 24 jam.',
      isPrimary: true,
    ),
    EmergencyContact(
      name: 'SAPA 129 via WhatsApp',
      organization: 'Kementerian PPPA',
      channel: ContactChannel.whatsapp,
      value: '08111129129',
      description: 'Konsultasi dan pendampingan kasus melalui pesan.',
    ),
    EmergencyContact(
      name: 'Layanan Darurat Nasional',
      organization: 'Kemendagri',
      channel: ContactChannel.phone,
      value: '112',
      description: 'Panggilan darurat terpadu di seluruh Indonesia.',
    ),
    EmergencyContact(
      name: 'Patroli Siber',
      organization: 'Bareskrim Polri',
      channel: ContactChannel.web,
      value: 'patrolisiber.id',
      description: 'Pelaporan tindak pidana siber secara daring.',
    ),
    // Sejak 13 Mei 2024 pengaduan KPAI hanya lewat WhatsApp (kpai.go.id).
    EmergencyContact(
      name: 'Pengaduan KPAI',
      organization: 'Komisi Perlindungan Anak Indonesia',
      channel: ContactChannel.whatsapp,
      value: '081110027727',
      description: 'Pengaduan dan pemantauan kasus perlindungan anak.',
    ),
    EmergencyContact(
      name: 'LPSK',
      organization: 'Lembaga Perlindungan Saksi dan Korban',
      channel: ContactChannel.phone,
      value: '148',
      description: 'Permohonan perlindungan bagi saksi dan korban.',
    ),
  ];

  List<LegalArticle> articlesFor(Iterable<ThreatCategory> categories) {
    final seen = <String>{};
    final result = <LegalArticle>[];
    for (final category in categories) {
      for (final article in _articles[category] ?? const <LegalArticle>[]) {
        if (seen.add(article.reference)) result.add(article);
      }
    }
    return result;
  }

  List<EmergencyContact> get contacts => _contacts;

  List<EmergencyContact> contactsFor(Iterable<ThreatCategory> categories) {
    if (categories.contains(ThreatCategory.selfHarm)) {
      return [
        const EmergencyContact(
          name: 'Layanan Sehat Jiwa (SEJIWA)',
          organization: 'Kemenkes',
          channel: ContactChannel.phone,
          value: '119',
          description:
              'Konseling kesehatan jiwa; tekan 8 setelah tersambung. '
              'Dahulukan menemani anak sebelum melapor ke mana pun.',
          isPrimary: true,
        ),
        ..._contacts,
      ];
    }
    return _contacts;
  }

  /// Langkah pelaporan yang disesuaikan dengan tingkat risiko.
  List<ReportingStep> stepsFor(
    RiskLevel level,
    List<ThreatCategory> categories,
  ) {
    if (categories.contains(ThreatCategory.selfHarm)) {
      return const [
        ReportingStep(
          title: 'Temani anak lebih dulu',
          detail:
              'Dampingi anak sekarang juga. Dengarkan tanpa menghakimi dan '
              'jangan tinggalkan sendirian. Keselamatan jiwa mendahului urusan '
              'bukti dan pelaporan.',
          caution:
              'Hindari memarahi, menyita ponsel sebagai hukuman, atau menuduh '
              'anak mencari perhatian.',
        ),
        ReportingStep(
          title: 'Hubungi layanan kesehatan jiwa',
          detail:
              'Telepon SEJIWA di 119 ekstensi 8, atau bawa anak ke IGD/puskesmas '
              'terdekat bila ada risiko langsung.',
        ),
        ReportingStep(
          title: 'Amankan benda berbahaya',
          detail:
              'Jauhkan obat-obatan, benda tajam, dan akses ke tempat berisiko '
              'selama masa krisis.',
        ),
        ReportingStep(
          title: 'Lapor hanya bila ada pihak yang mendorong anak',
          detail:
              'Bila tekanan datang dari perundungan atau ajakan pihak lain, '
              'barulah siapkan berkas bukti untuk dilaporkan.',
        ),
      ];
    }

    return [
      const ReportingStep(
        title: 'Amankan bukti, jangan hapus apa pun',
        detail:
            'Buka Vault Forensik AURA dan unduh berkas bukti (PDF + lampiran). '
            'Berkas sudah memuat stempel waktu dan nilai hash tiap bukti.',
        caution:
            'Jangan membalas, memancing, atau menghapus percakapan. Pesan yang '
            'dihapus menyulitkan pembuktian.',
      ),
      const ReportingStep(
        title: 'Jangan konfrontasi pelaku',
        detail:
            'Menghubungi pelaku membuat dia sadar dan biasanya langsung '
            'menghapus akun serta jejak digitalnya.',
      ),
      if (level.severity >= RiskLevel.high.severity)
        const ReportingStep(
          title: 'Hubungi 110 bila bahaya sedang berlangsung',
          detail:
              'Jika anak sedang diancam, dibuntuti, atau diajak bertemu hari ini, '
              'perlakukan sebagai keadaan darurat.',
        ),
      const ReportingStep(
        title: 'Datangi SPKT Polres terdekat',
        detail:
            'Bawa KTP orang tua, Kartu Keluarga, akta kelahiran anak, dan berkas '
            'bukti AURA (cetak serta salinan digital). Mintalah Surat Tanda '
            'Penerimaan Laporan (STPL) sebagai tanda laporan diterima.',
        caution:
            'Simpan STPL. Tanpa STPL, Anda sulit menanyakan perkembangan perkara.',
      ),
      const ReportingStep(
        title: 'Minta pendampingan UPTD PPA atau SAPA 129',
        detail:
            'Mereka menyediakan pendampingan hukum dan psikologis gratis bagi '
            'anak korban, termasuk saat pemeriksaan di kepolisian.',
      ),
      const ReportingStep(
        title: 'Laporkan juga ke platformnya',
        detail:
            'Laporkan akun pelaku ke aplikasi tempat kejadian dan ke '
            'aduankonten.id agar kontennya diturunkan.',
      ),
    ];
  }
}
