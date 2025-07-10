import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';
import 'firebase_service.dart';
import 'device_info_service.dart';
import '../utils/performance_optimizer.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocationService {
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final PerformanceOptimizer _performanceOptimizer = PerformanceOptimizer();
  static StreamSubscription<Position>? _positionStream;
  static const MethodChannel _bgChannel = MethodChannel('background_location');
  
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
      debugPrint('Error getting initial position: $e');
    }

    // Configure optimized location settings based on device performance
    final optimizedAccuracy = _performanceOptimizer.getOptimizedLocationAccuracy();
    final LocationSettings locationSettings = LocationSettings(
      accuracy: optimizedAccuracy <= 25 ? LocationAccuracy.high : 
                optimizedAccuracy <= 50 ? LocationAccuracy.medium : LocationAccuracy.low,
      distanceFilter: optimizedAccuracy.round(), // Use optimized distance filter (convert to int)
    );

    // Start background service for persistent location tracking
    if (Platform.isAndroid) {
      try {
        await _bgChannel.invokeMethod('start', {'userId': userId});
        debugPrint('Background location service started for user: $userId');
      } catch (e) {
        debugPrint('Background service error: $e');
        // Continue with Flutter-based updates as fallback
      }
    }

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
  static Future<void> stopRealtimeLocationUpdates() async {
    if (Platform.isAndroid) {
      try { 
        await _bgChannel.invokeMethod('stop'); 
        debugPrint('Background location service stopped');
      } catch (e) {
        debugPrint('Background service stop error: $e');
      }
    }
    await _positionStream?.cancel();
    _positionStream = null;
  }

  // Public wrapper for instance callers
  Future<void> stopTracking() async {
    await LocationService.stopRealtimeLocationUpdates();
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
      latitude: position.latitude,
      longitude: position.longitude,
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
      if (!userDoc.exists) {
        return null;
      }

      final data = userDoc.data()!;
      
      // Check for 'location' field first (current format)
      if (data.containsKey('location') && data['location'] != null) {
        final locationData = data['location'] as Map<String, dynamic>;
        if (locationData.containsKey('lat') && locationData.containsKey('lng')) {
          return LatLng(locationData['lat'], locationData['lng']);
        }
      }
      
      // Fallback to 'lastLocation' field (legacy format)
      if (data.containsKey('lastLocation')) {
        final GeoPoint geoPoint = data['lastLocation'] as GeoPoint;
        return LatLng(geoPoint.latitude, geoPoint.longitude);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting last known location: $e');
      return null;
    }
  }
  
  // Sync user's current location with Realtime Database (call this on login or app start)
  /// Usage: await syncLocationOnAppStartOrLogin(userId);
  Future<void> syncLocationOnAppStartOrLogin(String userId) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await saveLocationToRealtimeDatabase(userId, position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error syncing location on app start/login: $e');
    }
  }

  // Save latitude and longitude to Firebase Realtime Database
  /// Usage: await saveLocationToRealtimeDatabase(userId, latitude, longitude);
  Future<void> saveLocationToRealtimeDatabase(String userId, double latitude, double longitude) async {
    try {
      await _realtimeDb.ref('users/$userId/location').set({
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      debugPrint('Error saving location to Realtime Database: $e');
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

      // Get current user location using the correct field
      LatLng? currentUserLatLng;
      final currentUserData = currentUserDoc.data();
      
      if (currentUserData.containsKey('location') && currentUserData['location'] != null) {
        final locationData = currentUserData['location'] as Map<String, dynamic>;
        if (locationData.containsKey('lat') && locationData.containsKey('lng')) {
          currentUserLatLng = LatLng(locationData['lat'], locationData['lng']);
        }
      } else if (currentUserData.containsKey('lastLocation')) {
        final GeoPoint geoPoint = currentUserData['lastLocation'] as GeoPoint;
        currentUserLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
      }
      
      if (currentUserLatLng == null) return nearbyUsers;

      for (final doc in snapshot.docs) {
        if (doc.id == userId) continue;

        // Get other user location using the correct field
        LatLng? otherUserLatLng;
        final otherUserData = doc.data();
        
        if (otherUserData.containsKey('location') && otherUserData['location'] != null) {
          final locationData = otherUserData['location'] as Map<String, dynamic>;
          if (locationData.containsKey('lat') && locationData.containsKey('lng')) {
            otherUserLatLng = LatLng(locationData['lat'], locationData['lng']);
          }
        } else if (otherUserData.containsKey('lastLocation')) {
          final GeoPoint geoPoint = otherUserData['lastLocation'] as GeoPoint;
          otherUserLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
        }
        
        if (otherUserLatLng == null) continue;

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
