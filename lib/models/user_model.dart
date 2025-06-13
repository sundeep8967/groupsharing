import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final LatLng? lastLocation;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.lastLocation,
    this.lastSeen,
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
      'lastSeen': lastSeen,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final GeoPoint? geoPoint = map['lastLocation'] as GeoPoint?;
    
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      lastLocation: geoPoint != null 
          ? LatLng(geoPoint.latitude, geoPoint.longitude)
          : null,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
    );
  }
}
