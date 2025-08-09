import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../models/map_marker.dart';

/// Ultra-smooth map widget optimized for 60fps zooming performance
class UltraSmoothMap extends StatefulWidget {
  final latlong.LatLng initialPosition;
  final Set<MapMarker> markers;
  final bool showUserLocation;
  final latlong.LatLng? userLocation;
  final void Function(MapMarker)? onMarkerTap;
  final void Function(latlong.LatLng center, double zoom)? onMapMoved;

  const UltraSmoothMap({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.showUserLocation = true,
    this.userLocation,
    this.onMarkerTap,
    this.onMapMoved,
  });

  @override
  State<UltraSmoothMap> createState() => _UltraSmoothMapState();
}

class _UltraSmoothMapState extends State<UltraSmoothMap>
    with TickerProviderStateMixin {
  
  late final AnimatedMapController _animatedMapController;
  MapController get _mapController => _animatedMapController.mapController;
  
  // Performance optimization variables
  List<Marker> _cachedMarkers = [];
  Set<MapMarker>? _lastMarkersSet;
  Timer? _markerUpdateTimer;
  Timer? _zoomDebounceTimer;
  
  // Zoom performance tracking
  bool _isZooming = false;
  double _lastZoom = 15.0;
  
  // Marker cache for ultra-fast lookups
  final Map<String, Marker> _markerCache = {};
  
  // Theme
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    
    // Ultra-fast animation controller - 200ms for snappy response
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Much faster!
    );
    
    // Initialize tile cache for instant loading
    _initializeTileCache();
    
    // Build initial markers
    _updateMarkers();
  }

  void _initializeTileCache() async {
    try {
      // Removed tile caching initialization
    } catch (e) {
      debugPrint('Tile cache initialization: $e');
    }
  }

  @override
  void dispose() {
    _markerUpdateTimer?.cancel();
    _zoomDebounceTimer?.cancel();
    _animatedMapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UltraSmoothMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only update markers if they actually changed
    if (widget.markers != oldWidget.markers) {
      _scheduleMarkerUpdate();
    }
  }

  /// Debounced marker updates to prevent lag during zoom
  void _scheduleMarkerUpdate() {
    _markerUpdateTimer?.cancel();
    _markerUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _updateMarkers();
      }
    });
  }

  /// Ultra-fast marker building with aggressive caching
  void _updateMarkers() {
    // Skip marker updates during zoom for smooth performance
    if (_isZooming) return;
    
    // Check if markers actually changed
    if (_lastMarkersSet != null && 
        _lastMarkersSet!.length == widget.markers.length &&
        _lastMarkersSet!.containsAll(widget.markers)) {
      return; // No changes, skip update
    }

    final newMarkers = <Marker>[];
    
    // Add user location marker (highest priority)
    if (widget.showUserLocation && widget.userLocation != null) {
      final userMarker = _buildUserLocationMarker();
      if (userMarker != null) {
        newMarkers.add(userMarker);
      }
    }
    
    // Add friend markers with caching
    for (final mapMarker in widget.markers) {
      final cacheKey = '${mapMarker.point.latitude}_${mapMarker.point.longitude}_${mapMarker.label}';
      
      if (_markerCache.containsKey(cacheKey)) {
        newMarkers.add(_markerCache[cacheKey]!);
      } else {
        final marker = _buildFriendMarker(mapMarker);
        _markerCache[cacheKey] = marker;
        newMarkers.add(marker);
      }
    }
    
    setState(() {
      _cachedMarkers = newMarkers;
      _lastMarkersSet = Set.from(widget.markers);
    });
  }

  /// Build ultra-lightweight user location marker
  Marker? _buildUserLocationMarker() {
    if (widget.userLocation == null) return null;
    
    return Marker(
      point: widget.userLocation!,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }

  /// Build optimized friend marker
  Marker _buildFriendMarker(MapMarker mapMarker) {
    return Marker(
      point: mapMarker.point,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => widget.onMarkerTap?.call(mapMarker),
        child: Container(
          decoration: BoxDecoration(
            color: mapMarker.color ?? Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              mapMarker.label?.substring(0, 1).toUpperCase() ?? 'F',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ultra-smooth zoom with haptic feedback
  void _zoomBy(double delta) {
    HapticFeedback.lightImpact();
    
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + delta).clamp(2.0, 19.0);
    
    _animatedMapController.animatedZoomTo(newZoom);
  }

  /// Smooth user location centering
  void _goToUserLocation() {
    if (widget.userLocation != null) {
      HapticFeedback.mediumImpact();
      _animatedMapController.animateTo(
        dest: widget.userLocation!,
        zoom: 16.0,
      );
    }
  }

  /// Toggle theme with smooth transition
  void _toggleTheme() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  /// Handle zoom start/end for performance optimization
  void _onZoomStart() {
    _isZooming = true;
    _zoomDebounceTimer?.cancel();
  }

  void _onZoomEnd() {
    _zoomDebounceTimer?.cancel();
    _zoomDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _isZooming = false;
      _updateMarkers(); // Update markers after zoom ends
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Ultra-optimized FlutterMap
            RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.initialPosition,
                  initialZoom: 15,
                  minZoom: 2,
                  maxZoom: 19,
                  
                  // Optimized interaction settings for smooth zoom
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | 
                           InteractiveFlag.drag |
                           InteractiveFlag.doubleTapZoom,
                    pinchZoomWinGestures: MultiFingerGesture.pinchZoom,
                    pinchMoveWinGestures: MultiFingerGesture.pinchMove,
                    enableMultiFingerGestureRace: true,
                  ),
                  
                  // Performance callbacks
                  onMapReady: () {
                    debugPrint('Ultra-smooth map ready!');
                  },
                  
                  onPositionChanged: (position, hasGesture) {
                    // Handle zoom state for performance
                    final currentZoom = position.zoom ?? 15.0;
                    if ((currentZoom - _lastZoom).abs() > 0.1) {
                      if (!_isZooming) _onZoomStart();
                      _lastZoom = currentZoom;
                    }
                    
                    // Debounced callback to parent
                    if (widget.onMapMoved != null && position.center != null && position.zoom != null) {
                      _zoomDebounceTimer?.cancel();
                      _zoomDebounceTimer = Timer(const Duration(milliseconds: 100), () {
                        widget.onMapMoved!(position.center!, position.zoom!);
                        _onZoomEnd();
                      });
                    }
                  },
                ),
                
                children: [
                  // Single optimized tile layer for maximum performance
                  TileLayer(
                    urlTemplate: _isDarkMode
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.sundeep.groupsharing',
                    
                    // Performance optimizations
                    maxZoom: 19,
                    minZoom: 2,
                    retinaMode: false, // Disable retina for better performance
                    
                    // Ultra-fast tile caching removed
                    
                    // Error handling
                    errorTileCallback: (tile, error, stackTrace) {
                      // Silent error handling for smooth experience
                    },
                  ),
                  
                  // Optimized marker layer
                  MarkerLayer(
                    markers: _cachedMarkers,
                    rotate: false, // Disable rotation for better performance
                  ),
                ],
              ),
            ),
            
            // Floating controls with smooth animations
            Positioned(
              bottom: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmoothControlButton(
                    icon: Icons.add,
                    onTap: () => _zoomBy(1),
                    tooltip: 'Zoom In',
                  ),
                  const SizedBox(height: 8),
                  _SmoothControlButton(
                    icon: Icons.remove,
                    onTap: () => _zoomBy(-1),
                    tooltip: 'Zoom Out',
                  ),
                  if (widget.showUserLocation && widget.userLocation != null) ...[
                    const SizedBox(height: 8),
                    _SmoothControlButton(
                      icon: Icons.my_location,
                      onTap: _goToUserLocation,
                      tooltip: 'My Location',
                    ),
                  ],
                  const SizedBox(height: 8),
                  _SmoothControlButton(
                    icon: _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    onTap: _toggleTheme,
                    tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
                  ),
                ],
              ),
            ),
            
            // Performance indicator (debug mode only)
            if (kDebugMode)
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Zoom: ${_lastZoom.toStringAsFixed(1)}\nMarkers: ${_cachedMarkers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

/// Ultra-smooth control button with haptic feedback
class _SmoothControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _SmoothControlButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.black87,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}