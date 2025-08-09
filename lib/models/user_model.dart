import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class UserModel {
  final String uid;
  final String id;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final String? photoUrl;
  final LatLng? lastLocation;
  final DateTime? lastSeen;
  final String? friendCode; // New
  final DateTime? createdAt;  // New
  final DateTime? updatedAt;  // New
  final bool locationSharingEnabled; // New - real-time location sharing status
  final DateTime? locationSharingUpdatedAt; // New - when status was last updated
  final String? relationship; // Add relationship field

  UserModel({
    required this.uid,
    required this.id,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.photoUrl,
    this.lastLocation,
    this.lastSeen,
    this.friendCode, // New
    this.createdAt,  // New
    this.updatedAt,  // New
    this.locationSharingEnabled = false, // New - defaults to false
    this.locationSharingUpdatedAt, // New
    this.relationship, // Add relationship field
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'id': id,
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'photoUrl': photoUrl,
      'lastLocation': lastLocation != null
          ? GeoPoint(lastLocation!.latitude, lastLocation!.longitude)
          : null,
      'lastSeen': lastSeen, // Stays as DateTime, Firestore converts to Timestamp
      'friendCode': friendCode, // New
      'createdAt': createdAt,   // New
      'updatedAt': updatedAt,   // New
      'locationSharingEnabled': locationSharingEnabled, // New
      'locationSharingUpdatedAt': locationSharingUpdatedAt, // New
      'relationship': relationship, // Add relationship field
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
      uid: map['uid'] ?? id,
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      photoUrl: map['photoUrl'],
      lastLocation: location,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      friendCode: map['friendCode'] as String?, // New
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(), // New
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(), // New
      locationSharingEnabled: map['locationSharingEnabled'] as bool? ?? false, // New
      locationSharingUpdatedAt: (map['locationSharingUpdatedAt'] as Timestamp?)?.toDate(), // New
      relationship: map['relationship'] as String?, // Add relationship field
    );
  }
}
