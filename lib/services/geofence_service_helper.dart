import 'package:geofence_service/geofence_service.dart';
import '../models/geofence_model.dart';
import 'geofence_repository.dart';
// import 'package:geolocator/geolocator.dart'; // Removed unused import

/// Simplified geofencing wrapper.
class GeofenceHelper {
  static final GeofenceService _service = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
  );

  // Repository injected via initialize()
  static late GeofenceRepository _repo;

  static Future<void> initialize(String uid) async {
    _repo = GeofenceRepository(uid);
    final saved = await _repo.fetchGeofences();
    if (saved.isNotEmpty) {
      _service.addGeofenceList(saved.map((e) => e.toGeofence()).toList());
    }
  }

  static Future<void> addGeofence(GeofenceModel model) async {
    await _repo.saveGeofence(model);
    _service.addGeofence(model.toGeofence());
  }

  @deprecated
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
        // Persist event
        try {
          await _repo.addEvent(geofence, geofenceStatus, location);
        } catch (e) {
          // ignore or log
        }
      },
    );
    _service.addStreamErrorListener(
      (error) async {
        // Log to Firebase Crashlytics or console in real app
      },
    );
    await _service.start();
  }

  static Future<void> stop() async => _service.stop();
}
