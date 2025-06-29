import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Life360-style Location Service that works even when app is killed
/// This service provides the same reliability as Google Maps and Life360
/// by using native platform services that survive app termination
class Life360LocationService {
  static const String _tag = 'Life360LocationService';
  
  // Platform channels for native services
  static const MethodChannel _locationChannel = MethodChannel('persistent_location_service');
  static const MethodChannel _backgroundChannel = MethodChannel('background_location');
  
  // Service state
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static String? _currentUserId;
  
  // Callbacks
  static Function(LatLng)? _onLocationUpdate;
  static Function(String)? _onError;
  static Function()? _onServiceStopped;
  
  // Health monitoring
  static Timer? _healthCheckTimer;
  static DateTime? _lastLocationUpdate;
  
  /// Initialize the Life360-style location service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Life360-style location service');
      
      // Setup platform channel handlers
      await _setupChannelHandlers();
      
      // Check if we need to restore previous tracking state
      await _restoreTrackingState();
      
      _isInitialized = true;
      developer.log('[$_tag] Life360-style location service initialized successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      return false;
    }
  }
  
  /// Start persistent location tracking like Life360
  static Future<bool> startTracking({
    required String userId,
    Function(LatLng)? onLocationUpdate,
    Function(String)? onError,
    Function()? onServiceStopped,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isTracking && _currentUserId == userId) {
      developer.log('[$_tag] Location tracking already active for this user');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting Life360-style location tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      _onLocationUpdate = onLocationUpdate;
      _onError = onError;
      _onServiceStopped = onServiceStopped;
      
      // Step 1: Check and request all necessary permissions
      final hasPermissions = await _ensureAllPermissions();
      if (!hasPermissions) {
        _onError?.call('Required permissions not granted');
        return false;
      }
      
      // Step 2: Handle battery optimization (critical for Android)
      await _handleBatteryOptimization();
      
      // Step 3: Save tracking state for persistence
      await _saveTrackingState(userId, true);
      
      // Step 4: Start native background services (primary method)
      final nativeStarted = await _startNativeServices(userId);
      if (!nativeStarted) {
        developer.log('[$_tag] Native services failed to start, this may affect reliability');
      }
      
      // Step 5: Start Flutter location tracking (fallback/supplement)
      await _startFlutterLocationTracking();
      
      // Step 6: Start health monitoring
      await _startHealthMonitoring();
      
      // Step 7: Send initial location and heartbeat
      await _sendInitialData();
      
      _isTracking = true;
      _lastLocationUpdate = DateTime.now();
      
      developer.log('[$_tag] Life360-style location tracking started successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to start tracking: $e');
      _onError?.call('Failed to start location tracking: $e');
      return false;
    }
  }
  
  /// Stop location tracking
  static Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('[$_tag] Stopping Life360-style location tracking');
      
      // Save state
      if (_currentUserId != null) {
        await _saveTrackingState(_currentUserId!, false);
      }
      
      // Stop native services
      await _stopNativeServices();
      
      // Stop Flutter tracking
      await _stopFlutterLocationTracking();
      
      // Stop health monitoring
      await _stopHealthMonitoring();
      
      // Clear location data
      if (_currentUserId != null) {
        await _clearLocationData(_currentUserId!);
      }
      
      _isTracking = false;
      _currentUserId = null;
      _lastLocationUpdate = null;
      
      developer.log('[$_tag] Location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to stop tracking: $e');
      return false;
    }
  }
  
  /// Check if tracking is currently active
  static bool get isTracking => _isTracking;
  
  /// Get current user ID
  static String? get currentUserId => _currentUserId;
  
  /// Get last location update time
  static DateTime? get lastLocationUpdate => _lastLocationUpdate;
  
  // Private implementation methods
  
  static Future<void> _setupChannelHandlers() async {
    _locationChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLocationUpdate':
          await _handleLocationUpdate(call.arguments);
          break;
        case 'onError':
          _handleError(call.arguments['error'] as String);
          break;
        case 'onServiceStopped':
          _handleServiceStopped();
          break;
      }
    });
    
    _backgroundChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLocationUpdate':
          await _handleLocationUpdate(call.arguments);
          break;
        case 'onError':
          _handleError(call.arguments['error'] as String);
          break;
      }
    });
  }
  
  static Future<void> _handleLocationUpdate(dynamic arguments) async {
    try {
      final lat = arguments['latitude'] as double;
      final lng = arguments['longitude'] as double;
      final location = LatLng(lat, lng);
      
      _lastLocationUpdate = DateTime.now();
      _onLocationUpdate?.call(location);
      
      // Update Firebase
      if (_currentUserId != null) {
        await _updateFirebaseLocation(_currentUserId!, location);
      }
    } catch (e) {
      developer.log('[$_tag] Error handling location update: $e');
    }
  }
  
  static void _handleError(String error) {
    developer.log('[$_tag] Location error: $error');
    _onError?.call(error);
  }
  
  static void _handleServiceStopped() {
    developer.log('[$_tag] Native service stopped unexpectedly');
    _isTracking = false;
    _onServiceStopped?.call();
    
    // Attempt to restart if we should be tracking
    if (_currentUserId != null) {
      _attemptRestart();
    }
  }
  
  static Future<bool> _ensureAllPermissions() async {
    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('[$_tag] Location services are disabled');
        return false;
      }
      
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          developer.log('[$_tag] Location permission denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        developer.log('[$_tag] Location permission denied forever');
        return false;
      }
      
      // For Android, request background location permission
      if (Platform.isAndroid) {
        try {
          await _locationChannel.invokeMethod('requestBackgroundLocationPermission');
        } catch (e) {
          developer.log('[$_tag] Background location permission request failed: $e');
        }
      }
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Error checking permissions: $e');
      return false;
    }
  }
  
  static Future<void> _handleBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    
    try {
      // Check if battery optimization is disabled
      final isOptimized = await _locationChannel.invokeMethod('isBatteryOptimized') ?? true;
      
      if (isOptimized) {
        developer.log('[$_tag] Battery optimization is enabled, requesting to disable');
        await _locationChannel.invokeMethod('requestDisableBatteryOptimization');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling battery optimization: $e');
    }
  }
  
  static Future<void> _saveTrackingState(String userId, bool isTracking) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('life360_location_tracking', isTracking);
      await prefs.setString('life360_user_id', userId);
      await prefs.setInt('life360_tracking_start_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      developer.log('[$_tag] Error saving tracking state: $e');
    }
  }
  
  static Future<bool> _startNativeServices(String userId) async {
    try {
      // Start iOS native service
      if (Platform.isIOS) {
        final result = await _locationChannel.invokeMethod('startBackgroundLocationService', {
          'userId': userId,
        });
        return result == true;
      }
      
      // Start Android native service
      if (Platform.isAndroid) {
        final result = await _backgroundChannel.invokeMethod('start', {
          'userId': userId,
        });
        return result == true;
      }
      
      return false;
    } catch (e) {
      developer.log('[$_tag] Error starting native services: $e');
      return false;
    }
  }
  
  static Future<void> _stopNativeServices() async {
    try {
      if (Platform.isIOS) {
        await _locationChannel.invokeMethod('stopBackgroundLocationService');
      }
      
      if (Platform.isAndroid) {
        await _backgroundChannel.invokeMethod('stop');
      }
    } catch (e) {
      developer.log('[$_tag] Error stopping native services: $e');
    }
  }
  
  static StreamSubscription<Position>? _locationSubscription;
  
  static Future<void> _startFlutterLocationTracking() async {
    try {
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handleLocationUpdate({
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
        },
        onError: (error) {
          _handleError('Flutter location stream error: $error');
        },
      );
    } catch (e) {
      developer.log('[$_tag] Error starting Flutter location tracking: $e');
    }
  }
  
  static Future<void> _stopFlutterLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }
  
  static Future<void> _startHealthMonitoring() async {
    _healthCheckTimer?.cancel();
    
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      await _performHealthCheck();
    });
  }
  
  static Future<void> _stopHealthMonitoring() async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }
  
  static Future<void> _performHealthCheck() async {
    try {
      // Check if we've received a location update recently
      if (_lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceLastUpdate.inMinutes > 5) {
          developer.log('[$_tag] No location updates for ${timeSinceLastUpdate.inMinutes} minutes, attempting restart');
          await _attemptRestart();
        }
      }
      
      // Check if native services are still running
      final nativeHealthy = await _checkNativeServiceHealth();
      if (!nativeHealthy) {
        developer.log('[$_tag] Native service health check failed, attempting restart');
        await _attemptRestart();
      }
      
      // Send heartbeat
      await _sendHeartbeat();
    } catch (e) {
      developer.log('[$_tag] Error during health check: $e');
    }
  }
  
  static Future<bool> _checkNativeServiceHealth() async {
    try {
      if (Platform.isIOS) {
        return await _locationChannel.invokeMethod('isServiceHealthy') ?? false;
      }
      
      if (Platform.isAndroid) {
        return await _backgroundChannel.invokeMethod('isServiceRunning') ?? false;
      }
      
      return false;
    } catch (e) {
      developer.log('[$_tag] Error checking native service health: $e');
      return false;
    }
  }
  
  static Future<void> _attemptRestart() async {
    if (_currentUserId == null) return;
    
    try {
      developer.log('[$_tag] Attempting to restart location services');
      
      // Stop current services
      await _stopNativeServices();
      await _stopFlutterLocationTracking();
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 2));
      
      // Restart services
      await _startNativeServices(_currentUserId!);
      await _startFlutterLocationTracking();
      
      developer.log('[$_tag] Location services restarted successfully');
    } catch (e) {
      developer.log('[$_tag] Error restarting services: $e');
      _onError?.call('Service restart failed: $e');
    }
  }
  
  static Future<void> _sendInitialData() async {
    if (_currentUserId == null) return;
    
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final location = LatLng(position.latitude, position.longitude);
      await _updateFirebaseLocation(_currentUserId!, location);
      await _sendHeartbeat();
    } catch (e) {
      developer.log('[$_tag] Error sending initial data: $e');
    }
  }
  
  static Future<void> _updateFirebaseLocation(String userId, LatLng location) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Update Realtime Database for instant sync
      final realtimeDb = FirebaseDatabase.instance;
      await realtimeDb.ref('locations/$userId').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'isSharing': true,
        'timestamp': timestamp,
        'source': 'life360_service',
        'lastUpdate': ServerValue.timestamp,
      });
      
      // Update Firestore for persistence
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
          'timestamp': timestamp,
        },
        'locationSharingEnabled': true,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      developer.log('[$_tag] Location updated in Firebase: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      developer.log('[$_tag] Error updating Firebase location: $e');
    }
  }
  
  static Future<void> _sendHeartbeat() async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Update Realtime Database
      final realtimeDb = FirebaseDatabase.instance;
      await realtimeDb.ref('users/$_currentUserId').update({
        'lastHeartbeat': timestamp,
        'appUninstalled': false,
        'serviceActive': true,
        'lastSeen': ServerValue.timestamp,
      });
      
      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(_currentUserId!).update({
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'appUninstalled': false,
        'serviceActive': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('[$_tag] Error sending heartbeat: $e');
    }
  }
  
  static Future<void> _clearLocationData(String userId) async {
    try {
      // Remove from Realtime Database
      final realtimeDb = FirebaseDatabase.instance;
      await realtimeDb.ref('locations/$userId').remove();
      
      // Update status in both databases
      await realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': false,
        'serviceActive': false,
        'lastSeen': ServerValue.timestamp,
      });
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': false,
        'location': null,
        'serviceActive': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('[$_tag] Error clearing location data: $e');
    }
  }
  
  static Future<void> _restoreTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('life360_location_tracking') ?? false;
      final userId = prefs.getString('life360_user_id');
      
      if (wasTracking && userId != null) {
        developer.log('[$_tag] Restoring location tracking for user: ${userId.substring(0, 8)}');
        // Don't auto-start, just restore state variables
        _currentUserId = userId;
        _isTracking = false; // Will be set to true when startTracking is called
      }
    } catch (e) {
      developer.log('[$_tag] Error restoring tracking state: $e');
    }
  }
  
  /// Check if the service needs to be restored (call this on app startup)
  static Future<bool> shouldRestoreTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('life360_location_tracking') ?? false;
      final userId = prefs.getString('life360_user_id');
      return wasTracking && userId != null;
    } catch (e) {
      developer.log('[$_tag] Error checking restore state: $e');
      return false;
    }
  }
  
  /// Get the user ID that should be restored
  static Future<String?> getRestoreUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('life360_user_id');
    } catch (e) {
      developer.log('[$_tag] Error getting restore user ID: $e');
      return null;
    }
  }
  
  /// Cleanup when app is being terminated
  static Future<void> cleanup() async {
    try {
      await stopTracking();
      _isInitialized = false;
    } catch (e) {
      developer.log('[$_tag] Error during cleanup: $e');
    }
  }
}