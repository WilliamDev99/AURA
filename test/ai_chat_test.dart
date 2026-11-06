import 'package:aura/data/demo_repository.dart';
import 'package:aura/domain/models/app_user.dart';
import 'package:aura/domain/models/guardian_message.dart';
import 'package:aura/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ChatGPT tiruan: tidak memanggil OpenAI, mencatat apa yang dikirim.
class _FakeChatGpt extends DemoRepository {
  _FakeChatGpt({this.available = true});

  final bool available;
  final sent = <String>[];

  @override
  Future<(String, List<String>)?> aiChat({
    required String message,
    required List<GuardianMessage> history,
  }) async {
    sent.add(message);
    return available
        ? ('Balasan dari ChatGPT', const ['Pilihan A', 'Pilihan B'])
        : null;
  }
}

/// Obrolan Aura dengan ChatGPT: hanya untuk anak 13+, dan pesan berbahaya
/// tidak pernah dikirim ke luar ponsel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> childAged(int age, _FakeChatGpt repo) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(repository: repo, aiChat: true);
    addTearDown(state.dispose);
    await state.signIn(name: 'Rani', role: UserRole.child, age: age);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return state;
  }

  test('anak 15 tahun dibalas ChatGPT', () async {
    final repo = _FakeChatGpt();
    final state = await childAged(15, repo);

    final reply = await state.sendToGuardian('aku bingung milih ekskul');

    expect(state.usesAiChat, isTrue);
    expect(repo.sent, ['aku bingung milih ekskul']);
    expect(reply.text, 'Balasan dari ChatGPT');
    expect(reply.quickReplies, ['Pilihan A', 'Pilihan B']);
  });

  test('anak 10 tahun juga dibalas AI (Gemma 4, semua umur)', () async {
    final repo = _FakeChatGpt();
    final state = await childAged(10, repo);

    final reply = await state.sendToGuardian('aku kalah terus main ml');

    expect(state.usesAiChat, isTrue);
    expect(repo.sent, ['aku kalah terus main ml']);
    expect(reply.text, 'Balasan dari ChatGPT');
  });

  test('ChatGPT menolak atau gagal: Aura lokal yang menjawab', () async {
    final repo = _FakeChatGpt(available: false);
    final state = await childAged(14, repo);

    final reply = await state.sendToGuardian('aku kalah terus main ml');

    expect(reply.text, contains('Kalah terus'));
  });

  test(
    'pesan berbahaya tidak dikirim ke ChatGPT, orang tua diberi tahu',
    () async {
      final repo = _FakeChatGpt();
      final state = await childAged(15, repo);

      final reply = await state.sendToGuardian('aku pengen mati aja');

      expect(repo.sent, isEmpty, reason: 'tidak boleh keluar dari ponsel');
      expect(reply.shouldAlertParent, isTrue);
      expect(reply.text, isNot('Balasan dari ChatGPT'));
    },
  );

  test('ChatGPT tidak tersedia: Aura lokal yang menjawab', () async {
    final repo = _FakeChatGpt(available: false);
    final state = await childAged(15, repo);

    final reply = await state.sendToGuardian('halo');

    expect(repo.sent, ['halo']);
    expect(reply.text, contains('Rani'));
  });

  test('bawaan: obrolan AI menyala untuk semua anak', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeChatGpt();
    final state = AppState(repository: repo);
    addTearDown(state.dispose);
    await state.signIn(name: 'Rani', role: UserRole.child, age: 9);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await state.sendToGuardian('halo');

    expect(AppState.aiChatEnabled, isTrue);
    expect(state.usesAiChat, isTrue);
    expect(repo.sent, ['halo']);
  });
}
