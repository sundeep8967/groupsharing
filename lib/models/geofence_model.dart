import 'package:geofence_service/geofence_service.dart';

/// Represents a user-defined geofence that is persisted to Firebase.
class GeofenceModel {
  final String id;
  final double latitude;
  final double longitude;
  /// Radius list in metres. Multiple concentric radii are allowed.
  final List<double> radii;

  GeofenceModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radii,
  });

  factory GeofenceModel.fromMap(Map<String, dynamic> data, String id) {
    return GeofenceModel(
      id: id,
      latitude: (data['lat'] as num).toDouble(),
      longitude: (data['lng'] as num).toDouble(),
      radii: List<double>.from(data['radii'] ?? const [150.0]),
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': latitude,
        'lng': longitude,
        'radii': radii,
      };

  /// Converts this model to the [Geofence] object required by geofence_service.
  Geofence toGeofence() => Geofence(
        id: id,
        latitude: latitude,
        longitude: longitude,
        radius: [
          for (final r in radii) GeofenceRadius(id: '${id}_$r', length: r),
        ],
      );
}
