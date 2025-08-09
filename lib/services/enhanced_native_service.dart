import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Enhanced Native Service that integrates all native implementations
/// Provides unified access to driving detection, emergency services, and geofencing
/// Works seamlessly with existing Flutter services as fallback
class EnhancedNativeService {
  static const String _tag = 'EnhancedNativeService';
  
  // Method channels for different native services
  static const MethodChannel _drivingChannel = MethodChannel('native_driving_detection');
  static const MethodChannel _emergencyChannel = MethodChannel('native_emergency_service');
  static const MethodChannel _geofenceChannel = MethodChannel('native_geofence_service');
  
  // State tracking
  static bool _isInitialized = false;
  static String? _currentUserId;
  
  // Callbacks for native events
  static Function(bool isDriving, Map<String, dynamic>? session)? onDrivingStateChanged;
  static Function(String event, Map<String, dynamic>? data)? onEmergencyEvent;
  static Function(String geofenceId, String transition, LatLng? location)? onGeofenceTransition;
  
  /// Initialize all native services
  static Future<bool> initialize(String userId) async {
    if (_isInitialized) return true;
    
    try {
      _log('Initializing Enhanced Native Service for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      // Initialize driving detection
      final drivingSuccess = await _initializeDrivingDetection(userId);
      _log('Driving detection initialized: $drivingSuccess');
      
      // Initialize emergency service
      final emergencySuccess = await _initializeEmergencyService(userId);
      _log('Emergency service initialized: $emergencySuccess');
      
      // Initialize geofence service
      final geofenceSuccess = await _initializeGeofenceService(userId);
      _log('Geofence service initialized: $geofenceSuccess');
      
      _isInitialized = true;
      _log('Enhanced Native Service initialized successfully');
      return true;
    } catch (e) {
      _log('Error initializing Enhanced Native Service: $e');
      return false;
    }
  }
  
  /// Stop all native services
  static Future<void> stop() async {
    if (!_isInitialized) return;
    
    try {
      _log('Stopping Enhanced Native Service');
      
      // Stop driving detection
      await _drivingChannel.invokeMethod('stop');
      
      // Stop geofence service
      await _geofenceChannel.invokeMethod('stop');
      
      _isInitialized = false;
      _currentUserId = null;
      _log('Enhanced Native Service stopped');
    } catch (e) {
      _log('Error stopping Enhanced Native Service: $e');
    }
  }
  
  // MARK: - Driving Detection
  
  static Future<bool> _initializeDrivingDetection(String userId) async {
    try {
      final result = await _drivingChannel.invokeMethod('initialize', {
        'userId': userId,
      });
      return result == true;
    } catch (e) {
      _log('Error initializing driving detection: $e');
      return false;
    }
  }
  
  static Future<void> stopDrivingDetection() async {
    try {
      await _drivingChannel.invokeMethod('stop');
    } catch (e) {
      _log('Error stopping driving detection: $e');
    }
  }
  
  // MARK: - Emergency Service
  
  static Future<bool> _initializeEmergencyService(String userId) async {
    try {
      final result = await _emergencyChannel.invokeMethod('initialize', {
        'userId': userId,
      });
      return result == true;
    } catch (e) {
      _log('Error initializing emergency service: $e');
      return false;
    }
  }
  
  static Future<void> startSosCountdown() async {
    try {
      await _emergencyChannel.invokeMethod('startSos', {
        'userId': _currentUserId,
      });
      _log('SOS countdown started');
    } catch (e) {
      _log('Error starting SOS countdown: $e');
    }
  }
  
  static Future<void> cancelSosCountdown() async {
    try {
      await _emergencyChannel.invokeMethod('cancelSos');
      _log('SOS countdown cancelled');
    } catch (e) {
      _log('Error cancelling SOS countdown: $e');
    }
  }
  
  static Future<void> triggerEmergency() async {
    try {
      await _emergencyChannel.invokeMethod('triggerEmergency', {
        'userId': _currentUserId,
      });
      _log('Emergency triggered');
    } catch (e) {
      _log('Error triggering emergency: $e');
    }
  }
  
  static Future<void> cancelEmergency() async {
    try {
      await _emergencyChannel.invokeMethod('cancelEmergency');
      _log('Emergency cancelled');
    } catch (e) {
      _log('Error cancelling emergency: $e');
    }
  }
  
  static Future<void> updateEmergencyLocation(LatLng location) async {
    try {
      await _emergencyChannel.invokeMethod('updateLocation', {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'accuracy': 10.0, // Default accuracy
      });
    } catch (e) {
      _log('Error updating emergency location: $e');
    }
  }
  
  // MARK: - Geofence Service
  
  static Future<bool> _initializeGeofenceService(String userId) async {
    try {
      final result = await _geofenceChannel.invokeMethod('initialize', {
        'userId': userId,
      });
      return result == true;
    } catch (e) {
      _log('Error initializing geofence service: $e');
      return false;
    }
  }
  
  static Future<void> addGeofence({
    required String id,
    required String name,
    required LatLng center,
    required double radius,
  }) async {
    try {
      await _geofenceChannel.invokeMethod('addGeofence', {
        'userId': _currentUserId,
        'id': id,
        'name': name,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'radius': radius,
      });
      _log('Geofence added: $id');
    } catch (e) {
      _log('Error adding geofence: $e');
    }
  }
  
  static Future<void> removeGeofence(String id) async {
    try {
      await _geofenceChannel.invokeMethod('removeGeofence', {
        'id': id,
      });
      _log('Geofence removed: $id');
    } catch (e) {
      _log('Error removing geofence: $e');
    }
  }
  
  static Future<void> clearAllGeofences() async {
    try {
      await _geofenceChannel.invokeMethod('clearAll');
      _log('All geofences cleared');
    } catch (e) {
      _log('Error clearing geofences: $e');
    }
  }
  
  // MARK: - Smart Places Integration
  
  static Future<void> addSmartPlace({
    required String id,
    required String name,
    required LatLng center,
    double radius = 100.0,
  }) async {
    await addGeofence(
      id: id,
      name: name,
      center: center,
      radius: radius,
    );
  }
  
  static Future<void> addHomePlace(LatLng location) async {
    await addSmartPlace(
      id: 'home',
      name: 'Home',
      center: location,
      radius: 150.0,
    );
  }
  
  static Future<void> addWorkPlace(LatLng location) async {
    await addSmartPlace(
      id: 'work',
      name: 'Work',
      center: location,
      radius: 100.0,
    );
  }
  
  static Future<void> addSchoolPlace(LatLng location) async {
    await addSmartPlace(
      id: 'school',
      name: 'School',
      center: location,
      radius: 100.0,
    );
  }
  
  // MARK: - Integration with Existing Services
  
  /// Start all native services when location sharing begins
  static Future<void> startWithLocationSharing(String userId) async {
    await initialize(userId);
    _log('Native services started with location sharing');
  }
  
  /// Stop all native services when location sharing stops
  static Future<void> stopWithLocationSharing() async {
    await stop();
    _log('Native services stopped with location sharing');
  }
  
  /// Update location for all native services
  static Future<void> updateLocation(LatLng location) async {
    if (!_isInitialized) return;
    
    // Update emergency service location
    await updateEmergencyLocation(location);
    
    // Note: Driving detection and geofencing get location updates automatically
    // from the native location services
  }
  
  // MARK: - Platform Detection
  
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  
  static bool get isNativeSupported => isAndroid || isIOS;
  
  // MARK: - Status and Health Checks
  
  static bool get isInitialized => _isInitialized;
  static String? get currentUserId => _currentUserId;
  
  static Future<Map<String, bool>> getServiceStatus() async {
    if (!_isInitialized) {
      return {
        'driving': false,
        'emergency': false,
        'geofence': false,
      };
    }
    
    try {
      // In a real implementation, you might want to check each service individually
      return {
        'driving': true,
        'emergency': true,
        'geofence': true,
      };
    } catch (e) {
      _log('Error getting service status: $e');
      return {
        'driving': false,
        'emergency': false,
        'geofence': false,
      };
    }
  }
  
  // MARK: - Event Handling
  
  static void handleNativeEvent(String service, String event, Map<String, dynamic>? data) {
    _log('Native event: $service.$event - $data');
    
    switch (service) {
      case 'driving':
        _handleDrivingEvent(event, data);
        break;
      case 'emergency':
        _handleEmergencyEvent(event, data);
        break;
      case 'geofence':
        _handleGeofenceEvent(event, data);
        break;
      default:
        _log('Unknown native service event: $service.$event');
    }
  }
  
  static void _handleDrivingEvent(String event, Map<String, dynamic>? data) {
    switch (event) {
      case 'driving_started':
        onDrivingStateChanged?.call(true, data);
        break;
      case 'driving_ended':
        onDrivingStateChanged?.call(false, data);
        break;
      default:
        _log('Unknown driving event: $event');
    }
  }
  
  static void _handleEmergencyEvent(String event, Map<String, dynamic>? data) {
    onEmergencyEvent?.call(event, data);
  }
  
  static void _handleGeofenceEvent(String event, Map<String, dynamic>? data) {
    if (data != null) {
      final geofenceId = data['geofenceId'] as String?;
      final transition = data['transitionType'] as String?;
      final locationData = data['location'] as Map<String, dynamic>?;
      
      LatLng? location;
      if (locationData != null) {
        final lat = locationData['latitude'] as double?;
        final lng = locationData['longitude'] as double?;
        if (lat != null && lng != null) {
          location = LatLng(lat, lng);
        }
      }
      
      if (geofenceId != null && transition != null) {
        onGeofenceTransition?.call(geofenceId, transition, location);
      }
    }
  }
  
  // MARK: - Utility Methods
  
  static void _log(String message) {
    developer.log('$_tag: $message');
  }
  
  /// Get a summary of native service capabilities
  static Map<String, dynamic> getCapabilities() {
    return {
      'platform': Platform.operatingSystem,
      'nativeSupported': isNativeSupported,
      'services': {
        'drivingDetection': isNativeSupported,
        'emergencyService': isNativeSupported,
        'geofenceService': isNativeSupported,
        'backgroundLocation': isNativeSupported,
      },
      'features': {
        'motionSensors': isNativeSupported,
        'backgroundTasks': isNativeSupported,
        'foregroundServices': isAndroid,
        'significantLocationChanges': isIOS,
        'geofencing': isNativeSupported,
        'emergencyCall': isNativeSupported,
        'localNotifications': isNativeSupported,
      },
    };
  }
}