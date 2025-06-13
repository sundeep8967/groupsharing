import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

/// A Flutter widget that displays an OpenStreetMap map with markers and user location.
class AppMapWidget extends StatelessWidget {
  /// The initial position to center the map on.
  final latlong.LatLng initialPosition;

  /// A set of markers to display on the map.
  final Set<MapMarker> markers;

  /// Whether to show the user's location on the map.
  final bool showUserLocation;

  /// Called when a marker is tapped.
  final void Function(MapMarker)? onMarkerTap;

  /// Creates a map widget.
  const AppMapWidget({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.showUserLocation = true,
    this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: initialPosition,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.groupsharing',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        MarkerLayer(
          markers: markers.map((marker) {
            return Marker(
              width: 80.0,
              height: 80.0,
              point: marker.position,
              child: GestureDetector(
                onTap: () => onMarkerTap?.call(marker),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40.0,
                ),
              ),
            );
          }).toList(),
        ),
        // TODO: Add user location layer here if needed
      ],
    );
  }
}

/// A simple data class for a map marker.
class MapMarker {
  final String id;
  final latlong.LatLng position;
  final String title;
  final String? snippet;

  const MapMarker({
    required this.id,
    required this.position,
    required this.title,
    this.snippet,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapMarker &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
