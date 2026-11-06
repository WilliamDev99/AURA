import io
def patch_file(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:70], s.count(old))
        s = s.replace(old, new, 1)
    io.open(path, 'w', encoding='utf-8').write(s)

patch_file('lib/state/app_state.dart', [
    ("""  /// Matikan dengan `--dart-define=AURA_AI_CHAT=false`.
  ///
  /// Batas umur ditentukan server sesuai penyedia AI (lihat
  /// `supabase/functions/aura-chat`): Qwen di Cloudflare untuk semua umur,
  /// ChatGPT hanya 13+. Bila server menolak, Aura lokal yang menjawab.""",
     """  /// Umur minimum obrolan dengan ChatGPT. Di bawah ini Aura lokal yang
  /// menjawab: OpenAI mensyaratkan Zero Data Retention untuk anak di bawah
  /// 13 tahun. Server memeriksa batas yang sama.
  static const aiChatMinAge = 13;

  /// Matikan dengan `--dart-define=AURA_AI_CHAT=false`."""),
    ("""  /// Apakah obrolan anak ini dibalas AI.
  bool get usesAiChat => aiChatEnabled && (_user?.isChild ?? false);""",
     """  /// Apakah obrolan anak ini dibalas ChatGPT.
  bool get usesAiChat =>
      aiChatEnabled &&
      (_user?.isChild ?? false) &&
      (_user?.age ?? 0) >= aiChatMinAge;"""),
])

patch_file('lib/features/child/guardian_chat_page.dart', [
    ("""                  ? 'Aura dibantu AI. Jangan bagikan data pribadi. Orang '
                        'tuamu hanya diberi tahu kalau kamu dalam bahaya.'""",
     """                  ? 'Aura dibantu AI (ChatGPT). Jangan bagikan data '
                        'pribadi. Orang tuamu hanya diberi tahu kalau kamu '
                        'dalam bahaya.'"""),
])

# Layar persetujuan: penjelasan AI hanya untuk anak 13+.
p = 'lib/features/child/child_consent_page.dart'
s = io.open(p, encoding='utf-8').read()
old_item = """    (
      Icons.smart_toy_rounded,
      'Membalas obrolanmu dengan Aura memakai AI',
      'Pesan yang kamu tulis ke Aura dikirim ke layanan AI supaya Aura bisa '
          'menjawab, dan tidak dipakai untuk melatih AI. Pesan yang berbahaya '
          'tidak dikirim ke AI; orang tuamu yang diberi tahu.',
    ),
"""
assert s.count(old_item) == 1
s = s.replace(old_item, "", 1)
anchor = "  static const _doesNot = ["
assert s.count(anchor) == 1
s = s.replace(anchor, """  /// Hanya ditampilkan ke anak 13 tahun ke atas, yang obrolannya dibalas
  /// ChatGPT. Anak yang lebih muda memakai Aura lokal di ponsel.
  static const _aiItem = (
    Icons.smart_toy_rounded,
    'Membalas obrolanmu dengan Aura memakai ChatGPT',
    'Pesan yang kamu tulis ke Aura dikirim ke ChatGPT (OpenAI) supaya Aura '
        'bisa menjawab. Pesan yang berbahaya tidak dikirim ke sana; orang '
        'tuamu yang diberi tahu.',
  );

""" + anchor, 1)
old_use = "                          items: _does,"
assert s.count(old_use) == 1
s = s.replace(old_use, """                          items: [
                            ..._does,
                            if (context.watch<AppState>().usesAiChat) _aiItem,
                          ],""", 1)
io.open(p, 'w', encoding='utf-8').write(s)

patch_file('test/ai_chat_test.dart', [
    ("""  test('anak 10 tahun juga dibalas AI (batas umur ditentukan server)', () async {
    final repo = _FakeChatGpt();
    final state = await childAged(10, repo);

    final reply = await state.sendToGuardian('aku kalah terus main ml');

    expect(state.usesAiChat, isTrue);
    expect(repo.sent, ['aku kalah terus main ml']);
    expect(reply.text, 'Balasan dari ChatGPT');
  });""",
     """  test('anak 10 tahun memakai Aura lokal, tidak dikirim ke ChatGPT', () async {
    final repo = _FakeChatGpt();
    final state = await childAged(10, repo);

    final reply = await state.sendToGuardian('aku kalah terus main ml');

    expect(state.usesAiChat, isFalse);
    expect(repo.sent, isEmpty);
    expect(reply.text, contains('Kalah terus'));
  });"""),
    ("""  test('server menolak (mis. ChatGPT untuk anak di bawah 13): Aura lokal', () async {
    final repo = _FakeChatGpt(available: false);
    final state = await childAged(10, repo);""",
     """  test('ChatGPT menolak atau gagal: Aura lokal yang menjawab', () async {
    final repo = _FakeChatGpt(available: false);
    final state = await childAged(14, repo);"""),
])
print('ok')
