import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';
import 'firebase_service.dart';
import 'bulletproof_location_service.dart';
import 'android_background_location_fix.dart';

/// Android 8.0+ Background Location Solution
/// 
/// This service specifically addresses the Android 8.0+ (API 26+) background location limitations
/// mentioned in the error message. It implements the recommended solutions:
/// 
/// 1. Foreground Service Implementation:
///    - Starts a foreground service with ongoing notification
///    - Maintains continuous location updates while app is in background
///    - Complies with Android 11+ restrictions for background location access
/// 
/// 2. Geofencing API Integration:
///    - Uses GeofencingClient for power-optimized location monitoring
///    - Triggers location updates when user enters/exits geofences
///    - Minimizes battery usage while maintaining location awareness
/// 
/// 3. Passive Location Listener:
///    - Receives faster location updates from other foreground apps
///    - Leverages system-wide location requests for efficiency
/// 
/// 4. Batched Location Updates:
///    - Uses FusedLocationProviderApi for background batching
///    - Receives location updates in batches (few times per hour in background)
///    - Optimized for Android 8.0+ background limitations
class Android8BackgroundLocationSolution {
  static const String _tag = 'Android8BackgroundLocationSolution';
  
  // Method channels for Android-specific implementations
  static const MethodChannel _foregroundServiceChannel = MethodChannel('android_foreground_location_service');
  static const MethodChannel _geofencingChannel = MethodChannel('android_geofencing_client');
  static const MethodChannel _fusedLocationChannel = MethodChannel('android_fused_location_provider');
  static const MethodChannel _passiveLocationChannel = MethodChannel('android_passive_location_listener');
  
  // Service state management
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static bool _isForegroundServiceActive = false;
  static String? _currentUserId;
  static int _androidSdkVersion = 0;
  
  // Location tracking components
  static StreamSubscription<Position>? _geolocatorStream;
  static Timer? _batchProcessingTimer;
  static Timer? _healthCheckTimer;
  static List<LatLng> _locationBatch = [];
  static LatLng? _lastKnownLocation;
  static DateTime? _lastLocationUpdate;
  
  // Configuration based on Android version
  static Duration get _updateInterval => _androidSdkVersion >= 26 
      ? const Duration(minutes: 15) // Android 8.0+ background limit
      : const Duration(seconds: 30); // Pre-Android 8.0
      
  static Duration get _foregroundUpdateInterval => const Duration(seconds: 15);
  static Duration get _batchProcessingInterval => const Duration(minutes: 10);
  static const int _maxBatchSize = 20;
  static const double _geofenceRadius = 200.0; // meters
  
  // Firebase references
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseService.firestore;
  
  // Callbacks
  static Function(LatLng location)? onLocationUpdate;
  static Function(String error)? onError;
  static Function(String status)? onStatusUpdate;
  static Function()? onForegroundServiceStarted;
  static Function()? onForegroundServiceStopped;
  
  /// Initialize the Android 8.0+ background location solution
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Android 8.0+ Background Location Solution');
      
      // Check if running on Android
      if (!Platform.isAndroid) {
        developer.log('[$_tag] Not Android platform, skipping initialization');
        return false;
      }
      
      // Get Android SDK version
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _androidSdkVersion = androidInfo.version.sdkInt;
      
      developer.log('[$_tag] Android SDK Version: $_androidSdkVersion');
      
      // Log Android 8.0+ specific behavior
      if (_androidSdkVersion >= 26) {
        developer.log('[$_tag] Android 8.0+ detected - implementing background location limits');
        developer.log('[$_tag] Background location updates limited to few times per hour');
        developer.log('[$_tag] Foreground service required for continuous updates');
      }
      
      // Initialize method channels with safe error handling
      await _initializeMethodChannels();
      
      // Initialize native Android components
      await _initializeNativeComponents();
      
      // Setup health monitoring
      _setupHealthMonitoring();
      
      _isInitialized = true;
      developer.log('[$_tag] Android 8.0+ Background Location Solution initialized successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize Android background location solution: $e');
      return false;
    }
  }
  
  /// Start Android 8.0+ compliant location tracking
  static Future<bool> startTracking(String userId) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isTracking) {
      developer.log('[$_tag] Already tracking for user: ${userId.substring(0, 8)}');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting Android 8.0+ compliant location tracking');
      
      _currentUserId = userId;
      
      // Step 1: Verify all required permissions
      final permissionsGranted = await _verifyAndroidPermissions();
      if (!permissionsGranted) {
        onError?.call('Required Android permissions not granted');
        return false;
      }
      
      // Step 2: Start foreground service for continuous updates
      final foregroundStarted = await _startForegroundLocationService(userId);
      if (foregroundStarted) {
        developer.log('[$_tag] Foreground service started - continuous updates enabled');
      } else {
        developer.log('[$_tag] Foreground service failed - using background-limited updates');
      }
      
      // Step 3: Setup geofencing for power-efficient monitoring
      await _setupGeofencing();
      
      // Step 4: Initialize passive location listener
      await _startPassiveLocationListener();
      
      // Step 5: Start batched location provider (Android 8.0+ optimized)
      await _startBatchedLocationProvider();
      
      // Step 6: Start primary location stream with appropriate settings
      await _startPrimaryLocationStream();
      
      // Step 7: Start batch processing timer
      _startBatchProcessing();
      
      // Step 8: Start health monitoring
      _startHealthMonitoring();
      
      _isTracking = true;
      onStatusUpdate?.call('Android 8.0+ location tracking started');
      
      developer.log('[$_tag] Android 8.0+ location tracking started successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to start tracking: $e');
      onError?.call('Failed to start Android location tracking: $e');
      return false;
    }
  }
  
  /// Stop location tracking
  static Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('[$_tag] Stopping Android 8.0+ location tracking');
      
      // Stop all timers
      _batchProcessingTimer?.cancel();
      _healthCheckTimer?.cancel();
      
      // Stop location streams
      await _geolocatorStream?.cancel();
      
      // Stop native components
      await _stopForegroundLocationService();
      await _stopGeofencing();
      await _stopPassiveLocationListener();
      await _stopBatchedLocationProvider();
      
      // Process any remaining batched locations
      await _processBatchedLocations();
      
      // Clear state
      _isTracking = false;
      _currentUserId = null;
      _locationBatch.clear();
      _lastKnownLocation = null;
      _lastLocationUpdate = null;
      
      onStatusUpdate?.call('Location tracking stopped');
      
      developer.log('[$_tag] Android 8.0+ location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to stop tracking: $e');
      onError?.call('Failed to stop location tracking: $e');
      return false;
    }
  }
  
  // MARK: - Private Implementation
  
  /// Initialize method channels with safe error handling
  static Future<void> _initializeMethodChannels() async {
    try {
      // Foreground service channel
      _foregroundServiceChannel.setMethodCallHandler((call) async {
        try {
          return await _handleForegroundServiceCall(call);
        } catch (e) {
          developer.log('[$_tag] Error in foreground service handler: $e');
          return {'error': e.toString()};
        }
      });
      
      // Geofencing channel
      _geofencingChannel.setMethodCallHandler((call) async {
        try {
          return await _handleGeofencingCall(call);
        } catch (e) {
          developer.log('[$_tag] Error in geofencing handler: $e');
          return {'error': e.toString()};
        }
      });
      
      // Fused location provider channel
      _fusedLocationChannel.setMethodCallHandler((call) async {
        try {
          return await _handleFusedLocationCall(call);
        } catch (e) {
          developer.log('[$_tag] Error in fused location handler: $e');
          return {'error': e.toString()};
        }
      });
      
      // Passive location listener channel
      _passiveLocationChannel.setMethodCallHandler((call) async {
        try {
          return await _handlePassiveLocationCall(call);
        } catch (e) {
          developer.log('[$_tag] Error in passive location handler: $e');
          return {'error': e.toString()};
        }
      });
      
      developer.log('[$_tag] Method channels initialized successfully');
    } catch (e) {
      developer.log('[$_tag] Failed to initialize method channels: $e');
      throw e;
    }
  }
  
  /// Initialize native Android components
  static Future<void> _initializeNativeComponents() async {
    try {
      final initParams = {
        'sdkVersion': _androidSdkVersion,
        'packageName': 'com.sundeep.groupsharing',
        'enableAndroid8Optimizations': _androidSdkVersion >= 26,
        'foregroundUpdateInterval': _foregroundUpdateInterval.inMilliseconds,
        'backgroundUpdateInterval': _updateInterval.inMilliseconds,
        'geofenceRadius': _geofenceRadius,
      };
      
      // Initialize each component
      await _foregroundServiceChannel.invokeMethod('initialize', initParams);
      await _geofencingChannel.invokeMethod('initialize', initParams);
      await _fusedLocationChannel.invokeMethod('initialize', initParams);
      await _passiveLocationChannel.invokeMethod('initialize', initParams);
      
      developer.log('[$_tag] Native components initialized successfully');
    } catch (e) {
      developer.log('[$_tag] Failed to initialize native components: $e');
      // Don't throw - allow service to continue with Flutter-only mode
    }
  }
  
  /// Verify Android-specific permissions
  static Future<bool> _verifyAndroidPermissions() async {
    try {
      // Basic location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError?.call('Location permission denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        onError?.call('Location permission permanently denied');
        return false;
      }
      
      // Background location permission (Android 10+)
      if (_androidSdkVersion >= 29) {
        final backgroundPermission = await Permission.locationAlways.status;
        if (!backgroundPermission.isGranted) {
          developer.log('[$_tag] Requesting background location permission (Android 10+)');
          final result = await Permission.locationAlways.request();
          if (!result.isGranted) {
            developer.log('[$_tag] Background location permission denied - limited functionality');
          }
        }
      }
      
      // Notification permission (Android 13+)
      if (_androidSdkVersion >= 33) {
        final notificationPermission = await Permission.notification.status;
        if (!notificationPermission.isGranted) {
          await Permission.notification.request();
        }
      }
      
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('Location services are disabled');
        return false;
      }
      
      developer.log('[$_tag] Android permissions verified successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to verify permissions: $e');
      return false;
    }
  }
  
  /// Start foreground location service
  static Future<bool> _startForegroundLocationService(String userId) async {
    try {
      final params = {
        'userId': userId,
        'updateInterval': _foregroundUpdateInterval.inMilliseconds,
        'title': 'Location Sharing Active',
        'content': 'Sharing your location with friends and family',
        'enableHighAccuracy': true,
        'enableAndroid8Compliance': _androidSdkVersion >= 26,
      };
      
      final result = await _foregroundServiceChannel.invokeMethod('startForegroundService', params);
      _isForegroundServiceActive = result == true;
      
      if (_isForegroundServiceActive) {
        onForegroundServiceStarted?.call();
        developer.log('[$_tag] Foreground service started successfully');
      }
      
      return _isForegroundServiceActive;
    } catch (e) {
      developer.log('[$_tag] Failed to start foreground service: $e');
      return false;
    }
  }
  
  /// Stop foreground location service
  static Future<void> _stopForegroundLocationService() async {
    try {
      if (_isForegroundServiceActive) {
        await _foregroundServiceChannel.invokeMethod('stopForegroundService');
        _isForegroundServiceActive = false;
        onForegroundServiceStopped?.call();
        developer.log('[$_tag] Foreground service stopped');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to stop foreground service: $e');
    }
  }
  
  /// Setup geofencing for power-efficient monitoring
  static Future<void> _setupGeofencing() async {
    try {
      if (_lastKnownLocation != null) {
        final params = {
          'latitude': _lastKnownLocation!.latitude,
          'longitude': _lastKnownLocation!.longitude,
          'radius': _geofenceRadius,
          'id': 'user_location_geofence',
          'enableAndroid8Optimizations': _androidSdkVersion >= 26,
        };
        
        await _geofencingChannel.invokeMethod('addGeofence', params);
        developer.log('[$_tag] Geofencing setup completed');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to setup geofencing: $e');
    }
  }
  
  /// Stop geofencing
  static Future<void> _stopGeofencing() async {
    try {
      await _geofencingChannel.invokeMethod('removeAllGeofences');
      developer.log('[$_tag] Geofencing stopped');
    } catch (e) {
      developer.log('[$_tag] Failed to stop geofencing: $e');
    }
  }
  
  /// Start passive location listener
  static Future<void> _startPassiveLocationListener() async {
    try {
      final params = {
        'enableAndroid8Optimizations': _androidSdkVersion >= 26,
        'updateInterval': _updateInterval.inMilliseconds,
      };
      
      await _passiveLocationChannel.invokeMethod('startPassiveListener', params);
      developer.log('[$_tag] Passive location listener started');
    } catch (e) {
      developer.log('[$_tag] Failed to start passive location listener: $e');
    }
  }
  
  /// Stop passive location listener
  static Future<void> _stopPassiveLocationListener() async {
    try {
      await _passiveLocationChannel.invokeMethod('stopPassiveListener');
      developer.log('[$_tag] Passive location listener stopped');
    } catch (e) {
      developer.log('[$_tag] Failed to stop passive location listener: $e');
    }
  }
  
  /// Start batched location provider (Android 8.0+ optimized)
  static Future<void> _startBatchedLocationProvider() async {
    try {
      final params = {
        'batchSize': _maxBatchSize,
        'batchInterval': _batchProcessingInterval.inMilliseconds,
        'enableAndroid8Batching': _androidSdkVersion >= 26,
        'updateInterval': _updateInterval.inMilliseconds,
      };
      
      await _fusedLocationChannel.invokeMethod('startBatchedUpdates', params);
      developer.log('[$_tag] Batched location provider started');
    } catch (e) {
      developer.log('[$_tag] Failed to start batched location provider: $e');
    }
  }
  
  /// Stop batched location provider
  static Future<void> _stopBatchedLocationProvider() async {
    try {
      await _fusedLocationChannel.invokeMethod('stopBatchedUpdates');
      developer.log('[$_tag] Batched location provider stopped');
    } catch (e) {
      developer.log('[$_tag] Failed to stop batched location provider: $e');
    }
  }
  
  /// Start primary location stream with Android 8.0+ appropriate settings
  static Future<void> _startPrimaryLocationStream() async {
    try {
      // Configure location settings based on Android version and foreground service status
      final LocationSettings locationSettings;
      
      if (_isForegroundServiceActive) {
        // Foreground service active - use high accuracy with frequent updates
        locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 30),
        );
        developer.log('[$_tag] Using foreground location settings');
      } else if (_androidSdkVersion >= 26) {
        // Android 8.0+ background mode - use power-efficient settings
        locationSettings = LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 50,
          timeLimit: Duration(minutes: 2),
        );
        developer.log('[$_tag] Using Android 8.0+ background location settings');
      } else {
        // Pre-Android 8.0 - use standard settings
        locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
          timeLimit: Duration(seconds: 60),
        );
        developer.log('[$_tag] Using standard location settings');
      }
      
      _geolocatorStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          final location = LatLng(position.latitude, position.longitude);
          _processLocationUpdate(location, 'geolocator');
        },
        onError: (error) {
          developer.log('[$_tag] Geolocator stream error: $error');
        },
      );
      
      developer.log('[$_tag] Primary location stream started');
    } catch (e) {
      developer.log('[$_tag] Failed to start primary location stream: $e');
    }
  }
  
  /// Start batch processing timer
  static void _startBatchProcessing() {
    _batchProcessingTimer?.cancel();
    _batchProcessingTimer = Timer.periodic(_batchProcessingInterval, (_) {
      _processBatchedLocations();
    });
    
    developer.log('[$_tag] Batch processing started');
  }
  
  /// Setup health monitoring
  static void _setupHealthMonitoring() {
    // Health monitoring setup
  }
  
  /// Start health monitoring
  static void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _performHealthCheck();
    });
  }
  
  /// Perform health check
  static void _performHealthCheck() async {
    try {
      // Check if we've received location updates recently
      if (_lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
        final maxAllowedGap = _isForegroundServiceActive 
            ? Duration(minutes: 2) 
            : Duration(minutes: 20); // Android 8.0+ allows longer gaps
        
        if (timeSinceLastUpdate > maxAllowedGap) {
          developer.log('[$_tag] No location updates for ${timeSinceLastUpdate.inMinutes} minutes');
          onError?.call('Location updates delayed - this is normal on Android 8.0+ in background');
        }
      }
      
      // Check foreground service status
      if (_androidSdkVersion >= 26 && !_isForegroundServiceActive) {
        developer.log('[$_tag] Running in Android 8.0+ background mode - limited updates expected');
      }
      
      developer.log('[$_tag] Health check completed');
    } catch (e) {
      developer.log('[$_tag] Health check error: $e');
    }
  }
  
  /// Process location update with Android 8.0+ optimizations
  static void _processLocationUpdate(LatLng location, String source) {
    try {
      _lastKnownLocation = location;
      _lastLocationUpdate = DateTime.now();
      
      developer.log('[$_tag] Location update from $source: ${location.latitude}, ${location.longitude}');
      
      // Add to batch for processing
      _locationBatch.add(location);
      
      // Process immediately if foreground service is active or batch is full
      if (_isForegroundServiceActive || _locationBatch.length >= _maxBatchSize) {
        _processBatchedLocations();
      }
      
      // Update geofence if needed
      _updateGeofenceIfNeeded(location);
      
      // Notify listeners
      onLocationUpdate?.call(location);
      onStatusUpdate?.call('Location updated from $source');
    } catch (e) {
      developer.log('[$_tag] Failed to process location update: $e');
    }
  }
  
  /// Process batched locations
  static Future<void> _processBatchedLocations() async {
    if (_locationBatch.isEmpty || _currentUserId == null) return;
    
    try {
      final batch = List<LatLng>.from(_locationBatch);
      _locationBatch.clear();
      
      // Use the most recent location for Firebase update
      final latestLocation = batch.last;
      await _updateFirebaseLocation(latestLocation);
      
      developer.log('[$_tag] Processed batch of ${batch.length} locations');
    } catch (e) {
      developer.log('[$_tag] Failed to process batched locations: $e');
    }
  }
  
  /// Update geofence if location changed significantly
  static void _updateGeofenceIfNeeded(LatLng newLocation) {
    if (_lastKnownLocation != null) {
      final distance = Geolocator.distanceBetween(
        _lastKnownLocation!.latitude,
        _lastKnownLocation!.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );
      
      // Update geofence every 1km to maintain efficiency
      if (distance > 1000) {
        _setupGeofencing();
      }
    }
  }
  
  /// Update location in Firebase
  static Future<void> _updateFirebaseLocation(LatLng location) async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Update Realtime Database
      await _realtimeDb.ref('locations/${_currentUserId}').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'timestamp': timestamp,
        'isSharing': true,
        'accuracy': 10.0,
        'source': 'android_8_solution',
        'foregroundService': _isForegroundServiceActive,
        'androidSdk': _androidSdkVersion,
      });
      
      // Update Firestore for persistence
      await _firestore.collection('users').doc(_currentUserId!).update({
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      
      developer.log('[$_tag] Firebase location updated successfully');
    } catch (e) {
      developer.log('[$_tag] Failed to update Firebase location: $e');
    }
  }
  
  // MARK: - Method Call Handlers
  
  /// Handle foreground service method calls
  static Future<dynamic> _handleForegroundServiceCall(MethodCall call) async {
    switch (call.method) {
      case 'onServiceStarted':
        _isForegroundServiceActive = true;
        onForegroundServiceStarted?.call();
        developer.log('[$_tag] Foreground service started');
        break;
        
      case 'onServiceStopped':
        _isForegroundServiceActive = false;
        onForegroundServiceStopped?.call();
        developer.log('[$_tag] Foreground service stopped');
        break;
        
      case 'onLocationUpdate':
        final args = call.arguments as Map<String, dynamic>?;
        if (args != null) {
          final lat = args['latitude'] as double?;
          final lng = args['longitude'] as double?;
          if (lat != null && lng != null) {
            _processLocationUpdate(LatLng(lat, lng), 'foreground_service');
          }
        }
        break;
    }
  }
  
  /// Handle geofencing method calls
  static Future<dynamic> _handleGeofencingCall(MethodCall call) async {
    switch (call.method) {
      case 'onGeofenceEnter':
      case 'onGeofenceExit':
        developer.log('[$_tag] Geofence event: ${call.method}');
        // Trigger location update
        try {
          final position = await Geolocator.getCurrentPosition();
          _processLocationUpdate(LatLng(position.latitude, position.longitude), 'geofence');
        } catch (e) {
          developer.log('[$_tag] Failed to get location on geofence event: $e');
        }
        break;
    }
  }
  
  /// Handle fused location provider method calls
  static Future<dynamic> _handleFusedLocationCall(MethodCall call) async {
    switch (call.method) {
      case 'onBatchedLocationUpdate':
        final args = call.arguments as List<dynamic>?;
        if (args != null) {
          for (final locationData in args) {
            if (locationData is Map<String, dynamic>) {
              final lat = locationData['latitude'] as double?;
              final lng = locationData['longitude'] as double?;
              if (lat != null && lng != null) {
                _processLocationUpdate(LatLng(lat, lng), 'fused_batched');
              }
            }
          }
        }
        break;
    }
  }
  
  /// Handle passive location listener method calls
  static Future<dynamic> _handlePassiveLocationCall(MethodCall call) async {
    switch (call.method) {
      case 'onPassiveLocationUpdate':
        final args = call.arguments as Map<String, dynamic>?;
        if (args != null) {
          final lat = args['latitude'] as double?;
          final lng = args['longitude'] as double?;
          if (lat != null && lng != null) {
            _processLocationUpdate(LatLng(lat, lng), 'passive');
          }
        }
        break;
    }
  }
  
  // MARK: - Public Getters
  
  static bool get isInitialized => _isInitialized;
  static bool get isTracking => _isTracking;
  static bool get isForegroundServiceActive => _isForegroundServiceActive;
  static int get androidSdkVersion => _androidSdkVersion;
  static LatLng? get lastKnownLocation => _lastKnownLocation;
  static String? get currentUserId => _currentUserId;
  
  /// Get status information for debugging
  static Map<String, dynamic> getStatusInfo() {
    return {
      'isInitialized': _isInitialized,
      'isTracking': _isTracking,
      'isForegroundServiceActive': _isForegroundServiceActive,
      'androidSdkVersion': _androidSdkVersion,
      'lastLocationUpdate': _lastLocationUpdate?.toIso8601String(),
      'batchedLocationsCount': _locationBatch.length,
      'updateInterval': _updateInterval.inMilliseconds,
      'isAndroid8Plus': _androidSdkVersion >= 26,
    };
  }
  
  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await stopTracking();
      _isInitialized = false;
    } catch (e) {
      developer.log('[$_tag] Error disposing service: $e');
    }
  }
}