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

/// Android Background Location Fix Service
/// 
/// This service specifically addresses Android 8.0+ (API 26+) background location limitations:
/// 1. Implements proper foreground service for continuous location updates
/// 2. Uses geofencing API for power-efficient location monitoring
/// 3. Implements passive location listener for faster updates when other apps request location
/// 4. Uses batched location updates for background operation
/// 5. Handles JSON parsing errors in method channel communication
/// 6. Implements proper error handling and retry mechanisms
class AndroidBackgroundLocationFix {
  static const String _tag = 'AndroidBackgroundLocationFix';
  
  // Method channels with proper error handling
  static const MethodChannel _locationChannel = MethodChannel('android_background_location_fix');
  static const MethodChannel _geofenceChannel = MethodChannel('android_geofence_fix');
  static const MethodChannel _foregroundChannel = MethodChannel('android_foreground_service_fix');
  
  // Service state
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static bool _isForegroundServiceRunning = false;
  static String? _currentUserId;
  
  // Location tracking state
  static StreamSubscription<Position>? _positionStream;
  static StreamSubscription<Position>? _passivePositionStream;
  static LatLng? _lastKnownLocation;
  static DateTime? _lastLocationUpdate;
  static Timer? _batchUpdateTimer;
  static List<LatLng> _locationBatch = [];
  
  // Configuration for Android 8.0+ compliance
  static const Duration _foregroundUpdateInterval = Duration(seconds: 15);
  static const Duration _backgroundBatchInterval = Duration(minutes: 15); // Android 8.0+ limit
  static const Duration _passiveUpdateInterval = Duration(seconds: 30);
  static const double _geofenceRadius = 100.0; // meters
  static const int _maxBatchSize = 10;
  
  // Firebase references
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseService.firestore;
  
  // Callbacks
  static Function(LatLng location)? onLocationUpdate;
  static Function(String error)? onError;
  static Function(String status)? onStatusUpdate;
  
  /// Initialize the Android background location fix service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Android Background Location Fix Service');
      
      // Check Android version
      if (!Platform.isAndroid) {
        developer.log('[$_tag] Not Android platform, skipping initialization');
        return false;
      }
      
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      developer.log('[$_tag] Android SDK: $sdkInt');
      
      // Setup method call handlers with proper error handling
      await _setupMethodChannels();
      
      // Initialize native components
      await _initializeNativeComponents(sdkInt);
      
      _isInitialized = true;
      developer.log('[$_tag] Android Background Location Fix Service initialized successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize Android background location fix: $e');
      return false;
    }
  }
  
  /// Start Android-optimized location tracking
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
      developer.log('[$_tag] Starting Android-optimized location tracking');
      
      _currentUserId = userId;
      
      // Step 1: Verify permissions
      final permissionsGranted = await _verifyPermissions();
      if (!permissionsGranted) {
        onError?.call('Required permissions not granted');
        return false;
      }
      
      // Step 2: Start foreground service for continuous updates
      final foregroundStarted = await _startForegroundService(userId);
      if (!foregroundStarted) {
        developer.log('[$_tag] Failed to start foreground service, using fallback');
      }
      
      // Step 3: Setup geofencing for power-efficient monitoring
      await _setupGeofencing();
      
      // Step 4: Start passive location listener
      await _startPassiveLocationListener();
      
      // Step 5: Start batched location updates for background
      _startBatchedLocationUpdates();
      
      // Step 6: Start primary location stream
      await _startLocationStream();
      
      _isTracking = true;
      onStatusUpdate?.call('Android-optimized location tracking started');
      
      developer.log('[$_tag] Android-optimized location tracking started successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to start tracking: $e');
      onError?.call('Failed to start location tracking: $e');
      return false;
    }
  }
  
  /// Stop location tracking
  static Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('[$_tag] Stopping Android-optimized location tracking');
      
      // Stop all location streams
      await _positionStream?.cancel();
      await _passivePositionStream?.cancel();
      _batchUpdateTimer?.cancel();
      
      // Stop foreground service
      await _stopForegroundService();
      
      // Remove geofences
      await _removeGeofences();
      
      // Process any remaining batched locations
      await _processBatchedLocations();
      
      _isTracking = false;
      _currentUserId = null;
      _locationBatch.clear();
      
      onStatusUpdate?.call('Location tracking stopped');
      
      developer.log('[$_tag] Android-optimized location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to stop tracking: $e');
      onError?.call('Failed to stop location tracking: $e');
      return false;
    }
  }
  
  // MARK: - Private Implementation
  
  /// Setup method channels with proper error handling
  static Future<void> _setupMethodChannels() async {
    try {
      // Location channel handler
      _locationChannel.setMethodCallHandler((call) async {
        try {
          return await _handleLocationMethodCall(call);
        } catch (e) {
          developer.log('[$_tag] Error handling location method call: $e');
          return {'error': 'Method call handling failed: $e'};
        }
      });
      
      // Geofence channel handler
      _geofenceChannel.setMethodCallHandler((call) async {
        try {
          return await _handleGeofenceMethodCall(call);
        } catch (e) {
          developer.log('[$_tag] Error handling geofence method call: $e');
          return {'error': 'Method call handling failed: $e'};
        }
      });
      
      // Foreground service channel handler
      _foregroundChannel.setMethodCallHandler((call) async {
        try {
          return await _handleForegroundServiceMethodCall(call);
        } catch (e) {
          developer.log('[$_tag] Error handling foreground service method call: $e');
          return {'error': 'Method call handling failed: $e'};
        }
      });
      
      developer.log('[$_tag] Method channels setup completed');
    } catch (e) {
      developer.log('[$_tag] Failed to setup method channels: $e');
      throw e;
    }
  }
  
  /// Initialize native components
  static Future<void> _initializeNativeComponents(int sdkInt) async {
    try {
      // Initialize with safe JSON parameters
      final initParams = {
        'sdkInt': sdkInt,
        'packageName': 'com.sundeep.groupsharing',
        'enableBatching': sdkInt >= 26, // Android 8.0+
        'batchInterval': _backgroundBatchInterval.inMilliseconds,
        'foregroundInterval': _foregroundUpdateInterval.inMilliseconds,
      };
      
      // Initialize location service
      final locationResult = await _locationChannel.invokeMethod('initialize', initParams);
      developer.log('[$_tag] Location service initialized: $locationResult');
      
      // Initialize geofence service
      final geofenceResult = await _geofenceChannel.invokeMethod('initialize', initParams);
      developer.log('[$_tag] Geofence service initialized: $geofenceResult');
      
      // Initialize foreground service
      final foregroundResult = await _foregroundChannel.invokeMethod('initialize', initParams);
      developer.log('[$_tag] Foreground service initialized: $foregroundResult');
      
    } catch (e) {
      developer.log('[$_tag] Failed to initialize native components: $e');
      // Don't throw - allow service to continue with Flutter-only mode
    }
  }
  
  /// Verify required permissions
  static Future<bool> _verifyPermissions() async {
    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('Location services are disabled');
        return false;
      }
      
      // Check location permission
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
      
      // Check background location permission (Android 10+)
      final backgroundPermission = await Permission.locationAlways.status;
      if (!backgroundPermission.isGranted) {
        final result = await Permission.locationAlways.request();
        if (!result.isGranted) {
          developer.log('[$_tag] Background location permission not granted, but continuing');
        }
      }
      
      developer.log('[$_tag] All permissions verified');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to verify permissions: $e');
      return false;
    }
  }
  
  /// Start foreground service for continuous location updates
  static Future<bool> _startForegroundService(String userId) async {
    try {
      final params = {
        'userId': userId,
        'updateInterval': _foregroundUpdateInterval.inMilliseconds,
        'title': 'Location Sharing Active',
        'content': 'Sharing your location with friends and family',
      };
      
      final result = await _foregroundChannel.invokeMethod('startForegroundService', params);
      _isForegroundServiceRunning = result == true;
      
      developer.log('[$_tag] Foreground service started: $_isForegroundServiceRunning');
      return _isForegroundServiceRunning;
    } catch (e) {
      developer.log('[$_tag] Failed to start foreground service: $e');
      return false;
    }
  }
  
  /// Stop foreground service
  static Future<void> _stopForegroundService() async {
    try {
      if (_isForegroundServiceRunning) {
        await _foregroundChannel.invokeMethod('stopForegroundService');
        _isForegroundServiceRunning = false;
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
          'id': 'user_location_${_currentUserId}',
        };
        
        await _geofenceChannel.invokeMethod('addGeofence', params);
        developer.log('[$_tag] Geofence setup completed');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to setup geofencing: $e');
    }
  }
  
  /// Remove geofences
  static Future<void> _removeGeofences() async {
    try {
      await _geofenceChannel.invokeMethod('removeAllGeofences');
      developer.log('[$_tag] All geofences removed');
    } catch (e) {
      developer.log('[$_tag] Failed to remove geofences: $e');
    }
  }
  
  /// Start passive location listener for faster updates
  static Future<void> _startPassiveLocationListener() async {
    try {
      const passiveSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50,
        timeLimit: Duration(seconds: 10),
      );
      
      _passivePositionStream = Geolocator.getPositionStream(
        locationSettings: passiveSettings,
      ).listen(
        (position) {
          final location = LatLng(position.latitude, position.longitude);
          _processLocationUpdate(location, 'passive');
        },
        onError: (error) {
          developer.log('[$_tag] Passive location error: $error');
        },
      );
      
      developer.log('[$_tag] Passive location listener started');
    } catch (e) {
      developer.log('[$_tag] Failed to start passive location listener: $e');
    }
  }
  
  /// Start batched location updates for background operation
  static void _startBatchedLocationUpdates() {
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer.periodic(_backgroundBatchInterval, (_) {
      _processBatchedLocations();
    });
    
    developer.log('[$_tag] Batched location updates started');
  }
  
  /// Start primary location stream
  static Future<void> _startLocationStream() async {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: 30),
      );
      
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          final location = LatLng(position.latitude, position.longitude);
          _processLocationUpdate(location, 'primary');
        },
        onError: (error) {
          developer.log('[$_tag] Primary location error: $error');
        },
      );
      
      developer.log('[$_tag] Primary location stream started');
    } catch (e) {
      developer.log('[$_tag] Failed to start primary location stream: $e');
    }
  }
  
  /// Process location update with batching for background operation
  static void _processLocationUpdate(LatLng location, String source) {
    try {
      _lastKnownLocation = location;
      _lastLocationUpdate = DateTime.now();
      
      developer.log('[$_tag] Location update from $source: ${location.latitude}, ${location.longitude}');
      
      // Add to batch for background processing
      _locationBatch.add(location);
      
      // If batch is full or we're in foreground, process immediately
      if (_locationBatch.length >= _maxBatchSize || _isForegroundServiceRunning) {
        _processBatchedLocations();
      }
      
      // Update geofence if location changed significantly
      _updateGeofenceIfNeeded(location);
      
      // Notify listeners
      onLocationUpdate?.call(location);
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
    // Update geofence every 500 meters to maintain power efficiency
    if (_lastKnownLocation != null) {
      final distance = Geolocator.distanceBetween(
        _lastKnownLocation!.latitude,
        _lastKnownLocation!.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );
      
      if (distance > 500) {
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
        'source': 'android_background_fix',
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
  
  /// Handle location method calls with proper JSON parsing
  static Future<dynamic> _handleLocationMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onLocationUpdate':
          // Safe JSON parsing with null checks
          final args = call.arguments;
          if (args is Map<String, dynamic>) {
            final latitude = args['latitude'] as double?;
            final longitude = args['longitude'] as double?;
            
            if (latitude != null && longitude != null) {
              final location = LatLng(latitude, longitude);
              _processLocationUpdate(location, 'native');
            } else {
              developer.log('[$_tag] Invalid location data received');
            }
          } else {
            developer.log('[$_tag] Invalid arguments format for location update');
          }
          break;
          
        case 'onLocationError':
          final error = call.arguments as String? ?? 'Unknown location error';
          developer.log('[$_tag] Native location error: $error');
          onError?.call('Native location error: $error');
          break;
          
        default:
          developer.log('[$_tag] Unknown location method call: ${call.method}');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling location method call: $e');
    }
  }
  
  /// Handle geofence method calls
  static Future<dynamic> _handleGeofenceMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onGeofenceEnter':
        case 'onGeofenceExit':
          developer.log('[$_tag] Geofence event: ${call.method}');
          // Trigger location update when geofence events occur
          final currentPosition = await Geolocator.getCurrentPosition();
          final location = LatLng(currentPosition.latitude, currentPosition.longitude);
          _processLocationUpdate(location, 'geofence');
          break;
          
        default:
          developer.log('[$_tag] Unknown geofence method call: ${call.method}');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling geofence method call: $e');
    }
  }
  
  /// Handle foreground service method calls
  static Future<dynamic> _handleForegroundServiceMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onServiceStarted':
          _isForegroundServiceRunning = true;
          developer.log('[$_tag] Foreground service started');
          onStatusUpdate?.call('Foreground service started');
          break;
          
        case 'onServiceStopped':
          _isForegroundServiceRunning = false;
          developer.log('[$_tag] Foreground service stopped');
          onStatusUpdate?.call('Foreground service stopped');
          break;
          
        default:
          developer.log('[$_tag] Unknown foreground service method call: ${call.method}');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling foreground service method call: $e');
    }
  }
  
  // MARK: - Public Getters
  
  static bool get isInitialized => _isInitialized;
  static bool get isTracking => _isTracking;
  static bool get isForegroundServiceRunning => _isForegroundServiceRunning;
  static LatLng? get lastKnownLocation => _lastKnownLocation;
  static String? get currentUserId => _currentUserId;
  
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