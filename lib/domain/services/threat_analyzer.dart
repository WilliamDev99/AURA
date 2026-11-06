import 'dart:math' as math;

import '../models/risk.dart';

/// Hasil analisis satu pesan.
class ThreatAssessment {
  const ThreatAssessment({
    required this.score,
    required this.level,
    required this.categories,
    required this.signals,
    required this.summary,
    required this.excerpt,
  });

  final double score;
  final RiskLevel level;
  final List<ThreatCategory> categories;

  /// Frasa yang memicu deteksi — ditampilkan ke orang tua sebagai alasan.
  final List<String> signals;
  final String summary;

  /// Potongan teks seminimal mungkin di sekitar pemicu.
  final String excerpt;

  bool get isThreat => level.severity >= RiskLevel.low.severity;

  /// Membaca jawaban Edge Function `analyze-message`.
  factory ThreatAssessment.fromAi(Map<String, dynamic> json) {
    final level = RiskLevel.fromName(json['level'] as String?);
    if (json['dangerous'] != true || !level.notifiesParent) return safe;

    final name = json['category'] as String?;
    final category = ThreatCategory.values
        .where((c) => c.name == name)
        .firstOrNull;
    final reason = (json['reason'] as String? ?? '').trim();
    return ThreatAssessment(
      score: switch (level) {
        RiskLevel.critical => 0.9,
        RiskLevel.high => 0.7,
        _ => 0.5,
      },
      level: level,
      categories: [?category],
      signals: [if (reason.isNotEmpty) 'Penilaian AI: $reason'],
      summary: reason.isEmpty ? 'AI menilai pesan ini mencurigakan.' : reason,
      excerpt: (json['excerpt'] as String? ?? '').trim(),
    );
  }

  static const safe = ThreatAssessment(
    score: 0,
    level: RiskLevel.safe,
    categories: [],
    signals: [],
    summary: 'Tidak ditemukan indikasi berbahaya.',
    excerpt: '',
  );
}

/// Satu aturan leksikal: pola frasa untuk satu kategori ancaman.
class _Rule {
  const _Rule(
    this.category,
    this.weight,
    this.patterns, {
    this.context,
    this.wholeWord = false,
    this.severe = false,
  });

  final ThreatCategory category;

  /// Kontribusi dasar terhadap skor, 0..1.
  final double weight;
  final List<String> patterns;

  /// Bila diisi, bobot penuh hanya berlaku saat salah satu kata konteks hadir.
  final List<String>? context;

  /// Dicocokkan sebagai kata utuh, bukan potongan. Wajib untuk kata pendek:
  /// tanpa ini "tai" cocok di "santai" dan "asu" cocok di "masuk".
  final bool wholeWord;

  /// Boleh mencapai tingkat tertinggi (HARD) walau hanya berupa kata kasar.
  final bool severe;
}

/// Pemindai ancaman berbasis aturan yang berjalan di perangkat (on-device).
///
/// Dirancang untuk Bahasa Indonesia sehari-hari termasuk ragam gaul dan
/// penyamaran huruf (leetspeak, pengulangan huruf, penyisipan simbol).
/// Lapisan ini sengaja berjalan lokal supaya isi pesan anak tidak perlu
/// dikirim ke server untuk kasus yang jelas; hanya ringkasannya yang naik.
///
/// Untuk produksi, gabungkan dengan model NLP di Cloud Functions bagi kasus
/// ambigu. Lihat `functions/src/analyze.ts`.
class ThreatAnalyzer {
  const ThreatAnalyzer();

  static const List<_Rule> _rules = [
    // --- Grooming: pola pendekatan predator terhadap anak ---
    _Rule(ThreatCategory.grooming, 0.6, [
      'jangan bilang siapa siapa',
      'jangan bilang ke siapa siapa',
      'jangan kasih tau orang tua',
      'jangan kasih tau ortu',
      'jangan bilang ortu',
      'jangan bilang mama',
      'jangan bilang papa',
      'rahasia kita',
      'ini rahasia ya',
      'hapus chat ini',
      'hapus pesan ini',
      'jangan sampai ketahuan',
      'cuma kamu yang ngerti aku',
      'kamu beda dari yang lain',
      'kamu dewasa untuk umurmu',
      'kamu lebih dewasa dari umurmu',
      'aku sayang kamu walaupun kita baru kenal',
    ]),
    _Rule(ThreatCategory.grooming, 0.6, [
      'kirim pap',
      'minta pap',
      'pap dong',
      'vc berdua',
      'video call berdua',
    ]),
    _Rule(ThreatCategory.grooming, 0.3, [
      'umur kamu berapa',
      'kamu kelas berapa',
      'orang tua kamu ada di rumah',
      'kamu sendirian di rumah',
      'lagi sendiri di rumah',
      'kapan ortu kamu pergi',
      'pindah ke telegram',
      'chat di aplikasi lain aja',
      'lanjut di wa aja',
    ]),

    // --- Komentar dan ajakan bernuansa seksual (pelecehan nonfisik) ---
    // Sering menjadi tahap awal grooming: pujian soal tubuh untuk menguji
    // apakah anak akan diam. Dicocokkan sebagai frasa, karena "seksi" sendiri
    // juga berarti bagian kepanitiaan ("seksi acara").
    _Rule(ThreatCategory.sexualHarassment, 0.6, [
      'kamu seksi',
      'seksi banget',
      'seksi bgt',
      'seksi sekali',
      'kamu sexy',
      'sexy banget',
      'badan kamu seksi',
      'badan kamu bagus',
      'body kamu',
      'bodi kamu',
      'kamu hot',
      'hot banget kamu',
      'bikin nafsu',
      'nafsu liat kamu',
      'nafsu lihat kamu',
      'pengen cium kamu',
      'pengin cium kamu',
      'mau cium kamu',
      'pengen peluk kamu',
      'pengin peluk kamu',
      'pengen raba',
      'pegang badan kamu',
      'bibir kamu',
      'paha kamu',
      'pantat kamu',
      'ukuran bra',
      'lagi pakai baju apa',
      'lagi pake baju apa',
      'tidur bareng yuk',
      'tidur bareng aku',
      // "ml yuk" sengaja tidak dimasukkan: bagi anak, "ml" hampir selalu
      // berarti Mobile Legends.
      // Ajakan berciuman.
      'cium aku',
      'cium dong',
      'aku cium kamu',
      'gue cium lu',
      'gue cium lo',
      'sini aku cium',
      'boleh aku cium',
      'boleh cium',
      'cium bibir',
      'cium pipi kamu',
      'ciuman yuk',
      'ciuman yok',
      'yuk ciuman',
      'ayo ciuman',
      'ayok ciuman',
      'ciuman sama aku',
      'ciuman sama gue',
      'ciuman bibir',
      'pengen ciuman',
      'pengin ciuman',
      'mau ciuman',
      'ciumin kamu',
      'nyium kamu',
      'nyiumin kamu',
      'pengen nyium',
      'pengin nyium',
      'cipok yuk',
      'aku cipok',
      'kiss me',
      'french kiss',
    ]),
    // Kata berciuman tanpa ajakan tetap sampai ke orang tua (Sedang). "cium"
    // polos sengaja tidak dimasukkan: "cium tangan ibu" dan "aku cium bau
    // gosong" adalah kalimat biasa.
    _Rule(ThreatCategory.sexualHarassment, 0.35, wholeWord: true, [
      'ciuman',
      'ciumin',
      'diciumin',
      'dicium',
      'nyiumin',
      'cipok',
      'nyipok',
      'kiss',
      'kissing',
    ]),
    // Ajakan berhubungan seksual: langsung tingkat tinggi.
    _Rule(ThreatCategory.sexualHarassment, 0.9, [
      'hubungan badan',
      'berhubungan badan',
      'hubungan intim',
      'berhubungan intim',
      'hubungan seks',
      'berhubungan seks',
      'making love',
    ]),
    _Rule(ThreatCategory.sexualHarassment, 0.6, wholeWord: true, [
      'sange',
      'sangean',
      'horny',
    ]),

    // --- Permintaan konten seksual ---
    _Rule(ThreatCategory.sextortion, 0.92, [
      'kirim foto tanpa baju',
      'foto tanpa baju',
      'kirim foto bugil',
      'foto bugil',
      'video call bugil',
      'buka baju dong',
      'kirim foto badan kamu',
      'foto bagian bawah',
      'foto dada kamu',
      'pap tanpa baju',
      'pap body',
      'kirim nudes',
      'nude pic',
      'telanjang',
    ]),
    _Rule(ThreatCategory.sextortion, 0.95, [
      'nanti aku sebar fotomu',
      'aku sebar foto kamu',
      'aku kirim fotomu ke temanmu',
      'kalau kamu laporin aku sebar',
      'foto kamu ada di aku',
      'aku punya foto kamu',
    ]),

    // --- Ajakan bertemu diam-diam ---
    _Rule(
      ThreatCategory.meetup,
      0.7,
      [
        'ketemuan',
        'ketemu yuk',
        'aku jemput',
        'aku ke rumah kamu',
        'kita ketemu',
        'mau aku jemput',
        'tunggu di depan sekolah',
        'tunggu di gerbang',
      ],
      context: [
        'jangan bilang',
        'rahasia',
        'sendiri',
        'berdua',
        'diam diam',
        'malam',
        'hotel',
        'kos',
        'jangan kasih tau',
      ],
    ),

    // --- Perundungan siber ---
    _Rule(ThreatCategory.cyberbullying, 0.6, [
      'semua orang benci kamu',
      'gak ada yang suka kamu',
      'nggak ada yang suka sama kamu',
      'kamu gak berguna',
      'kamu tidak berguna',
      'dasar sampah',
      'mending kamu pergi aja',
      'mending kamu hilang',
      'jelek banget sih kamu',
      'gendut banget',
      'awas kamu besok di sekolah',
      'kita bully terus',
      // Ragam gaul "lu/lo/gue": bentuk yang paling sering dipakai remaja.
      'semua orang benci lu',
      'semua orang benci lo',
      'gak ada yang suka lu',
      'gak ada yang suka sama lu',
      'gak ada yang mau temenan sama lu',
      'gak ada yang mau temenan sama lo',
      'gak ada yang mau temenan sama kamu',
      'lu gak berguna',
      'lo gak berguna',
      'gak guna lu',
      'gak guna lo',
      'dasar gak guna',
      'dasar jelek',
      'dasar gendut',
      'dasar miskin',
      'muka lu jelek',
      'jelek banget lu',
      'mending lu pergi',
      'pergi aja lu',
      'awas lu besok',
      'awas lo besok',
    ]),
    // Menyuruh anak mati atau bunuh diri: setara ancaman serius.
    _Rule(ThreatCategory.cyberbullying, 0.85, [
      'mati aja lu',
      'mati aja lo',
      'mati aja kamu',
      'mati aja sana',
      'mending lu mati',
      'mending lo mati',
      'mending kamu mati',
      'bunuh diri aja',
    ]),

    // --- Ancaman kekerasan ---
    _Rule(ThreatCategory.violence, 0.85, [
      'aku bunuh kamu',
      'gue bunuh lo',
      'aku pukul kamu',
      'gue hajar lo',
      'kamu mati',
      'aku habisi kamu',
      'awas kepalamu',
      'aku tau rumah kamu',
      'gue tau rumah lo',
      'aku tunggu di jalan',
      'gue bunuh lu',
      'gw bunuh lo',
      'gue hajar lu',
      'gue gebukin lo',
      'gue gebukin lu',
      'gue tonjok lu',
      'gue habisin lo',
      'gue habisin lu',
      'gue tau rumah lu',
    ]),

    // --- Indikasi menyakiti diri sendiri ---
    _Rule(ThreatCategory.selfHarm, 0.9, [
      'pengen mati',
      'ingin mati',
      'pengin mati aja',
      'mau bunuh diri',
      'bunuh diri',
      'ngilang aja dari dunia',
      'gak kuat hidup',
      'capek hidup',
      'lebih baik aku gak ada',
      'lebih baik aku mati',
      'nyakitin diri sendiri',
      'sayat tangan',
    ]),
    _Rule(ThreatCategory.selfHarm, 0.65, [
      'mending aku hilang',
      'gak ada gunanya aku hidup',
      'semua akan lebih baik tanpa aku',
    ]),

    // --- Pemerasan dan penipuan finansial ---
    _Rule(ThreatCategory.financial, 0.75, [
      'transfer sekarang',
      'kirim pulsa ke nomor ini',
      'kirim uang dulu',
      'minta kode otp',
      'kode otp',
      'kode verifikasi',
      'kasih pin atm',
      'pinjam rekening kamu',
      'kalau nggak bayar aku sebar',
      'bayar kalau mau aman',
      'top up dulu baru dapat hadiah',
    ]),

    // --- Kebocoran data pribadi ---
    _Rule(ThreatCategory.personalData, 0.6, [
      'alamat rumah kamu dimana',
      'alamat lengkap kamu',
      'nomor kk',
      'nomor nik',
      'nik kamu berapa',
      'foto kartu keluarga',
      'foto ktp',
      'nama sekolah kamu apa',
      'password kamu apa',
      'kata sandi kamu',
    ]),

    // --- Zat terlarang ---
    _Rule(ThreatCategory.substance, 0.7, [
      'coba ini bikin melayang',
      'obat biar fly',
      'pil koplo',
      'tramadol biar enak',
      'vape isi cairan khusus',
    ]),
    // Kata utuh: "sabu" tidak boleh cocok di "sabun", dan "ganja" tidak di
    // "mengganjal".
    _Rule(ThreatCategory.substance, 0.7, wholeWord: true, ['sabu', 'ganja']),

    // --- Judi online ---
    _Rule(ThreatCategory.gambling, 0.6, wholeWord: true, [
      'judol',
      'judi',
      'togel',
      'maxwin',
      'taruhan',
      'betting',
    ]),
    _Rule(ThreatCategory.gambling, 0.6, [
      'judi online',
      'slot gacor',
      'situs slot',
      'situs gacor',
      'gacor hari ini',
      'scatter hitam',
      'depo 10k',
      'deposit slot',
      'link slot',
    ]),

    // --- Konten dewasa ---
    _Rule(ThreatCategory.sexualHarassment, 0.6, wholeWord: true, [
      'bokep',
      'porno',
      'porn',
      'cabul',
      'mesum',
      'onani',
      'bugil',
    ]),
    _Rule(ThreatCategory.sexualHarassment, 0.6, [
      'video dewasa',
      'film dewasa',
      'situs dewasa',
      'open bo',
      'sugar daddy',
      'om senang',
    ]),

    // --- Rokok, alkohol, narkoba (tambahan) ---
    _Rule(ThreatCategory.substance, 0.6, wholeWord: true, [
      'narkoba',
      'narkotika',
      'ekstasi',
      'inex',
      'putaw',
      'heroin',
      'kokain',
      'miras',
      'ngelem',
      'ngefly',
    ]),
    _Rule(ThreatCategory.substance, 0.4, [
      'ngerokok yuk',
      'sebat yuk',
      'ngevape yuk',
      'nyobain rokok',
      'minum alkohol',
      'mabok yuk',
      'lem aibon',
    ]),

    // --- Menyakiti diri (tambahan) ---
    _Rule(ThreatCategory.selfHarm, 0.9, [
      'mau mati aja',
      'gak mau hidup lagi',
      'nggak mau hidup lagi',
      'akhiri hidup',
      'mengakhiri hidup',
      'gantung diri',
      'minum racun',
      'silet tangan',
    ]),

    // --- Kekerasan dan tawuran (tambahan) ---
    _Rule(ThreatCategory.violence, 0.85, [
      'aku tusuk',
      'gue tusuk',
      'aku bacok',
      'gue bacok',
      'gue keroyok',
      'bawa celurit',
      'bawa sajam',
    ]),
    _Rule(ThreatCategory.violence, 0.5, wholeWord: true, ['tawuran']),

    // --- Iming-iming hadiah dari orang yang mendekati anak ---
    _Rule(ThreatCategory.grooming, 0.35, [
      'aku kasih hadiah',
      'aku beliin kamu',
      'mau aku kasih uang',
      'aku isiin pulsa',
      'aku topupin',
      'hapus chat kita',
      'jangan cerita ke siapa siapa',
    ]),

    // --- Kata kasar dan tidak sopan ---
    // Setiap kata di sini dikirim ke orang tua (lihat [ThreatAnalyzer.assess]),
    // jadi semuanya dicocokkan sebagai kata utuh supaya kata biasa yang
    // kebetulan mengandungnya tidak ikut terhitung.
    // Ringan (Sedang): tidak sopan, sering dipakai dalam candaan.
    _Rule(ThreatCategory.profanity, 0.35, wholeWord: true, [
      'anjir',
      'anjrit',
      'kampret',
      'sialan',
      'setan',
      'iblis',
      'tai',
      'taik',
      'tolol',
      'tll',
      'goblok',
      'goblog',
      'gblk',
      'bego',
      'begok',
      'bodoh',
      'idiot',
      'dungu',
      'bloon',
      'dongo',
      'sinting',
      'bacot',
      'najis',
      'monyet',
      'babi',
      'bangke',
      'sompret',
      'bedebah',
      'koplok',
      'shit',
      'bullshit',
      'stfu',
      'wtf',
    ]),
    // Kasar (Tinggi): umpatan berat, termasuk bahasa daerah.
    _Rule(ThreatCategory.profanity, 0.6, wholeWord: true, [
      'anjing', 'njing', 'anjg', 'ajg', 'anying', 'bangsat', 'bgst',
      'bngst', 'bajingan', 'brengsek', 'keparat', 'jingan',
      // Jawa
      'jancok', 'jancuk', 'dancok', 'cok', 'cuk', 'asu', 'asw', 'ndasmu',
      'raimu', 'gathel', 'kirik',
      // Makassar dan Medan
      'sundala', 'telaso', 'tailaso', 'kongkong',
      // Bahasa Inggris
      'fuck', 'fck', 'fucking', 'bitch', 'bastard', 'asshole',
      'motherfucker',
    ]),
    // Hinaan yang merendahkan (Tinggi). Bila ditujukan ke orang ("dasar
    // lonte"), naik ke HARD; lihat [_directedInsult].
    _Rule(ThreatCategory.profanity, 0.62, wholeWord: true, [
      'lonte',
      'pelacur',
      'sundal',
      'perek',
      'jablay',
      'pecun',
      'slut',
      'whore',
      'banci',
      'bencong',
      'retard',
    ]),

    // --- Tambahan kata kasar yang sering lolos ---
    // Ringan (Sedang): ragam gaul "anjir", hinaan, dan umpatan daerah ringan.
    _Rule(ThreatCategory.profanity, 0.35, wholeWord: true, [
      'anjay', 'anjim', 'anjer', 'anjrot', 'ajig', 'njir', 'kamvret',
      'geblek', 'oon', 'pea', 'bolot', 'budek', 'pekok', 'kunyuk', 'telek',
      'jahanam', 'laknat', 'mampus', 'modar',
      // Dicocokkan utuh supaya "gila lucu" tidak terhitung "gila lu".
      'gila lu', 'gila lo', 'dasar gila', 'edan lu', 'edan lo',
      'autis lu', 'autis lo', 'dasar autis', 'cacat lu', 'cacat lo',
      'dasar cacat',
    ]),
    // Kasar (Tinggi).
    _Rule(ThreatCategory.profanity, 0.6, wholeWord: true, [
      'jamput',
      'kampang',
      'bgsd',
      'fak',
      'fakyu',
      'fakyou',
      'mampus lu',
      'mampus lo',
      'mampus kamu',
      'modar kowe',
      'modar lu',
      'anak haram',
      'haram jadah',
      'haramjadah',
    ]),
    // --- Kata jorok (HARD) ---
    // Keputusan orang tua: kata yang menyebut alat kelamin atau hubungan seks
    // selalu tingkat tertinggi, walau dipakai sebagai umpatan biasa. Istilah
    // medis (penis, vagina) tetap di daftar bagian tubuh karena sering muncul
    // di pelajaran IPA.
    _Rule(ThreatCategory.profanity, 0.9, wholeWord: true, severe: true, [
      'kontol',
      'kntl',
      'memek',
      'mmk',
      'pepek',
      'puki',
      'jembut',
      'pantek',
      'cibai',
      'lancau',
      'kimak',
      'pukimak',
      'ngentot',
      'ngentod',
      'entot',
      'ngntd',
      'ngentd',
      'ngntot',
      'dick',
      'pussy',
    ]),
    _Rule(ThreatCategory.sexualHarassment, 0.9, wholeWord: true, severe: true, [
      'ngewe',
      'ewe',
      'ewean',
      'coli',
      'colmek',
      'toket',
    ]),

    // --- Tambahan istilah seksual yang sering lolos ---
    // Meminta video call seks atau foto bagian tubuh: setara permintaan
    // konten seksual.
    _Rule(ThreatCategory.sextortion, 0.92, wholeWord: true, [
      'vcs',
      'pap tt',
      'pap toket',
      'pap dada',
    ]),
    // Ajakan dan komentar seksual dengan istilah gaul (Tinggi). Dicocokkan
    // utuh supaya "bobo yuk" tidak terhitung "bo yuk".
    _Rule(ThreatCategory.sexualHarassment, 0.6, wholeWord: true, [
      'grepe',
      'grepein',
      'digrepe',
      'ena ena',
      'enaena',
      'mantap mantap yuk',
      'bikin anak yuk',
      'bo yuk',
      'mau bo',
      'kamu masih perawan',
      'masih perawan gak',
      'masih perawan nggak',
      'kamu masih perjaka',
      'remes dada',
      'remes tt',
      'remes toket',
      'remes susu',
      'remes pantat',
      'pegang susu',
      'susu kamu gede',
      'tt kamu gede',
      'tt gede',
    ]),
    // Kata seksual dan bagian tubuh tanpa ajakan (Sedang): perlu diketahui
    // orang tua, walau bisa juga muncul di pelajaran IPA.
    _Rule(ThreatCategory.sexualHarassment, 0.35, wholeWord: true, [
      // "kelamin" sengaja tidak: "jenis kelamin" ada di setiap formulir.
      'perawan', 'perjaka', 'nenen', 'penis', 'vagina', 'payudara',
      'sperma', 'kondom', 'dada kamu', 'pelukan yuk',
      'peluk aku dong', 'mau aku peluk',
    ]),
    // Orang dewasa yang merayu anak (Sedang): "om sayang kamu", "cantik dek".
    _Rule(ThreatCategory.grooming, 0.35, wholeWord: true, [
      'om sayang kamu',
      'om kangen kamu',
      'om suka kamu',
      'tante sayang kamu',
      'sayang kamu dek',
      'kangen kamu dek',
      'cantik dek',
      'ganteng dek',
      'manis dek',
      'dek cantik',
      'adek cantik',
      'dek ganteng',
      'mau jadi pacar aku',
      'mau jadi pacarku',
      'jadi pacarku ya',
      'pacaran yuk',
      'kita pacaran',
    ]),
  ];

  /// Kata yang menandakan pesan justru sedang melaporkan atau menolak ancaman,
  /// sehingga skornya diredam agar tidak jadi alarm palsu.
  static const _mitigators = [
    'aku laporin',
    'aku lapor',
    'aku blokir',
    'aku block',
    'jangan gitu',
    'gak mau ah',
    'nggak mau',
    'aku kasih tau mama',
    'aku kasih tau papa',
    'aku bilang ke ortu',
    'stop ya',
    'berhenti',
    'aku screenshot',
  ];

  /// Menilai satu pesan dan mengembalikan ringkasan risikonya.
  ThreatAssessment assess(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return ThreatAssessment.safe;

    final normalized = _normalize(text);
    final hits = <ThreatCategory, List<double>>{};
    final signals = <String>[];
    int? firstHitIndex;
    var severe = false;

    for (final rule in _rules) {
      for (final pattern in rule.patterns) {
        final index = rule.wholeWord
            ? _findWord(normalized, pattern)
            : normalized.indexOf(pattern);
        if (index < 0) continue;

        var weight = rule.weight;
        if (rule.context != null && !rule.context!.any(normalized.contains)) {
          weight *= 0.45; // Tanpa konteks pendukung, bobotnya diturunkan.
        }

        hits.putIfAbsent(rule.category, () => <double>[]).add(weight);
        if (!signals.contains(pattern)) signals.add(pattern);
        firstHitIndex ??= index;
        if (rule.severe) severe = true;
      }
    }

    // "kamu anjing" jauh lebih berat daripada "anjing" sebagai seruan.
    if (_directedInsult(normalized) case (final phrase, final index)) {
      hits.putIfAbsent(ThreatCategory.profanity, () => <double>[]).add(0.9);
      if (!signals.contains(phrase)) signals.add(phrase);
      firstHitIndex ??= index;
      severe = true;
    }

    if (hits.isEmpty) return ThreatAssessment.safe;

    // Dalam satu kategori, sinyal kedua dan seterusnya tetap menambah
    // keyakinan tetapi dengan bobot separuh: pesan yang menyebut kerahasiaan
    // dua kali lebih mengkhawatirkan daripada yang menyebutnya sekali.
    final categoryScores = {
      for (final entry in hits.entries)
        entry.key: _combineWithinCategory(entry.value),
    };
    var score = _combine(categoryScores.values.toList());

    // Beberapa kategori berbeda yang muncul bersamaan memperkuat kecurigaan.
    if (hits.length >= 2) score = math.min(1, score + 0.08 * (hits.length - 1));

    // Umpatan yang diulang-ulang naik levelnya; sekali lewat tidak.
    final profanityHits = signals
        .where(
          (s) => _rules
              .where((r) => r.category == ThreatCategory.profanity)
              .any((r) => r.patterns.contains(s)),
        )
        .length;
    if (profanityHits >= 3) score = math.min(1, score + 0.18);

    // Peredam tidak berlaku untuk tanda menyakiti diri: "aku nggak mau hidup
    // lagi" mengandung "nggak mau", tetapi justru bukan penolakan.
    if (!hits.containsKey(ThreatCategory.selfHarm) &&
        _mitigators.any(normalized.contains)) {
      score *= 0.55;
    }

    // Kategori terkuat ditempatkan lebih dulu: itu yang dibaca orang tua.
    final categories = categoryScores.keys.toList()
      ..sort((a, b) => categoryScores[b]!.compareTo(categoryScores[a]!));
    var level = RiskLevel.fromScore(score);

    // Keputusan orang tua: setiap kata kasar atau tidak sopan harus sampai ke
    // mereka, bukan hanya yang bertubi-tubi. Tingkat "sedang" adalah batas
    // terendah yang dikirim ke orang tua, tetapi belum menyela anak.
    if (categoryScores.containsKey(ThreatCategory.profanity) &&
        level.severity < RiskLevel.medium.severity) {
      level = RiskLevel.medium;
    }
    // Umpatan tanpa sasaran, sebanyak apa pun, bukan bahaya mendesak. Kata
    // jorok dan hinaan berat yang ditujukan ke orang ("kamu anjing") boleh
    // mencapai tingkat tertinggi.
    if (!severe &&
        categoryScores.length == 1 &&
        categoryScores.containsKey(ThreatCategory.profanity) &&
        level == RiskLevel.critical) {
      level = RiskLevel.high;
    }

    return ThreatAssessment(
      score: double.parse(score.toStringAsFixed(3)),
      level: level,
      categories: categories,
      signals: signals,
      summary: _summarize(categories.first, level),
      excerpt: _excerpt(text, firstHitIndex ?? 0),
    );
  }

  /// Hinaan berat yang menjadi HARD bila ditujukan ke orang.
  static const _insults = [
    'anjing',
    'njing',
    'anjg',
    'ajg',
    'anying',
    'bangsat',
    'bgst',
    'bngst',
    'bgsd',
    'bajingan',
    'brengsek',
    'keparat',
    'jingan',
    'jancok',
    'jancuk',
    'dancok',
    'cok',
    'cuk',
    'asu',
    'asw',
    'kirik',
    'gathel',
    'sundala',
    'telaso',
    'tailaso',
    'kongkong',
    'jamput',
    'kampang',
    'babi',
    'monyet',
    'tai',
    'taik',
    'setan',
    'iblis',
    'bangke',
    'lonte',
    'pelacur',
    'sundal',
    'perek',
    'jablay',
    'pecun',
    'banci',
    'bencong',
    'fuck',
    'fck',
    'bitch',
    'bastard',
    'asshole',
    'motherfucker',
    'slut',
    'whore',
    'retard',
  ];

  /// Kata yang sendirinya sudah berarti hinaan untuk "kamu".
  static const _selfDirected = ['ndasmu', 'raimu'];

  /// Sasaran sebelum hinaan: "kamu anjing", "dasar babi", "you bitch".
  static const _targetsBefore = {
    'kamu',
    'lu',
    'lo',
    'loe',
    'elu',
    'elo',
    'dasar',
    'ente',
    'situ',
    'kowe',
    'koe',
    'you',
  };

  /// Sasaran sesudah hinaan: "anjing lu", "fuck you". "anjing kamu" sengaja
  /// tidak, karena juga berarti "anjingmu" (hewan peliharaan).
  static const _targetsAfter = {
    'lu',
    'lo',
    'loe',
    'elu',
    'elo',
    'ente',
    'kowe',
    'koe',
    'you',
    'u',
  };

  /// Kata pengisi di antara sasaran dan hinaan: "kamu emang anjing".
  static const _fillers = {
    'itu',
    'tuh',
    'tu',
    'emang',
    'memang',
    'kayak',
    'kaya',
    'kek',
    'seperti',
    'bener',
    'beneran',
    'sih',
  };

  static final _tokenPatterns = <String, RegExp>{};

  static bool _tokenIs(String token, String word, {bool directed = false}) {
    final key = directed ? '>$word' : word;
    final pattern = _tokenPatterns.putIfAbsent(key, () {
      final letters = word.split('').map((c) => '${RegExp.escape(c)}+').join();
      // "anjinglu" sendiri sudah ditujukan ke orang.
      final suffix = directed ? '(?:lu|lo)' : '(?:nya|lah|in|an|ku)?';
      return RegExp('^$letters$suffix\$');
    });
    return pattern.hasMatch(token);
  }

  /// Frasa hinaan yang ditujukan ke orang beserta posisinya, atau null.
  static (String, int)? _directedInsult(String normalized) {
    final tokens = normalized.split(' ');
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      String? phrase;

      if (_selfDirected.any((w) => _tokenIs(token, w))) {
        phrase = token;
      } else if (_insults.any((w) => _tokenIs(token, w, directed: true))) {
        phrase = token;
      } else if (_insults.any((w) => _tokenIs(token, w))) {
        final before = i > 0 ? tokens[i - 1] : null;
        final twoBefore = i > 1 ? tokens[i - 2] : null;
        final after = i + 1 < tokens.length ? tokens[i + 1] : null;
        if (before != null && _targetsBefore.contains(before)) {
          phrase = '$before $token';
        } else if (twoBefore != null &&
            _targetsBefore.contains(twoBefore) &&
            _fillers.contains(before)) {
          phrase = '$twoBefore $before $token';
        } else if (after != null && _targetsAfter.contains(after)) {
          phrase = '$token $after';
        }
      }

      if (phrase != null) {
        return (phrase, math.max(0, normalized.indexOf(phrase)));
      }
    }
    return null;
  }

  /// Menggabungkan sinyal-sinyal dalam satu kategori. Sinyal terkuat dipakai
  /// penuh, sisanya diperhitungkan dengan bobot separuh.
  double _combineWithinCategory(List<double> weights) {
    if (weights.length == 1) return weights.first;
    final sorted = [...weights]..sort((a, b) => b.compareTo(a));
    return _combine([sorted.first, ...sorted.skip(1).map((w) => w * 0.5)]);
  }

  /// Menggabungkan beberapa sinyal secara probabilistik (noisy-OR), bukan
  /// dijumlahkan, supaya satu pesan dengan banyak umpatan ringan tidak
  /// melompat ke level kritis.
  double _combine(List<double> weights) {
    var inverse = 1.0;
    for (final w in weights) {
      inverse *= (1 - w.clamp(0, 0.99));
    }
    return 1 - inverse;
  }

  /// Menyeragamkan teks: huruf kecil, buang penyamaran karakter, rapikan spasi.
  static final _wordPatterns = <String, RegExp>{};

  /// Posisi [word] sebagai kata utuh di [text], atau -1.
  ///
  /// Akhiran yang lazim menempel ("anjingnya", "goblokin", "bangsatlah")
  /// tetap dihitung, tetapi awalan tidak: "santai" bukan "tai".
  ///
  /// Setiap huruf boleh diulang ("anjingg", "goblokk"), tetapi tidak boleh
  /// berkurang: "tll" tidak cocok dengan "tl" dan "mmk" tidak dengan "mk".
  static int _findWord(String text, String word) {
    final pattern = _wordPatterns.putIfAbsent(word, () {
      final letters = word.split('').map((c) => '${RegExp.escape(c)}+').join();
      return RegExp('(?:^| )$letters(?:nya|lah|in|an|mu|ku|lu|lo)?(?= |\$)');
    });
    final match = pattern.firstMatch(text);
    if (match == null) return -1;
    // Kecocokan di tengah kalimat ikut menangkap spasi di depannya.
    return match.start == 0 ? 0 : match.start + 1;
  }

  String _normalize(String input) {
    var text = input.toLowerCase();

    const substitutions = {
      '4': 'a',
      '@': 'a',
      '8': 'b',
      '3': 'e',
      '1': 'i',
      '!': 'i',
      '0': 'o',
      '5': 's',
      r'$': 's',
      '7': 't',
    };
    substitutions.forEach((from, to) => text = text.replaceAll(from, to));

    // Kata ulang: "siapa2" dan "siapa-siapa" menjadi "siapa siapa". Harus
    // sebelum pemisah dibuang, supaya tidak menjadi "siapasiapa".
    text = text
        .replaceAllMapped(RegExp(r'\b([a-z]+)2\b'), (m) => '${m[1]} ${m[1]}')
        .replaceAllMapped(RegExp(r'\b([a-z]+)-\1\b'), (m) => '${m[1]} ${m[1]}');

    // Buang pemisah yang disisipkan di tengah kata, mis. "a-n-j-i-n-g".
    text = text.replaceAll(RegExp(r'[*._\-+|]'), '');

    // Rampingkan huruf berulang: "anjjjjing" -> "anjing".
    text = text.replaceAllMapped(RegExp(r'(.)\1{2,}'), (m) => m.group(1)! * 1);

    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Huruf yang dipisah spasi disatukan: "a n j i n g" menjadi "anjing".
    text = text.replaceAllMapped(
      RegExp(r'\b[a-z]\b(?: [a-z]\b){2,}'),
      (m) => m[0]!.replaceAll(' ', ''),
    );

    // Singkatan chat diganti kata lengkapnya, supaya semua pola di atas juga
    // menangkap "kmu", "jgn blg", "bgt", dan sejenisnya.
    return text.split(' ').map((word) => _slang[word] ?? word).join(' ');
  }

  /// Singkatan chat sehari-hari dan bentuk lengkap yang dipakai pola.
  static const _slang = {
    'kmu': 'kamu',
    'km': 'kamu',
    'kau': 'kamu',
    'gw': 'gue',
    'ak': 'aku',
    'aq': 'aku',
    'bgt': 'banget',
    'bngt': 'banget',
    'bangett': 'banget',
    'jgn': 'jangan',
    'jngn': 'jangan',
    'blg': 'bilang',
    'bilangin': 'bilang',
    'ga': 'gak',
    'gk': 'gak',
    'ngga': 'nggak',
    'tdk': 'tidak',
    'yg': 'yang',
    'sm': 'sama',
    'dgn': 'dengan',
    'skrg': 'sekarang',
    'skali': 'sekali',
    'bodo': 'bodoh',
    'udh': 'udah',
    'sdh': 'sudah',
    'pny': 'punya',
    'org': 'orang',
    'tmn': 'teman',
    'rmh': 'rumah',
    'sklh': 'sekolah',
    'ktm': 'ketemu',
    'krm': 'kirim',
    'cntik': 'cantik',
  };

  String _summarize(ThreatCategory category, RiskLevel level) {
    final prefix = switch (level) {
      RiskLevel.critical => 'Bahaya serius terdeteksi',
      RiskLevel.high => 'Ancaman terdeteksi',
      RiskLevel.medium => 'Pola mencurigakan',
      _ => 'Perlu diperhatikan',
    };
    final detail = switch (category) {
      ThreatCategory.grooming =>
        'lawan bicara memakai pola pendekatan predator: meminta kerahasiaan '
            'dan menjauhkan anak dari orang tua.',
      ThreatCategory.sextortion =>
        'ada permintaan atau ancaman penyebaran konten seksual terhadap anak.',
      ThreatCategory.sexualHarassment =>
        'anak menerima komentar atau ajakan bernuansa seksual.',
      ThreatCategory.cyberbullying =>
        'anak menerima perundungan dan perendahan yang berulang.',
      ThreatCategory.violence => 'terdapat ancaman kekerasan fisik.',
      ThreatCategory.selfHarm =>
        'anak menunjukkan tanda tekanan berat dan niat menyakiti diri sendiri.',
      ThreatCategory.personalData =>
        'ada upaya menggali data pribadi anak dan keluarga.',
      ThreatCategory.meetup =>
        'ada ajakan bertemu secara diam-diam tanpa sepengetahuan orang tua.',
      ThreatCategory.financial =>
        'ada permintaan uang, OTP, atau pemerasan finansial.',
      ThreatCategory.profanity =>
        'percakapan memuat kata kasar atau tidak sopan.',
      ThreatCategory.gambling =>
        'ada ajakan atau promosi judi online kepada anak.',
      ThreatCategory.substance => 'ada pembicaraan mengenai zat terlarang.',
    };
    return '$prefix: $detail';
  }

  /// Mengambil jendela kecil di sekitar pemicu, bukan seluruh isi pesan.
  String _excerpt(String text, int hintIndex) {
    const window = 90;
    if (text.length <= window) return text;

    final center = hintIndex.clamp(0, text.length - 1);
    var start = math.max(0, center - window ~/ 2);
    var end = math.min(text.length, start + window);
    start = math.max(0, end - window);

    final buffer = StringBuffer();
    if (start > 0) buffer.write('...');
    buffer.write(text.substring(start, end).trim());
    if (end < text.length) buffer.write('...');
    return buffer.toString();
  }
}
