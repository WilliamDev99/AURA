import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/time_format.dart';
import '../../core/widgets/heat_tier.dart';
import '../models/app_user.dart';
import '../models/legal_article.dart';
import '../models/evidence_item.dart';
import '../models/threat_alert.dart';
import 'chain_of_custody.dart';
import 'legal_mapper.dart';

/// Menyusun berkas bukti siap cetak untuk dibawa ke kepolisian.
///
/// Isinya: identitas pelapor dan anak, kronologi kejadian, daftar bukti dengan
/// nilai hash dan hasil verifikasi rantai, rujukan pasal, serta pernyataan
/// dasar pengambilan bukti.
class DossierBuilder {
  const DossierBuilder({this.legalMapper = const LegalMapper()});

  final LegalMapper legalMapper;

  // Waktu ditulis dengan zona ponsel pembuat berkas (WIB/WITA/WIT), bukan
  // selalu WIB: jam kejadian bisa menjadi bukti.
  static String _full(DateTime time) =>
      formatWithZone(time, 'd MMMM yyyy, HH:mm:ss');
  static String _short(DateTime time) =>
      formatWithZone(time, 'd MMM yyyy HH:mm');

  /// Rentang karakter yang ada di font Poppins: Latin (termasuk huruf
  /// beraksen), tanda baca umum (kutip miring, tanda pisah, elipsis), dan
  /// simbol mata uang.
  static bool _printableRune(int rune) =>
      rune < 0x0250 ||
      (rune >= 0x1E00 && rune <= 0x1EFF) ||
      (rune >= 0x2010 && rune <= 0x2027) ||
      (rune >= 0x2030 && rune <= 0x205E) ||
      (rune >= 0x20A0 && rune <= 0x20C0) ||
      rune == 0x2122;

  /// Teks yang aman dicetak tanpa ada karakter yang hilang.
  ///
  /// Karakter yang tidak ada di font (emoji, aksara non-Latin) ditulis
  /// sebagai kodenya, mis. "[U+1F62D]" untuk 😭. Membuangnya diam-diam akan
  /// membuat kutipan di berkas berbeda dari pesan asli yang disegel hash-nya.
  static String printable(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      // Penyambung emoji dan pemilih varian tidak terlihat; tidak dicetak.
      if (rune == 0x200D || rune == 0xFE0F || rune == 0xFE0E) continue;
      if (_printableRune(rune)) {
        out.writeCharCode(rune);
      } else {
        out.write(
          '[U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}]',
        );
      }
    }
    return out.toString();
  }

  /// Font yang mendukung huruf Indonesia dan tanda baca lengkap. Helvetica
  /// bawaan PDF hanya mengenal huruf Latin dasar.
  static Future<pw.ThemeData> _theme() async {
    Future<pw.Font> load(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));
    final regular = await load('Poppins-Regular.ttf');
    final bold = await load('Poppins-Bold.ttf');
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
  }

  Future<Uint8List> build({
    required AppUser reporter,
    required List<ThreatAlert> alerts,
    required List<EvidenceItem> evidence,
    required ChainVerification verification,
    String? childName,
  }) async {
    final document = pw.Document(
      title: 'Berkas Bukti AURA',
      author: 'AURA Child Protection',
    );

    final ordered = [...evidence]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final categories = {for (final a in alerts) ...a.categories}.toList();
    final articles = legalMapper.articlesFor(categories);
    final generatedAt = DateTime.now();
    final theme = await _theme();

    document.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 46, 42, 46),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 14),
                child: pw.Text(
                  'Berkas Bukti AURA - Hal. ${context.pageNumber}',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 14),
          child: pw.Text(
            'Dokumen dihasilkan otomatis oleh aplikasi AURA pada '
            '${_full(generatedAt)}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _title(generatedAt),
          pw.SizedBox(height: 20),
          _section('I. IDENTITAS PELAPOR DAN KORBAN'),
          _keyValues({
            'Nama pelapor': printable(reporter.name),
            'Kedudukan': 'Orang tua / wali',
            'Nama anak': printable(
              childName ?? alerts.firstOrNull?.childName ?? '-',
            ),
            'Jumlah kejadian': '${alerts.length} peringatan',
            'Periode kejadian': _period(alerts),
          }),
          pw.SizedBox(height: 18),
          _section('II. KRONOLOGI KEJADIAN'),
          ..._chronology(alerts),
          pw.Text(
            'Catatan: karakter yang tidak dapat dicetak, seperti emoji, '
            'ditulis sebagai kode Unicode-nya (mis. [U+1F62D]) supaya isi '
            'kutipan tetap utuh dan dapat dicocokkan dengan bukti aslinya.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 18),
          _section('III. DAFTAR BARANG BUKTI DIGITAL'),
          _evidenceTable(ordered),
          pw.SizedBox(height: 12),
          _verificationBox(verification),
          pw.SizedBox(height: 18),
          _section('IV. RUJUKAN KETENTUAN PERUNDANG-UNDANGAN'),
          if (articles.isEmpty)
            pw.Text(
              'Tidak ada rujukan pasal otomatis untuk kategori kejadian ini.',
              style: const pw.TextStyle(fontSize: 9.5),
            )
          else
            ...articles.map(_articleBlock),
          pw.SizedBox(height: 14),
          _disclaimerBox(),
          pw.SizedBox(height: 18),
          _section('V. PERNYATAAN DASAR PEROLEHAN BUKTI'),
          _consentStatement(ordered),
          pw.SizedBox(height: 26),
          _signature(reporter.name, generatedAt),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _title(DateTime generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BERKAS BUKTI DIGITAL',
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Dugaan Tindak Pidana terhadap Anak',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Disusun oleh AURA Child Protection - '
            '${_full(generatedAt)}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey300),
          ),
        ],
      ),
    );
  }

  pw.Widget _section(String title) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _keyValues(Map<String, String> values) => pw.Column(
    children: values.entries
        .map(
          (entry) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 120,
                  child: pw.Text(
                    entry.key,
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Text(': ', style: const pw.TextStyle(fontSize: 9.5)),
                pw.Expanded(
                  child: pw.Text(
                    entry.value,
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );

  List<pw.Widget> _chronology(List<ThreatAlert> alerts) {
    final sorted = [...alerts]
      ..sort((a, b) => a.detectedAt.compareTo(b.detectedAt));

    return sorted.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final alert = entry.value;
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Text(
                  '$index. ${alert.primaryCategory.labelId}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'Tingkat: ${HeatTier.of(alert.riskLevel).label} '
                  '(${alert.riskLevel.labelId})',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Waktu    : ${_full(alert.detectedAt)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              printable(
                'Platform : ${alert.platform}'
                '${alert.counterpartName == null ? "" : " - lawan bicara: ${alert.counterpartName}"}',
              ),
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              'Sumber   : ${alert.source.labelId}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              printable(alert.summary),
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (alert.excerpt != null) ...[
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(7),
                color: PdfColors.grey100,
                child: pw.Text(
                  printable('Kutipan: "${alert.excerpt}"'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (alert.hasLocation) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                printable(
                  'Lokasi   : ${alert.latitude}, ${alert.longitude}'
                  '${alert.locationLabel == null ? "" : " (${alert.locationLabel})"}',
                ),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  pw.Widget _evidenceTable(List<EvidenceItem> evidence) {
    if (evidence.isEmpty) {
      return pw.Text(
        'Tidak ada bukti tersimpan.',
        style: const pw.TextStyle(fontSize: 9.5),
      );
    }

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellAlignment: pw.Alignment.topLeft,
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FixedColumnWidth(58),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FlexColumnWidth(2.1),
        4: const pw.FlexColumnWidth(1.9),
      },
      headers: const ['No', 'Jenis', 'Waktu', 'Uraian', 'SHA-256 (isi)'],
      data: evidence
          .map(
            (item) => [
              '${item.sequence}',
              item.kind.labelId,
              _short(item.capturedAt),
              printable(item.description),
              item.contentHash,
            ],
          )
          .toList(),
    );
  }

  pw.Widget _verificationBox(ChainVerification verification) {
    final intact = verification.isIntact;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: intact ? PdfColors.green50 : PdfColors.red50,
        border: pw.Border.all(
          color: intact ? PdfColors.green700 : PdfColors.red700,
          width: 0.8,
        ),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            intact
                ? 'HASIL VERIFIKASI: RANTAI BUKTI UTUH'
                : 'HASIL VERIFIKASI: RANTAI BUKTI TERPUTUS',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: intact ? PdfColors.green900 : PdfColors.red900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            printable(verification.reason),
            style: const pw.TextStyle(fontSize: 8.5),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Setiap bukti disegel dengan SHA-256 dan dikaitkan ke bukti '
            'sebelumnya, sehingga perubahan, penghapusan, atau penyisipan '
            'entri dapat dibuktikan secara teknis.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _articleBlock(LegalArticle article) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 9),
    padding: const pw.EdgeInsets.all(9),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${article.article} ${article.law}',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          article.title,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(article.summary, style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 3),
        pw.Text(
          'Ancaman pidana: ${article.penalty}',
          style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
        ),
      ],
    ),
  );

  pw.Widget _disclaimerBox() => pw.Container(
    padding: const pw.EdgeInsets.all(9),
    color: PdfColors.amber50,
    child: pw.Text(
      LegalMapper.disclaimer,
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
    ),
  );

  pw.Widget _consentStatement(List<EvidenceItem> evidence) {
    final notes = evidence
        .map((e) => e.consentNote)
        .whereType<String>()
        .toSet()
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bukti dalam berkas ini diperoleh melalui aplikasi AURA yang '
          'terpasang secara terbuka pada perangkat anak, dengan sepengetahuan '
          'anak dan atas kewenangan orang tua selaku wali. Aplikasi tidak '
          'melakukan perekaman tersembunyi.',
          style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
        ),
        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 7),
          ...notes.map(
            (note) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                printable('- $note'),
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _signature(String name, DateTime at) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            formatLocal(at, 'd MMMM yyyy'),
            style: const pw.TextStyle(fontSize: 9.5),
          ),
          pw.Text('Pelapor,', style: const pw.TextStyle(fontSize: 9.5)),
          pw.SizedBox(height: 52),
          pw.Container(width: 150, height: 0.8, color: PdfColors.grey700),
          pw.SizedBox(height: 3),
          pw.Text(
            printable(name),
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ],
  );

  String _period(List<ThreatAlert> alerts) {
    if (alerts.isEmpty) return '-';
    final sorted = [...alerts]
      ..sort((a, b) => a.detectedAt.compareTo(b.detectedAt));
    return '${formatLocal(sorted.first.detectedAt, 'd MMM yyyy HH:mm')} '
        's.d. ${_short(sorted.last.detectedAt)}';
  }
}
