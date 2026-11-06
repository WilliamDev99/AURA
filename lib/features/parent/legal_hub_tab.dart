import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/clay.dart';
import 'legal_action_page.dart';
import '../../core/l10n/l10n.dart';

const _poppins = 'Poppins';
const _navy = Color(0xFF102A71);

/// Tab "Laporan": empat pintu ke lembaga resmi dalam satu ketukan, kontak
/// darurat, lalu berkas bukti dan panduan hukum lengkap di bawahnya.
class LegalHubTab extends StatelessWidget {
  const LegalHubTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalActionBody(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 120),
      leading: [
        _HubPanel(),
        SizedBox(height: 16),
        _EmergencyCard(),
        SizedBox(height: 28),
      ],
    );
  }
}

/// Satu pilihan di lembar rincian lembaga.
class _Action {
  const _Action(this.icon, this.label, this.detail, this.uri);

  final IconData icon;
  final String label;
  final String detail;
  final Uri uri;
}

/// Satu lembaga di kisi "Pusat Aksi Hukum".
class _Agency {
  const _Agency({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.tint,
    required this.ink,
    required this.intro,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData badge;
  final Color tint;
  final Color ink;
  final String intro;
  final List<_Action> actions;
}

Uri _maps(String query) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});

// Getter: teksnya mengikuti bahasa yang sedang dipakai.
List<_Agency> get _agencies => [
  _Agency(
    title: tr('Buat laporan Polisi'),
    subtitle: tr('Langsung ke Sistem SPKT'),
    icon: Icons.local_police_rounded,
    badge: Icons.description_rounded,
    tint: const Color(0xFFDDE6FF),
    ink: const Color(0xFF1F3A8A),
    intro: tr(
      'Laporan polisi kini bisa dibuat online lewat Super App Polri '
      'dan diverifikasi petugas SPKT. Siapkan berkas bukti PDF dari '
      'AURA (di bawah halaman ini) sebelum melapor.',
    ),
    actions: [
      _Action(
        Icons.install_mobile_rounded,
        tr('Lapor online lewat Super App Polri'),
        tr('Aplikasi resmi Polri. Tidak perlu datang ke kantor polisi.'),
        Uri.https('play.google.com', '/store/search', {
          'q': 'Super App Polri',
          'c': 'apps',
        }),
      ),
      _Action(
        Icons.location_on_rounded,
        tr('Datang ke SPKT terdekat'),
        tr('Sentra Pelayanan Kepolisian Terpadu di Polres atau Polsek.'),
        _maps('SPKT Polres terdekat'),
      ),
      _Action(
        Icons.language_rounded,
        tr('Kejahatan siber: Patroli Siber'),
        tr('Pelaporan tindak pidana siber ke Bareskrim Polri.'),
        Uri.https('patrolisiber.id'),
      ),
      _Action(
        Icons.call_rounded,
        tr('Darurat: telepon 110'),
        tr('Bila anak sedang dalam bahaya saat ini juga.'),
        Uri(scheme: 'tel', path: '110'),
      ),
    ],
  ),
  _Agency(
    title: tr('Hubungi Unit PPA'),
    subtitle: tr('Polisi / Pendampingan Anak'),
    icon: Icons.family_restroom_rounded,
    badge: Icons.health_and_safety_rounded,
    tint: const Color(0xFFDDF4EE),
    ink: const Color(0xFF137A6B),
    intro: tr(
      'Unit PPA (Pelayanan Perempuan dan Anak) di Polres menyidik '
      'kasus anak. SAPA 129 dari KemenPPPA menerima laporan 24 jam, '
      'gratis, dan rahasia, lalu menghubungkan ke pendampingan.',
    ),
    actions: [
      _Action(
        Icons.call_rounded,
        tr('SAPA 129: telepon'),
        tr('Layanan KemenPPPA untuk kekerasan terhadap anak.'),
        Uri(scheme: 'tel', path: '129'),
      ),
      _Action(
        Icons.chat_rounded,
        tr('SAPA 129: WhatsApp'),
        '0811-1129-129',
        Uri.https('wa.me', '/628111129129'),
      ),
      _Action(
        Icons.assignment_rounded,
        tr('SAPA 129: formulir online'),
        'laporsapa129.kemenpppa.go.id',
        Uri.https('laporsapa129.kemenpppa.go.id', '/lapor'),
      ),
      _Action(
        Icons.location_on_rounded,
        tr('Unit PPA Polres terdekat'),
        tr('Penyidik khusus kasus perempuan dan anak.'),
        _maps('Unit PPA Polres'),
      ),
      _Action(
        Icons.location_on_rounded,
        tr('UPTD PPA terdekat'),
        tr('Pendampingan psikologis dan hukum dari pemerintah daerah.'),
        _maps('UPTD PPA'),
      ),
    ],
  ),
  _Agency(
    title: tr('Komnas Anak & KPAI'),
    subtitle: tr('Layanan Pengaduan dan Konsultasi'),
    icon: Icons.child_care_rounded,
    badge: Icons.volunteer_activism_rounded,
    tint: const Color(0xFFFFE6DA),
    ink: const Color(0xFFC2410C),
    intro: tr(
      'KPAI adalah lembaga negara pengawas perlindungan anak. Komnas '
      'Perlindungan Anak adalah lembaga masyarakat yang menerima '
      'pengaduan dan konsultasi.',
    ),
    actions: [
      _Action(
        Icons.chat_rounded,
        tr('KPAI: WhatsApp pengaduan'),
        tr('0811-1002-7727. Sejak Mei 2024 pengaduan KPAI lewat WhatsApp.'),
        Uri.https('wa.me', '/6281110027727'),
      ),
      _Action(
        Icons.assignment_rounded,
        tr('KPAI: formulir pengaduan'),
        'kpai.go.id',
        Uri.https('www.kpai.go.id', '/formulir-pengaduan'),
      ),
      _Action(
        Icons.chat_rounded,
        tr('Komnas Perlindungan Anak: WhatsApp'),
        tr('0822-2888-8454 (dari akun resmi @komnasanak).'),
        Uri.https('wa.me', '/6282228888454'),
      ),
    ],
  ),
  _Agency(
    title: tr('LBH & Bantuan Hukum'),
    subtitle: tr('Konsultasi Hukum Gratis'),
    icon: Icons.balance_rounded,
    badge: Icons.handshake_rounded,
    tint: const Color(0xFFFFF1D6),
    ink: const Color(0xFFB45309),
    intro: tr(
      'Negara membiayai bantuan hukum gratis lewat LBH terakreditasi '
      'BPHN (Kementerian Hukum), terutama bagi warga tidak mampu '
      'dengan surat keterangan tidak mampu.',
    ),
    actions: [
      _Action(
        Icons.search_rounded,
        tr('Cari LBH gratis terdekat'),
        tr('SIDBankum: daftar resmi organisasi bantuan hukum.'),
        Uri.https('sidbankum.bphn.go.id'),
      ),
      _Action(
        Icons.forum_rounded,
        tr('Konsultasi hukum online'),
        tr('Legal Smart Channel BPHN, gratis.'),
        Uri.https('lsc.bphn.go.id'),
      ),
      _Action(
        Icons.call_rounded,
        tr('LPSK: telepon 148'),
        tr('Perlindungan bagi saksi dan korban, termasuk anak.'),
        Uri(scheme: 'tel', path: '148'),
      ),
    ],
  ),
];

Future<void> _open(BuildContext context, Uri uri, String label) async {
  final opened = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  ).catchError((Object _) => false);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('Tidak bisa membuka {label}.', {'label': label})),
      ),
    );
  }
}

class _HubPanel extends StatelessWidget {
  const _HubPanel();

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      color: const Color(0xFFE8EDFF),
      radius: 32,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              tr('Pusat Aksi Hukum'),
              style: TextStyle(
                fontFamily: _poppins,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: _navy,
                height: 1.2,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              tr('Satu Ketukan, Perlindungan Hukum!'),
              style: TextStyle(
                fontFamily: _poppins,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: _navy,
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (var row = 0; row < _agencies.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 14),
            // Kedua kartu dalam satu baris selalu sama tinggi.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _AgencyTile(agency: _agencies[row])),
                  const SizedBox(width: 14),
                  Expanded(child: _AgencyTile(agency: _agencies[row + 1])),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgencyTile extends StatelessWidget {
  const _AgencyTile({required this.agency});

  final _Agency agency;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      radius: 30,
      padding: EdgeInsets.zero,
      onTap: () => _AgencySheet.show(context, agency),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 168),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Illustration(agency: agency),
              const SizedBox(height: 10),
              Text(
                agency.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _poppins,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                agency.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _poppins,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1B2A5A),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ilustrasi sederhana dari ikon: lingkaran berwarna dengan lencana kecil.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.agency});

  final _Agency agency;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 70,
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 0,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: agency.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(agency.icon, size: 40, color: agency.ink),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(agency.badge, size: 18, color: agency.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rincian satu lembaga dalam lembar clay: penjelasan singkat dan cara
/// menghubunginya.
class _AgencySheet extends StatelessWidget {
  const _AgencySheet({required this.agency});

  final _Agency agency;

  static Future<void> show(BuildContext context, _Agency agency) =>
      showClaySheet<void>(
        context: context,
        builder: (_) => _AgencySheet(agency: agency),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Illustration(agency: agency),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    agency.title,
                    style: const TextStyle(
                      fontFamily: _poppins,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: ClayColors.ink,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              agency.intro,
              style: const TextStyle(
                fontFamily: _poppins,
                fontSize: 13,
                height: 1.5,
                color: ClayColors.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            for (final action in agency.actions)
              ClayCard(
                margin: const EdgeInsets.only(bottom: 10),
                radius: 22,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                onTap: () => _open(context, action.uri, action.label),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: agency.tint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(action.icon, size: 21, color: agency.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.label,
                            style: const TextStyle(
                              fontFamily: _poppins,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ClayColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            action.detail,
                            style: const TextStyle(
                              fontFamily: _poppins,
                              fontSize: 12.5,
                              height: 1.35,
                              color: ClayColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: ClayColors.inkMuted,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('Telepon 112, Layanan Darurat Nasional'),
      excludeSemantics: true,
      child: ClayCard(
        radius: 28,
        padding: EdgeInsets.zero,
        onTap: () =>
            _open(context, Uri(scheme: 'tel', path: '112'), tr('telepon 112')),
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Kontak Darurat'),
                style: TextStyle(
                  fontFamily: _poppins,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '112',
                          style: TextStyle(
                            fontFamily: _poppins,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        Text(
                          tr('Layanan Darurat Nasional'),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontFamily: _poppins,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 14),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _navy,
                    child: Icon(Icons.call_rounded, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
