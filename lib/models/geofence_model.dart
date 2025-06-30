import 'package:latlong2/latlong.dart';
import 'package:geofence_service/geofence_service.dart';

/// Enhanced Geofence Model for Ultra-Precise Geofencing
class GeofenceModel {
  final String id;
  final LatLng center;
  final double radius;
  final String name;
  final bool isActive;
  final Map<String, dynamic> metadata;
  
  // Runtime state
  bool isInside;
  DateTime? lastTriggered;
  DateTime? createdAt;

  GeofenceModel({
    required this.id,
    required this.center,
    required this.radius,
    required this.name,
    this.isActive = true,
    this.metadata = const {},
    this.isInside = false,
    this.lastTriggered,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GeofenceModel.fromMap(Map<String, dynamic> data, String id) {
    return GeofenceModel(
      id: id,
      center: LatLng(
        (data['center']['lat'] as num).toDouble(),
        (data['center']['lng'] as num).toDouble(),
      ),
      radius: (data['radius'] as num?)?.toDouble() ?? 5.0,
      name: data['name'] as String? ?? 'Geofence $id',
      isActive: data['isActive'] as bool? ?? true,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      isInside: data['isInside'] as bool? ?? false,
      lastTriggered: data['lastTriggered'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['lastTriggered'] as int)
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'center': {
          'lat': center.latitude,
          'lng': center.longitude,
        },
        'radius': radius,
        'name': name,
        'isActive': isActive,
        'metadata': metadata,
        'isInside': isInside,
        'lastTriggered': lastTriggered?.millisecondsSinceEpoch,
        'createdAt': createdAt?.millisecondsSinceEpoch,
      };

  /// Create a copy with updated values
  GeofenceModel copyWith({
    String? id,
    LatLng? center,
    double? radius,
    String? name,
    bool? isActive,
    Map<String, dynamic>? metadata,
    bool? isInside,
    DateTime? lastTriggered,
    DateTime? createdAt,
  }) {
    return GeofenceModel(
      id: id ?? this.id,
      center: center ?? this.center,
      radius: radius ?? this.radius,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      isInside: isInside ?? this.isInside,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to geofence_service Geofence object
  Geofence toGeofence() {
    return Geofence(
      id: id,
      latitude: center.latitude,
      longitude: center.longitude,
      radius: [
        GeofenceRadius(id: '${id}_radius', length: radius),
      ],
    );
  }

  @override
  String toString() {
    return 'GeofenceModel(id: $id, name: $name, center: $center, radius: ${radius}m, isInside: $isInside)';
  }
}
