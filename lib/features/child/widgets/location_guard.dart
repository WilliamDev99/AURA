import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/services/location_service.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

/// Meminta GPS dinyalakan setiap kali AURA dibuka di ponsel anak, supaya
/// tombol darurat selalu bisa mengirim lokasi.
///
/// Android tidak mengizinkan aplikasi menyalakan GPS diam-diam; yang muncul
/// adalah jendela resmi Google "Aktifkan lokasi?" dengan satu ketukan.
/// Lokasi tetap hanya diambil saat anak menekan tombol darurat.
class LocationGuard extends StatefulWidget {
  const LocationGuard({super.key, required this.child});

  final Widget child;

  @override
  State<LocationGuard> createState() => _LocationGuardState();
}

class _LocationGuardState extends State<LocationGuard>
    with WidgetsBindingObserver {
  bool _asking = false;

  /// Anak sempat meninggalkan AURA. Jendela "Aktifkan lokasi?" sendiri hanya
  /// membuat AURA "inactive"; tanpa pembeda ini, anak yang menolak akan
  /// langsung ditanya lagi tanpa henti.
  bool _leftApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _leftApp = true;
      case AppLifecycleState.resumed when _leftApp:
        _leftApp = false;
        _ensure();
      default:
        break;
    }
  }

  Future<void> _ensure() async {
    if (_asking || !mounted) return;
    _asking = true;
    final location = context.read<AppState>().locationService;
    final result = await location.ensureServiceOn();
    _asking = false;

    if (result == LocationSwitch.declined && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 6),
          content: Text(
            tr(
              'GPS masih mati. Kalau kamu menekan tombol darurat, lokasimu '
              'tidak bisa dikirim ke orang tuamu.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
