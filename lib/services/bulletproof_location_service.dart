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

/// Bulletproof Background Location Service
/// 
/// This service addresses all critical issues with background location tracking:
/// 1. Services being killed by Android's aggressive battery optimization
/// 2. Location permissions being revoked in background
/// 3. Proper foreground service implementation with Android 12+ support
/// 4. Critical Android 12+ restrictions handling
/// 5. Proper service lifecycle management with auto-restart
/// 6. Firebase updates with retry mechanisms and error handling
/// 7. Multi-layer fallback system for maximum reliability
/// 8. Device-specific optimizations (OnePlus, Xiaomi, Huawei, etc.)
class BulletproofLocationService {
  static const String _tag = 'BulletproofLocationService';
  
  // Method channels for native services
  static const MethodChannel _bulletproofChannel = MethodChannel('bulletproof_location_service');
  static const MethodChannel _permissionChannel = MethodChannel('bulletproof_permissions');
  static const MethodChannel _batteryChannel = MethodChannel('bulletproof_battery');
  
  // Service state management
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static String? _currentUserId;
  static Timer? _healthCheckTimer;
  static Timer? _permissionCheckTimer;
  static Timer? _firebaseRetryTimer;
  
  // Location tracking state
  static StreamSubscription<Position>? _positionStream;
  static LatLng? _lastKnownLocation;
  static DateTime? _lastLocationUpdate;
  static int _consecutiveFailures = 0;
  static int _firebaseRetryCount = 0;
  
  // Configuration
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _permissionCheckInterval = Duration(minutes: 5);
  static const Duration _locationTimeout = Duration(seconds: 30);
  static const Duration _firebaseRetryDelay = Duration(seconds: 5);
  static const int _maxConsecutiveFailures = 3;
  static const int _maxFirebaseRetries = 5;
  static const double _distanceFilter = 10.0;
  
  // Firebase references
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseService.firestore;
  
  // Callbacks
  static Function(LatLng location)? onLocationUpdate;
  static Function(String error)? onError;
  static Function(String status)? onStatusUpdate;
  static Function()? onServiceStarted;
  static Function()? onServiceStopped;
  static Function()? onPermissionRevoked;
  
  /// Initialize the bulletproof location service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Bulletproof Location Service');
      
      // Initialize native platform channels
      await _initializePlatformChannels();
      
      // Setup device-specific optimizations
      await _setupDeviceOptimizations();
      
      // Initialize permission monitoring
      await _initializePermissionMonitoring();
      
      // Initialize battery optimization handling
      await _initializeBatteryOptimizations();
      
      // Setup health monitoring
      _setupHealthMonitoring();
      
      // Setup Firebase error handling
      _setupFirebaseErrorHandling();
      
      _isInitialized = true;
      developer.log('[$_tag] Bulletproof Location Service initialized successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      return false;
    }
  }
  
  /// Start bulletproof location tracking
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
      developer.log('[$_tag] Starting bulletproof location tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      // Step 1: Verify and request all required permissions
      final permissionsGranted = await _verifyAndRequestPermissions();
      if (!permissionsGranted) {
        onError?.call('Critical permissions not granted');
        return false;
      }
      
      // Step 2: Setup battery optimization exemptions
      await _setupBatteryOptimizationExemptions();
      
      // Step 3: Start native foreground service
      final nativeStarted = await _startNativeService(userId);
      if (!nativeStarted) {
        developer.log('[$_tag] Native service failed to start, using Flutter fallback');
      }
      
      // Step 4: Start Flutter location tracking as backup
      await _startFlutterLocationTracking();
      
      // Step 5: Save tracking state
      await _saveTrackingState(true, userId);
      
      // Step 6: Start monitoring systems
      _startHealthMonitoring();
      _startPermissionMonitoring();
      
      _isTracking = true;
      onServiceStarted?.call();
      onStatusUpdate?.call('Bulletproof location tracking started');
      
      developer.log('[$_tag] Bulletproof location tracking started successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to start tracking: $e');
      onError?.call('Failed to start location tracking: $e');
      return false;
    }
  }
  
  /// Stop bulletproof location tracking
  static Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('[$_tag] Stopping bulletproof location tracking');
      
      // Stop all monitoring
      _stopHealthMonitoring();
      _stopPermissionMonitoring();
      
      // Stop Flutter location tracking
      await _stopFlutterLocationTracking();
      
      // Stop native service
      await _stopNativeService();
      
      // Clear tracking state
      await _saveTrackingState(false, null);
      
      _isTracking = false;
      _currentUserId = null;
      _consecutiveFailures = 0;
      _firebaseRetryCount = 0;
      
      onServiceStopped?.call();
      onStatusUpdate?.call('Location tracking stopped');
      
      developer.log('[$_tag] Bulletproof location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to stop tracking: $e');
      onError?.call('Failed to stop location tracking: $e');
      return false;
    }
  }
  
  /// Get current tracking status
  static bool get isTracking => _isTracking;
  
  /// Get last known location
  static LatLng? get lastKnownLocation => _lastKnownLocation;
  
  /// Get current user ID
  static String? get currentUserId => _currentUserId;
  
  // MARK: - Private Implementation
  
  /// Initialize platform channels
  static Future<void> _initializePlatformChannels() async {
    try {
      // Setup method call handlers
      _bulletproofChannel.setMethodCallHandler(_handleNativeMethodCall);
      _permissionChannel.setMethodCallHandler(_handlePermissionMethodCall);
      _batteryChannel.setMethodCallHandler(_handleBatteryMethodCall);
      
      // Initialize native services with error handling
      try {
        if (Platform.isAndroid) {
          await _bulletproofChannel.invokeMethod('initialize');
          developer.log('[$_tag] Android native service initialized');
        } else if (Platform.isIOS) {
          await _bulletproofChannel.invokeMethod('initializeIOS');
          developer.log('[$_tag] iOS native service initialized');
        }
      } catch (e) {
        developer.log('[$_tag] Native service not available: $e');
        developer.log('[$_tag] Continuing with Flutter-only implementation');
        // Don't throw - continue with Flutter fallback
      }
      
      developer.log('[$_tag] Platform channels setup completed');
    } catch (e) {
      developer.log('[$_tag] Failed to setup platform channels: $e');
      // Don't throw - allow service to continue with Flutter-only mode
      developer.log('[$_tag] Continuing in Flutter-only mode');
    }
  }
  
  /// Setup device-specific optimizations
  static Future<void> _setupDeviceOptimizations() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        final model = androidInfo.model.toLowerCase();
        
        developer.log('[$_tag] Setting up optimizations for $manufacturer $model');
        
        // Device-specific optimizations
        final optimizations = <String, dynamic>{
          'manufacturer': manufacturer,
          'model': model,
          'sdkInt': androidInfo.version.sdkInt,
        };
        
        await _bulletproofChannel.invokeMethod('setupDeviceOptimizations', optimizations);
      }
    } catch (e) {
      developer.log('[$_tag] Failed to setup device optimizations: $e');
    }
  }
  
  /// Initialize permission monitoring
  static Future<void> _initializePermissionMonitoring() async {
    try {
      await _permissionChannel.invokeMethod('initializePermissionMonitoring');
      developer.log('[$_tag] Permission monitoring initialized');
    } catch (e) {
      developer.log('[$_tag] Failed to initialize permission monitoring: $e');
    }
  }
  
  /// Initialize battery optimizations
  static Future<void> _initializeBatteryOptimizations() async {
    try {
      await _batteryChannel.invokeMethod('initializeBatteryOptimizations');
      developer.log('[$_tag] Battery optimizations initialized');
    } catch (e) {
      developer.log('[$_tag] Failed to initialize battery optimizations: $e');
    }
  }
  
  /// Verify and request all required permissions
  static Future<bool> _verifyAndRequestPermissions() async {
    try {
      developer.log('[$_tag] Verifying and requesting permissions');
      
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
      
      // For Android, check background location permission
      if (Platform.isAndroid) {
        final backgroundGranted = await _verifyBackgroundLocationPermission();
        if (!backgroundGranted) {
          return false;
        }
        
        // Check notification permission (Android 13+)
        final notificationGranted = await _verifyNotificationPermission();
        if (!notificationGranted) {
          developer.log('[$_tag] Notification permission not granted, but continuing');
        }
        
        // Check exact alarm permission (Android 12+)
        await _verifyExactAlarmPermission();
      }
      
      developer.log('[$_tag] All required permissions verified');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to verify permissions: $e');
      onError?.call('Permission verification failed: $e');
      return false;
    }
  }
  
  /// Verify background location permission
  static Future<bool> _verifyBackgroundLocationPermission() async {
    try {
      final result = await _permissionChannel.invokeMethod('checkBackgroundLocationPermission');
      if (result == true) {
        return true;
      }
      
      // Request background location permission
      final granted = await _permissionChannel.invokeMethod('requestBackgroundLocationPermission');
      return granted == true;
    } catch (e) {
      developer.log('[$_tag] Failed to verify background location permission: $e');
      return false;
    }
  }
  
  /// Verify notification permission
  static Future<bool> _verifyNotificationPermission() async {
    try {
      final permission = await Permission.notification.status;
      if (permission.isGranted) {
        return true;
      }
      
      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e) {
      developer.log('[$_tag] Failed to verify notification permission: $e');
      return false;
    }
  }
  
  /// Verify exact alarm permission
  static Future<bool> _verifyExactAlarmPermission() async {
    try {
      final result = await _permissionChannel.invokeMethod('checkExactAlarmPermission');
      if (result == true) {
        return true;
      }
      
      // Request exact alarm permission
      await _permissionChannel.invokeMethod('requestExactAlarmPermission');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to verify exact alarm permission: $e');
      return false;
    }
  }
  
  /// Setup battery optimization exemptions
  static Future<void> _setupBatteryOptimizationExemptions() async {
    try {
      if (Platform.isAndroid) {
        await _batteryChannel.invokeMethod('requestBatteryOptimizationExemption');
        await _batteryChannel.invokeMethod('requestAutoStartPermission');
        await _batteryChannel.invokeMethod('requestBackgroundAppPermission');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to setup battery optimization exemptions: $e');
    }
  }
  
  /// Start native foreground service
  static Future<bool> _startNativeService(String userId) async {
    try {
      final result = await _bulletproofChannel.invokeMethod('startBulletproofService', {
        'userId': userId,
        'updateInterval': 15000, // 15 seconds
        'distanceFilter': _distanceFilter,
        'enableHighAccuracy': true,
        'enablePersistentMode': true,
      });
      
      return result == true;
    } catch (e) {
      developer.log('[$_tag] Failed to start native service: $e');
      return false;
    }
  }
  
  /// Stop native service
  static Future<void> _stopNativeService() async {
    try {
      await _bulletproofChannel.invokeMethod('stopBulletproofService');
    } catch (e) {
      developer.log('[$_tag] Failed to stop native service: $e');
    }
  }
  
  /// Start Flutter location tracking as backup
  static Future<void> _startFlutterLocationTracking() async {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: 30),
      );
      
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _handleLocationUpdate,
        onError: _handleLocationError,
      );
      
      developer.log('[$_tag] Flutter location tracking started');
    } catch (e) {
      developer.log('[$_tag] Failed to start Flutter location tracking: $e');
    }
  }
  
  /// Stop Flutter location tracking
  static Future<void> _stopFlutterLocationTracking() async {
    try {
      await _positionStream?.cancel();
      _positionStream = null;
      developer.log('[$_tag] Flutter location tracking stopped');
    } catch (e) {
      developer.log('[$_tag] Failed to stop Flutter location tracking: $e');
    }
  }
  
  /// Handle location updates from Flutter
  static void _handleLocationUpdate(Position position) {
    final location = LatLng(position.latitude, position.longitude);
    _processLocationUpdate(location, 'flutter');
  }
  
  /// Handle location errors from Flutter
  static void _handleLocationError(dynamic error) {
    developer.log('[$_tag] Flutter location error: $error');
    _consecutiveFailures++;
    
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      _handleServiceFailure('Flutter location tracking failed');
    }
  }
  
  /// Process location update from any source
  static void _processLocationUpdate(LatLng location, String source) {
    try {
      _lastKnownLocation = location;
      _lastLocationUpdate = DateTime.now();
      _consecutiveFailures = 0;
      _firebaseRetryCount = 0;
      
      developer.log('[$_tag] Location update from $source: ${location.latitude}, ${location.longitude}');
      
      // Update Firebase
      _updateFirebaseLocation(location);
      
      // Notify listeners
      onLocationUpdate?.call(location);
      onStatusUpdate?.call('Location updated from $source');
    } catch (e) {
      developer.log('[$_tag] Failed to process location update: $e');
    }
  }
  
  /// Update location in Firebase with retry mechanism
  static Future<void> _updateFirebaseLocation(LatLng location) async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Update Realtime Database with correct format for location provider
      await _realtimeDb.ref('locations/${_currentUserId}').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'timestamp': timestamp,
        'isSharing': true,
        'accuracy': 10.0,
      });
      
      // Also update Firestore for persistence
      await _firestore.collection('users').doc(_currentUserId!).update({
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      
      developer.log('[$_tag] Firebase location updated successfully: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      developer.log('[$_tag] Failed to update Firebase location: $e');
      _handleFirebaseError(location);
    }
  }
  
  /// Handle Firebase update errors with retry mechanism
  static void _handleFirebaseError(LatLng location) {
    _firebaseRetryCount++;
    
    if (_firebaseRetryCount <= _maxFirebaseRetries) {
      developer.log('[$_tag] Retrying Firebase update (attempt $_firebaseRetryCount)');
      
      _firebaseRetryTimer?.cancel();
      _firebaseRetryTimer = Timer(_firebaseRetryDelay * _firebaseRetryCount, () {
        _updateFirebaseLocation(location);
      });
    } else {
      developer.log('[$_tag] Max Firebase retries reached, giving up');
      onError?.call('Firebase updates failing persistently');
    }
  }
  
  /// Setup health monitoring
  static void _setupHealthMonitoring() {
    // Health monitoring will be started when tracking begins
  }
  
  /// Start health monitoring
  static void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }
  
  /// Stop health monitoring
  static void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }
  
  /// Perform health check
  static void _performHealthCheck() async {
    try {
      // Check if we've received location updates recently
      if (_lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceLastUpdate > Duration(minutes: 2)) {
          developer.log('[$_tag] No location updates for ${timeSinceLastUpdate.inMinutes} minutes');
          _handleServiceFailure('No recent location updates');
          return;
        }
      }
      
      // Check native service health
      if (Platform.isAndroid) {
        final isHealthy = await _bulletproofChannel.invokeMethod('checkServiceHealth');
        if (isHealthy != true) {
          developer.log('[$_tag] Native service health check failed');
          _handleServiceFailure('Native service unhealthy');
          return;
        }
      }
      
      // Check permissions
      final permissionsOk = await _checkPermissionsHealth();
      if (!permissionsOk) {
        developer.log('[$_tag] Permission health check failed');
        _handlePermissionFailure();
        return;
      }
      
      developer.log('[$_tag] Health check passed');
    } catch (e) {
      developer.log('[$_tag] Health check error: $e');
    }
  }
  
  /// Check permissions health
  static Future<bool> _checkPermissionsHealth() async {
    try {
      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return false;
      }
      
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      
      // Check background location permission on Android
      if (Platform.isAndroid) {
        final backgroundGranted = await _permissionChannel.invokeMethod('checkBackgroundLocationPermission');
        if (backgroundGranted != true) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Permission health check error: $e');
      return false;
    }
  }
  
  /// Handle service failure
  static void _handleServiceFailure(String reason) async {
    developer.log('[$_tag] Service failure detected: $reason');
    
    try {
      // Attempt to restart the service
      if (_currentUserId != null) {
        developer.log('[$_tag] Attempting to restart service');
        
        // Stop current tracking
        await _stopFlutterLocationTracking();
        await _stopNativeService();
        
        // Wait a moment
        await Future.delayed(Duration(seconds: 2));
        
        // Restart tracking
        final restarted = await startTracking(_currentUserId!);
        if (restarted) {
          developer.log('[$_tag] Service restarted successfully');
          onStatusUpdate?.call('Service restarted after failure');
        } else {
          developer.log('[$_tag] Failed to restart service');
          onError?.call('Service restart failed: $reason');
        }
      }
    } catch (e) {
      developer.log('[$_tag] Error handling service failure: $e');
      onError?.call('Service failure handling error: $e');
    }
  }
  
  /// Handle permission failure
  static void _handlePermissionFailure() {
    developer.log('[$_tag] Permission failure detected');
    onPermissionRevoked?.call();
    onError?.call('Location permissions have been revoked');
  }
  
  /// Start permission monitoring
  static void _startPermissionMonitoring() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = Timer.periodic(_permissionCheckInterval, (_) {
      _checkPermissionsHealth();
    });
  }
  
  /// Stop permission monitoring
  static void _stopPermissionMonitoring() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;
  }
  
  /// Setup Firebase error handling
  static void _setupFirebaseErrorHandling() {
    // Firebase error handling is integrated into the update methods
  }
  
  /// Save tracking state to persistent storage
  static Future<void> _saveTrackingState(bool isTracking, String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bulletproof_location_tracking', isTracking);
      if (userId != null) {
        await prefs.setString('bulletproof_user_id', userId);
      } else {
        await prefs.remove('bulletproof_user_id');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to save tracking state: $e');
    }
  }
  
  /// Restore tracking state from persistent storage
  static Future<bool> restoreTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('bulletproof_location_tracking') ?? false;
      final userId = prefs.getString('bulletproof_user_id');
      
      if (wasTracking && userId != null) {
        developer.log('[$_tag] Restoring location tracking for user: ${userId.substring(0, 8)}');
        final restored = await startTracking(userId);
        if (restored) {
          developer.log('[$_tag] Location tracking restored successfully');
          return true;
        } else {
          developer.log('[$_tag] Failed to restore location tracking');
          return false;
        }
      } else {
        developer.log('[$_tag] No previous tracking state to restore');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to restore tracking state: $e');
      return false;
    }
  }
  
  /// Check if tracking should be restored
  static Future<bool> shouldRestoreTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('bulletproof_location_tracking') ?? false;
      final userId = prefs.getString('bulletproof_user_id');
      return wasTracking && userId != null;
    } catch (e) {
      developer.log('[$_tag] Failed to check restore state: $e');
      return false;
    }
  }
  
  /// Get user ID for restoration
  static Future<String?> getRestoreUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('bulletproof_user_id');
    } catch (e) {
      developer.log('[$_tag] Failed to get restore user ID: $e');
      return null;
    }
  }
  
  /// Check service health
  static Future<bool> checkServiceHealth() async {
    try {
      if (!_isTracking) return false;
      
      // Check if we've received location updates recently
      if (_lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceLastUpdate > Duration(minutes: 2)) {
          return false;
        }
      }
      
      // Check native service health
      if (Platform.isAndroid || Platform.isIOS) {
        final isHealthy = await _bulletproofChannel.invokeMethod('checkServiceHealth');
        return isHealthy == true;
      }
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to check service health: $e');
      return false;
    }
  }
  
  // MARK: - Method Call Handlers
  
  /// Handle native method calls with safe JSON parsing
  static Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onLocationUpdate':
          // Safe JSON parsing with null checks and type validation
          final args = call.arguments;
          if (args == null) {
            developer.log('[$_tag] Null arguments received for location update');
            return;
          }
          
          Map<String, dynamic> locationData;
          if (args is Map<String, dynamic>) {
            locationData = args;
          } else if (args is String) {
            // Handle case where arguments might be JSON string
            try {
              locationData = Map<String, dynamic>.from(args as Map);
            } catch (e) {
              developer.log('[$_tag] Failed to parse location arguments as JSON: $e');
              return;
            }
          } else {
            developer.log('[$_tag] Invalid arguments type for location update: ${args.runtimeType}');
            return;
          }
          
          // Safely extract latitude and longitude with type checking
          final latitude = _safeExtractDouble(locationData, 'latitude');
          final longitude = _safeExtractDouble(locationData, 'longitude');
          
          if (latitude != null && longitude != null) {
            final location = LatLng(latitude, longitude);
            _processLocationUpdate(location, 'native');
          } else {
            developer.log('[$_tag] Invalid location data - lat: $latitude, lng: $longitude');
          }
          break;
          
        case 'onServiceStarted':
          developer.log('[$_tag] Native service started');
          onStatusUpdate?.call('Native service started');
          break;
          
        case 'onServiceStopped':
          developer.log('[$_tag] Native service stopped');
          _handleServiceFailure('Native service stopped unexpectedly');
          break;
          
        case 'onError':
          final error = _safeExtractString(call.arguments, 'error') ?? 
                       (call.arguments?.toString() ?? 'Unknown native error');
          developer.log('[$_tag] Native service error: $error');
          onError?.call('Native service error: $error');
          break;
          
        default:
          developer.log('[$_tag] Unknown native method call: ${call.method}');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling native method call: $e');
      // Don't propagate the error to prevent app crashes
    }
  }
  
  /// Safely extract double value from dynamic data
  static double? _safeExtractDouble(dynamic data, String key) {
    try {
      if (data is Map<String, dynamic>) {
        final value = data[key];
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value);
      }
      return null;
    } catch (e) {
      developer.log('[$_tag] Error extracting double for key $key: $e');
      return null;
    }
  }
  
  /// Safely extract string value from dynamic data
  static String? _safeExtractString(dynamic data, String key) {
    try {
      if (data is String) return data;
      if (data is Map<String, dynamic>) {
        final value = data[key];
        return value?.toString();
      }
      return data?.toString();
    } catch (e) {
      developer.log('[$_tag] Error extracting string for key $key: $e');
      return null;
    }
  }
  
  /// Handle permission method calls with safe JSON parsing
  static Future<dynamic> _handlePermissionMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onPermissionRevoked':
          final permission = _safeExtractString(call.arguments, 'permission') ?? 
                           (call.arguments?.toString() ?? 'Unknown permission');
          developer.log('[$_tag] Permission revoked: $permission');
          _handlePermissionFailure();
          break;
          
        case 'onPermissionGranted':
          final permission = _safeExtractString(call.arguments, 'permission') ?? 
                           (call.arguments?.toString() ?? 'Unknown permission');
          developer.log('[$_tag] Permission granted: $permission');
          onStatusUpdate?.call('Permission granted: $permission');
          break;
          
        default:
          developer.log('[$_tag] Unknown permission method call: ${call.method}');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling permission method call: $e');
      // Don't propagate the error to prevent app crashes
    }
  }
  
  /// Handle battery method calls with safe JSON parsing
  static Future<dynamic> _handleBatteryMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onBatteryOptimizationChanged':
          final isOptimized = _safeExtractBool(call.arguments, 'isOptimized') ?? false;
          developer.log('[$_tag] Battery optimization changed: $isOptimized');
          if (isOptimized) {
            onStatusUpdate?.call('Battery optimization enabled - may affect location tracking');
          } else {
            onStatusUpdate?.call('Battery optimization disabled - location tracking optimized');
          }
          break;
          
        default:
          developer.log('[$_tag] Unknown battery method call: ${call.method}');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling battery method call: $e');
      // Don't propagate the error to prevent app crashes
    }
  }
  
  /// Safely extract boolean value from dynamic data
  static bool? _safeExtractBool(dynamic data, String key) {
    try {
      if (data is bool) return data;
      if (data is Map<String, dynamic>) {
        final value = data[key];
        if (value is bool) return value;
        if (value is String) {
          return value.toLowerCase() == 'true';
        }
        if (value is int) return value != 0;
      }
      return null;
    } catch (e) {
      developer.log('[$_tag] Error extracting bool for key $key: $e');
      return null;
    }
  }
  
  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await stopTracking();
      _stopHealthMonitoring();
      _stopPermissionMonitoring();
      _firebaseRetryTimer?.cancel();
      _isInitialized = false;
    } catch (e) {
      developer.log('[$_tag] Error disposing service: $e');
    }
  }
}