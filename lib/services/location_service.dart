import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';
import 'firebase_service.dart';
import 'device_info_service.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  StreamSubscription<Position>? _positionStream;
  
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled, request to enable them
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        return LocationPermission.denied;
      }
    }
    
    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermission.denied;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // The user previously denied the permission. Show an educational UI.
      return LocationPermission.deniedForever;
    }
    
    return permission;
  }
  
  // Enable/disable background location updates
  Future<bool> enableBackgroundLocation({required bool enable}) async {
    try {
      if (enable) {
        // Configure for background location updates
        await Geolocator.requestPermission();
        await Geolocator.getCurrentPosition();
      }
      return true;
    } catch (e) {
      developer.log('Error configuring background location', error: e);
      return false;
    }
  }
  
  // Start tracking user's location
  Future<StreamSubscription<Position>> startTracking(String userId, Function(LatLng) onLocationUpdate) async {
    // Check if location services are enabled
    final bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    // Request permission (try to get background if possible)
    final permission = await requestLocationPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
    // On Android, request background location if not already granted
    // (geolocator handles this internally if you call requestPermission)

    try {
      // Get initial position
      final Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final initialLatLng = LatLng(initialPosition.latitude, initialPosition.longitude);
      onLocationUpdate(initialLatLng);
      await updateUserLocation(userId, initialLatLng);
    } catch (e) {
      print('Error getting initial position: $e');
    }

    // Configure location settings for background updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    // Start location stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      // Convert Position to LatLng and notify
      final latLng = LatLng(position.latitude, position.longitude);
      onLocationUpdate(latLng);
      // Update user's location in Firestore
      await updateUserLocation(userId, latLng);
      // Remove location history write
      // await saveLocationHistory(userId, position);
      // Also send device info and battery status
      await sendDeviceAndBatteryInfo(userId);
    });

    return _positionStream!;
  }

  // Stop tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }

  // Update user's current location
  Future<void> updateUserLocation(String userId, LatLng location) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'lastOnline': FieldValue.serverTimestamp(),
    });
  }

  // Save location to history
  Future<void> saveLocationHistory(String userId, Position position) async {
    final LocationModel location = LocationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      position: LatLng(position.latitude, position.longitude),
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection('locations')
        .doc(userId)
        .collection('history')
        .add(location.toMap());
  }

  // Get user's last known location
  Future<LatLng?> getLastKnownLocation(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || !userDoc.data()!.containsKey('lastLocation')) {
        return null;
      }

      final GeoPoint geoPoint = userDoc.data()!['lastLocation'] as GeoPoint;
      return LatLng(geoPoint.latitude, geoPoint.longitude);
    } catch (e) {
      print('Error getting last known location: $e');
      return null;
    }
  }
  
  // Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return const Distance().as(
      LengthUnit.Kilometer,
      point1,
      point2,
    );
  }

  // Stream of nearby users
  Stream<List<String>> getNearbyUsers(String userId, double radiusInKm) {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final List<String> nearbyUsers = [];
      final currentUserDoc = snapshot.docs.firstWhere(
        (doc) => doc.id == userId,
        orElse: () => throw Exception('Current user not found'),
      );

      final GeoPoint? currentUserLocation = 
          currentUserDoc.data()['lastLocation'] as GeoPoint?;
      if (currentUserLocation == null) return nearbyUsers;

      final currentUserLatLng = 
          LatLng(currentUserLocation.latitude, currentUserLocation.longitude);

      for (final doc in snapshot.docs) {
        if (doc.id == userId) continue;

        final GeoPoint? otherUserLocation = 
            doc.data()['lastLocation'] as GeoPoint?;
        if (otherUserLocation == null) continue;

        final otherUserLatLng = 
            LatLng(otherUserLocation.latitude, otherUserLocation.longitude);

        final distance = calculateDistance(currentUserLatLng, otherUserLatLng);
        if (distance <= radiusInKm) {
          nearbyUsers.add(doc.id);
        }
      }

      return nearbyUsers;
    });
  }

  // Stub: send device and battery info
  Future<void> sendDeviceAndBatteryInfo(String userId) async {
    await DeviceInfoService.sendDeviceAndBatteryInfo(userId);
  }

 void initBackgroundGeolocation() {
   // Background location tracking removed
}
}
