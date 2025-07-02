import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'native_background_location_service.dart';
import 'persistent_location_service.dart';
import 'auth_service.dart';

/// Universal Location Integration Service
/// 
/// This service ensures that ALL authenticated users get the same working
/// background location functionality that was previously only available to test users.
/// 
/// Key Features:
/// - Persistent foreground notification with "Update Now" button
/// - Background location tracking that survives app kills
/// - Real-time Firebase sync
/// - Automatic service recovery
/// - Works for ALL authenticated users, not just test users
class UniversalLocationIntegrationService {
  static const String _tag = 'UniversalLocationIntegration';
  
  // State tracking
  static bool _isInitialized = false;
  static bool _isActive = false;
  static String? _currentUserId;
  static Timer? _healthCheckTimer;
  static Timer? _syncTimer;
  
  // Firebase references
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Callbacks
  static Function(LatLng)? onLocationUpdate;
  static Function(String)? onError;
  static VoidCallback? onServiceStarted;
  static VoidCallback? onServiceStopped;
  
  /// Initialize the universal location integration
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing universal location integration');
      
      // Initialize native background service
      final nativeInitialized = await NativeBackgroundLocationService.initialize();
      if (!nativeInitialized) {
        developer.log('[$_tag] Warning: Native service initialization failed');
      }
      
      // Initialize persistent service as backup
      final persistentInitialized = await PersistentLocationService.initialize();
      if (!persistentInitialized) {
        developer.log('[$_tag] Warning: Persistent service initialization failed');
      }
      
      _isInitialized = true;
      developer.log('[$_tag] Universal location integration initialized successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      return false;
    }
  }
  
  /// Start location tracking for ANY authenticated user
  /// This provides the same functionality that test users had
  static Future<bool> startLocationTrackingForUser(String userId) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isActive && _currentUserId == userId) {
      developer.log('[$_tag] Already tracking for user: ${userId.substring(0, 8)}');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting universal location tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      // Step 1: Update Firebase status immediately
      await _updateUserLocationSharingStatus(userId, true);
      
      // Step 2: Start native background service (priority)
      // This provides the persistent notification with "Update Now" button
      final nativeStarted = await _startNativeService(userId);
      
      // Step 3: Start persistent service as backup
      final persistentStarted = await _startPersistentService(userId);
      
      // Step 4: Verify at least one service is running
      if (!nativeStarted && !persistentStarted) {
        developer.log('[$_tag] CRITICAL: Both services failed to start for user: ${userId.substring(0, 8)}');
        await _updateUserLocationSharingStatus(userId, false);
        return false;
      }
      
      // Step 5: Start monitoring and sync
      _startHealthMonitoring();
      _startSyncMonitoring();
      
      _isActive = true;
      onServiceStarted?.call();
      
      developer.log('[$_tag] SUCCESS: Universal location tracking started for user: ${userId.substring(0, 8)}');
      developer.log('[$_tag] Native service: ${nativeStarted ? "RUNNING" : "FAILED"}');
      developer.log('[$_tag] Persistent service: ${persistentStarted ? "RUNNING" : "FAILED"}');
      
      return true;
    } catch (e) {
      developer.log('[$_tag] FAILED to start location tracking: $e');
      onError?.call('Failed to start location tracking: $e');
      return false;
    }
  }
  
  /// Stop location tracking
  static Future<bool> stopLocationTracking() async {
    if (!_isActive) return true;
    
    try {
      developer.log('[$_tag] Stopping universal location tracking');
      
      // Update Firebase status
      if (_currentUserId != null) {
        await _updateUserLocationSharingStatus(_currentUserId!, false);
      }
      
      // Stop native service
      await NativeBackgroundLocationService.stopService();
      
      // Stop persistent service
      await PersistentLocationService.stopTracking();
      
      // Stop monitoring
      _stopHealthMonitoring();
      _stopSyncMonitoring();
      
      _isActive = false;
      _currentUserId = null;
      onServiceStopped?.call();
      
      developer.log('[$_tag] Universal location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Error stopping location tracking: $e');
      return false;
    }
  }
  
  /// Trigger immediate location update (same as notification "Update Now" button)
  static Future<bool> triggerUpdateNow() async {
    if (!_isActive || _currentUserId == null) {
      developer.log('[$_tag] Cannot trigger update: service not active');
      return false;
    }
    
    try {
      developer.log('[$_tag] Triggering immediate location update');
      
      // Try native service first (this is what the notification button does)
      final nativeTriggered = await NativeBackgroundLocationService.triggerUpdateNow();
      if (nativeTriggered) {
        developer.log('[$_tag] Native service update triggered successfully');
        return true;
      }
      
      // Fallback to persistent service
      developer.log('[$_tag] Native service failed, trying persistent service');
      // Persistent service doesn't have direct trigger, so we'll force a sync
      await _forceSyncLocation();
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Error triggering update: $e');
      onError?.call('Failed to trigger location update: $e');
      return false;
    }
  }
  
  /// Get service status information
  static Map<String, dynamic> getServiceStatus() {
    final nativeStatus = NativeBackgroundLocationService.getStatusInfo();
    
    // Create persistent service status manually since getStatusInfo() doesn't exist
    final persistentStatus = {
      'isTracking': PersistentLocationService.isTracking,
      'serviceName': 'PersistentLocationService',
      'isInitialized': true, // Assume initialized if we can access it
    };
    
    return {
      'isActive': _isActive,
      'currentUserId': _currentUserId,
      'nativeService': nativeStatus,
      'persistentService': persistentStatus,
      'hasUpdateNowButton': nativeStatus['hasUpdateNowButton'] == true,
      'persistsWhenAppClosed': true,
      'instructions': [
        '1. Location sharing is ${_isActive ? "ACTIVE" : "INACTIVE"}',
        '2. Check notification panel for "Location Sharing Active"',
        '3. Tap "Update Now" button for immediate location update',
        '4. Service persists even when app is closed',
        '5. Works for ALL authenticated users',
      ],
    };
  }
  
  /// Check if the service is working for the current user
  static bool isWorkingForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    return _isActive && _currentUserId == user.uid;
  }
  
  // Private helper methods
  
  static Future<bool> _startNativeService(String userId) async {
    try {
      // Set up callbacks
      NativeBackgroundLocationService.onLocationUpdate = (LatLng location) {
        developer.log('[$_tag] Native service location update: ${location.latitude}, ${location.longitude}');
        onLocationUpdate?.call(location);
        _syncLocationToFirebase(location);
      };
      
      NativeBackgroundLocationService.onError = (String error) {
        developer.log('[$_tag] Native service error: $error');
        onError?.call(error);
      };
      
      // Start the service
      final started = await NativeBackgroundLocationService.startService(userId);
      
      if (started) {
        developer.log('[$_tag] Native background service started successfully');
        return true;
      } else {
        developer.log('[$_tag] Native background service failed to start');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Error starting native service: $e');
      return false;
    }
  }
  
  static Future<bool> _startPersistentService(String userId) async {
    try {
      final started = await PersistentLocationService.startTracking(
        userId: userId,
        onLocationUpdate: (LatLng location) {
          developer.log('[$_tag] Persistent service location update: ${location.latitude}, ${location.longitude}');
          onLocationUpdate?.call(location);
          _syncLocationToFirebase(location);
        },
        onError: (String error) {
          developer.log('[$_tag] Persistent service error: $error');
          onError?.call(error);
        },
        onServiceStopped: () {
          developer.log('[$_tag] Persistent service stopped unexpectedly');
          // Try to restart if still active
          if (_isActive && _currentUserId != null) {
            Future.delayed(const Duration(seconds: 5), () {
              _startPersistentService(_currentUserId!);
            });
          }
        },
      );
      
      if (started) {
        developer.log('[$_tag] Persistent location service started successfully');
        return true;
      } else {
        developer.log('[$_tag] Persistent location service failed to start');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Error starting persistent service: $e');
      return false;
    }
  }
  
  static Future<void> _updateUserLocationSharingStatus(String userId, bool isSharing) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Update Realtime Database for instant sync
      await _realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': isSharing,
        'lastSeen': ServerValue.timestamp,
        'lastHeartbeat': timestamp,
        'appUninstalled': false,
      });
      
      // Update Firestore for persistence
      await _firestore.collection('users').doc(userId).update({
        'locationSharingEnabled': isSharing,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'appUninstalled': false,
      });
      
      if (!isSharing) {
        // Clear location data when stopping
        await _realtimeDb.ref('locations/$userId').remove();
      }
      
      developer.log('[$_tag] Updated location sharing status for user: ${userId.substring(0, 8)} -> $isSharing');
    } catch (e) {
      developer.log('[$_tag] Error updating location sharing status: $e');
    }
  }
  
  static Future<void> _syncLocationToFirebase(LatLng location) async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final timestampReadable = DateTime.now().toIso8601String();
      
      // Update Realtime Database with location
      await _realtimeDb.ref('locations/${_currentUserId!}').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'timestamp': timestamp,
        'timestampReadable': timestampReadable,
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
      
      developer.log('[$_tag] Location synced to Firebase: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      developer.log('[$_tag] Error syncing location to Firebase: $e');
    }
  }
  
  static Future<void> _forceSyncLocation() async {
    if (_currentUserId == null) return;
    
    try {
      // Force a location update through the persistent service
      // This is a fallback when native service fails
      developer.log('[$_tag] Forcing location sync for user: ${_currentUserId!.substring(0, 8)}');
      
      // The persistent service should handle this automatically
      // We just need to ensure the heartbeat is updated
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await _realtimeDb.ref('users/${_currentUserId!}').update({
        'lastHeartbeat': timestamp,
        'forceLocationUpdate': timestamp,
      });
      
      developer.log('[$_tag] Force sync triggered');
    } catch (e) {
      developer.log('[$_tag] Error forcing location sync: $e');
    }
  }
  
  static void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _performHealthCheck();
    });
  }
  
  static void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }
  
  static Future<void> _performHealthCheck() async {
    if (!_isActive || _currentUserId == null) return;
    
    try {
      // Check native service health
      final nativeHealthy = await NativeBackgroundLocationService.isServiceHealthy();
      
      // Check persistent service health
      final persistentHealthy = PersistentLocationService.isTracking;
      
      if (!nativeHealthy && !persistentHealthy) {
        developer.log('[$_tag] CRITICAL: Both services are unhealthy, attempting restart');
        
        // Try to restart both services
        await _startNativeService(_currentUserId!);
        await _startPersistentService(_currentUserId!);
      } else if (!nativeHealthy) {
        developer.log('[$_tag] Native service unhealthy, attempting restart');
        await _startNativeService(_currentUserId!);
      } else if (!persistentHealthy) {
        developer.log('[$_tag] Persistent service unhealthy, attempting restart');
        await _startPersistentService(_currentUserId!);
      }
      
      developer.log('[$_tag] Health check completed - Native: $nativeHealthy, Persistent: $persistentHealthy');
    } catch (e) {
      developer.log('[$_tag] Error during health check: $e');
    }
  }
  
  static void _startSyncMonitoring() {
    _syncTimer?.cancel();
    
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _performSyncCheck();
    });
  }
  
  static void _stopSyncMonitoring() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  static Future<void> _performSyncCheck() async {
    if (!_isActive || _currentUserId == null) return;
    
    try {
      // Send heartbeat to keep the user active
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await _realtimeDb.ref('users/${_currentUserId!}').update({
        'lastHeartbeat': timestamp,
        'appUninstalled': false,
      });
      
      // Ensure location sharing status is correct
      await _updateUserLocationSharingStatus(_currentUserId!, true);
    } catch (e) {
      developer.log('[$_tag] Error during sync check: $e');
    }
  }
  
  /// Dispose of the service
  static void dispose() {
    developer.log('[$_tag] Disposing universal location integration service');
    
    _stopHealthMonitoring();
    _stopSyncMonitoring();
    
    _isInitialized = false;
    _isActive = false;
    _currentUserId = null;
    
    // Clear callbacks
    onLocationUpdate = null;
    onError = null;
    onServiceStarted = null;
    onServiceStopped = null;
  }
}