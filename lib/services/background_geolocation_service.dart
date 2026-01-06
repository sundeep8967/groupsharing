import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'firebase_service.dart';

class BackgroundGeolocationService {
  static const String _tag = 'BackgroundGeolocationService';

  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseService.firestore;
  static String? _currentUserId;
  static bool _isTracking = false;

  /// Initialize and configure the plugin
  static Future<void> initialize() async {
    developer.log('[$_tag] Initializing Flutter Background Geolocation (Production)...');

    // 1. Listen to events
    bg.BackgroundGeolocation.onLocation(_onLocation, _onLocationError);
    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
    bg.BackgroundGeolocation.onProviderChange(_onProviderChange);
    bg.BackgroundGeolocation.onConnectivityChange(_onConnectivityChange);

    // 2. Configure the plugin
    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 10.0,
      stopOnTerminate: false,
      startOnBoot: true,
      debug: false, // OFF for production (no sounds)
      logLevel: bg.Config.LOG_LEVEL_INFO,
      reset: true,
      // Android specific notification
      notification: bg.Notification(
        title: "Location Sharing Active",
        text: "Updating your location in background",
        priority: bg.Config.NOTIFICATION_PRIORITY_DEFAULT,
      ),
      // Background configuration
      enableHeadless: true,
      foregroundService: true,
    )).then((bg.State state) {
      developer.log("[$_tag] - Configuration ready: $state");
      _isTracking = state.enabled;
    });
  }

  /// Start tracking for a specific user
  static Future<void> startTracking(String userId) async {
    _currentUserId = userId;
    
    // Ensure initialized
    final state = await bg.BackgroundGeolocation.state;
    if (!state.enabled) {
      await bg.BackgroundGeolocation.start();
      _isTracking = true;
      developer.log("[$_tag] - Service started for user: $userId");
    } else {
      developer.log("[$_tag] - Service already running for user: $userId");
    }
    
    // Force a location update immediately
    bg.BackgroundGeolocation.getCurrentPosition(
      samples: 1, 
      persist: true
    ).then((bg.Location location) {
      developer.log("[$_tag] - Initial location: $location");
    }); // No catchError to keep it simple
  }

  /// Stop tracking
  static Future<void> stopTracking() async {
    await bg.BackgroundGeolocation.stop();
    _isTracking = false;
    _currentUserId = null;
    developer.log("[$_tag] - Service stopped");
  }

  // --- Event Handlers ---

  static void _onLocation(bg.Location location) {
    developer.log('[$_tag] [onLocation] $location');
    _updateFirebaseLocation(location);
  }

  static void _onLocationError(bg.LocationError error) {
    developer.log('[$_tag] [onLocation] ERROR: $error');
  }

  static void _onMotionChange(bg.Location location) {
    developer.log('[$_tag] [onMotionChange] $location');
    _updateFirebaseLocation(location);
  }

  static void _onProviderChange(bg.ProviderChangeEvent event) {
    developer.log('[$_tag] [onProviderChange] $event');
  }

  static void _onConnectivityChange(bg.ConnectivityChangeEvent event) {
    developer.log('[$_tag] [onConnectivityChange] $event');
  }

  // --- Firebase Integration ---

  static Future<void> _updateFirebaseLocation(bg.Location bgLocation) async {
    if (_currentUserId == null) return;

    try {
      final lat = bgLocation.coords.latitude;
      final lng = bgLocation.coords.longitude;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Update Realtime Database (Matches old format)
      await _realtimeDb.ref('locations/${_currentUserId}').set({
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp,
        'isSharing': true,
        'accuracy': bgLocation.coords.accuracy,
        'speed': bgLocation.coords.speed,
        'heading': bgLocation.coords.heading,
        'battery': bgLocation.battery.level,
        'isMoving': bgLocation.isMoving,
      });
      
      // Update Firestore (Matches old format)
      await _firestore.collection('users').doc(_currentUserId!).update({
        'location': {
          'lat': lat,
          'lng': lng,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      
      developer.log('[$_tag] Firebase updated: $lat, $lng');
    } catch (e) {
      developer.log('[$_tag] Failed to update Firebase: $e');
    }
  }
}
