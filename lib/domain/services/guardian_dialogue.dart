import '../../core/l10n/l10n.dart';

import '../models/guardian_message.dart';

/// Topik obrolan sehari-hari yang dikenali Aura.
enum DialogueTopic {
  joke,
  blockHow,
  tellParents,
  aboutAura,
  howAreYou,
  thanks,
  bye,
  hurtAtHome,
  alreadySent,
  threatened,
  photoRequest,
  meetRequest,
  addressAsk,
  insult,
  strangeChat,
  game,
  fear,
  sad,
  angry,
  school,
  friends,
  family,
  bored,
  tired,
  happy,
  sick,
  crush,
  copeIdea,
  wantToTell,
  fine,
  greeting,
  yes,
  no,
  unsure,
}

/// Satu balasan Aura beserta pilihan cepatnya.
class DialogueTurn {
  const DialogueTurn(this.text, this.quickReplies, {this.topic});

  final String text;
  final List<String> quickReplies;

  /// Null bila Aura tidak mengenali topiknya dan meminta anak bercerita lagi.
  final DialogueTopic? topic;

  bool get isFallback => topic == null;
}

/// Obrolan sehari-hari Aura untuk hal yang bukan bahaya.
///
/// Berjalan sepenuhnya di ponsel, tanpa AI dan tanpa internet. Aura
/// mengenali topik dari kata kunci, mengingat topik yang sedang dibahas
/// (supaya "iya" atau "nggak" dipahami), dan balasannya makin dalam bila
/// anak terus membahas topik yang sama, tidak mengulang kalimat yang sama.
///
/// Tanda bahaya tidak ditangani di sini, melainkan oleh [ThreatAnalyzer] dan
/// balasan khususnya di `LocalGuardianBrain`.
class GuardianDialogue {
  const GuardianDialogue();

  /// Obrolan yang lebih lama dari ini dianggap sudah selesai.
  static const _contextWindow = Duration(hours: 1);

  DialogueTurn reply({
    required String message,
    required List<GuardianMessage> history,
    required String childName,
    DateTime? now,
  }) {
    final text = normalize(message);
    final words = text.split(' ').toSet();
    final earlier = _earlierChildMessages(history, message, now);

    final previous = earlier.reversed
        .map((m) => _detect(normalize(m.text), _words(m.text)))
        .firstWhere((t) => t != null && !_isAnswer(t), orElse: () => null);

    var topic = _detect(text, words);
    // Jawaban pendek seperti "iya" atau "gak tau" dipahami sebagai
    // tanggapan atas topik yang sedang dibahas.
    if ((topic == null || _isAnswer(topic)) && previous != null) {
      return _followUp(previous, topic, text, childName, earlier);
    }
    if (topic == null) return _fallback(earlier.length, childName);

    // Ejekan di tengah obrolan soal game adalah pemain yang toxic.
    if (topic == DialogueTopic.insult && previous == DialogueTopic.game) {
      topic = DialogueTopic.game;
    }

    final depth = earlier
        .where((m) => _detect(normalize(m.text), _words(m.text)) == topic)
        .length;
    return _turn(topic, text, words, childName, depth);
  }

  // ---------------------------------------------------------------------------
  // Pengenalan topik
  // ---------------------------------------------------------------------------

  static bool _isAnswer(DialogueTopic t) =>
      t == DialogueTopic.yes ||
      t == DialogueTopic.no ||
      t == DialogueTopic.unsure;

  List<GuardianMessage> _earlierChildMessages(
    List<GuardianMessage> history,
    String current,
    DateTime? now,
  ) {
    final cutoff = (now ?? DateTime.now()).subtract(_contextWindow);
    final recent = history
        .where((m) => m.isChild && m.sentAt.isAfter(cutoff))
        .toList();
    // Pesan yang sedang dibalas mungkin sudah ikut tersimpan di riwayat.
    if (recent.isNotEmpty && recent.last.text.trim() == current.trim()) {
      recent.removeLast();
    }
    return recent.length > 8 ? recent.sublist(recent.length - 8) : recent;
  }

  /// Huruf kecil, tanpa tanda baca, huruf berulang dirampingkan, dan
  /// singkatan chat diganti kata lengkap.
  static String normalize(String input) {
    var text = input.toLowerCase();
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAllMapped(RegExp(r'([a-z])\1+'), (m) => m.group(1)!);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.split(' ').map((w) => _slang[w] ?? w).join(' ');
  }

  static Set<String> _words(String raw) => normalize(raw).split(' ').toSet();

  static const _slang = {
    'aq': 'aku',
    'ak': 'aku',
    'gw': 'aku',
    'gue': 'aku',
    'km': 'kamu',
    'kmu': 'kamu',
    'lu': 'kamu',
    'lo': 'kamu',
    'ga': 'gak',
    'gk': 'gak',
    'nggak': 'gak',
    'ngak': 'gak',
    'enggak': 'gak',
    'engak': 'gak',
    'tidak': 'gak',
    'tdk': 'gak',
    'bgt': 'banget',
    'banget': 'banget',
    'tp': 'tapi',
    'yg': 'yang',
    'sm': 'sama',
    'udh': 'udah',
    'sdh': 'udah',
    'sudah': 'udah',
    'dah': 'udah',
    'gmn': 'gimana',
    'gmna': 'gimana',
    'bagaimana': 'gimana',
    'knp': 'kenapa',
    'np': 'kenapa',
    'emg': 'emang',
    'jg': 'juga',
    'blm': 'belum',
    'sklh': 'sekolah',
    'temen': 'teman',
    'tmn': 'teman',
    'tau': 'tahu',
    'tw': 'tahu',
    'iy': 'iya',
    'y': 'iya',
    'ya': 'iya',
    'yaa': 'iya',
    'yup': 'iya',
    'ok': 'oke',
    'okay': 'oke',
    'okey': 'oke',
    'makasi': 'makasih',
    'mksh': 'makasih',
    'thx': 'makasih',
    'thanks': 'makasih',
    'ma': 'mama',
    'mamah': 'mama',
    'mami': 'mama',
    'ibu': 'mama',
    'bunda': 'mama',
    'pa': 'papa',
    'papah': 'papa',
    'papi': 'papa',
    'ayah': 'papa',
    'bapak': 'papa',
    'ortu': 'orangtua',
  };

  /// Kata kunci per topik, diperiksa berurutan: yang lebih khusus lebih dulu.
  /// Kata tunggal dicocokkan sebagai kata utuh, frasa sebagai potongan teks.
  static final _keywords = <(DialogueTopic, List<String>)>[
    (
      DialogueTopic.joke,
      [
        'tebak tebakan',
        'tebakan',
        'lelucon',
        'lucu dong',
        'cerita lucu',
        'lagi dong',
        'jokes',
        'lawak',
      ],
    ),
    (
      DialogueTopic.blockHow,
      [
        'cara blokir',
        'cara block',
        'gimana blokir',
        'gimana caranya',
        'cara lapor',
        'cara report',
        'blokir gimana',
        'block gimana',
        'akun baru',
      ],
    ),
    (
      DialogueTopic.tellParents,
      [
        'takut dimarahi',
        'takut bilang',
        'takut cerita',
        'malu cerita',
        'gak berani',
        'bantu aku',
        'cerita ke guru',
        'malu',
      ],
    ),
    (
      DialogueTopic.aboutAura,
      [
        'kamu siapa',
        'siapa kamu',
        'kamu itu apa',
        'aura itu',
        'kamu robot',
        'kamu manusia',
        'nama kamu',
        'kamu bisa apa',
        'rahasia kan',
        'kamu umur',
        'umur kamu',
        'kamu tinggal',
        'rahasia ah',
      ],
    ),
    (
      DialogueTopic.howAreYou,
      ['apa kabar', 'kabar kamu', 'kamu gimana', 'kamu baik'],
    ),
    (DialogueTopic.thanks, ['makasih', 'terima kasih', 'makasih aura']),
    (
      DialogueTopic.bye,
      [
        'dadah',
        'bye',
        'udahan',
        'sampai jumpa',
        'udah dulu',
        'tidur dulu',
        'mau tidur',
      ],
    ),
    (
      DialogueTopic.hurtAtHome,
      [
        'dipukul',
        'ditampar',
        'ditendang',
        'dicubit',
        'disakiti',
        'dijambak',
        'disiksa',
      ],
    ),
    (
      DialogueTopic.alreadySent,
      ['terlanjur', 'udah kirim', 'udah kasih', 'klik link', 'udah klik'],
    ),
    (
      DialogueTopic.threatened,
      [
        'ngancam',
        'mengancam',
        'diancam',
        'ancam',
        'maksa',
        'memaksa',
        'dipaksa',
      ],
    ),
    (
      DialogueTopic.photoRequest,
      [
        'minta foto',
        'minta fotoku',
        'minta foto aku',
        'kirim foto',
        'minta pap',
        'fotoku',
      ],
    ),
    (
      DialogueTopic.meetRequest,
      [
        'ngajak ketemu',
        'ajak ketemu',
        'ketemuan',
        'mau ketemu',
        'janji ketemu',
        'ngajak chat di luar',
      ],
    ),
    (
      DialogueTopic.addressAsk,
      [
        'nanya alamat',
        'tanya alamat',
        'alamatku',
        'alamat rumah',
        'nama sekolah',
        'sekolah dimana',
        'minta data',
      ],
    ),
    (
      DialogueTopic.insult,
      [
        'ngatain',
        'dikatain',
        'ngejek',
        'diejek',
        'dihina',
        'menghina',
        'toxic',
        'dibully',
        'bully',
        'dimaki',
      ],
    ),
    (
      DialogueTopic.strangeChat,
      [
        'chat aneh',
        'orang asing',
        'gak kenal',
        'gak dikenal',
        'nomor asing',
        'dm aneh',
        'chat aku terus',
        'orang aneh',
        'stranger',
        'ganggu aku',
        'yang ganggu',
        'ada orang',
        'kenal di internet',
        'dari internet',
        'link aneh',
      ],
    ),
    (
      DialogueTopic.game,
      [
        'game',
        'gim',
        'ml',
        'mobile legend',
        'mobile legends',
        'free fire',
        'ff',
        'roblox',
        'minecraft',
        'pubg',
        'mabar',
        'rank',
        'push rank',
        'diamond',
        'top up',
        'topup',
        'skin',
        'robux',
        'akun',
        'password',
        'kata sandi',
        'otp',
        'dibajak',
        'hack',
        'link',
        'tim',
        'kalah',
        'noob',
        'main',
      ],
    ),
    (
      DialogueTopic.fear,
      [
        'takut',
        'ketakutan',
        'cemas',
        'khawatir',
        'deg degan',
        'gelisah',
        'mimpi buruk',
        'hantu',
        'gelap',
      ],
    ),
    (
      DialogueTopic.sad,
      [
        'sedih',
        'nangis',
        'menangis',
        'kesepian',
        'sendirian',
        'galau',
        'kecewa',
        'patah hati',
        'hancur',
        'gak punya teman',
        'dijauhi',
        'dikucilkan',
        'gak diajak',
        'capek pikiran',
        'gak enak hati',
        'ada masalah',
      ],
    ),
    (
      DialogueTopic.angry,
      [
        'kesel',
        'kesal',
        'marah',
        'sebel',
        'bete',
        'jengkel',
        'nyebelin',
        'emosi',
      ],
    ),
    (
      DialogueTopic.happy,
      [
        'senang',
        'seneng',
        'bahagia',
        'asik',
        'asyik',
        'seru',
        'juara',
        'menang',
        'nilai bagus',
        'nilai seratus',
        'hore',
        'yey',
      ],
    ),
    (
      DialogueTopic.school,
      [
        'sekolah',
        'guru',
        'pr',
        'tugas',
        'ujian',
        'ulangan',
        'nilai',
        'rapor',
        'remedial',
        'pelajaran',
        'matematika',
        'kelas',
        'belajar',
      ],
    ),
    (
      DialogueTopic.friends,
      [
        'teman',
        'sahabat',
        'berantem',
        'bertengkar',
        'marahan',
        'musuhan',
        'dimusuhi',
        'salah paham',
      ],
    ),
    (
      DialogueTopic.family,
      [
        'mama',
        'papa',
        'orangtua',
        'orang tua',
        'kakak',
        'adik',
        'rumah',
        'keluarga',
        'cerai',
        'dimarahi',
      ],
    ),
    (
      DialogueTopic.bored,
      ['bosen', 'bosan', 'gabut', 'gak ada kerjaan', 'ide lain'],
    ),
    (DialogueTopic.tired, ['capek', 'cape', 'lelah', 'ngantuk', 'letih']),
    (
      DialogueTopic.sick,
      ['sakit', 'pusing', 'demam', 'batuk', 'pilek', 'mual', 'flu'],
    ),
    (
      DialogueTopic.crush,
      [
        'naksir',
        'suka sama',
        'pacar',
        'pacaran',
        'crush',
        'gebetan',
        'jatuh cinta',
      ],
    ),
    (
      DialogueTopic.copeIdea,
      [
        'dengerin musik',
        'musik',
        'nyanyi',
        'gambar',
        'menggambar',
        'baca buku',
        'olahraga',
        'jalan jalan',
        'ngobrol sama teman',
      ],
    ),
    (
      DialogueTopic.wantToTell,
      ['mau cerita', 'pengen cerita', 'mau curhat', 'curhat', 'ngobrol'],
    ),
    (
      DialogueTopic.fine,
      [
        'baik',
        'biasa aja',
        'lumayan',
        'nyaman',
        'baik baik aja',
        'aman kok',
        'gak papa',
      ],
    ),
    (
      DialogueTopic.greeting,
      [
        'halo',
        'hai',
        'hi',
        'hello',
        'hey',
        'pagi',
        'siang',
        'sore',
        'malam',
        'assalamualaikum',
        'permisi',
      ],
    ),
    // Urutan penting: "gak tahu" sebelum "gak", dan "gak ada" sebelum "ada".
    (
      DialogueTopic.unsure,
      ['gak tahu', 'bingung', 'entah', 'entahlah', 'mungkin', 'gak yakin'],
    ),
    (
      DialogueTopic.no,
      [
        'gak',
        'belum',
        'jangan',
        'gak mau',
        'gak ada',
        'nope',
        'nanti',
        'nanti aja',
        'lain kali',
      ],
    ),
    (
      DialogueTopic.yes,
      [
        'iya',
        'oke',
        'boleh',
        'mau',
        'ada',
        'pernah',
        'udah',
        'bener',
        'betul',
        'siap',
      ],
    ),
  ];

  /// Kata kunci yang sudah dinormalkan dengan cara yang sama seperti pesan.
  static final _normalizedKeywords = [
    for (final (topic, words) in _keywords)
      (topic, [for (final w in words) normalize(w)]),
  ];

  DialogueTopic? _detect(String text, Set<String> words) {
    // Jawaban pendek: periksa "gak tahu" sebelum "gak".
    final short = words.length <= 3;
    for (final (topic, keywords) in _normalizedKeywords) {
      if (_isAnswer(topic) && !short) continue;
      if (_matches(text, words, keywords)) return topic;
    }
    return null;
  }

  /// Akhiran yang lazim: "nilaiku", "tugasnya", "pelajarannya".
  static const _suffixes = ['nya', 'ku', 'mu', 'lah', 'kah', 'an'];

  bool _matches(String text, Set<String> words, List<String> keywords) {
    for (final k in keywords) {
      if (k.contains(' ')) {
        if (text.contains(k)) return true;
        continue;
      }
      if (words.contains(k)) return true;
      // Kata sangat pendek ("ff", "pr", "ml") hanya dicocokkan utuh.
      if (k.length < 4) continue;
      for (final w in words) {
        if (w.startsWith(k) && _suffixes.contains(w.substring(k.length))) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasAny(String text, Set<String> words, List<String> raw) =>
      _matches(text, words, [for (final w in raw) normalize(w)]);

  // ---------------------------------------------------------------------------
  // Balasan per topik
  // ---------------------------------------------------------------------------

  DialogueTurn _turn(
    DialogueTopic topic,
    String text,
    Set<String> words,
    String name,
    int depth,
  ) {
    DialogueTurn t(String reply, List<String> chips) =>
        DialogueTurn(reply, chips, topic: topic);
    T pick<T>(List<T> options) => options[depth % options.length];

    switch (topic) {
      case DialogueTopic.joke:
        return t(pick(_jokes), const [
          'Lagi dong!',
          'Hahaha',
          'Aku mau cerita',
        ]);

      case DialogueTopic.blockHow:
        if (_hasAny(text, words, ['akun baru'])) {
          return t(
            tr(
              'Kalau dia terus mengganggu pakai akun baru, itu sudah termasuk pelecehan, {name}. Simpan tangkapan layarnya dan ceritakan ke orang tuamu ya, mereka bisa bantu melaporkan.',
              {'name': name},
            ),
            const ['Oke, aku cerita', 'Aku takut dimarahi', 'Makasih Aura'],
          );
        }
        return t(
          tr(
            'Caranya gampang: buka chat orang itu, ketuk namanya atau tiga titik di pojok, lalu pilih "Blokir". Kalau ada tombol "Laporkan", tekan juga. Jangan hapus chat-nya dulu ya, itu bisa jadi bukti.',
          ),
          const ['Udah aku blokir', 'Dia bikin akun baru', 'Makasih Aura'],
        );

      case DialogueTopic.tellParents:
        if (_hasAny(text, words, ['cerita ke guru'])) {
          return t(
            tr(
              'Itu pilihan yang bagus. Guru atau wali kelas bisa bantu kamu. Cari waktu saat guru nggak sibuk, lalu bilang kamu mau cerita sesuatu yang penting.',
            ),
            const ['Oke', 'Aku masih malu', 'Makasih Aura'],
          );
        }
        if (_hasAny(text, words, ['bantu aku'])) {
          return t(
            tr(
              'Kamu bisa mulai dengan bilang: "Ma, Pa, aku mau cerita sesuatu, tapi janji dengerin dulu ya." Itu kalimat yang berani banget. Aku yakin kamu bisa, {name}.',
              {'name': name},
            ),
            const ['Oke, aku coba', 'Aku masih takut', 'Makasih Aura'],
          );
        }
        return t(
          pick([
            tr(
              'Wajar kalau kamu takut atau malu, {name}. Tapi orang tuamu pasti lebih ingin tahu daripada kamu menanggungnya sendiri. Kamu nggak salah. Mau aku bantu mulai ceritanya?',
              {'name': name},
            ),
            tr(
              'Rasa takut itu nggak apa-apa. Kamu bisa cerita ke orang dewasa mana pun yang kamu percaya, nggak harus orang tua: guru, kakak, atau saudara. Siapa yang paling enak diajak bicara?',
            ),
          ]),
          const ['Iya, bantu aku', 'Aku mau cerita ke guru', 'Nanti aja'],
        );

      case DialogueTopic.aboutAura:
        if (_hasAny(text, words, ['bisa apa'])) {
          return t(
            tr(
              'Aku bisa nemenin kamu cerita, kasih tips kalau ada yang ganggu di chat atau game, dan bantu kasih tahu orang tuamu kalau kamu dalam bahaya. Untuk hal penting, tetap cerita juga ke orang dewasa ya, karena mereka bisa bantu langsung.',
            ),
            const [
              'Ceritanya rahasia kan?',
              'Aku mau cerita',
              'Tebak-tebakan!',
            ],
          );
        }
        if (_hasAny(text, words, ['rahasia kan', 'rahasia ah'])) {
          return t(
            tr(
              'Ceritamu aman di sini. Aku cuma kasih tahu orang tuamu kalau kamu dalam bahaya, misalnya ada yang mengancam atau minta foto. Selain itu, obrolan kita nggak dikirim ke siapa-siapa.',
            ),
            const ['Oke, aku cerita', 'Kamu bisa apa aja?', 'Makasih Aura'],
          );
        }
        if (_hasAny(text, words, ['umur', 'tinggal'])) {
          return t(
            tr(
              'Aku nggak punya umur kayak manusia. Aku tinggal di HP kamu, di dalam aplikasi AURA ini, dan selalu siap kalau kamu panggil.',
            ),
            const ['Kamu bisa apa aja?', 'Aku mau cerita', 'Tebak-tebakan!'],
          );
        }
        return t(
          tr(
            'Aku Aura, robot penjaga yang tinggal di HP kamu. Tugasku nemenin kamu ngobrol dan bantu kalau ada yang bikin kamu nggak nyaman di internet. Aku bukan manusia, tapi aku dengerin beneran.',
          ),
          const [
            'Kamu bisa apa aja?',
            'Ceritanya rahasia kan?',
            'Aku mau cerita',
          ],
        );

      case DialogueTopic.howAreYou:
        return t(
          tr(
            'Aku baik, makasih udah nanya! Robot kayak aku nggak pernah capek dengerin cerita. Kamu sendiri gimana hari ini, {name}?',
            {'name': name},
          ),
          const ['Baik', 'Biasa aja', 'Lagi sedih'],
        );

      case DialogueTopic.thanks:
        return t(
          tr('Sama-sama, {name}! Kapan pun kamu butuh, aku ada di sini.', {
            'name': name,
          }),
          const ['Aku mau cerita lagi', 'Tebak-tebakan!', 'Udah dulu ya'],
        );

      case DialogueTopic.bye:
        return t(
          tr(
            'Oke, {name}. Makasih udah ngobrol sama aku. Ingat ya, kalau ada apa-apa, tombol merah di beranda selalu siap. Dadah! 👋',
            {'name': name},
          ),
          const [],
        );

      case DialogueTopic.hurtAtHome:
        return t(
          tr(
            'Kalau ada yang menyakiti badanmu, itu tidak boleh, siapa pun orangnya, {name}. Kamu berhak aman. Ceritakan ke orang dewasa yang kamu percaya, misalnya guru, atau minta mereka menelepon layanan SAPA 129. Kalau kamu dalam bahaya sekarang, tekan tombol merah di beranda.',
            {'name': name},
          ),
          const ['Aku takut', 'Aku mau cerita ke guru', 'Udah sering terjadi'],
        );

      case DialogueTopic.alreadySent:
        if (_hasAny(text, words, ['link', 'klik'])) {
          return t(
            tr(
              'Nggak apa-apa, {name}. Jangan isi password atau data apa pun di halaman itu ya. Bilang ke orang tuamu sekarang supaya kata sandi akunmu bisa segera diganti.',
              {'name': name},
            ),
            const ['Aku takut dimarahi', 'Oke, aku bilang', 'Makasih Aura'],
          );
        }
        return t(
          tr(
            'Nggak apa-apa, {name}, kamu tidak salah. Yang salah adalah orang yang meminta. Jangan kirim apa-apa lagi, jangan hapus chat-nya, dan ceritakan ke orang tuamu sekarang ya supaya mereka bisa membantu. Kalau dia mengancam, tekan tombol merah di beranda.',
            {'name': name},
          ),
          const ['Aku takut dimarahi', 'Dia mengancam aku', 'Oke, aku cerita'],
        );

      case DialogueTopic.threatened:
        if (_hasAny(text, words, ['maksa', 'memaksa', 'dipaksa'])) {
          return t(
            tr(
              'Kalau dia memaksa terus, itu tanda dia bukan orang baik. Kamu boleh berhenti membalas dan langsung blokir. Kamu nggak harus menuruti siapa pun yang bikin kamu nggak nyaman.',
            ),
            const ['Gimana caranya blokir?', 'Dia mengancam aku', 'Oke'],
          );
        }
        return t(
          tr(
            'Kalau ada yang mengancam kamu, itu serius dan bukan salahmu, {name}. Jangan turuti dan jangan temui dia. Ceritakan ke orang tuamu sekarang, dan kalau kamu merasa dalam bahaya, tekan tombol merah di beranda.',
            {'name': name},
          ),
          const [
            'Aku takut dimarahi',
            'Oke, aku cerita',
            'Gimana caranya blokir?',
          ],
        );

      case DialogueTopic.photoRequest:
        return t(
          tr(
            'Jangan kirim foto ke orang yang kamu kenal dari internet ya, apalagi kalau dia maksa atau minta dirahasiakan. Itu bukan salahmu. Jangan hapus chat-nya, dan ceritakan ke orang tuamu.',
          ),
          const [
            'Aku udah terlanjur kirim',
            'Dia maksa terus',
            'Iya, aku cerita',
          ],
        );

      case DialogueTopic.meetRequest:
        return t(
          pick([
            tr(
              'Jangan pergi ketemu orang yang kamu kenal dari internet tanpa orang tuamu ya, {name}, walaupun dia kelihatan baik. Orang di internet bisa pura-pura jadi siapa saja.',
              {'name': name},
            ),
            tr(
              'Batalkan aja janjinya, nggak apa-apa. Keselamatanmu lebih penting daripada janji. Ceritakan ke orang tuamu supaya mereka tahu, ya.',
            ),
          ]),
          const ['Dia maksa', 'Aku udah janji ketemu', 'Oke, aku nggak pergi'],
        );

      case DialogueTopic.addressAsk:
        return t(
          tr(
            'Alamat rumah, nama sekolah, dan nomor HP itu rahasia, nggak boleh dikasih ke orang yang kamu kenal dari internet. Kalau dia terus nanya, blokir aja dan ceritakan ke orang tuamu.',
          ),
          const ['Aku udah terlanjur kasih', 'Gimana caranya blokir?', 'Oke'],
        );

      case DialogueTopic.insult:
        return t(
          pick([
            tr(
              'Diejek itu nyakitin, {name}. Kata-kata mereka nggak menentukan siapa kamu. Kalau terjadi di chat, jangan dibalas dan simpan buktinya. Sudah berapa lama begini?',
              {'name': name},
            ),
            tr(
              'Kamu nggak pantas diperlakukan begitu. Coba ceritakan ke orang dewasa yang kamu percaya ya, biar mereka bisa bantu menghentikannya.',
            ),
          ]),
          const ['Baru sekali', 'Sudah lama', 'Aku takut dimarahi'],
        );

      case DialogueTopic.strangeChat:
        return t(
          pick([
            tr(
              'Makasih udah cerita, {name}. Orang yang nggak kamu kenal di dunia nyata itu nggak selalu jujur soal siapa dia. Dia ngomong apa ke kamu?',
              {'name': name},
            ),
            tr(
              'Kamu boleh banget nggak balas dan langsung blokir. Jangan kasih foto, alamat, atau nama sekolah ya. Mau aku kasih tahu cara blokirnya?',
            ),
          ]),
          const ['Dia minta fotoku', 'Dia ngajak ketemu', 'Dia nanya alamatku'],
        );

      case DialogueTopic.game:
        if (_hasAny(text, words, [
          'ngatain',
          'dikatain',
          'ngejek',
          'diejek',
          'toxic',
          'dihina',
        ])) {
          return t(
            tr(
              'Pemain yang ngatain itu nggak sportif. Kamu nggak salah. Kamu bisa mute atau blokir dia, dan nggak usah dibalas. Mau tahu caranya?',
            ),
            const [
              'Iya, gimana caranya',
              'Dia ngatain terus',
              'Udah aku blokir',
            ],
          );
        }
        if (_hasAny(text, words, [
          'akun',
          'akunku',
          'dibajak',
          'hack',
          'password',
          'kata sandi',
        ])) {
          return t(
            tr(
              'Waduh, akunmu kenapa? Ingat ya: jangan pernah kasih password atau kode OTP ke siapa pun, termasuk yang ngaku admin game. Minta tolong orang tuamu untuk mengamankan akunnya ya.',
            ),
            const ['Akunku dibajak', 'Ada yang minta password', 'Oke'],
          );
        }
        if (_hasAny(text, words, [
          'diamond',
          'top up',
          'topup',
          'skin',
          'robux',
          'gratis',
          'hadiah',
        ])) {
          return t(
            tr(
              'Hati-hati ya, tawaran diamond atau skin gratis sering cuma tipuan buat mencuri akun atau uang. Yang asli cuma dari toko resmi di dalam game. Ada yang nawarin kamu?',
            ),
            const ['Ada yang nawarin', 'Aku udah klik link', 'Nggak ada'],
          );
        }
        if (_hasAny(text, words, ['kalah', 'rank', 'noob', 'lose'])) {
          return t(
            tr(
              'Kalah terus itu nyebelin banget ya, {name}. Kadang istirahat sebentar bikin mainnya lebih fokus lagi. Ada yang bikin kamu kesal pas main?',
              {'name': name},
            ),
            const [
              'Ada yang ngatain aku',
              'Cuma kesel aja',
              'Timku nggak kompak',
            ],
          );
        }
        return t(
          pick([
            tr(
              'Seru ya main game! Kamu lagi main apa? Ada yang bikin kamu nggak nyaman pas main?',
            ),
            tr('Aku dengerin. Ceritain lebih lanjut dong, kejadiannya gimana?'),
            tr(
              'Main game boleh, asal jangan sampai lupa istirahat dan belajar ya. Ada lagi yang mau kamu ceritain?',
            ),
          ]),
          const [
            'Ada yang ngatain aku',
            'Kalah terus',
            'Ada yang ngajak chat di luar game',
          ],
        );

      case DialogueTopic.fear:
        if (_hasAny(text, words, ['mimpi buruk', 'hantu', 'gelap'])) {
          return t(
            tr(
              'Mimpi buruk itu nggak nyata, dan sekarang kamu aman. Nyalakan lampu kecil kalau mau, atau peluk bantal kesayanganmu. Mau ngobrol sebentar biar tenang?',
            ),
            const ['Mau', 'Aku masih takut', 'Udah mendingan'],
          );
        }
        return t(
          pick([
            tr(
              'Nggak apa-apa merasa takut, {name}. Coba tarik napas pelan-pelan bareng aku... tahan sebentar... buang pelan. Apa yang bikin kamu takut?',
              {'name': name},
            ),
            tr(
              'Aku tetap di sini. Kalau rasa takutnya karena ada orang yang mengganggu, cerita ke orang dewasa itu langkah paling berani. Kamu mau cerita ke siapa?',
            ),
          ]),
          const [
            'Ada orang yang ganggu aku',
            'Aku takut dimarahi',
            'Mimpi buruk',
          ],
        );

      case DialogueTopic.sad:
        if (_hasAny(text, words, [
          'dijauhi',
          'dikucilkan',
          'gak diajak',
          'gak punya teman',
        ])) {
          return t(
            tr(
              'Dijauhi teman itu nyakitin banget. Itu bukan karena kamu kurang baik, {name}. Ada satu teman yang masih baik sama kamu?',
              {'name': name},
            ),
            const ['Ada satu', 'Gak ada', 'Mereka ngejek aku'],
          );
        }
        if (_hasAny(text, words, ['kesepian', 'sendirian'])) {
          return t(
            tr(
              'Merasa sendirian itu nggak enak banget. Tapi sekarang kamu lagi ngobrol sama aku, jadi kamu nggak sendirian. Ada teman atau keluarga yang biasanya enak diajak ngobrol?',
            ),
            const ['Ada', 'Gak ada', 'Aku mau ngobrol sama kamu aja'],
          );
        }
        return t(
          pick([
            tr(
              'Aku di sini, {name}. Kedengarannya hatimu lagi berat. Mau cerita pelan-pelan apa yang bikin kamu sedih?',
              {'name': name},
            ),
            tr(
              'Makasih udah mau cerita. Sedih itu wajar, dan kamu nggak harus kuat terus. Apa yang biasanya bikin kamu sedikit lebih baik?',
            ),
            tr(
              'Kalau sedihnya nggak hilang-hilang beberapa hari, cerita juga ke orang dewasa yang kamu percaya ya. Mereka bisa bantu lebih banyak dari aku.',
            ),
          ]),
          depth == 1
              ? ['Dengerin musik', 'Main game', 'Ngobrol sama teman']
              : ['Aku dijauhi teman', 'Masalah di rumah', 'Gak tahu kenapa'],
        );

      case DialogueTopic.angry:
        return t(
          pick([
            tr(
              'Kedengarannya kamu lagi kesal banget. Wajar kok marah. Mau cerita apa yang bikin kamu sekesal ini?',
            ),
            tr(
              'Kalau lagi marah, coba hitung pelan sampai sepuluh atau minum air dulu. Setelah agak tenang, kita pikirin bareng ya.',
            ),
          ]),
          const ['Aku dimarahi', 'Teman-temanku nyebelin', 'Kalah main game'],
        );

      case DialogueTopic.school:
        if (_hasAny(text, words, [
          'nilai jelek',
          'remedial',
          'nilaiku jelek',
          'jelek',
        ])) {
          return t(
            tr(
              'Nilai jelek bukan berarti kamu bodoh, {name}. Itu cuma tanda bagian mana yang perlu dilatih lagi. Kamu bisa minta bantuan guru atau orang tua untuk belajar bareng.',
              {'name': name},
            ),
            const ['Aku takut dimarahi', 'Oke, aku coba', 'Pelajarannya susah'],
          );
        }
        if (_hasAny(text, words, [
          'pr',
          'tugas',
          'ujian',
          'ulangan',
          'pelajaran',
          'matematika',
          'susah',
          'belajar',
        ])) {
          return t(
            tr(
              'Tugas dan ujian memang bisa bikin pusing. Coba kerjakan sedikit demi sedikit, mulai dari yang paling gampang, lalu istirahat sebentar. Pelajaran apa yang paling bikin susah?',
            ),
            const ['Matematika', 'Nilaiku jelek', 'Tugasnya banyak banget'],
          );
        }
        if (_hasAny(text, words, ['guru'])) {
          return t(
            tr(
              'Kalau ada masalah dengan guru dan menurutmu nggak adil, kamu boleh cerita ke orang tuamu supaya mereka bisa bicara baik-baik dengan gurunya.',
            ),
            const ['Aku dimarahi guru', 'Oke', 'Makasih Aura'],
          );
        }
        return t(
          tr(
            'Gimana sekolahmu hari ini, {name}? Ada yang seru, atau ada yang bikin nggak nyaman?',
            {'name': name},
          ),
          const ['Seru!', 'Ada yang ganggu aku', 'Capek banget'],
        );

      case DialogueTopic.friends:
        if (_hasAny(text, words, [
          'berantem',
          'bertengkar',
          'marahan',
          'musuhan',
          'salah paham',
        ])) {
          return t(
            tr(
              'Berantem sama teman memang bikin nggak enak hati. Biasanya setelah sama-sama tenang, ngobrol baik-baik bisa membantu. Kalian berantem soal apa?',
            ),
            const ['Soal game', 'Salah paham', 'Dia ngejek aku'],
          );
        }
        return t(
          pick([
            tr('Cerita soal temanmu dong. Kalian biasanya main apa?'),
            tr(
              'Teman yang baik itu yang bikin kamu nyaman jadi diri sendiri. Temanmu seperti itu?',
            ),
          ]),
          const ['Main game bareng', 'Ngobrol di sekolah', 'Lagi marahan'],
        );

      case DialogueTopic.family:
        if (_hasAny(text, words, ['dimarahi'])) {
          return t(
            tr(
              'Dimarahi itu bikin sedih ya. Biasanya orang tua marah karena khawatir, bukan karena nggak sayang. Mau cerita kenapa kamu dimarahi?',
            ),
            const ['Karena nilai', 'Karena main HP', 'Gak tahu kenapa'],
          );
        }
        if (_hasAny(text, words, [
          'cerai',
          'berantem',
          'bertengkar',
          'ribut',
          'pisah',
        ])) {
          return t(
            tr(
              'Kalau orang di rumah lagi bertengkar, itu bukan salah kamu, {name}. Kamu boleh cari tempat yang tenang dan cerita ke orang dewasa lain yang kamu percaya.',
              {'name': name},
            ),
            const ['Aku takut', 'Udah sering', 'Makasih Aura'],
          );
        }
        return t(
          tr('Gimana keadaan di rumah, {name}? Kamu nyaman di rumah?', {
            'name': name,
          }),
          const ['Nyaman kok', 'Lagi ada masalah', 'Aku sering sendirian'],
        );

      case DialogueTopic.bored:
        return t(
          pick([
            tr(
              'Lagi gabut ya? Mau tebak-tebakan sama aku? Atau coba ini: gambar robot kayak aku, atau main di luar sebentar kalau cuacanya cerah 😄',
            ),
            tr(
              'Ide lain: bikin cerita pendek tentang petualangan robot, bantu orang di rumah, atau baca buku yang kamu suka. Mana yang seru?',
            ),
          ]),
          const ['Tebak-tebakan!', 'Aku mau cerita', 'Ide lain dong'],
        );

      case DialogueTopic.tired:
        return t(
          tr(
            'Kamu kedengarannya capek. Istirahat dulu nggak apa-apa kok. Kamu udah minum air dan makan belum?',
          ),
          const ['Udah', 'Belum', 'Capek pikiran'],
        );

      case DialogueTopic.happy:
        return t(
          pick([
            tr(
              'Wah, ikut senang dengarnya, {name}! 🎉 Cerita dong, apa yang bikin kamu senang?',
              {'name': name},
            ),
            tr(
              'Keren! Kamu pantas bangga sama dirimu sendiri. Cerita juga ke orang tuamu ya, pasti mereka ikut senang.',
            ),
          ]),
          const ['Aku menang', 'Dapat nilai bagus', 'Main sama teman'],
        );

      case DialogueTopic.sick:
        return t(
          tr(
            'Semoga cepat sembuh ya, {name}. Bilang ke orang tuamu atau orang dewasa di dekatmu kalau badanmu nggak enak, supaya bisa diperiksa. Aku nggak bisa kasih obat, tapi aku bisa nemenin ngobrol.',
            {'name': name},
          ),
          const ['Aku udah bilang', 'Belum', 'Makasih Aura'],
        );

      case DialogueTopic.crush:
        return t(
          tr(
            'Hihi, suka sama seseorang itu wajar kok 😊. Yang penting, kalau dia orang yang kamu kenal dari internet lalu minta foto atau ngajak ketemu diam-diam, itu tanda bahaya ya. Dia teman sekolahmu?',
          ),
          const ['Teman sekolah', 'Kenal di internet', 'Rahasia ah'],
        );

      case DialogueTopic.copeIdea:
        return t(
          tr(
            'Itu cara yang bagus buat menenangkan diri. Coba lakukan sebentar ya, nanti cerita lagi sama aku kalau mau.',
          ),
          const ['Oke', 'Aku mau cerita', 'Tebak-tebakan!'],
        );

      case DialogueTopic.wantToTell:
        return t(
          tr(
            'Ceritain aja, {name}. Aku dengerin dari awal sampai akhir, dan aku nggak akan marah. Ini soal apa?',
            {'name': name},
          ),
          const ['Soal sekolah', 'Soal teman', 'Soal game'],
        );

      case DialogueTopic.fine:
        return t(
          tr(
            'Syukurlah! Kalau nanti ada yang mau diceritain, aku di sini. Mau tebak-tebakan dulu?',
          ),
          const ['Tebak-tebakan!', 'Aku mau cerita', 'Udah dulu ya'],
        );

      case DialogueTopic.greeting:
        final String hello;
        if (words.contains('pagi')) {
          hello = tr('Selamat pagi, {name}! ☀️ Semoga harimu menyenangkan.', {
            'name': name,
          });
        } else if (words.contains('malam')) {
          hello = tr('Selamat malam, {name}. 🌙 Belum tidur?', {'name': name});
        } else if (words.contains('assalamualaikum')) {
          hello = tr('Waalaikumsalam, {name}! 😊', {'name': name});
        } else {
          hello = pick([
            tr('Hai, {name}! Senang kamu mampir.', {'name': name}),
            tr('Hai lagi, {name}!', {'name': name}),
          ]);
        }
        return t('$hello Gimana harimu?', const [
          'Lagi seneng',
          'Biasa aja',
          'Lagi nggak enak hati',
        ]);

      case DialogueTopic.yes:
      case DialogueTopic.no:
      case DialogueTopic.unsure:
        return _answerWithoutContext(topic, name);
    }
  }

  static List<String> get _jokes => [
    tr('Tebak-tebakan ya! Ikan apa yang bisa terbang? ... Lele-lawar! 🦇😄'),
    tr('Kenapa matahari tenggelam? ... Karena nggak bisa berenang! ☀️😄'),
    tr('Sayur apa yang paling dingin? ... Kembang kol, soalnya "cold"! 🥦😄'),
    tr('Hewan apa yang paling kuat? ... Kuda, soalnya bisa angkat kaki! 🐴😄'),
  ];

  // ---------------------------------------------------------------------------
  // Jawaban pendek atas topik yang sedang dibahas
  // ---------------------------------------------------------------------------

  DialogueTurn _followUp(
    DialogueTopic previous,
    DialogueTopic? answer,
    String text,
    String name,
    List<GuardianMessage> earlier,
  ) {
    DialogueTurn t(String reply, List<String> chips) =>
        DialogueTurn(reply, chips, topic: previous);

    // Hal yang menyangkut keselamatan: "iya" berarti setuju bercerita.
    const safety = {
      DialogueTopic.alreadySent,
      DialogueTopic.threatened,
      DialogueTopic.strangeChat,
      DialogueTopic.photoRequest,
      DialogueTopic.meetRequest,
      DialogueTopic.addressAsk,
      DialogueTopic.insult,
      DialogueTopic.hurtAtHome,
      DialogueTopic.tellParents,
    };
    if (previous == DialogueTopic.hurtAtHome) {
      return t(
        tr(
          'Kalau sudah sering terjadi, kamu perlu bantuan orang dewasa secepatnya, {name}. Cerita ke guru atau orang dewasa yang kamu percaya, atau minta mereka menelepon SAPA 129. Kamu tidak sendirian.',
          {'name': name},
        ),
        const ['Aku takut', 'Aku mau cerita ke guru', 'Makasih Aura'],
      );
    }
    if (previous == DialogueTopic.insult) {
      final words = text.split(' ').toSet();
      if (words.contains('lama') || words.contains('sering')) {
        return t(
          tr(
            'Kalau sudah lama, itu bukan hal kecil lagi, {name}. Kamu sudah bertahan sendirian cukup lama. Saatnya minta bantuan orang dewasa supaya ini berhenti.',
            {'name': name},
          ),
          const ['Aku takut dimarahi', 'Aku mau cerita ke guru', 'Oke'],
        );
      }
      if (words.contains('baru')) {
        return t(
          tr(
            'Bagus kamu cerita dari awal, {name}. Jangan dibalas, simpan buktinya, dan kalau terulang, ceritakan ke orang dewasa ya.',
            {'name': name},
          ),
          const ['Gimana caranya blokir?', 'Oke', 'Makasih Aura'],
        );
      }
    }
    if (safety.contains(previous)) {
      return switch (answer) {
        DialogueTopic.yes => t(
          tr(
            'Kamu berani banget, {name}. Tunjukkan chat atau ceritakan kejadiannya ke orang tuamu atau guru ya. Aku tetap di sini kalau kamu mau cerita lagi.',
            {'name': name},
          ),
          const [
            'Gimana caranya blokir?',
            'Aku takut dimarahi',
            'Makasih Aura',
          ],
        ),
        DialogueTopic.no => t(
          tr(
            'Nggak apa-apa. Yang penting jangan balas dan jangan kirim apa pun ke orang itu ya. Kalau nanti kamu siap cerita, aku ada di sini.',
          ),
          const ['Gimana caranya blokir?', 'Aku mau cerita', 'Oke'],
        ),
        _ => t(
          tr(
            'Nggak apa-apa kalau masih bingung. Coba ceritakan pelan-pelan, orang itu ngomong apa ke kamu?',
          ),
          const ['Dia minta fotoku', 'Dia ngajak ketemu', 'Dia ngatain aku'],
        ),
      };
    }

    if (previous == DialogueTopic.joke) {
      final told = earlier
          .where(
            (m) =>
                _detect(normalize(m.text), _words(m.text)) ==
                DialogueTopic.joke,
          )
          .length;
      return t(_jokes[told % _jokes.length], const [
        'Lagi dong!',
        'Hahaha',
        'Aku mau cerita',
      ]);
    }

    if (previous == DialogueTopic.tired && answer == DialogueTopic.no) {
      return t(
        tr(
          'Yuk minum air dan makan dulu ya, {name}. Badan yang segar bikin pikiran juga lebih tenang. Nanti cerita lagi sama aku.',
          {'name': name},
        ),
        const ['Oke', 'Capek pikiran', 'Makasih Aura'],
      );
    }

    return switch (answer) {
      DialogueTopic.yes => t(
        tr('Oke, ceritain aja, {name}. Aku dengerin.', {'name': name}),
        const ['Aku mau cerita', 'Ada yang ganggu aku', 'Tebak-tebakan!'],
      ),
      DialogueTopic.no => t(
        tr(
          'Nggak apa-apa. Kalau nanti ada yang mau kamu ceritain, aku tetap di sini ya.',
        ),
        const ['Tebak-tebakan!', 'Aku mau cerita', 'Udah dulu ya'],
      ),
      _ => t(
        tr(
          'Nggak apa-apa kalau belum tahu. Kita pelan-pelan aja. Coba ceritain apa yang terjadi hari ini?',
        ),
        const ['Soal sekolah', 'Soal teman', 'Soal game'],
      ),
    };
  }

  DialogueTurn _answerWithoutContext(
    DialogueTopic answer,
    String name,
  ) => DialogueTurn(
    answer == DialogueTopic.no
        ? tr(
            'Oke, nggak apa-apa. Kalau ada yang mau kamu ceritain, aku di sini ya, {name}.',
            {'name': name},
          )
        : tr('Aku dengerin kok, {name}. Mau cerita soal apa?', {'name': name}),
    const ['Soal sekolah', 'Soal teman', 'Soal game'],
    topic: answer,
  );

  DialogueTurn _fallback(int turn, String name) {
    final lines = [
      tr('Aku dengerin kok. Boleh ceritain lebih detail biar aku ngerti?'),
      tr(
        'Hmm, aku belum terlalu ngerti. Ini soal sekolah, teman, game, atau yang lain?',
      ),
      tr(
        'Maaf ya, aku robot jadi kadang kurang paham. Coba ceritain pakai kata-kata lain?',
      ),
    ];
    return DialogueTurn(lines[turn % lines.length], const [
      'Soal sekolah',
      'Soal teman',
      'Soal game',
    ]);
  }
}
