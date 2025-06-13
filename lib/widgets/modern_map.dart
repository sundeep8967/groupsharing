import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'app_map_widget.dart';

/// A drop-in replacement for [AppMapWidget] that adds a "modern" UI layer
/// similar to Google / Uber / WhatsApp maps while remaining **100 % free** by
/// using open-source OpenStreetMap vector styles from Carto.
///
/// Features
/// ────────────────────────────────────────────────────────────────────────────
/// • Light & Dark map styles (CartoDB Positron / DarkMatter)
/// • Rounded-corner map with subtle shadow (Material 3)
/// • Floating zoom-in / zoom-out buttons
/// • "Locate me" button (centres camera on the user position)
/// • Optional search bar placeholder (for future geocoding integration)
/// • Elegant marker icons & clustering-ready (just swap the `MarkerLayer`)
class ModernMap extends StatefulWidget {
  final latlong.LatLng initialPosition;
  final Set<MapMarker> markers;
  final bool showUserLocation;
  final latlong.LatLng? userLocation;
  final void Function(MapMarker)? onMarkerTap;

  const ModernMap({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.showUserLocation = true,
    this.userLocation,
    this.onMarkerTap,
  });

  @override
  State<ModernMap> createState() => _ModernMapState();
}

enum _MapTheme { light, dark }

class _ModernMapState extends State<ModernMap> {
  final MapController _mapController = MapController();
  _MapTheme _currentTheme = _MapTheme.light;

  String get _tileUrl {
    switch (_currentTheme) {
      case _MapTheme.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case _MapTheme.light:
      default:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialPosition,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  tileProvider: CancellableNetworkTileProvider(),
                  userAgentPackageName: 'com.example.groupsharing',
                ),
                MarkerLayer(
                  markers: [
                    // User location marker
                    if (widget.showUserLocation && widget.userLocation != null)
                      Marker(
                        width: 40,
                        height: 40,
                        point: widget.userLocation!,
                        child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
                      ),
                    // Other markers
                    ...widget.markers.map(_toMarker),
                  ],
                ),
              ],
            ),
            // Search bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _SearchBar(onSubmitted: (q) {/* Hook up geocoding here */}),
            ),
            // Zoom controls
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  _CircleIconButton(
                    icon: Icons.add,
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _CircleIconButton(
                    icon: Icons.remove,
                    onTap: () => _zoomBy(-1),
                  ),
                  if (widget.showUserLocation) ...[
                    const SizedBox(height: 12),
                    _CircleIconButton(
                      icon: Icons.my_location,
                      onTap: _goToUserLocation,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _CircleIconButton(
                    icon: _currentTheme == _MapTheme.light ? Icons.dark_mode : Icons.light_mode,
                    onTap: _toggleTheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to convert MapMarker to Marker widget.
  Marker _toMarker(MapMarker m) => Marker(
        width: 80,
        height: 80,
        point: m.position,
        child: GestureDetector(
          onTap: () => widget.onMarkerTap?.call(m),
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
      );

  void _zoomBy(double delta) {
    _mapController.move(_mapController.center, _mapController.zoom + delta);
  }

  void _goToUserLocation() {
    if (widget.userLocation == null) return;
    _mapController.move(widget.userLocation!, 17);
  }

  void _toggleTheme() {
    setState(() {
      _currentTheme = _currentTheme == _MapTheme.light ? _MapTheme.dark : _MapTheme.light;
    });
  }
}

/// Search bar placeholder. Replace with real geocoding if desired.
class _SearchBar extends StatelessWidget {
  final void Function(String) onSubmitted;
  const _SearchBar({required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Search place…',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// A round Material button used for map controls.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
