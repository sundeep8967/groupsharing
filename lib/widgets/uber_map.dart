import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

class UberMap extends StatelessWidget {
  /// The current location of the user (latitude and longitude)
  final LatLng? userLocation;
  
  /// Callback function when user requests to center on their location
  final VoidCallback? onMyLocationPressed;

  const UberMap({
    Key? key,
    this.userLocation,
    this.onMyLocationPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Map
        FlutterMap(
          options: MapOptions(
            initialCenter: userLocation != null
                ? latlong.LatLng(userLocation!.latitude, userLocation!.longitude)
                : const latlong.LatLng(0, 0),
            initialZoom: 15.0,
          ),
          children: [
            // OpenStreetMap Tile Layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
              tileProvider: NetworkTileProvider(),
            ),
            
            // User Location Marker (if available)
            if (userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: latlong.LatLng(userLocation!.latitude, userLocation!.longitude),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // My Location Button
        Positioned(
          bottom: 20,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'my_location',
            backgroundColor: Colors.white,
            elevation: 2,
            onPressed: onMyLocationPressed,
            child: const Icon(Icons.my_location, color: Colors.blue),
          ),
        ),
      ],
    );
  }
}

// Simple LatLng class for coordinates
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}
