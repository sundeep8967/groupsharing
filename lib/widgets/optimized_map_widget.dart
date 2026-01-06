import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// Optimized Map Widget with performance improvements
class OptimizedMapWidget extends StatefulWidget {
  final LatLng? currentLocation;
  final List<MapMarker> markers;
  final Function(LatLng)? onTap;
  final Function(LatLng)? onLongPress;
  final double initialZoom;
  final bool showCurrentLocation;
  final bool enableInteraction;

  const OptimizedMapWidget({
    Key? key,
    this.currentLocation,
    this.markers = const [],
    this.onTap,
    this.onLongPress,
    this.initialZoom = 13.0,
    this.showCurrentLocation = true,
    this.enableInteraction = true,
  }) : super(key: key);

  @override
  State<OptimizedMapWidget> createState() => _OptimizedMapWidgetState();
}

class _OptimizedMapWidgetState extends State<OptimizedMapWidget>
    with AutomaticKeepAliveClientMixin {
  late MapController _mapController;
  Timer? _debounceTimer;
  LatLng? _lastCenter;
  double? _lastZoom;
  
  // Performance optimization: Cache markers
  List<Widget> _cachedMarkers = [];
  List<MapMarker> _lastMarkerData = [];
  
  @override
  bool get wantKeepAlive => true; // Keep widget alive for performance

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _updateCachedMarkers();
  }

  @override
  void didUpdateWidget(OptimizedMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only rebuild markers if they actually changed
    if (_markersChanged(oldWidget.markers, widget.markers)) {
      _updateCachedMarkers();
    }
    
    // Smoothly animate to new location if changed
    if (oldWidget.currentLocation != widget.currentLocation &&
        widget.currentLocation != null) {
      _animateToLocation(widget.currentLocation!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Check if markers actually changed to avoid unnecessary rebuilds
  bool _markersChanged(List<MapMarker> oldMarkers, List<MapMarker> newMarkers) {
    if (oldMarkers.length != newMarkers.length) return true;
    
    for (int i = 0; i < oldMarkers.length; i++) {
      if (oldMarkers[i].id != newMarkers[i].id ||
          oldMarkers[i].position != newMarkers[i].position) {
        return true;
      }
    }
    return false;
  }

  /// Update cached markers only when necessary
  void _updateCachedMarkers() {
    _lastMarkerData = List.from(widget.markers);
    _cachedMarkers = widget.markers.map((marker) => _buildMarker(marker)).toList();
    
    // Add current location marker if enabled
    if (widget.showCurrentLocation && widget.currentLocation != null) {
      _cachedMarkers.add(_buildCurrentLocationMarker(widget.currentLocation!));
    }
  }

  /// Build individual marker with caching
  Widget _buildMarker(MapMarker marker) {
    return GestureDetector(
      onTap: () => marker.onTap?.call(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: marker.color ?? Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          marker.icon ?? Icons.person,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Build current location marker
  Widget _buildCurrentLocationMarker(LatLng location) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.my_location,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  /// Smoothly animate to location with debouncing
  void _animateToLocation(LatLng location) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        try {
          _mapController.move(location, widget.initialZoom);
        } catch (e) {
          developer.log('Error animating to location: $e');
        }
      }
    });
  }

  /// Handle map events with debouncing for performance
  void _onMapEvent() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Handle map event
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Map Widget'),
            Text('Current Location: ${widget.currentLocation?.toString() ?? "Unknown"}'),
            Text('Markers: ${widget.markers.length}'),
            if (widget.markers.isNotEmpty)
              ...widget.markers.map((marker) => 
                ListTile(
                  leading: Icon(marker.icon ?? Icons.location_on),
                  title: Text(marker.label ?? marker.id),
                  onTap: marker.onTap,
                )
              ),
          ],
        ),
      ),
    );
  }
}

/// Map marker data class
class MapMarker {
  final String id;
  final LatLng position;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? label;

  const MapMarker({
    required this.id,
    required this.position,
    this.icon,
    this.color,
    this.onTap,
    this.label,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapMarker &&
        other.id == id &&
        other.position == position;
  }

  @override
  int get hashCode => id.hashCode ^ position.hashCode;
}

// Simplified map controller for the demo
class MapController {
  void move(LatLng location, double zoom) {
    // Placeholder for map movement
  }
}