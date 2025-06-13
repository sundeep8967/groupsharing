import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class LocationModel {
  final String id;
  final String userId;
  final LatLng position;
  final DateTime timestamp;
  final String? address;

  LocationModel({
    required this.id,
    required this.userId,
    required this.position,
    required this.timestamp,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'position': GeoPoint(position.latitude, position.longitude),
      'timestamp': timestamp,
      'address': address,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map, String id) {
    final GeoPoint geoPoint = map['position'] as GeoPoint;
    
    return LocationModel(
      id: id,
      userId: map['userId'] as String,
      position: LatLng(geoPoint.latitude, geoPoint.longitude),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      address: map['address'] as String?,
    );
  }

  double calculateDistance(LatLng other) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, position, other);
  }
}
