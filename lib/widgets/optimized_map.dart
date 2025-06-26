import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../models/map_marker.dart';

/// Extremely optimized map widget for buttery smooth 60fps zooming
/// Removes all unnecessary features that could cause lag
class OptimizedMap extends StatefulWidget {
  final latlong.LatLng initialPosition;
  final Set<MapMarker> markers;
  final bool showUserLocation;
  final latlong.LatLng? userLocation;
  final void Function(MapMarker)? onMarkerTap;
  final void Function(latlong.LatLng center, double zoom)? onMapMoved;

  const OptimizedMap({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.showUserLocation = true,
    this.userLocation,
    this.onMarkerTap,
    this.onMapMoved,
  });

  @override
  State<OptimizedMap> createState() => _OptimizedMapState();
}

class _OptimizedMapState extends State<OptimizedMap> {
  late final MapController _mapController;
  
  // Ultra-lightweight marker cache
  List<Marker> _cachedMarkers = [];
  Set<MapMarker>? _lastMarkersSet;
  Timer? _updateTimer;
  
  // Performance tracking
  bool _isInteracting = false;
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _buildMarkers();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(OptimizedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.markers != oldWidget.markers) {
      _scheduleMarkerUpdate();
    }
  }

  void _scheduleMarkerUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 50), _buildMarkers);
  }

  void _buildMarkers() {
    // Skip updates during interaction for smooth performance
    if (_isInteracting) return;
    
    // Quick equality check
    if (_lastMarkersSet != null && 
        _lastMarkersSet!.length == widget.markers.length &&
        _lastMarkersSet!.containsAll(widget.markers)) {
      return;
    }

    final markers = <Marker>[];
    
    // Ultra-simple user marker
    if (widget.showUserLocation && widget.userLocation != null) {
      markers.add(Marker(
        point: widget.userLocation!,
        width: 20,
        height: 20,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 12),
        ),
      ));
    }
    
    // Ultra-simple friend markers
    for (final mapMarker in widget.markers) {
      markers.add(Marker(
        point: mapMarker.point,
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => widget.onMarkerTap?.call(mapMarker),
          child: Container(
            decoration: BoxDecoration(
              color: mapMarker.color ?? Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Center(
              child: Text(
                mapMarker.label?.substring(0, 1).toUpperCase() ?? 'F',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ));
    }
    
    if (mounted) {
      setState(() {
        _cachedMarkers = markers;
        _lastMarkersSet = Set.from(widget.markers);
      });
    }
  }

  void _onInteractionStart() {
    _isInteracting = true;
  }

  void _onInteractionEnd() {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 100), () {
      _isInteracting = false;
      _buildMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Ultra-optimized FlutterMap
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialPosition,
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 18,
                
                // Optimized for smooth zooming
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | 
                         InteractiveFlag.drag |
                         InteractiveFlag.doubleTapZoom,
                  enableMultiFingerGestureRace: true,
                ),
                
                onMapReady: () {
                  debugPrint('Optimized map ready');
                },
                
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _onInteractionStart();
                  }
                  
                  _currentZoom = position.zoom ?? 15.0;
                  
                  // Debounced callback
                  if (widget.onMapMoved != null && position.center != null && position.zoom != null) {
                    _updateTimer?.cancel();
                    _updateTimer = Timer(const Duration(milliseconds: 100), () {
                      widget.onMapMoved!(position.center!, position.zoom!);
                      _onInteractionEnd();
                    });
                  }
                },
              ),
              
              children: [
                // Single lightweight tile layer
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.sundeep.groupsharing',
                  maxZoom: 18,
                  minZoom: 3,
                  retinaMode: false, // Disabled for performance
                  
                  // Minimal error handling
                  errorTileCallback: (tile, error, stackTrace) {
                    // Silent handling
                  },
                ),
                
                // Lightweight marker layer
                MarkerLayer(
                  markers: _cachedMarkers,
                  rotate: false,
                ),
              ],
            ),
            
            // Minimal controls
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QuickButton(
                    icon: Icons.add,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newZoom = (_currentZoom + 1).clamp(3.0, 18.0);
                      _mapController.move(_mapController.camera.center, newZoom);
                    },
                  ),
                  const SizedBox(height: 8),
                  _QuickButton(
                    icon: Icons.remove,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newZoom = (_currentZoom - 1).clamp(3.0, 18.0);
                      _mapController.move(_mapController.camera.center, newZoom);
                    },
                  ),
                  if (widget.userLocation != null) ...[
                    const SizedBox(height: 8),
                    _QuickButton(
                      icon: Icons.my_location,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _mapController.move(widget.userLocation!, 16);
                      },
                    ),
                  ],
                ],
              ),
            ),
            
            // Performance debug info
            if (kDebugMode)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Z: ${_currentZoom.toStringAsFixed(1)} M: ${_cachedMarkers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ultra-lightweight button for maximum performance
class _QuickButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 18),
      ),
    );
  }
}