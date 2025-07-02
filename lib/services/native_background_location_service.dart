import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Native Background Location Service
/// Integrates with the native Android BackgroundLocationService that provides
/// persistent foreground notifications with "Update Now" button functionality
class NativeBackgroundLocationService {
  static const MethodChannel _channel = MethodChannel('background_location');
  
  // State
  static bool _isInitialized = false;
  static bool _isRunning = false;
  static String? _currentUserId;
  
  // Callbacks
  static Function(LatLng)? onLocationUpdate;
  static Function(String)? onError;
  static VoidCallback? onServiceStarted;
  static VoidCallback? onServiceStopped;
  
  // Getters
  static bool get isInitialized => _isInitialized;
  static bool get isRunning => _isRunning;
  static String? get currentUserId => _currentUserId;
  
  /// Initialize the native background location service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('Initializing NativeBackgroundLocationService');
      
      // The native service doesn't need explicit initialization
      // It's ready to use when the method channel is available
      _isInitialized = true;
      
      developer.log('NativeBackgroundLocationService initialized successfully');
      return true;
    } catch (e) {
      developer.log('Failed to initialize NativeBackgroundLocationService: $e');
      return false;
    }
  }
  
  /// Start the native background location service with persistent notification
  static Future<bool> startService(String userId) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isRunning && _currentUserId == userId) {
      developer.log('Native background location service already running for user: ${userId.substring(0, 8)}');
      return true;
    }
    
    try {
      developer.log('Starting native background location service for user: ${userId.substring(0, 8)}');
      
      final result = await _channel.invokeMethod('start', {
        'userId': userId,
      });
      
      if (result == true) {
        // Service started successfully
        _isRunning = true;
        _currentUserId = userId;
        onServiceStarted?.call();
        
        developer.log('Native background location service started successfully');
        return true;
      } else {
        developer.log('Failed to start native background location service: result=$result');
        return false;
      }
    } catch (e) {
      developer.log('Error starting native background location service: $e');
      onError?.call('Failed to start service: $e');
      return false;
    }
  }
  
  /// Stop the native background location service
  static Future<bool> stopService() async {
    if (!_isRunning) return true;
    
    try {
      developer.log('Stopping native background location service');
      
      await _channel.invokeMethod('stop');
      
      _isRunning = false;
      _currentUserId = null;
      onServiceStopped?.call();
      
      developer.log('Native background location service stopped successfully');
      return true;
    } catch (e) {
      developer.log('Error stopping native background location service: $e');
      onError?.call('Failed to stop service: $e');
      return false;
    }
  }
  
  /// Check if the service is healthy and running
  static Future<bool> isServiceHealthy() async {
    try {
      // The native service doesn't expose a health check method
      // We assume it's healthy if we think it's running
      return _isRunning;
    } catch (e) {
      developer.log('Error checking service health: $e');
      return false;
    }
  }
  
  /// Get service status information
  static Map<String, dynamic> getStatusInfo() {
    return {
      'isInitialized': _isInitialized,
      'isRunning': _isRunning,
      'currentUserId': _currentUserId,
      'serviceName': 'NativeBackgroundLocationService',
      'hasUpdateNowButton': true,
      'persistsWhenAppClosed': true,
      'usesNativeCode': true,
    };
  }
  
  /// Restart the service (useful for recovery)
  static Future<bool> restartService() async {
    if (_currentUserId == null) {
      developer.log('Cannot restart service - no user ID available');
      return false;
    }
    
    final userId = _currentUserId!;
    
    try {
      developer.log('Restarting native background location service');
      
      // Stop the service first
      await stopService();
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 2));
      
      // Start it again
      return await startService(userId);
    } catch (e) {
      developer.log('Error restarting service: $e');
      return false;
    }
  }
  
  /// Force an immediate location update (triggers "Update Now" functionality)
  /// This can be called from Flutter to trigger the same action as the notification button
  static Future<bool> triggerUpdateNow() async {
    if (!_isRunning) {
      developer.log('Cannot trigger update - service not running');
      return false;
    }
    
    try {
      developer.log('Triggering immediate location update from Flutter');
      
      // Call the native method to trigger immediate location update
      final result = await _channel.invokeMethod('updateNow');
      
      if (result == true) {
        developer.log('Update Now triggered successfully');
        return true;
      } else {
        developer.log('Update Now failed to trigger');
        return false;
      }
    } catch (e) {
      developer.log('Error triggering update now: $e');
      // Fallback: The user can still use the notification button
      developer.log('Fallback: User should tap the "Update Now" button in the notification panel');
      return false;
    }
  }
  
  /// Get information about the persistent notification
  static Map<String, dynamic> getNotificationInfo() {
    return {
      'hasNotification': _isRunning,
      'notificationTitle': 'Location Sharing Active',
      'notificationContent': 'Sharing your location with family members',
      'hasUpdateNowButton': true,
      'hasStopButton': true,
      'persistsWhenAppClosed': true,
      'instructions': [
        '1. Check your notification panel',
        '2. Look for "Location Sharing Active" notification',
        '3. Expand the notification to see action buttons',
        '4. Tap "Update Now" for immediate location update',
        '5. Tap "Stop" to stop location sharing',
        '6. Notification persists even when app is closed',
      ],
    };
  }
  
  /// Dispose of the service
  static void dispose() {
    developer.log('Disposing NativeBackgroundLocationService');
    
    _isInitialized = false;
    _isRunning = false;
    _currentUserId = null;
    
    // Clear callbacks
    onLocationUpdate = null;
    onError = null;
    onServiceStarted = null;
    onServiceStopped = null;
  }
}