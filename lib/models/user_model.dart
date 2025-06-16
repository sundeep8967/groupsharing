import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final LatLng? lastLocation;
  final DateTime? lastSeen;
  final String? friendCode; // New
  final DateTime? createdAt;  // New
  final DateTime? updatedAt;  // New

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.lastLocation,
    this.lastSeen,
    this.friendCode, // New
    this.createdAt,  // New
    this.updatedAt,  // New
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'lastLocation': lastLocation != null
          ? GeoPoint(lastLocation!.latitude, lastLocation!.longitude)
          : null,
      'lastSeen': lastSeen, // Stays as DateTime, Firestore converts to Timestamp
      'friendCode': friendCode, // New
      'createdAt': createdAt,   // New
      'updatedAt': updatedAt,   // New
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    // Try 'lastLocation' (GeoPoint), fallback to 'location' (Map with lat/lng)
    LatLng? location;
    final GeoPoint? geoPoint = map['lastLocation'] as GeoPoint?;
    if (geoPoint != null) {
      location = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else if (map['location'] != null && map['location'] is Map) {
      final locMap = map['location'] as Map;
      final lat = locMap['lat'];
      final lng = locMap['lng'];
      if (lat != null && lng != null) {
        location = LatLng((lat as num).toDouble(), (lng as num).toDouble());
      }
    }
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      lastLocation: location,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      friendCode: map['friendCode'] as String?, // New
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(), // New
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(), // New
    );
  }
}
