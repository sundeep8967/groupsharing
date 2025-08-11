import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';

/// Hardware Sensor Fusion Service
///
/// This service uses multiple hardware sensors to detect user movement and context:
/// 1. Accelerometer - Detects movement start/stop and intensity
/// 2. Gyroscope - Detects orientation changes and rotation
/// 3. Magnetometer - Detects direction changes and compass heading
/// 4. Barometer - Detects elevation changes (stairs, hills, buildings)
/// 5. Ambient Light - Detects indoor/outdoor transitions
///
/// Benefits:
/// - Ultra-low battery usage (hardware sensors are very efficient)
/// - Works when GPS/Network unavailable
/// - Instant movement detection (no delay)
/// - Rich context information (walking vs driving vs stairs)
/// - Works in all environments (indoor, underground, etc.)
class SensorFusionService {
  static const String _tag = 'SensorFusionService';
  
  // Method channels
  static const MethodChannel _channel = MethodChannel('sensor_fusion_detector');
  
  // Service state
  static bool _isInitialized = false;
  static bool _isMonitoring = false;
  
  // Movement state
  static bool _isMoving = false;
  static double _movementIntensity = 0.0;
  static bool _isIndoor = true;
  static bool _isClimbingStairs = false;
  static String _lastMovementType = 'STILL';
  static DateTime? _lastMovementTime;
  
  // Sensor availability
  static Map<String, bool> _sensorsAvailable = {};
  
  // Callbacks
  static Function(String eventType, Map<String, dynamic> data, Map<String, dynamic> context)? onSensorMovementDetected;
  static Function(String error)? onError;
  static Function(String status)? onStatusUpdate;
  
  /// Initialize the sensor fusion service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Hardware Sensor Fusion Service');
      
      // Only available on Android
      if (!Platform.isAndroid) {
        developer.log('[$_tag] Hardware Sensor Fusion only supported on Android');
        return false;
      }
      
      // Setup method call handler
      _channel.setMethodCallHandler(_handleMethodCall);
      
      _isInitialized = true;
      developer.log('[$_tag] Hardware Sensor Fusion Service initialized');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize Hardware Sensor Fusion Service: $e');
      return false;
    }
  }
  
  /// Start sensor fusion monitoring
  static Future<bool> startMonitoring() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isMonitoring) {
      developer.log('[$_tag] Already monitoring sensor fusion');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting sensor fusion monitoring');
      
      // Start native sensor monitoring
      final result = await _channel.invokeMethod('startSensorMonitoring');
      
      if (result == true) {
        _isMonitoring = true;
        
        // Get sensor availability
        await _updateSensorState();
        
        onStatusUpdate?.call('Hardware sensor monitoring started');
        developer.log('[$_tag] Sensor fusion monitoring started successfully');
        return true;
      } else {
        onError?.call('Failed to start sensor fusion monitoring');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to start monitoring: $e');
      onError?.call('Failed to start sensor fusion monitoring: $e');
      return false;
    }
  }
  
  /// Stop sensor fusion monitoring
  static Future<bool> stopMonitoring() async {
    if (!_isMonitoring) return true;
    
    try {
      developer.log('[$_tag] Stopping sensor fusion monitoring');
      
      // Stop native sensor monitoring
      final result = await _channel.invokeMethod('stopSensorMonitoring');
      
      if (result == true) {
        _isMonitoring = false;
        onStatusUpdate?.call('Hardware sensor monitoring stopped');
        developer.log('[$_tag] Sensor fusion monitoring stopped successfully');
        return true;
      } else {
        onError?.call('Failed to stop sensor fusion monitoring');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to stop monitoring: $e');
      onError?.call('Failed to stop sensor fusion monitoring: $e');
      return false;
    }
  }
  
  /// Get current sensor state
  static Future<Map<String, dynamic>?> getSensorState() async {
    if (!_isMonitoring) return null;
    
    try {
      final result = await _channel.invokeMethod('getSensorState');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      developer.log('[$_tag] Failed to get sensor state: $e');
      return null;
    }
  }
  
  /// Update sensor state from native
  static Future<void> _updateSensorState() async {
    final state = await getSensorState();
    if (state != null) {
      _isMoving = state['isMoving'] ?? false;
      _movementIntensity = (state['movementIntensity'] ?? 0.0).toDouble();
      _isIndoor = state['isIndoor'] ?? true;
      _isClimbingStairs = state['isClimbingStairs'] ?? false;
      
      final sensorsAvailable = state['sensorsAvailable'] as Map<String, dynamic>?;
      if (sensorsAvailable != null) {
        _sensorsAvailable = Map<String, bool>.from(sensorsAvailable);
      }
    }
  }
  
  /// Get current monitoring state
  static bool get isMonitoring => _isMonitoring;
  
  /// Get current movement state
  static Map<String, dynamic> getCurrentMovementState() {
    return {
      'isMoving': _isMoving,
      'movementIntensity': _movementIntensity,
      'isIndoor': _isIndoor,
      'isClimbingStairs': _isClimbingStairs,
      'lastMovementType': _lastMovementType,
      'lastMovementTime': _lastMovementTime,
      'sensorsAvailable': _sensorsAvailable,
    };
  }
  
  /// Check if movement is significant enough to trigger location update
  static bool isSignificantMovement(String eventType, Map<String, dynamic> data) {
    switch (eventType) {
      case 'MOVEMENT_STARTED':
        final intensity = (data['intensity'] ?? 0.0) as double;
        return intensity > 2.0; // Significant acceleration
        
      case 'MOVEMENT_CLASSIFIED':
        final movementType = data['movementType'] as String?;
        return movementType != null && movementType != 'STILL';
        
      case 'STAIRS_DETECTED':
        return true; // Stairs always indicate significant movement
        
      case 'ENTERED_OUTDOOR':
        return true; // Going outdoor often means starting a journey
        
      case 'ORIENTATION_CHANGED':
        final rotation = (data['rotation'] ?? 0.0) as double;
        return rotation > 1.0 && _isMoving; // Significant rotation while moving
        
      case 'DIRECTION_CHANGED':
        return _isMoving; // Direction change while moving indicates navigation
        
      default:
        return false;
    }
  }
  
  /// Get movement context description
  static String getMovementDescription(String eventType, Map<String, dynamic> data, Map<String, dynamic> context) {
    switch (eventType) {
      case 'MOVEMENT_STARTED':
        final intensity = (data['intensity'] ?? 0.0) as double;
        return 'Movement started (intensity: ${intensity.toStringAsFixed(1)})';
        
      case 'MOVEMENT_STOPPED':
        final duration = (data['duration'] ?? 0) as int;
        return 'Movement stopped (duration: ${(duration / 1000).toStringAsFixed(0)}s)';
        
      case 'MOVEMENT_CLASSIFIED':
        final movementType = data['movementType'] as String? ?? 'Unknown';
        return 'Movement type: $movementType';
        
      case 'STAIRS_DETECTED':
        final elevation = (data['elevationChange'] ?? 0.0) as double;
        return 'Climbing stairs (${elevation.toStringAsFixed(0)}m elevation)';
        
      case 'ENTERED_INDOOR':
        return 'Entered indoor environment';
        
      case 'ENTERED_OUTDOOR':
        return 'Entered outdoor environment';
        
      case 'ORIENTATION_CHANGED':
        return 'Device orientation changed';
        
      case 'DIRECTION_CHANGED':
        return 'Direction changed';
        
      default:
        return 'Sensor event: $eventType';
    }
  }
  
  /// Get sensor availability summary
  static String getSensorAvailabilitySummary() {
    if (_sensorsAvailable.isEmpty) return 'No sensor data available';
    
    final available = _sensorsAvailable.entries.where((e) => e.value).map((e) => e.key).toList();
    final unavailable = _sensorsAvailable.entries.where((e) => !e.value).map((e) => e.key).toList();
    
    String summary = '';
    if (available.isNotEmpty) {
      summary += 'Available: ${available.join(', ')}';
    }
    if (unavailable.isNotEmpty) {
      if (summary.isNotEmpty) summary += '; ';
      summary += 'Unavailable: ${unavailable.join(', ')}';
    }
    
    return summary;
  }
  
  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSensorMovementDetected':
        final eventType = call.arguments['eventType'] as String;
        final timestamp = call.arguments['timestamp'] as int;
        final data = Map<String, dynamic>.from(call.arguments['data'] as Map);
        final context = Map<String, dynamic>.from(call.arguments['context'] as Map);
        
        _lastMovementTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        // Update internal state from context
        _isMoving = context['isMoving'] ?? false;
        _movementIntensity = (context['movementIntensity'] ?? 0.0).toDouble();
        _isIndoor = context['isIndoor'] ?? true;
        _isClimbingStairs = context['isClimbingStairs'] ?? false;
        
        // Update movement type if classified
        if (eventType == 'MOVEMENT_CLASSIFIED') {
          _lastMovementType = data['movementType'] ?? 'UNKNOWN';
        }
        
        developer.log('[$_tag] Sensor movement detected: $eventType');
        developer.log('[$_tag] Context: isMoving=$_isMoving, intensity=$_movementIntensity, indoor=$_isIndoor');
        
        onSensorMovementDetected?.call(eventType, data, context);
        break;
        
      case 'onError':
        final error = call.arguments['error'] as String;
        developer.log('[$_tag] Error: $error');
        onError?.call(error);
        break;
    }
  }
}