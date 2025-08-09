import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class LocationModel {
  final String id;
  final String userId;
  final LatLng position;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;
  final double? speed;
  final double? accuracy;
  final double? altitude;

  LocationModel({
    required this.id,
    required this.userId,
    required this.position,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
    this.speed,
    this.accuracy,
    this.altitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'position': GeoPoint(position.latitude, position.longitude),
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'address': address,
      'speed': speed,
      'accuracy': accuracy,
      'altitude': altitude,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map, String id) {
    final GeoPoint? geoPoint = map['position'] as GeoPoint?;
    final double lat = map['latitude'] ?? geoPoint?.latitude ?? 0.0;
    final double lng = map['longitude'] ?? geoPoint?.longitude ?? 0.0;
    
    return LocationModel(
      id: id,
      userId: map['userId'] as String,
      position: LatLng(lat, lng),
      latitude: lat,
      longitude: lng,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      address: map['address'] as String?,
      speed: map['speed'] as double?,
      accuracy: map['accuracy'] as double?,
      altitude: map['altitude'] as double?,
    );
  }

  double calculateDistance(LatLng other) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, position, other);
  }
}
