import '../models/guardian_message.dart';
import '../models/risk.dart';
import 'guardian_dialogue.dart';
import 'threat_analyzer.dart';
import '../../core/l10n/l10n.dart';

/// Jawaban AI Guardian untuk satu giliran percakapan.
class GuardianReply {
  const GuardianReply({
    required this.text,
    required this.quickReplies,
    required this.assessment,
    required this.shouldAlertParent,
  });

  final String text;
  final List<String> quickReplies;
  final ThreatAssessment assessment;
  final bool shouldAlertParent;
}

/// Pendamping percakapan untuk anak.
///
/// Implementasi bawaan berjalan sepenuhnya di perangkat dengan respons
/// terskrip, sehingga aplikasi tetap berguna tanpa koneksi dan tanpa mengirim
/// curhat anak ke mana pun. Untuk percakapan yang lebih luwes, ganti dengan
/// pemanggilan model melalui Cloud Function (lihat `functions/src/guardian.ts`)
/// yang memakai Claude agar kunci API tidak pernah ada di perangkat.
abstract interface class GuardianBrain {
  GuardianReply respond({
    required String childMessage,
    required List<GuardianMessage> history,
    required String childName,
  });

  /// Sapaan pembuka saat anak membuka ruang obrolan.
  GuardianMessage greeting(String childName);
}

class LocalGuardianBrain implements GuardianBrain {
  const LocalGuardianBrain({
    this.analyzer = const ThreatAnalyzer(),
    this.dialogue = const GuardianDialogue(),
  });

  final ThreatAnalyzer analyzer;

  /// Obrolan sehari-hari untuk hal yang bukan bahaya.
  final GuardianDialogue dialogue;

  @override
  GuardianMessage greeting(String childName) => GuardianMessage(
    id: 'greeting',
    author: MessageAuthor.guardian,
    text: tr(
      'Halo, {childName}. Aku Aura. Kalau ada yang bikin kamu bingung, takut, atau nggak enak di hati, cerita aja ke aku. Aku nggak akan marah.',
      {'childName': childName},
    ),
    sentAt: DateTime.now(),
    quickReplies: [
      'Ada yang chat aku terus',
      'Aku dibully di sekolah',
      'Ada yang minta fotoku',
      'Aku lagi sedih',
    ],
  );

  @override
  GuardianReply respond({
    required String childMessage,
    required List<GuardianMessage> history,
    required String childName,
  }) {
    final assessment = analyzer.assess(childMessage);
    final category = assessment.categories.isEmpty
        ? null
        : assessment.categories.first;

    // Kata kasar yang diketik anak sendiri bukan bahaya: Aura tidak memberi
    // tahu orang tua karenanya, sesuai janji "Ceritamu aman".
    final profanityOnly =
        assessment.categories.isNotEmpty &&
        assessment.categories.every((c) => c == ThreatCategory.profanity);

    if (category == null || profanityOnly) {
      final turn = dialogue.reply(
        message: childMessage,
        history: history,
        childName: childName,
      );
      final (text, quickReplies) =
          _afterDanger(turn, childMessage, history, childName) ??
          (profanityOnly && turn.isFallback
              ? _profanityReply
              : (turn.text, turn.quickReplies));
      return GuardianReply(
        text: text,
        quickReplies: quickReplies,
        assessment: assessment,
        shouldAlertParent: false,
      );
    }

    final (text, quickReplies) = switch (category) {
      ThreatCategory.selfHarm => (
        tr(
          'Terima kasih sudah berani cerita, {childName}. Yang kamu rasakan itu berat, dan kamu nggak perlu menanggungnya sendirian. Aku mau kamu ngobrol sama orang dewasa yang kamu percaya sekarang. Kalau kamu mau, aku bisa kasih tahu orang tuamu supaya mereka menemani kamu.',
          {'childName': childName},
        ),
        const [
          'Boleh, kasih tahu mereka',
          'Aku belum siap',
          'Aku mau cerita dulu',
        ],
      ),
      ThreatCategory.sextortion => (
        tr(
          'Ini penting, {childName}: kamu tidak salah, dan ini bukan kesalahan kamu. Jangan kirim apa pun lagi dan jangan hapus chat-nya, karena itu bukti. Orang dewasa perlu tahu supaya bisa menghentikan orang ini.',
          {'childName': childName},
        ),
        const [
          'Aku takut dimarahi',
          'Beri tahu orang tuaku',
          'Dia ancam sebar fotoku',
        ],
      ),
      ThreatCategory.sexualHarassment => (
        tr(
          'Kalau ada yang bilang hal seperti itu tentang tubuhmu dan bikin kamu nggak nyaman, itu bukan salahmu, {childName}. Orang dewasa yang baik tidak bicara begitu ke anak. Kamu boleh tidak membalas.',
          {'childName': childName},
        ),
        const [
          'Dia orang dewasa',
          'Aku mau blokir dia',
          'Beri tahu orang tuaku',
        ],
      ),
      ThreatCategory.gambling => (
        tr(
          'Judi online itu dibuat supaya pemainnya terus kalah dan ketagihan, {childName}. Banyak orang dewasa pun kehilangan semua uangnya. Kamu nggak perlu ikut, dan kamu nggak akan dimarahi kalau cerita.',
          {'childName': childName},
        ),
        const [
          'Temanku yang ngajak',
          'Aku sudah terlanjur main',
          'Beri tahu orang tuaku',
        ],
      ),
      ThreatCategory.grooming => (
        tr(
          'Aku perhatikan orang itu minta kamu merahasiakan sesuatu dari orang tuamu. Orang yang benar-benar baik tidak akan pernah minta begitu. Kamu sudah tepat menceritakannya ke aku.',
        ),
        const [
          'Dia bilang ini rahasia kita',
          'Dia ngajak ketemu',
          'Aku mau blokir dia',
        ],
      ),
      ThreatCategory.cyberbullying => (
        tr(
          'Itu menyakitkan, dan kamu nggak pantas diperlakukan begitu. Apa yang mereka tulis tidak menentukan siapa kamu. Jangan dibalas ya, biar kita simpan buktinya dulu.',
        ),
        const ['Sudah lama begini', 'Aku malu cerita', 'Simpan buktinya'],
      ),
      ThreatCategory.violence => (
        tr(
          'Kalau ada yang mengancam mau menyakiti kamu, itu serius dan harus ditangani orang dewasa sekarang juga. Jangan temui dia, dan tetap di tempat yang ramai.',
        ),
        const [
          'Beri tahu orang tuaku',
          'Dia tahu rumahku',
          'Aku sedang sendirian',
        ],
      ),
      ThreatCategory.meetup => (
        tr(
          'Ajakan ketemu diam-diam tanpa sepengetahuan orang tua itu tanda bahaya, {childName}. Jangan pergi dulu. Kita beri tahu orang tuamu ya.',
          {'childName': childName},
        ),
        const ['Dia maksa', 'Aku sudah janji ketemu', 'Beri tahu orang tuaku'],
      ),
      ThreatCategory.financial => (
        tr(
          'Jangan kirim uang, pulsa, atau kode apa pun. Kode OTP itu seperti kunci rumah: siapa pun yang memintanya sedang mencoba masuk.',
        ),
        const [
          'Dia janji hadiah',
          'Aku sudah terlanjur kirim',
          'Oke, aku stop',
        ],
      ),
      ThreatCategory.personalData => (
        tr(
          'Alamat, nama sekolah, dan foto kartu identitas sebaiknya tidak pernah kamu kirim ke orang yang kamu kenal dari internet.',
        ),
        const ['Aku sudah terlanjur kasih', 'Oke aku hapus', 'Dia maksa terus'],
      ),
      ThreatCategory.substance => (
        tr(
          'Apa pun yang ditawarkan supaya kamu merasa "enak" dari orang seperti itu bisa membahayakan tubuh kamu. Tolak dan ceritakan ke orang dewasa.',
        ),
        const ['Teman yang nawarin', 'Aku sudah coba', 'Aku tolak'],
      ),
      // Sudah ditangani di atas oleh obrolan sehari-hari.
      ThreatCategory.profanity => _profanityReply,
    };

    return GuardianReply(
      text: text,
      quickReplies: quickReplies,
      assessment: assessment,
      shouldAlertParent: assessment.level.notifiesParent,
    );
  }

  // Getter: jawabannya mengikuti bahasa yang sedang dipakai. Nilai tombol
  // balasan tetap bahasa Indonesia supaya dikenali Aura.
  static (String, List<String>) get _profanityReply => (
    tr(
      'Kedengarannya kamu lagi kesal banget. Wajar kok marah. Mau cerita apa yang bikin kamu sekesal ini?',
    ),
    ['Aku dimarahi', 'Teman-temanku nyebelin', 'Aku capek aja'],
  );

  /// Jawaban singkat anak tepat setelah ia menceritakan hal berbahaya,
  /// misalnya "boleh, kasih tahu mereka" atau "aku belum siap".
  (String, List<String>)? _afterDanger(
    DialogueTurn turn,
    String message,
    List<GuardianMessage> history,
    String childName,
  ) {
    final understood =
        !turn.isFallback &&
        turn.topic != DialogueTopic.yes &&
        turn.topic != DialogueTopic.no &&
        turn.topic != DialogueTopic.unsure;
    if (understood) return null;

    final earlier = history.where((m) => m.isChild).toList();
    if (earlier.isNotEmpty && earlier.last.text.trim() == message.trim()) {
      earlier.removeLast();
    }
    if (earlier.isEmpty) return null;

    final previous = analyzer.assess(earlier.last.text);
    final danger =
        previous.level.notifiesParent &&
        !previous.categories.every((c) => c == ThreatCategory.profanity);
    if (!danger) return null;

    final parentsKnow = history.any((m) => !m.isChild && m.escalated);
    final text = GuardianDialogue.normalize(message);

    if (RegExp(r'\b(belum siap|takut|malu|jangan)\b').hasMatch(text)) {
      return (
        tr(
          'Nggak apa-apa merasa begitu, {childName}. Kamu nggak salah, dan orang yang sayang sama kamu akan lebih ingin membantu daripada marah. Aku tetap di sini kalau kamu siap.',
          {'childName': childName},
        ),
        const ['Aku mau cerita dulu', 'Aku mau cerita ke guru', 'Makasih Aura'],
      );
    }
    if (RegExp(
      r'\b(boleh|iya|oke|kasih tahu|beri tahu|bilang)\b',
    ).hasMatch(text)) {
      return (
        parentsKnow
            ? tr(
                'Terima kasih sudah berani, {childName}. Orang tuamu sudah diberi tahu lewat AURA, jadi mereka bisa segera membantumu. Sambil menunggu, tetap di tempat yang aman ya.',
                {'childName': childName},
              )
            : tr(
                'Terima kasih sudah berani, {childName}. Ceritakan ke orang tuamu atau orang dewasa yang kamu percaya sekarang ya. Kalau kamu dalam bahaya, tekan tombol merah di beranda.',
                {'childName': childName},
              ),
        const ['Aku mau cerita dulu', 'Aku takut dimarahi', 'Makasih Aura'],
      );
    }
    return (
      tr(
        'Aku masih di sini, {childName}. Ceritain pelan-pelan ya, apa yang terjadi?',
        {'childName': childName},
      ),
      const ['Aku takut dimarahi', 'Gimana caranya blokir?', 'Makasih Aura'],
    );
  }
}
