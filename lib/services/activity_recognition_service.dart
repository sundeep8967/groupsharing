import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Activity Recognition Service
///
/// This service uses Android's Activity Recognition API to detect user activities
/// and trigger location updates based on movement. This approach is more reliable for
/// background operation because:
///
/// 1. Google Play Services Integration: Activity Recognition uses Google Play Services,
///    which has system-level privileges that regular apps don't have
/// 2. Hardware-Level Detection: Uses accelerometer/gyroscope which work even in Doze mode
/// 3. Lower Power Consumption: More battery-efficient than continuous GPS
/// 4. OEM Tolerance: Most OEMs don't aggressively kill activity recognition services
class ActivityRecognitionService {
  static const String _tag = 'ActivityRecognitionService';
  
  // Method channels
  static const MethodChannel _channel = MethodChannel('activity_recognition_service');
  
  // Service state
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static String? _currentUserId;
  
  // Activity state
  static String _currentActivity = 'unknown';
  static int _currentConfidence = 0;
  static DateTime? _lastActivityUpdate;
  
  // Callbacks
  static Function(String activity, int confidence)? onActivityUpdate;
  static Function(String error)? onError;
  static Function(String status)? onStatusUpdate;
  
  /// Initialize the activity recognition service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Activity Recognition Service');
      
      // Only available on Android
      if (!Platform.isAndroid) {
        developer.log('[$_tag] Activity Recognition only supported on Android');
        return false;
      }
      
      // Setup method call handler
      _channel.setMethodCallHandler(_handleMethodCall);
      
      _isInitialized = true;
      developer.log('[$_tag] Activity Recognition Service initialized');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize Activity Recognition Service: $e');
      return false;
    }
  }
  
  /// Start activity recognition tracking
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
      developer.log('[$_tag] Starting activity recognition tracking');
      
      _currentUserId = userId;
      
      // Save user ID to shared preferences for native components
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter.current_user_id', userId);
      
      // Start native activity recognition service
      final result = await _channel.invokeMethod('startActivityRecognition');
      
      if (result == true) {
        _isTracking = true;
        onStatusUpdate?.call('Activity recognition tracking started');
        developer.log('[$_tag] Activity recognition tracking started successfully');
        return true;
      } else {
        onError?.call('Failed to start activity recognition tracking');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to start tracking: $e');
      onError?.call('Failed to start activity recognition tracking: $e');
      return false;
    }
  }
  
  /// Stop activity recognition tracking
  static Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('[$_tag] Stopping activity recognition tracking');
      
      // Stop native activity recognition service
      final result = await _channel.invokeMethod('stopActivityRecognition');
      
      if (result == true) {
        _isTracking = false;
        _currentUserId = null;
        onStatusUpdate?.call('Activity recognition tracking stopped');
        developer.log('[$_tag] Activity recognition tracking stopped successfully');
        return true;
      } else {
        onError?.call('Failed to stop activity recognition tracking');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to stop tracking: $e');
      onError?.call('Failed to stop activity recognition tracking: $e');
      return false;
    }
  }
  
  /// Get current activity state
  static Map<String, dynamic> getCurrentActivity() {
    return {
      'activity': _currentActivity,
      'confidence': _currentConfidence,
      'lastUpdate': _lastActivityUpdate,
    };
  }
  
  /// Check if tracking is currently active
  static bool get isTracking => _isTracking;
  
  /// Get current user ID
  static String? get currentUserId => _currentUserId;
  
  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onActivityDetected':
        final activityType = call.arguments['activityType'] as int;
        final activityName = call.arguments['activityName'] as String;
        final confidence = call.arguments['confidence'] as int;
        final timestamp = call.arguments['timestamp'] as int;
        
        _currentActivity = activityName;
        _currentConfidence = confidence;
        _lastActivityUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        developer.log('[$_tag] Activity detected: $activityName (confidence: $confidence%)');
        
        onActivityUpdate?.call(activityName, confidence);
        break;
        
      case 'onError':
        final error = call.arguments['error'] as String;
        developer.log('[$_tag] Error: $error');
        onError?.call(error);
        break;
    }
  }
}