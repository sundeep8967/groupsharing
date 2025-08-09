import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';
import 'firebase_service.dart';
import 'bulletproof_location_service.dart';
import 'android_background_location_fix.dart';
import 'android_8_background_location_solution.dart';

/// Comprehensive Location Fix Service
/// 
/// This service integrates all location fixes and solutions:
/// 1. JSON parsing error fixes for method channel communication
/// 2. Android 8.0+ background location limitations compliance
/// 3. Bulletproof location service integration
/// 4. Multi-layer fallback system for maximum reliability
/// 5. Device-specific optimizations
/// 6. Proper error handling and recovery mechanisms
class ComprehensiveLocationFixService {
  static const String _tag = 'ComprehensiveLocationFixService';
  
  // Service state
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static String? _currentUserId;
  static String? _activeService;
  
  // Service instances
  static bool _bulletproofServiceAvailable = false;
  static bool _android8SolutionAvailable = false;
  static bool _androidFixAvailable = false;
  
  // Location state
  static LatLng? _lastKnownLocation;
  static DateTime? _lastLocationUpdate;
  static Timer? _serviceHealthTimer;
  
  // Configuration
  static const Duration _healthCheckInterval = Duration(minutes: 2);
  static const Duration _serviceFailoverDelay = Duration(seconds: 10);
  
  // Firebase references
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseService.firestore;
  
  // Callbacks
  static Function(LatLng location)? onLocationUpdate;
  static Function(String error)? onError;
  static Function(String status)? onStatusUpdate;
  static Function(String service)? onServiceChanged;
  
  /// Initialize the comprehensive location fix service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Comprehensive Location Fix Service');
      
      // Initialize all available services
      await _initializeAllServices();
      
      // Setup service callbacks
      _setupServiceCallbacks();
      
      // Setup health monitoring
      _setupHealthMonitoring();
      
      _isInitialized = true;
      developer.log('[$_tag] Comprehensive Location Fix Service initialized successfully');
      
      // Log available services
      _logAvailableServices();
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize comprehensive location fix: $e');
      return false;
    }
  }
  
  /// Start location tracking with automatic service selection
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
      developer.log('[$_tag] Starting comprehensive location tracking');
      
      _currentUserId = userId;
      
      // Try services in order of preference
      final started = await _startBestAvailableService(userId);
      
      if (started) {
        _isTracking = true;
        _startHealthMonitoring();
        
        // Save tracking state
        await _saveTrackingState(true, userId);
        
        onStatusUpdate?.call('Comprehensive location tracking started with $_activeService');
        developer.log('[$_tag] Location tracking started successfully with $_activeService');
        return true;
      } else {
        onError?.call('Failed to start any location service');
        return false;
      }
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
      developer.log('[$_tag] Stopping comprehensive location tracking');
      
      // Stop health monitoring
      _serviceHealthTimer?.cancel();
      
      // Stop active service
      await _stopActiveService();
      
      // Clear state
      _isTracking = false;
      _currentUserId = null;
      _activeService = null;
      
      // Clear tracking state
      await _saveTrackingState(false, null);
      
      onStatusUpdate?.call('Location tracking stopped');
      
      developer.log('[$_tag] Comprehensive location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to stop tracking: $e');
      onError?.call('Failed to stop location tracking: $e');
      return false;
    }
  }
  
  /// Force switch to a specific service
  static Future<bool> switchToService(String serviceName, String userId) async {
    if (!_isTracking) return false;
    
    try {
      developer.log('[$_tag] Switching to service: $serviceName');
      
      // Stop current service
      await _stopActiveService();
      
      // Start requested service
      final started = await _startSpecificService(serviceName, userId);
      
      if (started) {
        _activeService = serviceName;
        onServiceChanged?.call(serviceName);
        onStatusUpdate?.call('Switched to $serviceName');
        developer.log('[$_tag] Successfully switched to $serviceName');
        return true;
      } else {
        // Fallback to best available service
        await _startBestAvailableService(userId);
        developer.log('[$_tag] Failed to switch to $serviceName, using fallback');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to switch service: $e');
      return false;
    }
  }
  
  // MARK: - Private Implementation
  
  /// Initialize all available services
  static Future<void> _initializeAllServices() async {
    developer.log('[$_tag] Initializing all location services...');
    
    // Initialize Bulletproof Location Service
    try {
      _bulletproofServiceAvailable = await BulletproofLocationService.initialize();
      developer.log('[$_tag] Bulletproof service available: $_bulletproofServiceAvailable');
    } catch (e) {
      developer.log('[$_tag] Bulletproof service initialization failed: $e');
      _bulletproofServiceAvailable = false;
    }
    
    // Initialize Android 8.0+ Solution (Android only)
    if (Platform.isAndroid) {
      try {
        _android8SolutionAvailable = await Android8BackgroundLocationSolution.initialize();
        developer.log('[$_tag] Android 8.0+ solution available: $_android8SolutionAvailable');
      } catch (e) {
        developer.log('[$_tag] Android 8.0+ solution initialization failed: $e');
        _android8SolutionAvailable = false;
      }
      
      // Initialize Android Background Location Fix
      try {
        _androidFixAvailable = await AndroidBackgroundLocationFix.initialize();
        developer.log('[$_tag] Android fix available: $_androidFixAvailable');
      } catch (e) {
        developer.log('[$_tag] Android fix initialization failed: $e');
        _androidFixAvailable = false;
      }
    }
  }
  
  /// Setup callbacks for all services
  static void _setupServiceCallbacks() {
    // Bulletproof Location Service callbacks
    BulletproofLocationService.onLocationUpdate = (location) {
      _handleLocationUpdate(location, 'bulletproof');
    };
    BulletproofLocationService.onError = (error) {
      _handleServiceError('bulletproof', error);
    };
    BulletproofLocationService.onStatusUpdate = (status) {
      onStatusUpdate?.call('Bulletproof: $status');
    };
    
    // Android 8.0+ Solution callbacks
    if (Platform.isAndroid) {
      Android8BackgroundLocationSolution.onLocationUpdate = (location) {
        _handleLocationUpdate(location, 'android8');
      };
      Android8BackgroundLocationSolution.onError = (error) {
        _handleServiceError('android8', error);
      };
      Android8BackgroundLocationSolution.onStatusUpdate = (status) {
        onStatusUpdate?.call('Android8: $status');
      };
      
      // Android Background Location Fix callbacks
      AndroidBackgroundLocationFix.onLocationUpdate = (location) {
        _handleLocationUpdate(location, 'androidfix');
      };
      AndroidBackgroundLocationFix.onError = (error) {
        _handleServiceError('androidfix', error);
      };
      AndroidBackgroundLocationFix.onStatusUpdate = (status) {
        onStatusUpdate?.call('AndroidFix: $status');
      };
    }
  }
  
  /// Start the best available service
  static Future<bool> _startBestAvailableService(String userId) async {
    // Service priority order
    final servicePriority = [
      'bulletproof',
      'android8',
      'androidfix',
    ];
    
    for (final service in servicePriority) {
      if (await _isServiceAvailable(service)) {
        final started = await _startSpecificService(service, userId);
        if (started) {
          _activeService = service;
          onServiceChanged?.call(service);
          developer.log('[$_tag] Started service: $service');
          return true;
        }
      }
    }
    
    developer.log('[$_tag] No services available to start');
    return false;
  }
  
  /// Check if a specific service is available
  static Future<bool> _isServiceAvailable(String serviceName) async {
    switch (serviceName) {
      case 'bulletproof':
        return _bulletproofServiceAvailable;
      case 'android8':
        return Platform.isAndroid && _android8SolutionAvailable;
      case 'androidfix':
        return Platform.isAndroid && _androidFixAvailable;
      default:
        return false;
    }
  }
  
  /// Start a specific service
  static Future<bool> _startSpecificService(String serviceName, String userId) async {
    try {
      switch (serviceName) {
        case 'bulletproof':
          return await BulletproofLocationService.startTracking(userId);
        case 'android8':
          return await Android8BackgroundLocationSolution.startTracking(userId);
        case 'androidfix':
          return await AndroidBackgroundLocationFix.startTracking(userId);
        default:
          return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to start $serviceName: $e');
      return false;
    }
  }
  
  /// Stop the active service
  static Future<void> _stopActiveService() async {
    if (_activeService == null) return;
    
    try {
      switch (_activeService) {
        case 'bulletproof':
          await BulletproofLocationService.stopTracking();
          break;
        case 'android8':
          await Android8BackgroundLocationSolution.stopTracking();
          break;
        case 'androidfix':
          await AndroidBackgroundLocationFix.stopTracking();
          break;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to stop $_activeService: $e');
    }
  }
  
  /// Handle location updates from any service
  static void _handleLocationUpdate(LatLng location, String source) {
    _lastKnownLocation = location;
    _lastLocationUpdate = DateTime.now();
    
    developer.log('[$_tag] Location update from $source: ${location.latitude}, ${location.longitude}');
    
    // Forward to main callback
    onLocationUpdate?.call(location);
  }
  
  /// Handle service errors with automatic failover
  static void _handleServiceError(String serviceName, String error) async {
    developer.log('[$_tag] Service error from $serviceName: $error');
    
    // If this is the active service, try to failover
    if (serviceName == _activeService && _currentUserId != null) {
      developer.log('[$_tag] Active service failed, attempting failover...');
      
      // Wait a moment before failover
      await Future.delayed(_serviceFailoverDelay);
      
      // Try to start a different service
      final failoverSuccess = await _attemptServiceFailover(_currentUserId!);
      
      if (failoverSuccess) {
        onStatusUpdate?.call('Failover successful to $_activeService');
      } else {
        onError?.call('All location services failed: $error');
      }
    } else {
      // Forward error if not from active service
      onError?.call('$serviceName error: $error');
    }
  }
  
  /// Attempt service failover
  static Future<bool> _attemptServiceFailover(String userId) async {
    final currentService = _activeService;
    
    // Stop current service
    await _stopActiveService();
    _activeService = null;
    
    // Try other available services
    final servicePriority = [
      'bulletproof',
      'android8',
      'androidfix',
    ];
    
    for (final service in servicePriority) {
      if (service != currentService && await _isServiceAvailable(service)) {
        final started = await _startSpecificService(service, userId);
        if (started) {
          _activeService = service;
          onServiceChanged?.call(service);
          developer.log('[$_tag] Failover successful to $service');
          return true;
        }
      }
    }
    
    developer.log('[$_tag] Failover failed - no alternative services available');
    return false;
  }
  
  /// Setup health monitoring
  static void _setupHealthMonitoring() {
    // Health monitoring will be started when tracking begins
  }
  
  /// Start health monitoring
  static void _startHealthMonitoring() {
    _serviceHealthTimer?.cancel();
    _serviceHealthTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }
  
  /// Perform health check
  static void _performHealthCheck() async {
    try {
      // Check if we've received location updates recently
      if (_lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceLastUpdate > Duration(minutes: 5)) {
          developer.log('[$_tag] No location updates for ${timeSinceLastUpdate.inMinutes} minutes');
          
          // Attempt service restart
          if (_currentUserId != null) {
            await _attemptServiceRestart(_currentUserId!);
          }
        }
      }
      
      // Check active service health
      if (_activeService != null) {
        final isHealthy = await _checkActiveServiceHealth();
        if (!isHealthy) {
          developer.log('[$_tag] Active service health check failed');
          
          // Attempt failover
          if (_currentUserId != null) {
            await _attemptServiceFailover(_currentUserId!);
          }
        }
      }
      
      developer.log('[$_tag] Health check completed');
    } catch (e) {
      developer.log('[$_tag] Health check error: $e');
    }
  }
  
  /// Check active service health
  static Future<bool> _checkActiveServiceHealth() async {
    if (_activeService == null) return false;
    
    try {
      switch (_activeService) {
        case 'bulletproof':
          return await BulletproofLocationService.checkServiceHealth();
        case 'android8':
          return Android8BackgroundLocationSolution.isTracking;
        case 'androidfix':
          return AndroidBackgroundLocationFix.isTracking;
        default:
          return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to check $_activeService health: $e');
      return false;
    }
  }
  
  /// Attempt service restart
  static Future<bool> _attemptServiceRestart(String userId) async {
    if (_activeService == null) return false;
    
    try {
      developer.log('[$_tag] Attempting to restart $_activeService');
      
      // Stop and restart the current service
      await _stopActiveService();
      await Future.delayed(Duration(seconds: 2));
      
      final restarted = await _startSpecificService(_activeService!, userId);
      
      if (restarted) {
        developer.log('[$_tag] Service restart successful');
        onStatusUpdate?.call('Service restarted successfully');
        return true;
      } else {
        developer.log('[$_tag] Service restart failed, attempting failover');
        return await _attemptServiceFailover(userId);
      }
    } catch (e) {
      developer.log('[$_tag] Service restart error: $e');
      return false;
    }
  }
  
  /// Log available services
  static void _logAvailableServices() {
    developer.log('[$_tag] Available services:');
    developer.log('[$_tag] - Bulletproof: $_bulletproofServiceAvailable');
    if (Platform.isAndroid) {
      developer.log('[$_tag] - Android 8.0+ Solution: $_android8SolutionAvailable');
      developer.log('[$_tag] - Android Fix: $_androidFixAvailable');
    }
  }
  
  // MARK: - Public Getters
  
  static bool get isInitialized => _isInitialized;
  static bool get isTracking => _isTracking;
  static String? get activeService => _activeService;
  static LatLng? get lastKnownLocation => _lastKnownLocation;
  static String? get currentUserId => _currentUserId;
  
  /// Get comprehensive status information
  static Map<String, dynamic> getStatusInfo() {
    return {
      'isInitialized': _isInitialized,
      'isTracking': _isTracking,
      'activeService': _activeService,
      'currentUserId': _currentUserId,
      'lastLocationUpdate': _lastLocationUpdate?.toIso8601String(),
      'availableServices': {
        'bulletproof': _bulletproofServiceAvailable,
        'android8': _android8SolutionAvailable,
        'androidfix': _androidFixAvailable,
      },
      'platform': Platform.operatingSystem,
    };
  }
  
  /// Get available service names
  static List<String> getAvailableServices() {
    final services = <String>[];
    
    if (_bulletproofServiceAvailable) services.add('bulletproof');
    if (Platform.isAndroid && _android8SolutionAvailable) services.add('android8');
    if (Platform.isAndroid && _androidFixAvailable) services.add('androidfix');
    
    return services;
  }
  
  /// Check if tracking should be restored
  static Future<bool> shouldRestoreTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('comprehensive_location_tracking') ?? false;
      final userId = prefs.getString('comprehensive_user_id');
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
      return prefs.getString('comprehensive_user_id');
    } catch (e) {
      developer.log('[$_tag] Failed to get restore user ID: $e');
      return null;
    }
  }
  
  /// Restore tracking state from persistent storage
  static Future<bool> restoreTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('comprehensive_location_tracking') ?? false;
      final userId = prefs.getString('comprehensive_user_id');
      
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
  
  /// Save tracking state to persistent storage
  static Future<void> _saveTrackingState(bool isTracking, String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('comprehensive_location_tracking', isTracking);
      if (userId != null) {
        await prefs.setString('comprehensive_user_id', userId);
      } else {
        await prefs.remove('comprehensive_user_id');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to save tracking state: $e');
    }
  }
  
  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await stopTracking();
      
      // Dispose all services
      await BulletproofLocationService.dispose();
      if (Platform.isAndroid) {
        await Android8BackgroundLocationSolution.dispose();
        await AndroidBackgroundLocationFix.dispose();
      }
      
      _isInitialized = false;
    } catch (e) {
      developer.log('[$_tag] Error disposing service: $e');
    }
  }
}