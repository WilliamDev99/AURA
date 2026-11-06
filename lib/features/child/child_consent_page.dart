import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/aura_widgets.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// Layar persetujuan anak.
///
/// Ditulis dengan bahasa yang bisa dipahami anak, menjelaskan apa yang dilihat
/// aplikasi dan apa yang tidak. Persetujuan ini juga menjadi dasar sah
/// pengambilan bukti saat berkas dibawa ke penyidik.
class ChildConsentPage extends StatefulWidget {
  const ChildConsentPage({super.key});

  @override
  State<ChildConsentPage> createState() => _ChildConsentPageState();
}

class _ChildConsentPageState extends State<ChildConsentPage> {
  bool _understood = false;

  // Getter, bukan konstanta: teksnya mengikuti bahasa yang sedang dipakai.
  static List<(IconData, String, String)> get _does => [
    (
      Icons.search_rounded,
      tr('Memeriksa tanda bahaya di pesan yang masuk'),
      tr(
        'AURA membaca notifikasi pesan dari WhatsApp, Instagram, TikTok, '
        'Telegram, SMS, chat game Roblox, dan aplikasi chat lain, lalu '
        'mencari tanda bahaya seperti ancaman, ajakan bertemu diam-diam, '
        'atau permintaan foto. Pemeriksaannya terjadi di ponselmu '
        'sendiri; obrolan biasa tidak dikirim ke siapa pun.',
      ),
    ),
    (
      Icons.notifications_active_rounded,
      tr('Memberi tahu orang tuamu kalau ada bahaya'),
      tr(
        'Yang dikirim adalah jenis bahayanya dan potongan kecil pesan '
        'pemicunya, bukan seluruh isi chat kamu.',
      ),
    ),
    (
      Icons.emergency_share_rounded,
      tr('Mengirim lokasimu kalau kamu menekan tombol darurat'),
      tr(
        'Setiap AURA dibuka, kamu diminta menyalakan GPS supaya lokasimu '
        'siap kalau darurat. Lokasi tetap hanya dikirim saat kamu '
        'sendiri yang menekan tombol itu.',
      ),
    ),
    (
      Icons.call_rounded,
      tr('Menelepon orang tuamu kalau kamu menekan tombol darurat'),
      tr(
        'Supaya orang tuamu bisa langsung bicara denganmu. Tetap jalan '
        'walau internet sedang mati.',
      ),
    ),
  ];

  /// Ditampilkan bila obrolan dengan Aura dibalas AI.
  static (IconData, String, String) get _aiItem => (
    Icons.smart_toy_rounded,
    tr('Membalas obrolanmu dengan Aura memakai AI'),
    tr(
      'Pesan yang kamu tulis ke Aura dikirim ke layanan AI supaya Aura '
      'bisa menjawab, dan tidak dipakai untuk melatih AI. Pesan yang '
      'berbahaya tidak dikirim ke sana; orang tuamu yang diberi tahu.',
    ),
  );

  static List<(IconData, String, String)> get _doesNot => [
    (
      Icons.videocam_off_rounded,
      tr('Tidak merekam diam-diam'),
      tr('AURA tidak pernah menyalakan kamera atau mikrofon tanpa kamu tahu.'),
    ),
    (
      Icons.visibility_off_rounded,
      tr('Tidak membaca semua obrolanmu'),
      tr(
        'Obrolan yang tidak mengandung tanda bahaya tidak dikirim ke '
        'mana pun.',
      ),
    ),
    (
      Icons.app_registration_rounded,
      tr('Tidak menyembunyikan dirinya'),
      tr(
        'Ikon AURA selalu terlihat di ponselmu, dan kamu bisa membuka '
        'riwayat apa saja yang pernah dikirim ke orang tuamu.',
      ),
    ),
  ];

  Future<void> _accept() async {
    final state = context.read<AppState>();
    await state.giveConsent();

    // Izin lokasi diminta di sini, selagi tenang dan tepat setelah anak
    // membaca penjelasannya. Meminta saat tombol darurat ditekan berarti
    // dialog sistem muncul di tengah keadaan panik dan menunda pertolongan.
    await state.locationService.requestPermission();
    await state.callService.requestPermission();

    // Akses notifikasi tidak punya dialog izin; harus dinyalakan sendiri di
    // Pengaturan Android. Tanpanya pesan masuk tidak terpindai, jadi anak
    // diberi tahu terus terang dan dibukakan halamannya.
    if (await state.notificationAccess.isGranted() == false && mounted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.mark_chat_read_rounded,
            color: AuraColors.cyan,
            size: 36,
          ),
          title: Text(tr('Satu langkah lagi'), textAlign: TextAlign.center),
          content: Text(
            tr(
              'Supaya AURA bisa memeriksa pesan yang masuk, nyalakan "Akses '
              'notifikasi" untuk AURA di halaman berikutnya.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: AuraColors.textSecondary),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(tr('Nanti')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(tr('Buka')),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (open == true) await state.notificationAccess.openSettings();
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kesepakatan Kita'))),
      extendBodyBehindAppBar: true,
      body: AuraBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Apa yang AURA lakukan di ponsel ini'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            'Baca pelan-pelan ya. Kalau ada yang kamu tidak setujui, kamu '
                            'boleh bertanya ke orang tuamu dulu.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 22),
                        _ConsentGroup(
                          title: tr('Yang AURA lakukan'),
                          color: AuraColors.cyan,
                          items: [
                            ..._does,
                            if (context.watch<AppState>().usesAiChat) _aiItem,
                          ],
                        ),
                        const SizedBox(height: 18),
                        _ConsentGroup(
                          title: tr('Yang AURA tidak lakukan'),
                          color: AuraColors.safe,
                          items: _doesNot,
                        ),
                        const SizedBox(height: 18),
                        GlassCard(
                          borderColor: AuraColors.ember.withValues(alpha: 0.4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: AuraColors.ember,
                                size: 19,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tr(
                                    'Kalau nanti kamu merasa AURA keliru atau kamu tidak nyaman, '
                                    'bilang ke orang tuamu. Kamu juga bisa melihat sendiri semua '
                                    'peringatan yang pernah dikirim.',
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        CheckboxListTile(
                          value: _understood,
                          onChanged: (value) =>
                              setState(() => _understood = value ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AuraColors.safe,
                          title: Text(
                            tr('Aku sudah baca dan mengerti'),
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        child: Text(tr('Nanti dulu')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _understood ? _accept : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AuraColors.safe,
                        ),
                        child: Text(tr('Aku setuju')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentGroup extends StatelessWidget {
  const _ConsentGroup({
    required this.title,
    required this.color,
    required this.items,
  });

  final String title;
  final Color color;
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            final (icon, heading, detail) = item;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
