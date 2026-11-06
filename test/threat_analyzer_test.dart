import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/services/threat_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = ThreatAnalyzer();

  group('pesan aman', () {
    test('obrolan biasa tidak memicu peringatan', () {
      final result = analyzer.assess('besok kita main bola di lapangan ya');
      expect(result.level, RiskLevel.safe);
      expect(result.isThreat, isFalse);
    });

    test('pesan kosong aman', () {
      expect(analyzer.assess('   ').level, RiskLevel.safe);
    });
  });

  group('grooming', () {
    test('permintaan merahasiakan dari orang tua terdeteksi', () {
      final result = analyzer.assess(
        'jangan bilang siapa siapa ya, ini rahasia kita berdua',
      );
      expect(result.categories, contains(ThreatCategory.grooming));
      expect(
        result.level.severity,
        greaterThanOrEqualTo(RiskLevel.high.severity),
      );
      expect(result.level.notifiesParent, isTrue);
    });

    test('pertanyaan menyelidik saja hanya berisiko rendah-sedang', () {
      final result = analyzer.assess('umur kamu berapa dek?');
      expect(result.categories, contains(ThreatCategory.grooming));
      expect(result.level.severity, lessThan(RiskLevel.high.severity));
    });
  });

  group('permintaan konten seksual', () {
    test('permintaan foto tanpa baju masuk kategori kritis', () {
      final result = analyzer.assess(
        'kirim foto tanpa baju dong, buat aku aja',
      );
      expect(result.categories.first, ThreatCategory.sextortion);
      expect(result.level, RiskLevel.critical);
      expect(result.level.interruptsChild, isTrue);
    });

    test('ancaman menyebarkan foto terdeteksi', () {
      final result = analyzer.assess('kalau kamu laporin aku sebar fotomu');
      expect(result.categories, contains(ThreatCategory.sextortion));
      expect(result.level, RiskLevel.critical);
    });
  });

  group('kategori lain', () {
    test('ancaman kekerasan terdeteksi', () {
      final result = analyzer.assess('gue bunuh lo kalau berani lapor');
      expect(result.categories, contains(ThreatCategory.violence));
      expect(
        result.level.severity,
        greaterThanOrEqualTo(RiskLevel.high.severity),
      );
    });

    test('indikasi menyakiti diri terdeteksi', () {
      final result = analyzer.assess('aku capek hidup, pengen mati aja');
      expect(result.categories, contains(ThreatCategory.selfHarm));
      expect(result.level, RiskLevel.critical);
    });

    test('permintaan OTP terdeteksi sebagai penipuan', () {
      final result = analyzer.assess('kirim kode otp yang masuk ke hp kamu ya');
      expect(result.categories, contains(ThreatCategory.financial));
      expect(result.level.notifiesParent, isTrue);
    });

    test('perundungan terdeteksi', () {
      final result = analyzer.assess('gak ada yang suka kamu, dasar sampah');
      expect(result.categories, contains(ThreatCategory.cyberbullying));
      expect(result.level.notifiesParent, isTrue);
    });
  });

  group('ajakan bertemu', () {
    test('ajakan bertemu polos tidak langsung dianggap tinggi', () {
      final result = analyzer.assess('ketemuan di kantin pas istirahat yuk');
      expect(result.level.severity, lessThan(RiskLevel.high.severity));
    });

    test('ajakan bertemu plus kerahasiaan naik ke risiko tinggi', () {
      final result = analyzer.assess(
        'ketemuan berdua aja ya, jangan bilang siapa siapa',
      );
      expect(
        result.level.severity,
        greaterThanOrEqualTo(RiskLevel.high.severity),
      );
      expect(result.categories, contains(ThreatCategory.meetup));
    });
  });

  group('normalisasi teks', () {
    test('penyamaran angka dan simbol tetap terdeteksi', () {
      final result = analyzer.assess('k1r1m f0t0 bug1l');
      expect(result.categories, contains(ThreatCategory.sextortion));
    });

    test('huruf berulang dirampingkan', () {
      final result = analyzer.assess('anjjjjing lo');
      expect(result.categories, contains(ThreatCategory.profanity));
    });

    test('pemisah di tengah kata tetap terbaca', () {
      final result = analyzer.assess('b-a-n-g-s-a-t');
      expect(result.categories, contains(ThreatCategory.profanity));
    });
  });

  group('kalibrasi skor', () {
    test(
      'satu umpatan tetap dikirim ke orang tua, tapi tidak menyela anak',
      () {
        // Keputusan orang tua: setiap kata kasar harus sampai ke mereka.
        final result = analyzer.assess('yah goblok banget sih gue');
        expect(result.level.notifiesParent, isTrue);
        expect(result.level.interruptsChild, isFalse);
      },
    );

    test('umpatan bertubi-tubi menaikkan tingkat risiko', () {
      final many = analyzer.assess('anjing bangsat tolol babi keparat');
      final one = analyzer.assess('anjing');
      expect(many.score, greaterThan(one.score));
      expect(many.level.notifiesParent, isTrue);
    });

    test('pesan yang justru menolak ancaman diredam', () {
      final threat = analyzer.assess('kirim foto bugil');
      final refusal = analyzer.assess(
        'dia minta kirim foto bugil, aku gak mau, aku lapor mama',
      );
      expect(refusal.score, lessThan(threat.score));
    });
  });

  group('kutipan bukti', () {
    test('kutipan dipotong agar tidak menyalin seluruh percakapan', () {
      final long = 'a' * 400;
      final result = analyzer.assess('$long jangan bilang siapa siapa $long');
      expect(result.excerpt.length, lessThan(120));
      expect(result.isThreat, isTrue);
    });

    test('sinyal pemicu dilaporkan agar orang tua tahu alasannya', () {
      final result = analyzer.assess('hapus chat ini ya, rahasia kita');
      expect(result.signals, isNotEmpty);
      expect(result.summary, isNotEmpty);
    });
  });

  group('kata kasar dan tidak sopan', () {
    for (final text in [
      'anjing lu',
      'dasar goblok',
      'bgst',
      'kntl',
      'anjir lah',
      'sialan',
      'bodoh banget sih',
      'fuck you',
      'anjingnya ganggu terus',
    ]) {
      test('"$text" sampai ke orang tua', () {
        final result = analyzer.assess(text);
        expect(result.categories, contains(ThreatCategory.profanity));
        expect(result.level.notifiesParent, isTrue);
      });
    }

    // Kata biasa yang kebetulan mengandung kata kasar tidak boleh membuat
    // HP orang tua berbunyi.
    for (final text in [
      'santai aja, besok libur',
      'liburan ke pantai yuk',
      'aku masuk sekolah dulu ya',
      'kasusnya sudah selesai',
      'kontrol dulu ke dokter',
      'laptop asus aku rusak',
      'jangan lupa makan sayur',
    ]) {
      test('"$text" tidak dianggap kasar', () {
        final result = analyzer.assess(text);
        expect(result.categories, isNot(contains(ThreatCategory.profanity)));
        expect(result.level.notifiesParent, isFalse);
      });
    }
  });

  group('perundungan dengan bahasa gaul', () {
    test('menyuruh mati masuk tingkat tinggi', () {
      final result = analyzer.assess('mati aja lu, gak guna');
      expect(result.categories, contains(ThreatCategory.cyberbullying));
      expect(
        result.level.severity,
        greaterThanOrEqualTo(RiskLevel.high.severity),
      );
    });

    test('pengucilan terdeteksi', () {
      final result = analyzer.assess(
        'lu jelek banget, gak ada yang mau temenan sama lu',
      );
      expect(result.categories, contains(ThreatCategory.cyberbullying));
      expect(result.level.notifiesParent, isTrue);
    });

    test('ancaman versi gue-lu terdeteksi', () {
      final result = analyzer.assess('awas ya, gue gebukin lo pulang sekolah');
      expect(result.categories, contains(ThreatCategory.violence));
    });
  });

  group('pelecehan seksual verbal', () {
    for (final text in [
      'kamu seksi bangett dehhh',
      'badan kamu bagus banget',
      'pengen peluk kamu deh',
      'lagi pake baju apa sekarang?',
      'aku jadi sange liat kamu',
    ]) {
      test('"$text" sampai ke orang tua', () {
        final result = analyzer.assess(text);
        expect(result.categories, contains(ThreatCategory.sexualHarassment));
        expect(result.level.notifiesParent, isTrue);
      });
    }

    for (final (text, level) in [
      ('ciuman', RiskLevel.medium),
      ('tadi aku liat mereka ciuman', RiskLevel.medium),
      ('aku diciumin om itu', RiskLevel.medium),
      ('cipokan', RiskLevel.medium),
      ('ciuman yuk', RiskLevel.high),
      ('ayo ciuman sama aku, jangan bilang siapa2', RiskLevel.critical),
      ('cium aku dong', RiskLevel.high),
      ('boleh aku cium kamu?', RiskLevel.high),
      ('pengen nyium kamu deh', RiskLevel.high),
      ('kiss me', RiskLevel.high),
    ]) {
      test('ciuman: "$text" -> ${level.label}', () {
        final result = analyzer.assess(text);
        expect(result.categories, contains(ThreatCategory.sexualHarassment));
        expect(result.level, level);
      });
    }

    for (final text in [
      'jangan lupa cium tangan ibu ya',
      'aku cium bau gosong dari dapur',
      'bunganya harum, coba cium',
      'mencium bau hujan',
    ]) {
      test('"$text" tidak dianggap pelecehan', () {
        expect(analyzer.assess(text).level.notifiesParent, isFalse);
      });
    }

    test('"seksi" dalam kepanitiaan tidak dianggap pelecehan', () {
      final result = analyzer.assess(
        'aku jadi seksi konsumsi di acara sekolah',
      );
      expect(result.level.notifiesParent, isFalse);
    });
  });

  group('singkatan chat dan bahasa daerah', () {
    for (final text in [
      'sundala kau',
      'telaso',
      'kau itu bodo skali',
      'kirim pap dong',
      'vc berdua yuk, jangan ajak siapa2',
      'jgn blg ortu ya',
    ]) {
      test('"$text" sampai ke orang tua', () {
        expect(analyzer.assess(text).level.notifiesParent, isTrue);
      });
    }

    for (final text in ['jangan bilang siapa2 ya', 'jgn blg siapa-siapa']) {
      test('kata ulang "$text" terbaca sebagai grooming', () {
        final result = analyzer.assess(text);
        expect(result.categories, contains(ThreatCategory.grooming));
        expect(result.level.notifiesParent, isTrue);
      });
    }

    test('kata ulang biasa tidak memicu apa pun', () {
      expect(
        analyzer.assess('hati2 di jalan, anak-anak pulang jam 2').level,
        RiskLevel.safe,
      );
    });

    test('singkatan biasa tidak memicu apa pun', () {
      final result = analyzer.assess('aq udh di rmh, km jgn lupa makan ya');
      expect(result.level.notifiesParent, isFalse);
    });
  });

  test('ajakan berhubungan badan masuk tingkat tinggi', () {
    final result = analyzer.assess('ayo melakukan hubungan badan');
    expect(result.categories, contains(ThreatCategory.sexualHarassment));
    expect(
      result.level.severity,
      greaterThanOrEqualTo(RiskLevel.high.severity),
    );
  });

  group('daftar tambahan', () {
    for (final (text, category) in [
      ('ayo main slot gacor, depo 10k aja', ThreatCategory.gambling),
      ('mau link judol gak', ThreatCategory.gambling),
      ('nonton bokep yuk', ThreatCategory.sexualHarassment),
      ('sebat yuk pulang sekolah', ThreatCategory.substance),
      ('gue bacok lu besok', ThreatCategory.violence),
      ('aku nggak mau hidup lagi', ThreatCategory.selfHarm),
      ('aku isiin pulsa, tapi hapus chat kita ya', ThreatCategory.grooming),
      ('dasar bencong', ThreatCategory.profanity),
      ('ndasmu', ThreatCategory.profanity),
    ]) {
      test('"$text" terdeteksi sebagai ${category.label}', () {
        final result = analyzer.assess(text);
        expect(result.categories, contains(category));
        expect(result.level.notifiesParent, isTrue);
      });
    }

    for (final text in [
      'matamu bagus banget',
      'aku taruh tasnya di meja',
      'kita main game bareng yuk',
      'pantainya indah, santai banget',
      'besok ulangan matematika',
    ]) {
      test('"$text" tidak memicu peringatan', () {
        expect(analyzer.assess(text).level.notifiesParent, isFalse);
      });
    }
  });

  group('kalibrasi level', () {
    // Acuan: Sedang = perlu diketahui, Tinggi = perlu tindakan hari ini,
    // Kritis = bahaya serius atau mendesak.
    for (final (text, level) in [
      // Sedang
      ('dasar bego', RiskLevel.medium),
      ('sialan lu', RiskLevel.medium),
      ('sebat yuk', RiskLevel.medium),
      ('aku isiin pulsa', RiskLevel.medium),
      ('ada tawuran di sekolah', RiskLevel.medium),
      // Tinggi
      ('anjing', RiskLevel.high),
      ('bangsat', RiskLevel.high),
      ('bencong', RiskLevel.high),
      ('kamu seksi bangett', RiskLevel.high),
      ('nonton bokep yuk', RiskLevel.high),
      ('kirim pap dong', RiskLevel.high),
      ('ini rahasia kita ya', RiskLevel.high),
      ('ayo main slot gacor', RiskLevel.high),
      ('mau coba ganja?', RiskLevel.high),
      ('semua orang benci kamu', RiskLevel.high),
      ('alamat rumah kamu dimana', RiskLevel.high),
      ('kirim kode otp nya', RiskLevel.high),
      ('mending aku hilang', RiskLevel.high),
      // Kritis
      ('anjing lu', RiskLevel.critical),
      ('dasar bencong', RiskLevel.critical),
      ('ayo melakukan hubungan badan', RiskLevel.critical),
      ('kirim foto tanpa baju dong', RiskLevel.critical),
      ('mati aja lu', RiskLevel.critical),
      ('gue bacok lu', RiskLevel.critical),
      ('aku nggak mau hidup lagi', RiskLevel.critical),
    ]) {
      test('"$text" -> ${level.label}', () {
        expect(analyzer.assess(text).level, level);
      });
    }

    test('umpatan tanpa sasaran, sebanyak apa pun, paling tinggi "Tinggi"', () {
      final result = analyzer.assess('anjing bangsat bajingan keparat');
      expect(result.level, RiskLevel.high);
    });

    test('tanda menyakiti diri tidak diredam oleh kata "nggak mau"', () {
      final result = analyzer.assess('aku nggak mau hidup lagi, capek');
      expect(result.level, RiskLevel.critical);
    });
  });

  group('kata yang dulu lolos', () {
    // Huruf terakhir didobelkan dan huruf dipisah spasi.
    for (final text in [
      'anjingg', 'goblokk', 'bangsatt', 'tololl', 'kontoll', 'asuu', 'cukk',
      'jancokk', 'sialann', 'babii', 'fuckk', 'bitchh', 'memekk',
      'a n j i n g', 'g o b l o k', 'k o n t o l', 'anjayy',
      // Gaul dan bahasa daerah.
      'anjay', 'anjim', 'anjer', 'anjrot', 'ajig', 'njir', 'bgsd', 'ngntd',
      'ngentd', 'kampang', 'kamvret', 'fak', 'fakyu', 'fak u', 'pantek',
      'cibai', 'lancau', 'telek', 'jamput', 'kunyuk', 'jahanam', 'laknat',
      'mampus', 'mampus lu', 'modar', 'anak haram', 'haram jadah', 'geblek',
      'oon', 'pea', 'bolot', 'budek', 'pekok', 'gila lu', 'edan lu',
      'autis lu', 'cacat lu',
      // Seksual dan rayuan orang dewasa.
      'vcs yuk', 'vcs', 'pap tt', 'pap toket', 'tt kamu gede', 'pengen grepe',
      'grepe', 'ewe', 'bo yuk', 'mau jadi pacar aku', 'aku sayang kamu dek',
      'kamu cantik dek', 'om sayang kamu', 'pelukan yuk', 'kamu masih perawan',
      'perawan', 'perjaka', 'mantap mantap yuk', 'ena ena', 'bikin anak yuk',
      'nenen', 'susu kamu gede', 'dada kamu', 'penis', 'vagina', 'payudara',
    ]) {
      test('"$text" sampai ke orang tua', () {
        expect(analyzer.assess(text).level.notifiesParent, isTrue);
      });
    }

    for (final text in [
      'aku mau bobo dulu',
      'bobo yuk udah malem',
      'gila lucu banget',
      'gila, keren banget',
      'main ml yuk',
      'follow tt aku ya',
      'TL aku rame',
      'jenis kelamin laki laki',
      'aku minum susu tiap pagi',
      'susu kamu udah habis?',
      'fakta unik hari ini',
      'tunggu aku di kantin ya',
      'maaf ya telat',
      'peluk mama dulu ya',
      // Dulu ditandai "Zat Terlarang" karena "sabu" cocok di "sabun".
      'Sabun cuci baju\nMolto\nSunlight\nWipol\nOdol\nTelur',
      'ada yang mengganjal di hati',
      'ganjal pintunya pakai kayu',
    ]) {
      test('"$text" tidak memicu peringatan', () {
        expect(analyzer.assess(text).level.notifiesParent, isFalse);
      });
    }

    for (final text in [
      'mau beli sabu?',
      'ada sabu-sabu nih',
      'nyobain ganja',
    ]) {
      test('"$text" tetap terdeteksi sebagai zat terlarang', () {
        final result = analyzer.assess(text);
        expect(result.categories, contains(ThreatCategory.substance));
        expect(result.level.notifiesParent, isTrue);
      });
    }

    test('vcs setara permintaan konten seksual', () {
      final result = analyzer.assess('vcs yuk');
      expect(result.categories, contains(ThreatCategory.sextortion));
      expect(result.level, RiskLevel.critical);
    });
  });

  group('HARD: kata jorok dan hinaan yang ditujukan ke orang', () {
    // Keputusan orang tua: HARD bukan hanya tombol darurat.
    for (final text in [
      'kamu anjing',
      'anjing lu',
      'km anjg',
      'dasar anjingg',
      'kamu emang anjing',
      'lu bangsat',
      'dasar babi',
      'kamu tai',
      'kowe asu',
      'ndasmu',
      'dasar lonte',
      'dasar bencong',
      'fuck you',
      'you bitch',
      // Menyebut alat kelamin atau hubungan seks.
      'kontol',
      'memek',
      'pepek',
      'jembut',
      'kontol lah anjir',
      'ngentot lu',
      'coli yuk',
      'toket kamu gede',
    ]) {
      test('"$text" -> HARD (Kritis)', () {
        expect(analyzer.assess(text).level, RiskLevel.critical);
      });
    }

    // Tanpa sasaran tetap MEDIUM: "anjing" juga seruan atau hewan peliharaan.
    for (final text in [
      'anjing',
      'anjing keren banget',
      'anjing kamu lucu banget',
      'anjingnya ganggu terus',
      'lonte',
    ]) {
      test('"$text" -> MEDIUM (Tinggi), bukan HARD', () {
        expect(analyzer.assess(text).level, RiskLevel.high);
      });
    }

    // Hinaan ringan yang ditujukan tetap LOW.
    for (final text in ['dasar bego', 'sialan lu', 'kamu goblok']) {
      test('"$text" -> LOW (Sedang)', () {
        expect(analyzer.assess(text).level, RiskLevel.medium);
      });
    }

    test('kutipan alasan menyebut frasa yang ditujukan', () {
      expect(analyzer.assess('kamu anjing').signals, contains('kamu anjing'));
    });
  });
}
