import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/aura_colors.dart';
import '../../domain/models/risk.dart';
import '../../domain/services/threat_analyzer.dart';
import '../../core/l10n/l10n.dart';

/// Menampilkan peringatan dini kepada anak saat ancaman serius terdeteksi.
///
/// Nadanya sengaja menenangkan, bukan menakuti: anak yang panik cenderung
/// menyembunyikan masalah, sedangkan anak yang merasa aman akan bercerita.
Future<void> showInterventionSheet(
  BuildContext context,
  ThreatAssessment assessment,
) {
  HapticFeedback.heavyImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _InterventionSheet(assessment: assessment),
  );
}

class _InterventionSheet extends StatelessWidget {
  const _InterventionSheet({required this.assessment});

  final ThreatAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final category = assessment.categories.isEmpty
        ? ThreatCategory.profanity
        : assessment.categories.first;
    final level = assessment.level;

    return Container(
      decoration: BoxDecoration(
        color: AuraColors.midnight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: level.color.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraColors.glassStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: level.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(category.icon, color: level.color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Peringatan Dini'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        category.label,
                        style: TextStyle(fontSize: 12.5, color: level.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AuraColors.glassStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline(category),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _advice(category),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: AuraColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._steps(category).map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                      color: AuraColors.safe,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(fontSize: 13.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (level.notifiesParent)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AuraColors.medium.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AuraColors.medium,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          'Orang tuamu sudah diberi tahu supaya bisa membantu. Kamu tidak '
                          'sedang dalam masalah.',
                        ),
                        style: TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: level.color),
              child: Text(tr('Saya mengerti')),
            ),
          ],
        ),
      ),
    );
  }

  String _headline(ThreatCategory category) => switch (category) {
    ThreatCategory.grooming => tr(
      'Orang ini memakai cara yang sering dipakai pelaku untuk '
      'mendekati anak.',
    ),
    ThreatCategory.sextortion => tr(
      'Jangan kirim foto apa pun. Ini bukan salahmu, dan kamu tidak '
      'sendirian.',
    ),
    ThreatCategory.sexualHarassment => tr(
      'Komentar soal tubuhmu yang bikin nggak nyaman itu salah mereka, '
      'bukan kamu.',
    ),
    ThreatCategory.gambling => tr(
      'Judi online dibuat supaya pemainnya kalah. Kamu tidak perlu ikut.',
    ),
    ThreatCategory.cyberbullying => tr(
      'Apa yang mereka katakan tidak benar dan tidak menggambarkan dirimu.',
    ),
    ThreatCategory.violence => tr(
      'Ada ancaman kekerasan di sini. Ini harus ditangani orang dewasa.',
    ),
    ThreatCategory.selfHarm => tr(
      'Yang kamu rasakan berat sekali, dan kamu berhak dibantu.',
    ),
    ThreatCategory.meetup => tr(
      'Ajakan ketemu diam-diam adalah tanda bahaya yang serius.',
    ),
    ThreatCategory.financial => tr(
      'Jangan kirim uang, pulsa, atau kode apa pun ke orang ini.',
    ),
    ThreatCategory.personalData => tr(
      'Orang ini sedang mengumpulkan data pribadimu.',
    ),
    ThreatCategory.substance => tr(
      'Yang ditawarkan ke kamu bisa membahayakan.',
    ),
    ThreatCategory.profanity => tr(
      'Percakapan ini mulai kasar. Kamu boleh berhenti kapan saja.',
    ),
  };

  String _advice(ThreatCategory category) => switch (category) {
    ThreatCategory.grooming => tr(
      'Orang dewasa yang baik tidak akan pernah minta anak menyimpan '
      'rahasia dari orang tuanya. Kamu sudah benar dengan tidak '
      'langsung menuruti.',
    ),
    ThreatCategory.sextortion => tr(
      'Pelaku biasanya mengancam agar kamu diam. Begitu orang dewasa '
      'tahu, ancamannya kehilangan kekuatan.',
    ),
    ThreatCategory.sexualHarassment => tr(
      'Pelaku sering mulai dengan pujian soal tubuh untuk melihat '
      'apakah kamu akan diam. Bercerita ke orang dewasa '
      'menghentikannya.',
    ),
    ThreatCategory.gambling => tr(
      'Situs judi sering menyamar jadi game atau hadiah. Kalau sudah '
      'terlanjur main, ceritakan sekarang sebelum utangnya bertambah.',
    ),
    ThreatCategory.cyberbullying => tr(
      'Membalas biasanya membuat mereka makin menjadi. Menyimpan bukti '
      'jauh lebih berguna.',
    ),
    ThreatCategory.violence => tr(
      'Jangan menemui orang itu sendirian, dan tetap berada di tempat '
      'ramai.',
    ),
    ThreatCategory.selfHarm => tr(
      'Rasa ini bisa berubah, dan ada orang yang siap menemanimu '
      'melewatinya.',
    ),
    ThreatCategory.meetup => tr(
      'Kalau memang orangnya baik, dia tidak akan keberatan orang '
      'tuamu tahu.',
    ),
    ThreatCategory.financial => tr(
      'Kode OTP itu seperti kunci rumah. Siapa pun yang memintanya '
      'sedang mencoba masuk.',
    ),
    ThreatCategory.personalData => tr(
      'Alamat, nama sekolah, dan foto kartu identitas sebaiknya tidak '
      'pernah dikirim ke orang yang kamu kenal dari internet.',
    ),
    ThreatCategory.substance => tr(
      'Tidak ada yang namanya "coba sekali saja" untuk hal seperti ini.',
    ),
    ThreatCategory.profanity => tr(
      'Kamu boleh keluar dari obrolan yang membuatmu tidak nyaman.',
    ),
  };

  List<String> _steps(ThreatCategory category) => switch (category) {
    ThreatCategory.selfHarm => [
      tr('Cari orang dewasa yang kamu percaya sekarang.'),
      tr('Kamu bisa menelepon 119 ekstensi 8 untuk bicara dengan konselor.'),
      tr('Tetap bersama orang lain, jangan sendirian dulu.'),
    ],
    ThreatCategory.sextortion => [
      tr('Berhenti membalas pesannya.'),
      tr('Jangan hapus chat-nya, itu bukti penting.'),
      tr('Beri tahu orang tua atau guru hari ini juga.'),
    ],
    ThreatCategory.sexualHarassment => [
      tr('Tidak usah membalas pesannya.'),
      tr('Jangan hapus chat-nya, itu bukti.'),
      tr('Blokir dan ceritakan ke orang tua atau guru.'),
    ],
    _ => [
      tr('Jangan balas dulu pesannya.'),
      tr('Jangan hapus percakapannya, itu bukti.'),
      tr('Blokir kalau kamu merasa perlu.'),
      tr('Ceritakan ke orang dewasa yang kamu percaya.'),
    ],
  };
}
