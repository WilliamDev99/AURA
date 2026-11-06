import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/aura_colors.dart';
import 'clay.dart';
import '../../core/l10n/l10n.dart';

/// Keterangan sumber peta di pojok kanan bawah, yang menyusut bila tempatnya
/// sempit alih-alih meluber.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          tr('© OpenStreetMap'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: Color(0xFF333333)),
        ),
      ),
    );
  }
}

/// Peta lokasi anak bergaya Leaflet, dengan lingkaran akurasi.
///
/// Memakai flutter_map, pustaka peta Flutter yang meniru Leaflet, dengan ubin
/// OpenStreetMap: tanpa kunci API dan tanpa akun penagihan. Peta bisa digeser
/// dan diperbesar seperti Leaflet; Google Maps hanya dibuka lewat tombol di
/// bawahnya.
class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracyMetres,
    this.height = 180,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMetres;
  final double height;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  static const _initialZoom = 16.0;
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openInMaps() async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${widget.latitude},${widget.longitude}',
    });
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('AURA: Google Maps tidak bisa dibuka ($error).');
    }
  }

  void _zoomBy(double delta) {
    final camera = _controller.camera;
    _controller.move(
      camera.center,
      (camera.zoom + delta).clamp(3, 19).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    final accuracy = widget.accuracyMetres;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.height,
            child: Semantics(
              label: tr(
                'Peta lokasi anak. Geser atau cubit untuk memperbesar.',
              ),
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: _initialZoom,
                  backgroundColor: const Color(0xFF1B2140),
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'id.aura.aura',
                  ),
                  if (accuracy != null && accuracy > 0)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: point,
                          radius: accuracy,
                          useRadiusInMeter: true,
                          color: AuraColors.critical.withValues(alpha: 0.15),
                          borderColor: AuraColors.critical.withValues(
                            alpha: 0.6,
                          ),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          size: 40,
                          color: AuraColors.critical,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Tombol perbesar/perkecil di kiri atas, seperti Leaflet.
                  Align(
                    alignment: Alignment.topLeft,
                    child: _ZoomControl(
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
                      onRecenter: () => _controller.move(point, _initialZoom),
                    ),
                  ),
                  // Wajib menurut ketentuan pemakaian OpenStreetMap. Dibuat
                  // sendiri karena SimpleAttributionWidget tidak bisa
                  // menyusut dan meluber di layar sempit atau huruf besar.
                  const _Attribution(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            // Di atas permukaan clay yang terang, biru muda sulit terbaca.
            final color = OnClay.of(context)
                ? const Color(0xFF0277BD)
                : AuraColors.cyan;
            return OutlinedButton.icon(
              onPressed: _openInMaps,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(tr('Buka di Google Maps')),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Kotak tombol +/- bergaya Leaflet, ditambah tombol kembali ke titik anak.
class _ZoomControl extends StatelessWidget {
  const _ZoomControl({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) {
      return Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 20, color: const Color(0xFF333333)),
          ),
        ),
      );
    }

    const divider = SizedBox(
      width: 34,
      child: Divider(height: 1, thickness: 1, color: Color(0xFFCCCCCC)),
    );

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x33000000), width: 2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(Icons.add_rounded, tr('Perbesar peta'), onZoomIn),
            divider,
            button(Icons.remove_rounded, tr('Perkecil peta'), onZoomOut),
            divider,
            button(
              Icons.my_location_rounded,
              tr('Kembali ke lokasi anak'),
              onRecenter,
            ),
          ],
        ),
      ),
    );
  }
}
