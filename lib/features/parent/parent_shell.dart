import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../state/app_state.dart';
import '../shared/settings_page.dart';
import 'forensics_timeline_page.dart';
import 'legal_hub_tab.dart';
import 'parent_dashboard_page.dart';
import '../../core/l10n/l10n.dart';

/// Kerangka antarmuka orang tua: Beranda, Log bukti, Laporan hukum, Profil.
class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _index = 0;

  static List<String> get _titles => [
    'AURA',
    tr('LOG BUKTI'),
    tr('LAPORAN'),
    tr('PROFIL'),
  ];
  static const _log = 1;
  static const _laporan = 2;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AppState>().unreadAlerts.length;

    // Tombol kembali Android di tab lain membawa ke Beranda dulu, bukan
    // langsung menutup aplikasi.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,
        body: _ParentBackdrop(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Tab Log dan Laporan sudah punya judul besar di panelnya.
                if (_index != _log && _index != _laporan)
                  _TitleBar(
                    title: _titles[_index],
                    // Di Beranda tidak ada tujuan "kembali".
                    onBack: _index == 0 ? null : () => _select(0),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: const [
                      ParentDashboardPage(),
                      ForensicsTimelinePage(),
                      LegalHubTab(),
                      SettingsBody(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _NavBar(
          index: _index,
          unread: unread,
          onSelect: _select,
        ),
      ),
    );
  }
}

/// Latar gelap dengan cahaya oranye di kanan atas dan biru di kiri bawah.
class _ParentBackdrop extends StatelessWidget {
  const _ParentBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07070D), Color(0xFF0A0F2E), Color(0xFF0B1A55)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -170,
            right: -150,
            child: _Glow(
              size: 460,
              colors: [Color(0xFFFF8A1F), Color(0xCCE8452C), Color(0x00E8452C)],
            ),
          ),
          const Positioned(
            bottom: -120,
            left: -160,
            child: _Glow(
              size: 420,
              colors: [Color(0xCC2F6BFF), Color(0x662F6BFF), Color(0x002F6BFF)],
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors, stops: const [0, 0.45, 1]),
        ),
      ),
    );
  }
}

/// Kapsul kaca selebar layar berisi judul di tengah.
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: LiquidGlass(
        borderRadius: 26,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (back != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: tr('Kembali ke Beranda'),
                    child: InkResponse(
                      onTap: back,
                      radius: 26,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: Colors.white,
                  height: 1.2,
                  shadows: [Shadow(color: Color(0x40000000), blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigasi bawah putih dengan ikon tosca, sesuai desain.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.unread,
    required this.onSelect,
  });

  final int index;
  final int unread;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Log'),
    (Icons.schedule_rounded, Icons.watch_later_rounded, 'Laporan'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    selectedIcon: _items[i].$2,
                    label: tr(_items[i].$3),
                    selected: i == index,
                    badge: i == 0 ? unread : 0,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  static const _teal = Color(0xFF16A3B5);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _teal : _teal.withValues(alpha: 0.55);
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0
          ? tr('{label}, {badge} menunggu tindakan', {
              'label': label,
              'badge': badge,
            })
          : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AuraColors.critical,
              child: Icon(
                selected ? selectedIcon : icon,
                size: 30,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
