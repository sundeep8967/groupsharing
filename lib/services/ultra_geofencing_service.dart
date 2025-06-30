import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_model.dart';

/// Ultra-Active Geofencing Service with 5-meter precision
/// This service provides military-grade location tracking that works even when:
/// - Flutter app is killed
/// - Phone is restarted
/// - Battery optimization is enabled
/// - Phone is in doze mode
class UltraGeofencingService {
  static const String _tag = 'UltraGeofencing';
  
  // Platform channels for native services
  static const MethodChannel _locationChannel = MethodChannel('ultra_geofencing_service');
  static const MethodChannel _nativeChannel = MethodChannel('native_location_service');
  
  // Ultra-precise configuration
  static const double _geofenceRadius = 5.0; // 5 meters precision
  static const Duration _ultraActiveInterval = Duration(seconds: 5); // Every 5 seconds
  static const Duration _normalInterval = Duration(seconds: 15); // Normal mode
  static const Duration _heartbeatInterval = Duration(seconds: 10); // Frequent heartbeat
  static const LocationAccuracy _ultraAccuracy = LocationAccuracy.bestForNavigation;
  
  // Service state
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static bool _isUltraActive = false;
  static String? _currentUserId;
  static LatLng? _lastKnownLocation;
  static DateTime? _lastLocationUpdate;
  
  // Geofencing state
  static final List<GeofenceModel> _activeGeofences = [];
  static final Map<String, LatLng> _geofenceLocations = {};
  static Timer? _ultraActiveTimer;
  static Timer? _heartbeatTimer;
  static Timer? _healthCheckTimer;
  
  // Callbacks
  static Function(LatLng, double)? _onLocationUpdate;
  static Function(GeofenceModel, bool)? _onGeofenceEvent;
  static Function(String)? _onError;
  
  /// Initialize ultra-active geofencing service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Ultra-Active Geofencing Service');
      
      // Setup platform channel handlers
      await _setupChannelHandlers();
      
      // Initialize native background services
      await _initializeNativeServices();
      
      // Setup battery optimization bypass
      await _bypassBatteryOptimization();
      
      // Register background task handlers
      await _registerBackgroundHandlers();
      
      // Restore previous state
      await _restoreTrackingState();
      
      _isInitialized = true;
      developer.log('[$_tag] Ultra-Active Geofencing Service initialized successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      return false;
    }
  }
  
  /// Start ultra-active location tracking with geofencing
  static Future<bool> startUltraActiveTracking({
    required String userId,
    bool ultraActive = true,
    Function(LatLng, double)? onLocationUpdate,
    Function(GeofenceModel, bool)? onGeofenceEvent,
    Function(String)? onError,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    try {
      developer.log('[$_tag] Starting ultra-active tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      _isUltraActive = ultraActive;
      _onLocationUpdate = onLocationUpdate;
      _onGeofenceEvent = onGeofenceEvent;
      _onError = onError;
      
      // Ensure all permissions are granted
      final hasPermissions = await _ensureAllPermissions();
      if (!hasPermissions) {
        _onError?.call('Critical permissions not granted');
        return false;
      }
      
      // Save tracking state for persistence
      await _saveTrackingState(userId, true, ultraActive);
      
      // Start native background services (survives app termination)
      await _startNativeBackgroundServices(userId);
      
      // Start ultra-active location monitoring
      await _startUltraActiveLocationMonitoring();
      
      // Start geofencing system
      await _startGeofencingSystem();
      
      // Start health monitoring and heartbeat
      await _startHealthMonitoring();
      
      // Send initial location
      await _sendInitialLocation();
      
      _isTracking = true;
      _lastLocationUpdate = DateTime.now();
      
      developer.log('[$_tag] Ultra-active tracking started successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to start ultra-active tracking: $e');
      _onError?.call('Failed to start tracking: $e');
      return false;
    }
  }
  
  /// Add geofence with 5-meter precision
  static Future<bool> addGeofence({
    required String id,
    required LatLng center,
    double radius = 5.0,
    String? name,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final geofence = GeofenceModel(
        id: id,
        center: center,
        radius: radius,
        name: name ?? 'Geofence $id',
        isActive: true,
        metadata: metadata ?? {},
      );
      
      _activeGeofences.add(geofence);
      _geofenceLocations[id] = center;
      
      // Register with native service for background monitoring
      await _registerNativeGeofence(geofence);
      
      developer.log('[$_tag] Added geofence: $id at ${center.latitude}, ${center.longitude} (${radius}m)');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to add geofence: $e');
      return false;
    }
  }
  
  /// Start ultra-active location monitoring
  static Future<void> _startUltraActiveLocationMonitoring() async {
    try {
      // Start native location service with ultra-high precision
      await _nativeChannel.invokeMethod('startUltraActiveTracking', {
        'userId': _currentUserId,
        'interval': _isUltraActive ? _ultraActiveInterval.inMilliseconds : _normalInterval.inMilliseconds,
        'accuracy': 'bestForNavigation',
        'distanceFilter': _geofenceRadius,
        'backgroundMode': true,
        'persistentMode': true,
      });
      
      // Start Flutter-based monitoring as backup
      _ultraActiveTimer?.cancel();
      _ultraActiveTimer = Timer.periodic(
        _isUltraActive ? _ultraActiveInterval : _normalInterval,
        (timer) => _performLocationCheck(),
      );
      
      developer.log('[$_tag] Ultra-active location monitoring started');
    } catch (e) {
      developer.log('[$_tag] Error starting location monitoring: $e');
    }
  }
  
  /// Perform location check with geofencing
  static Future<void> _performLocationCheck() async {
    try {
      // Get current location with ultra-high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _ultraAccuracy,
        timeLimit: const Duration(seconds: 10),
      );
      
      final currentLocation = LatLng(position.latitude, position.longitude);
      final accuracy = position.accuracy;
      
      // Check if location changed by 5+ meters
      if (_lastKnownLocation != null) {
        final distance = _calculateDistance(_lastKnownLocation!, currentLocation);
        if (distance < _geofenceRadius) {
          // Location hasn't changed significantly, skip update
          return;
        }
      }
      
      _lastKnownLocation = currentLocation;
      _lastLocationUpdate = DateTime.now();
      
      // Process geofences
      await _processGeofences(currentLocation);
      
      // Update Firebase with high precision
      await _updateFirebaseLocation(currentLocation, accuracy);
      
      // Notify callback
      _onLocationUpdate?.call(currentLocation, accuracy);
      
      developer.log('[$_tag] Location updated: ${currentLocation.latitude}, ${currentLocation.longitude} (±${accuracy}m)');
    } catch (e) {
      developer.log('[$_tag] Error during location check: $e');
      _onError?.call('Location check failed: $e');
    }
  }
  
  /// Process geofences for current location
  static Future<void> _processGeofences(LatLng currentLocation) async {
    for (final geofence in _activeGeofences) {
      if (!geofence.isActive) continue;
      
      final distance = _calculateDistance(currentLocation, geofence.center);
      final isInside = distance <= geofence.radius;
      
      // Check for geofence entry/exit
      if (isInside != geofence.isInside) {
        geofence.isInside = isInside;
        geofence.lastTriggered = DateTime.now();
        
        // Trigger geofence event
        _onGeofenceEvent?.call(geofence, isInside);
        
        // Update Firebase with geofence event
        await _updateGeofenceEvent(geofence, isInside, currentLocation);
        
        developer.log('[$_tag] Geofence ${isInside ? "ENTERED" : "EXITED"}: ${geofence.name} (${distance.toStringAsFixed(1)}m)');
      }
    }
  }
  
  /// Update Firebase with location data
  static Future<void> _updateFirebaseLocation(LatLng location, double accuracy) async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final realtimeDb = FirebaseDatabase.instance;
      
      // Update Realtime Database for instant sync
      await realtimeDb.ref('locations/${_currentUserId!}').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'timestamp': timestamp,
        'accuracy': accuracy,
        'isSharing': true,
        'isUltraActive': _isUltraActive,
        'geofenceRadius': _geofenceRadius,
        'lastUpdate': ServerValue.timestamp,
      });
      
      // Update user status
      await realtimeDb.ref('users/${_currentUserId!}').update({
        'locationSharingEnabled': true,
        'lastLocationUpdate': ServerValue.timestamp,
        'lastHeartbeat': ServerValue.timestamp,
        'isUltraActive': _isUltraActive,
        'accuracy': accuracy,
      });
      
      // Also update Firestore for persistence
      await FirebaseFirestore.instance.collection('users').doc(_currentUserId!).update({
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'accuracy': accuracy,
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'isUltraActive': _isUltraActive,
      });
      
    } catch (e) {
      developer.log('[$_tag] Error updating Firebase: $e');
    }
  }
  
  /// Update Firebase with geofence event
  static Future<void> _updateGeofenceEvent(GeofenceModel geofence, bool entered, LatLng location) async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final realtimeDb = FirebaseDatabase.instance;
      
      // Create geofence event
      final eventData = {
        'geofenceId': geofence.id,
        'geofenceName': geofence.name,
        'event': entered ? 'enter' : 'exit',
        'timestamp': timestamp,
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
        },
        'geofenceCenter': {
          'lat': geofence.center.latitude,
          'lng': geofence.center.longitude,
        },
        'radius': geofence.radius,
        'distance': _calculateDistance(location, geofence.center),
        'userId': _currentUserId,
      };
      
      // Store in geofence events
      await realtimeDb.ref('geofence_events').push().set(eventData);
      
      // Update user's current geofences
      await realtimeDb.ref('users/${_currentUserId!}/currentGeofences/${geofence.id}').set({
        'isInside': entered,
        'lastTriggered': ServerValue.timestamp,
        'geofenceName': geofence.name,
      });
      
    } catch (e) {
      developer.log('[$_tag] Error updating geofence event: $e');
    }
  }
  
  /// Start health monitoring and heartbeat
  static Future<void> _startHealthMonitoring() async {
    // Heartbeat timer
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      await _sendHeartbeat();
    });
    
    // Health check timer
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _performHealthCheck();
    });
    
    developer.log('[$_tag] Health monitoring started');
  }
  
  /// Send heartbeat to Firebase
  static Future<void> _sendHeartbeat() async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final realtimeDb = FirebaseDatabase.instance;
      
      await realtimeDb.ref('users/${_currentUserId!}').update({
        'lastHeartbeat': ServerValue.timestamp,
        'isAlive': true,
        'serviceActive': _isTracking,
        'ultraActive': _isUltraActive,
        'lastHeartbeatLocal': timestamp,
      });
      
    } catch (e) {
      developer.log('[$_tag] Error sending heartbeat: $e');
    }
  }
  
  /// Perform health check
  static Future<void> _performHealthCheck() async {
    try {
      // Check if location service is still active
      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        developer.log('[$_tag] Location service disabled, attempting restart');
        await _restartLocationService();
      }
      
      // Check if we have recent location updates
      if (_lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceLastUpdate > const Duration(minutes: 2)) {
          developer.log('[$_tag] No recent location updates, restarting service');
          await _restartLocationService();
        }
      }
      
      // Check native service health
      final nativeHealth = await _checkNativeServiceHealth();
      if (!nativeHealth) {
        developer.log('[$_tag] Native service unhealthy, restarting');
        await _restartNativeServices();
      }
      
    } catch (e) {
      developer.log('[$_tag] Error during health check: $e');
    }
  }
  
  /// Calculate distance between two points in meters
  static double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
  
  /// Setup platform channel handlers
  static Future<void> _setupChannelHandlers() async {
    _locationChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLocationUpdate':
          final lat = call.arguments['lat'] as double;
          final lng = call.arguments['lng'] as double;
          final accuracy = call.arguments['accuracy'] as double;
          final location = LatLng(lat, lng);
          await _handleNativeLocationUpdate(location, accuracy);
          break;
        case 'onGeofenceEvent':
          final geofenceId = call.arguments['geofenceId'] as String;
          final entered = call.arguments['entered'] as bool;
          await _handleNativeGeofenceEvent(geofenceId, entered);
          break;
        case 'onError':
          final error = call.arguments['error'] as String;
          _onError?.call(error);
          break;
      }
    });
  }
  
  /// Handle native location update
  static Future<void> _handleNativeLocationUpdate(LatLng location, double accuracy) async {
    // Check if location changed by 5+ meters
    if (_lastKnownLocation != null) {
      final distance = _calculateDistance(_lastKnownLocation!, location);
      if (distance < _geofenceRadius) return;
    }
    
    _lastKnownLocation = location;
    _lastLocationUpdate = DateTime.now();
    
    // Process geofences
    await _processGeofences(location);
    
    // Update Firebase
    await _updateFirebaseLocation(location, accuracy);
    
    // Notify callback
    _onLocationUpdate?.call(location, accuracy);
  }
  
  /// Handle native geofence event
  static Future<void> _handleNativeGeofenceEvent(String geofenceId, bool entered) async {
    final geofence = _activeGeofences.firstWhere(
      (g) => g.id == geofenceId,
      orElse: () => GeofenceModel(id: '', center: const LatLng(0, 0), radius: 0, name: ''),
    );
    
    if (geofence.id.isNotEmpty) {
      geofence.isInside = entered;
      geofence.lastTriggered = DateTime.now();
      _onGeofenceEvent?.call(geofence, entered);
      
      if (_lastKnownLocation != null) {
        await _updateGeofenceEvent(geofence, entered, _lastKnownLocation!);
      }
    }
  }
  
  /// Initialize native services
  static Future<void> _initializeNativeServices() async {
    try {
      if (Platform.isAndroid) {
        await _nativeChannel.invokeMethod('initializeAndroidService');
      } else if (Platform.isIOS) {
        await _nativeChannel.invokeMethod('initializeIOSService');
      }
    } catch (e) {
      developer.log('[$_tag] Error initializing native services: $e');
    }
  }
  
  /// Start native background services
  static Future<void> _startNativeBackgroundServices(String userId) async {
    try {
      await _nativeChannel.invokeMethod('startBackgroundService', {
        'userId': userId,
        'ultraActive': _isUltraActive,
        'geofenceRadius': _geofenceRadius,
        'interval': _isUltraActive ? _ultraActiveInterval.inMilliseconds : _normalInterval.inMilliseconds,
      });
    } catch (e) {
      developer.log('[$_tag] Error starting native services: $e');
    }
  }
  
  /// Register native geofence
  static Future<void> _registerNativeGeofence(GeofenceModel geofence) async {
    try {
      await _nativeChannel.invokeMethod('addGeofence', {
        'id': geofence.id,
        'lat': geofence.center.latitude,
        'lng': geofence.center.longitude,
        'radius': geofence.radius,
        'name': geofence.name,
      });
    } catch (e) {
      developer.log('[$_tag] Error registering native geofence: $e');
    }
  }
  
  /// Bypass battery optimization
  static Future<void> _bypassBatteryOptimization() async {
    try {
      if (Platform.isAndroid) {
        await _nativeChannel.invokeMethod('bypassBatteryOptimization');
        await _nativeChannel.invokeMethod('requestIgnoreBatteryOptimizations');
        await _nativeChannel.invokeMethod('enableAutoStart');
      }
    } catch (e) {
      developer.log('[$_tag] Error bypassing battery optimization: $e');
    }
  }
  
  /// Ensure all permissions
  static Future<bool> _ensureAllPermissions() async {
    try {
      // Location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        return false;
      }
      
      if (permission != LocationPermission.always) {
        // Request always permission for background tracking
        permission = await Geolocator.requestPermission();
      }
      
      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      developer.log('[$_tag] Error checking permissions: $e');
      return false;
    }
  }
  
  /// Save tracking state
  static Future<void> _saveTrackingState(String userId, bool isTracking, bool ultraActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ultra_geofencing_tracking', isTracking);
      await prefs.setBool('ultra_geofencing_ultra_active', ultraActive);
      await prefs.setString('ultra_geofencing_user_id', userId);
      await prefs.setInt('ultra_geofencing_last_update', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      developer.log('[$_tag] Error saving tracking state: $e');
    }
  }
  
  /// Restore tracking state
  static Future<void> _restoreTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('ultra_geofencing_tracking') ?? false;
      final wasUltraActive = prefs.getBool('ultra_geofencing_ultra_active') ?? false;
      final userId = prefs.getString('ultra_geofencing_user_id');
      
      if (wasTracking && userId != null) {
        developer.log('[$_tag] Restoring tracking state for user: ${userId.substring(0, 8)}');
        await startUltraActiveTracking(
          userId: userId,
          ultraActive: wasUltraActive,
        );
      }
    } catch (e) {
      developer.log('[$_tag] Error restoring tracking state: $e');
    }
  }
  
  /// Register background handlers
  static Future<void> _registerBackgroundHandlers() async {
    // Implementation for background task registration
  }
  
  /// Start geofencing system
  static Future<void> _startGeofencingSystem() async {
    // Implementation for geofencing system startup
  }
  
  /// Send initial location
  static Future<void> _sendInitialLocation() async {
    await _performLocationCheck();
  }
  
  /// Restart location service
  static Future<void> _restartLocationService() async {
    if (_currentUserId != null) {
      await _startUltraActiveLocationMonitoring();
    }
  }
  
  /// Check native service health
  static Future<bool> _checkNativeServiceHealth() async {
    try {
      final result = await _nativeChannel.invokeMethod('checkServiceHealth');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Restart native services
  static Future<void> _restartNativeServices() async {
    if (_currentUserId != null) {
      await _startNativeBackgroundServices(_currentUserId!);
    }
  }
  
  /// Stop ultra-active tracking
  static Future<bool> stopTracking() async {
    try {
      developer.log('[$_tag] Stopping ultra-active tracking');
      
      // Stop timers
      _ultraActiveTimer?.cancel();
      _heartbeatTimer?.cancel();
      _healthCheckTimer?.cancel();
      
      // Stop native services
      await _nativeChannel.invokeMethod('stopBackgroundService');
      
      // Clear state
      if (_currentUserId != null) {
        await _saveTrackingState(_currentUserId!, false, false);
        await _clearLocationData(_currentUserId!);
      }
      
      _isTracking = false;
      _isUltraActive = false;
      _currentUserId = null;
      _lastKnownLocation = null;
      _activeGeofences.clear();
      _geofenceLocations.clear();
      
      developer.log('[$_tag] Ultra-active tracking stopped');
      return true;
    } catch (e) {
      developer.log('[$_tag] Error stopping tracking: $e');
      return false;
    }
  }
  
  /// Clear location data
  static Future<void> _clearLocationData(String userId) async {
    try {
      final realtimeDb = FirebaseDatabase.instance;
      await realtimeDb.ref('locations/$userId').remove();
      await realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': false,
        'isUltraActive': false,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      developer.log('[$_tag] Error clearing location data: $e');
    }
  }
  
  // Getters
  static bool get isInitialized => _isInitialized;
  static bool get isTracking => _isTracking;
  static bool get isUltraActive => _isUltraActive;
  static String? get currentUserId => _currentUserId;
  static LatLng? get lastKnownLocation => _lastKnownLocation;
  static List<GeofenceModel> get activeGeofences => List.unmodifiable(_activeGeofences);
}