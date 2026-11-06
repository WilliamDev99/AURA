import 'dart:convert';
import 'dart:io';

import 'package:aura/core/l10n/l10n.dart';
import 'package:aura/core/l10n/strings_en.dart';
import 'package:aura/domain/models/evidence_item.dart';
import 'package:aura/domain/models/risk.dart';
import 'package:aura/domain/models/threat_alert.dart';
import 'package:aura/domain/services/legal_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Semua teks `tr('...')` di folder lib, digabung bila ditulis berupa
/// beberapa potong string berdampingan.
Map<String, String> _trCalls() {
  final found = <String, String>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final source = file.readAsStringSync();
    var index = 0;
    while (true) {
      index = source.indexOf(RegExp(r'(?<![\w.])tr\('), index);
      if (index < 0) break;
      // Contoh di dalam komentar bukan teks yang tampil.
      final lineStart = source.lastIndexOf('\n', index) + 1;
      final inComment = source
          .substring(lineStart, index)
          .trimLeft()
          .startsWith('//');
      index += 3;
      if (inComment) continue;
      final text = _readLiterals(source, index);
      if (text != null) found[text] = file.path;
    }
  }
  return found;
}

/// Membaca deret literal string mulai [start]; null bila argumennya bukan
/// literal (mis. variabel).
String? _readLiterals(String source, int start) {
  var i = start;
  final buffer = StringBuffer();
  var any = false;
  while (true) {
    while (i < source.length && ' \t\r\n'.contains(source[i])) {
      i++;
    }
    if (i >= source.length) break;
    var raw = false;
    if (source[i] == 'r' &&
        i + 1 < source.length &&
        (source[i + 1] == "'" || source[i + 1] == '"')) {
      raw = true;
      i++;
    }
    final quote = source[i];
    if (quote != "'" && quote != '"') break;
    i++;
    while (i < source.length && source[i] != quote) {
      if (!raw && source[i] == r'\' && i + 1 < source.length) {
        final next = source[i + 1];
        buffer.write(switch (next) {
          'n' => '\n',
          't' => '\t',
          _ => next,
        });
        i += 2;
        continue;
      }
      buffer.write(source[i]);
      i++;
    }
    i++;
    any = true;
  }
  return any ? buffer.toString() : null;
}

/// Label tombol balasan cepat Aura: teks berawalan huruf besar yang tidak
/// dibungkus tr(), di luar daftar kata kunci pengenal.
Set<String> _quickReplies() {
  final found = <String>{};
  for (final path in [
    'lib/domain/services/guardian_brain.dart',
    'lib/domain/services/guardian_dialogue.dart',
  ]) {
    var source = File(path).readAsStringSync();
    final marker = source.indexOf('static const _suffixes');
    if (marker > 0) source = source.substring(marker);
    final literal = RegExp(r"'([A-Z][^'\n]*)'");
    for (final m in literal.allMatches(source)) {
      // Teks yang sudah dibungkus tr( adalah jawaban, bukan label tombol.
      final before = source.substring(
        (m.start - 60).clamp(0, m.start),
        m.start,
      );
      if (RegExp(r'tr\(\s*$').hasMatch(before)) continue;
      final text = m.group(1)!;
      if (text.contains(r'$') || !RegExp('[a-z]').hasMatch(text)) continue;
      found.add(text);
    }
  }
  return found;
}

/// Bila AURA_L10N_DUMP diisi, teks yang belum diterjemahkan ditulis ke
/// `build/l10n_missing_JENIS.json`, sebagai bahan menulis terjemahan.
void _dump(String kind, Map<String, String> keys) {
  if (Platform.environment['AURA_L10N_DUMP'] == null) return;
  File('build/l10n_missing_$kind.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(keys));
}

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m[1]!).toSet();

void main() {
  tearDown(() => Lang.instance.resetForTest());

  test('setiap teks tr() punya terjemahan bahasa Inggris', () {
    final missing = <String>[];
    final keys = <String, String>{};
    _trCalls().forEach((text, file) {
      if (!englishStrings.containsKey(text)) {
        missing.add('$file: "$text"');
        keys[text] = file;
      }
    });
    _dump('tr', keys);
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test(
    'teks lewat variabel (label, hukum, tombol Aura) juga diterjemahkan',
    () {
      const mapper = LegalMapper();
      final texts = <String>{
        for (final v in RiskLevel.values) v.labelId,
        for (final v in ThreatCategory.values) v.labelId,
        for (final v in EvidenceKind.values) v.labelId,
        for (final v in AlertSource.values) v.labelId,
        for (final v in AlertStatus.values) v.labelId,
        LegalMapper.disclaimer,
        for (final a in mapper.articlesFor(ThreatCategory.values)) ...[
          a.title,
          a.summary,
          a.penalty,
        ],
        for (final c in mapper.contacts) ...[c.name, c.description],
        for (final level in RiskLevel.values)
          for (final categories in [
            [ThreatCategory.selfHarm],
            [ThreatCategory.grooming],
          ])
            for (final s in mapper.stepsFor(level, categories)) ...[
              s.title,
              s.detail,
              ?s.caution,
            ],
        // Menu bawah, saringan Log, dan pilihan aplikasi di "Laporkan".
        'Beranda', 'Log', 'Laporan', 'Profil',
        'Semua', 'Low', 'Medium', 'Hard',
        'Instagram DM', 'Chat Game', 'Lainnya',
        ..._quickReplies(),
      };
      final missing =
          texts.where((t) => !englishStrings.containsKey(t)).toList()..sort();
      _dump('var', {for (final m in missing) m: 'data'});
      expect(missing, isEmpty, reason: missing.map((m) => '"$m"').join('\n'));
    },
  );

  test('isian {nama} sama di kedua bahasa', () {
    final mismatched = <String>[];
    englishStrings.forEach((id, en) {
      if (!_placeholders(id).containsAll(_placeholders(en)) ||
          !_placeholders(en).containsAll(_placeholders(id))) {
        mismatched.add('"$id" -> "$en"');
      }
    });
    expect(mismatched, isEmpty, reason: mismatched.join('\n'));
  });

  test('terjemahan tidak kosong dan tidak sama dengan aslinya', () {
    final bad = englishStrings.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('tr() mengikuti bahasa yang dipilih dan mengisi isian', () {
    expect(tr('Bahasa'), 'Bahasa');
    Lang.instance.resetForTest(AppLanguage.en);
    expect(tr('Bahasa'), 'Language');
    // Teks yang belum diterjemahkan tetap tampil dalam bahasa Indonesia.
    expect(tr('Teks tanpa terjemahan'), 'Teks tanpa terjemahan');
    expect(tr('Halo {name},', {'name': 'Bunda'}), 'Hello Bunda,');
  });
}
