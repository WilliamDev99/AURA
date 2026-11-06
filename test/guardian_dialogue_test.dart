import 'package:aura/domain/models/guardian_message.dart';
import 'package:aura/domain/services/guardian_brain.dart';
import 'package:aura/domain/services/guardian_dialogue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Obrolan Aura tanpa AI: harus nyambung dengan apa yang diceritakan anak.
void main() {
  const dialogue = GuardianDialogue();
  const brain = LocalGuardianBrain();
  final now = DateTime.now();

  GuardianMessage child(String text) => GuardianMessage(
    id: text,
    author: MessageAuthor.child,
    text: text,
    sentAt: now,
  );

  GuardianMessage aura(String text, {bool escalated = false}) =>
      GuardianMessage(
        id: 'a-$text',
        author: MessageAuthor.guardian,
        text: text,
        sentAt: now,
        escalated: escalated,
      );

  /// Menjalankan percakapan dan mengembalikan balasan terakhir.
  GuardianReply talk(List<String> messages) {
    final history = <GuardianMessage>[];
    late GuardianReply reply;
    for (final m in messages) {
      reply = brain.respond(
        childMessage: m,
        history: history,
        childName: 'Ayu',
      );
      history
        ..add(child(m))
        ..add(aura(reply.text, escalated: reply.shouldAlertParent));
    }
    return reply;
  }

  group('mengenali topik', () {
    for (final (message, topic) in [
      ('halo aura', DialogueTopic.greeting),
      ('selamat pagi', DialogueTopic.greeting),
      ('kamu siapa sih?', DialogueTopic.aboutAura),
      ('apa kabar?', DialogueTopic.howAreYou),
      ('aku kalah terus main ml', DialogueTopic.game),
      ('akunku dibajak', DialogueTopic.game),
      ('aku sedih banget hari ini', DialogueTopic.sad),
      ('aku takut tidur sendirian, mimpi buruk', DialogueTopic.fear),
      ('nilaiku jelek', DialogueTopic.school),
      ('tugasnya banyak banget', DialogueTopic.school),
      ('aku dijauhi teman sekelas', DialogueTopic.sad),
      ('aku berantem sama sahabatku', DialogueTopic.friends),
      ('aku dimarahi mama', DialogueTopic.family),
      ('gabut nih', DialogueTopic.bored),
      ('tebak tebakan dong', DialogueTopic.joke),
      ('makasih ya aura', DialogueTopic.thanks),
      ('aku udah terlanjur kirim fotonya', DialogueTopic.alreadySent),
      ('dia ngajak ketemuan', DialogueTopic.meetRequest),
      ('gimana caranya blokir orang?', DialogueTopic.blockHow),
      ('aku takut dimarahi kalau cerita', DialogueTopic.tellParents),
    ]) {
      test('"$message" -> ${topic.name}', () {
        final turn = dialogue.reply(
          message: message,
          history: const [],
          childName: 'Ayu',
        );
        expect(turn.topic, topic);
      });
    }
  });

  test('menyebut nama anak', () {
    expect(talk(['halo']).text, contains('Ayu'));
  });

  test('"iya" dipahami sesuai topik yang sedang dibahas', () {
    final reply = talk(['ada orang asing chat aku terus', 'iya']);
    expect(reply.text, contains('berani'));
  });

  test('"gak tahu" tidak dianggap "gak"', () {
    final turn = dialogue.reply(
      message: 'gak tau',
      history: const [],
      childName: 'Ayu',
    );
    expect(turn.topic, DialogueTopic.unsure);
  });

  test('topik yang sama dibahas lagi tidak mengulang kalimat yang sama', () {
    final first = talk(['aku sedih']).text;
    final second = talk(['aku sedih', 'aku masih sedih']).text;
    expect(second, isNot(first));
  });

  test('tebak-tebakan berikutnya berbeda', () {
    final first = talk(['tebak tebakan dong']).text;
    final second = talk(['tebak tebakan dong', 'lagi dong!']).text;
    expect(second, isNot(first));
  });

  test('pesan yang tidak dimengerti dijawab bergantian, tidak monoton', () {
    final a = talk(['qwerty zxcv']).text;
    final b = talk(['qwerty zxcv', 'asdf ghjk']).text;
    expect(b, isNot(a));
  });

  test('disakiti di rumah: arahkan ke SAPA 129', () {
    expect(talk(['aku dipukul di rumah']).text, contains('SAPA 129'));
  });

  test('kata kasar anak sendiri tidak memberi tahu orang tua', () {
    final reply = talk(['anjir seru banget gamenya']);
    expect(reply.shouldAlertParent, isFalse);
    // Membahas game-nya, bukan menegur.
    expect(reply.text, isNot(contains('kesal')));
  });

  test('bahaya sungguhan tetap memberi tahu orang tua', () {
    expect(talk(['aku pengen mati aja']).shouldAlertParent, isTrue);
  });

  test('"boleh, kasih tahu mereka" setelah cerita bahaya dijawab sesuai', () {
    final reply = talk(['aku pengen mati aja', 'Boleh, kasih tahu mereka']);
    expect(reply.text, contains('Orang tuamu sudah diberi tahu'));
  });

  test('"aku belum siap" setelah cerita bahaya ditenangkan', () {
    final reply = talk(['aku pengen mati aja', 'Aku belum siap']);
    expect(reply.text, contains('nggak salah'));
  });

  test('setiap pilihan cepat dipahami, sampai tiga langkah', () {
    const seeds = [
      'Aku ada masalah di game',
      'Ada yang chat aneh',
      'Aku merasa takut',
      'halo',
      'kamu siapa',
      'apa kabar',
      'aku sedih',
      'aku kesel',
      'aku bosen',
      'tebak tebakan',
      'aku dimarahi mama',
      'aku dipukul',
      'aku berantem sama teman',
      'aku naksir seseorang',
      'aku sakit',
      'aku capek',
      'aku senang',
      'tugasku banyak',
      'makasih',
      'aku mau cerita',
    ];
    final failures = <String>[];

    void explore(List<GuardianMessage> history, String message, int depth) {
      final turn = dialogue.reply(
        message: message,
        history: history,
        childName: 'Ayu',
      );
      if (turn.isFallback) {
        final path = [
          ...history.where((m) => m.isChild).map((m) => m.text),
          message,
        ];
        failures.add(path.join(' -> '));
        return;
      }
      if (depth == 3) return;
      final next = [...history, child(message), aura(turn.text)];
      for (final chip in turn.quickReplies) {
        explore(next, chip, depth + 1);
      }
    }

    for (final seed in seeds) {
      explore(const [], seed, 1);
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
