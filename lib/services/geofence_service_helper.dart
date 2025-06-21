import 'package:geofence_service/geofence_service.dart';
// import 'package:geolocator/geolocator.dart'; // Removed unused import

/// Simplified geofencing wrapper.
class GeofenceHelper {
  static final GeofenceService _service = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,


  );

  static Future<void> addDefaultGeofences() async {
    // Example, replace with real coordinates.
    final geofences = [
      Geofence(
        id: 'home',
        latitude: 12.9716,
        longitude: 77.5946,
        radius: [
          GeofenceRadius(id: 'radius_150', length: 150),
        ],
      ),
    ];
    _service.addGeofenceList(geofences);
  }

  static Future<void> start() async {
    // Register listeners before starting the service.
    _service.addGeofenceStatusChangeListener(
      (geofence, geofenceRadius, geofenceStatus, location) async {
        // TODO: handle geofence enter/exit events.
        return;
      },
    );
    _service.addStreamErrorListener(
      (error) async {
        // TODO: handle or log errors.
        return;
      },
    );
    await _service.start();
  }

  static Future<void> stop() async => _service.stop();
}
