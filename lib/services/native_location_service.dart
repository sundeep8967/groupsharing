import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Universal Native Location Service
/// This service provides a unified interface to native background location services
/// for both Android and iOS platforms
class NativeLocationService {
  static const String _tag = 'NativeLocationService';
  
  // Method channels for different platforms
  static const MethodChannel _androidChannel = MethodChannel('background_location');
  static const MethodChannel _iosChannel = MethodChannel('persistent_location_service');
  
  // State tracking
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static String? _currentUserId;
  
  // Callbacks
  static Function(String message)? onStatusUpdate;
  static Function(String error)? onError;
  static Function()? onServiceStarted;
  static Function()? onServiceStopped;
  
  /// Initialize the native location service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _log('Initializing Native Location Service for ${Platform.operatingSystem}');
      
      // Platform-specific initialization
      if (Platform.isAndroid) {
        await _initializeAndroid();
      } else if (Platform.isIOS) {
        await _initializeIOS();
      } else {
        _logError('Unsupported platform: ${Platform.operatingSystem}');
        return false;
      }
      
      _isInitialized = true;
      _log('Native Location Service initialized successfully');
      return true;
    } catch (e) {
      _logError('Failed to initialize Native Location Service: $e');
      return false;
    }
  }
  
  /// Start native background location tracking
  static Future<bool> startTracking(String userId) async {
    if (!_isInitialized) {
      _logError('Service not initialized. Call initialize() first.');
      return false;
    }
    
    if (_isTracking && _currentUserId == userId) {
      _log('Already tracking for user: ${userId.substring(0, 8)}');
      return true;
    }
    
    try {
      _log('Starting native background location tracking for user: ${userId.substring(0, 8)}');
      
      // Save state
      await _saveTrackingState(true, userId);
      
      bool success = false;
      
      if (Platform.isAndroid) {
        success = await _startAndroidTracking(userId);
      } else if (Platform.isIOS) {
        success = await _startIOSTracking(userId);
      }
      
      if (success) {
        _isTracking = true;
        _currentUserId = userId;
        onServiceStarted?.call();
        onStatusUpdate?.call('Native background location service started');
        _log('✅ Native background location tracking started successfully');
      } else {
        _logError('Failed to start native background location tracking');
      }
      
      return success;
    } catch (e) {
      _logError('Error starting native background location tracking: $e');
      return false;
    }
  }
  
  /// Stop native background location tracking
  static Future<bool> stopTracking() async {
    if (!_isTracking) {
      _log('Not currently tracking');
      return true;
    }
    
    try {
      _log('Stopping native background location tracking');
      
      // Save state
      await _saveTrackingState(false, null);
      
      bool success = false;
      
      if (Platform.isAndroid) {
        success = await _stopAndroidTracking();
      } else if (Platform.isIOS) {
        success = await _stopIOSTracking();
      }
      
      if (success) {
        _isTracking = false;
        _currentUserId = null;
        onServiceStopped?.call();
        onStatusUpdate?.call('Native background location service stopped');
        _log('✅ Native background location tracking stopped successfully');
      } else {
        _logError('Failed to stop native background location tracking');
      }
      
      return success;
    } catch (e) {
      _logError('Error stopping native background location tracking: $e');
      return false;
    }
  }
  
  /// Check if native service is currently running
  static Future<bool> isServiceRunning() async {
    try {
      if (Platform.isAndroid) {
        return await _androidChannel.invokeMethod('isServiceRunning') ?? false;
      } else if (Platform.isIOS) {
        return await _iosChannel.invokeMethod('isServiceHealthy') ?? false;
      }
      return false;
    } catch (e) {
      _logError('Error checking service status: $e');
      return false;
    }
  }
  
  /// Request necessary permissions for background location
  static Future<bool> requestPermissions() async {
    try {
      _log('Requesting background location permissions');
      
      if (Platform.isAndroid) {
        return await _requestAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _requestIOSPermissions();
      }
      
      return false;
    } catch (e) {
      _logError('Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Check battery optimization status (Android only)
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    
    try {
      return await _androidChannel.invokeMethod('checkBatteryOptimization') ?? false;
    } catch (e) {
      _logError('Error checking battery optimization: $e');
      return false;
    }
  }
  
  /// Request to disable battery optimization (Android only)
  static Future<void> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _androidChannel.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      _logError('Error requesting battery optimization: $e');
    }
  }
  
  /// Restore tracking state after app restart
  static Future<bool> restoreTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('native_location_tracking_enabled') ?? false;
      final userId = prefs.getString('native_location_user_id');
      
      if (isEnabled && userId != null) {
        _log('Restoring native location tracking for user: ${userId.substring(0, 8)}');
        return await startTracking(userId);
      }
      
      return false;
    } catch (e) {
      _logError('Error restoring tracking state: $e');
      return false;
    }
  }
  
  // MARK: - Platform-specific implementations
  
  /// Initialize Android native service
  static Future<void> _initializeAndroid() async {
    try {
      // Android service is initialized when started
      _log('Android native service ready');
    } catch (e) {
      _logError('Android initialization error: $e');
      rethrow;
    }
  }
  
  /// Initialize iOS native service
  static Future<void> _initializeIOS() async {
    try {
      // iOS service initialization
      await _iosChannel.invokeMethod('registerBackgroundLocationHandler');
      _log('iOS native service ready');
    } catch (e) {
      _logError('iOS initialization error: $e');
      rethrow;
    }
  }
  
  /// Start Android background tracking
  static Future<bool> _startAndroidTracking(String userId) async {
    try {
      await _androidChannel.invokeMethod('startBackgroundLocationService', {
        'userId': userId,
      });
      return true;
    } catch (e) {
      _logError('Android start tracking error: $e');
      return false;
    }
  }
  
  /// Start iOS background tracking
  static Future<bool> _startIOSTracking(String userId) async {
    try {
      final result = await _iosChannel.invokeMethod('startBackgroundLocationService', {
        'userId': userId,
      });
      return result == true;
    } catch (e) {
      _logError('iOS start tracking error: $e');
      return false;
    }
  }
  
  /// Stop Android background tracking
  static Future<bool> _stopAndroidTracking() async {
    try {
      await _androidChannel.invokeMethod('stopBackgroundLocationService');
      return true;
    } catch (e) {
      _logError('Android stop tracking error: $e');
      return false;
    }
  }
  
  /// Stop iOS background tracking
  static Future<bool> _stopIOSTracking() async {
    try {
      final result = await _iosChannel.invokeMethod('stopBackgroundLocationService');
      return result == true;
    } catch (e) {
      _logError('iOS stop tracking error: $e');
      return false;
    }
  }
  
  /// Request Android permissions
  static Future<bool> _requestAndroidPermissions() async {
    try {
      // Request location permissions
      final locationPermission = await _androidChannel.invokeMethod('requestLocationPermissions');
      if (locationPermission != true) {
        _logError('Location permission denied');
        return false;
      }
      
      // Request background location permission
      final backgroundPermission = await _androidChannel.invokeMethod('requestBackgroundLocationPermission');
      if (backgroundPermission != true) {
        _logError('Background location permission denied');
        return false;
      }
      
      _log('Android permissions granted');
      return true;
    } catch (e) {
      _logError('Android permission error: $e');
      return false;
    }
  }
  
  /// Request iOS permissions
  static Future<bool> _requestIOSPermissions() async {
    try {
      final result = await _iosChannel.invokeMethod('requestBackgroundLocationPermission');
      _log('iOS permissions result: $result');
      return result == true;
    } catch (e) {
      _logError('iOS permission error: $e');
      return false;
    }
  }
  
  /// Save tracking state to preferences
  static Future<void> _saveTrackingState(bool enabled, String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('native_location_tracking_enabled', enabled);
      
      if (userId != null) {
        await prefs.setString('native_location_user_id', userId);
      } else {
        await prefs.remove('native_location_user_id');
      }
      
      // Also save to the keys used by native services
      await prefs.setBool('location_sharing_enabled', enabled);
      if (userId != null) {
        await prefs.setString('user_id', userId);
      } else {
        await prefs.remove('user_id');
      }
      
      _log('Tracking state saved: enabled=$enabled, userId=${userId?.substring(0, 8)}');
    } catch (e) {
      _logError('Error saving tracking state: $e');
    }
  }
  
  // MARK: - Getters
  
  static bool get isInitialized => _isInitialized;
  static bool get isTracking => _isTracking;
  static String? get currentUserId => _currentUserId;
  
  // MARK: - Logging
  
  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] $message', name: _tag);
    onStatusUpdate?.call(message);
  }
  
  static void _logError(String error) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] ERROR: $error', name: _tag);
    onError?.call(error);
  }
  
  /// Get comprehensive service status
  static Future<Map<String, dynamic>> getServiceStatus() async {
    final status = <String, dynamic>{
      'initialized': _isInitialized,
      'tracking': _isTracking,
      'platform': Platform.operatingSystem,
      'userId': _currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    try {
      status['serviceRunning'] = await isServiceRunning();
      
      if (Platform.isAndroid) {
        status['batteryOptimizationDisabled'] = await isBatteryOptimizationDisabled();
      }
      
      // Check saved preferences
      final prefs = await SharedPreferences.getInstance();
      status['savedTrackingEnabled'] = prefs.getBool('native_location_tracking_enabled') ?? false;
      status['savedUserId'] = prefs.getString('native_location_user_id');
      
    } catch (e) {
      status['error'] = e.toString();
    }
    
    return status;
  }
}