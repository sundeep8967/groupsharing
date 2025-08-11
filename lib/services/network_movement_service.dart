import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';

/// Network Movement Service
///
/// This service detects user movement using network changes instead of GPS:
/// 1. Cell Tower Changes - Detects movement between cellular coverage areas
/// 2. WiFi Network Changes - Detects movement between different locations
///
/// Benefits:
/// - ZERO GPS battery usage
/// - Works when GPS is disabled
/// - Detects movement in poor GPS signal areas
/// - Triggers location updates only when user actually moves
class NetworkMovementService {
  static const String _tag = 'NetworkMovementService';
  
  // Method channels
  static const MethodChannel _channel = MethodChannel('network_movement_detector');
  
  // Service state
  static bool _isInitialized = false;
  static bool _isMonitoring = false;
  
  // Network state
  static String? _currentCellId;
  static String? _currentWifiSSID;
  static DateTime? _lastNetworkChange;
  
  // Callbacks
  static Function(String changeType, Map<String, dynamic> details)? onNetworkMovementDetected;
  static Function(String error)? onError;
  static Function(String status)? onStatusUpdate;
  
  /// Initialize the network movement service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Network Movement Service');
      
      // Only available on Android
      if (!Platform.isAndroid) {
        developer.log('[$_tag] Network Movement Detection only supported on Android');
        return false;
      }
      
      // Setup method call handler
      _channel.setMethodCallHandler(_handleMethodCall);
      
      _isInitialized = true;
      developer.log('[$_tag] Network Movement Service initialized');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize Network Movement Service: $e');
      return false;
    }
  }
  
  /// Start network movement monitoring
  static Future<bool> startMonitoring() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isMonitoring) {
      developer.log('[$_tag] Already monitoring network movement');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting network movement monitoring');
      
      // Start native network monitoring
      final result = await _channel.invokeMethod('startNetworkMonitoring');
      
      if (result == true) {
        _isMonitoring = true;
        onStatusUpdate?.call('Network movement monitoring started');
        developer.log('[$_tag] Network movement monitoring started successfully');
        return true;
      } else {
        onError?.call('Failed to start network movement monitoring');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to start monitoring: $e');
      onError?.call('Failed to start network movement monitoring: $e');
      return false;
    }
  }
  
  /// Stop network movement monitoring
  static Future<bool> stopMonitoring() async {
    if (!_isMonitoring) return true;
    
    try {
      developer.log('[$_tag] Stopping network movement monitoring');
      
      // Stop native network monitoring
      final result = await _channel.invokeMethod('stopNetworkMonitoring');
      
      if (result == true) {
        _isMonitoring = false;
        onStatusUpdate?.call('Network movement monitoring stopped');
        developer.log('[$_tag] Network movement monitoring stopped successfully');
        return true;
      } else {
        onError?.call('Failed to stop network movement monitoring');
        return false;
      }
    } catch (e) {
      developer.log('[$_tag] Failed to stop monitoring: $e');
      onError?.call('Failed to stop network movement monitoring: $e');
      return false;
    }
  }
  
  /// Manually trigger cell tower check
  static Future<void> checkCellTower() async {
    if (!_isMonitoring) return;
    
    try {
      await _channel.invokeMethod('checkCellTower');
    } catch (e) {
      developer.log('[$_tag] Failed to check cell tower: $e');
    }
  }
  
  /// Get current monitoring state
  static bool get isMonitoring => _isMonitoring;
  
  /// Get current network state
  static Map<String, dynamic> getCurrentNetworkState() {
    return {
      'cellId': _currentCellId,
      'wifiSSID': _currentWifiSSID,
      'lastChange': _lastNetworkChange,
      'isMonitoring': _isMonitoring,
    };
  }
  
  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNetworkMovementDetected':
        final changeType = call.arguments['changeType'] as String;
        final timestamp = call.arguments['timestamp'] as int;
        final details = call.arguments['details'] as Map<String, dynamic>;
        
        _lastNetworkChange = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        // Update current network state
        if (changeType == 'CELL_TOWER_CHANGE') {
          _currentCellId = details['newCellId'] as String?;
        } else if (changeType == 'WIFI_NETWORK_CHANGE') {
          _currentWifiSSID = details['newSSID'] as String?;
        }
        
        developer.log('[$_tag] Network movement detected: $changeType');
        developer.log('[$_tag] Details: $details');
        
        onNetworkMovementDetected?.call(changeType, details);
        break;
        
      case 'checkCellTower':
        // Trigger cell tower check from native callback
        await checkCellTower();
        break;
        
      case 'onError':
        final error = call.arguments['error'] as String;
        developer.log('[$_tag] Error: $error');
        onError?.call(error);
        break;
    }
  }
  
  /// Get human-readable description of network change
  static String getNetworkChangeDescription(String changeType, Map<String, dynamic> details) {
    switch (changeType) {
      case 'CELL_TOWER_CHANGE':
        final oldCell = details['oldCellId'] ?? 'Unknown';
        final newCell = details['newCellId'] ?? 'Unknown';
        return 'Cell tower changed from $oldCell to $newCell';
        
      case 'WIFI_NETWORK_CHANGE':
        final oldWifi = details['oldSSID'] ?? 'None';
        final newWifi = details['newSSID'] ?? 'None';
        return 'WiFi network changed from $oldWifi to $newWifi';
        
      default:
        return 'Network change detected: $changeType';
    }
  }
  
  /// Check if network change indicates significant movement
  static bool isSignificantNetworkChange(String changeType, Map<String, dynamic> details) {
    switch (changeType) {
      case 'CELL_TOWER_CHANGE':
        // Cell tower changes usually indicate movement of 1-5km
        return true;
        
      case 'WIFI_NETWORK_CHANGE':
        final oldSSID = details['oldSSID'] as String?;
        final newSSID = details['newSSID'] as String?;
        
        // Disconnecting from WiFi (going mobile) indicates movement
        if (oldSSID != null && newSSID == null) return true;
        
        // Connecting to new WiFi indicates arrival at new location
        if (oldSSID != newSSID && newSSID != null) return true;
        
        return false;
        
      default:
        return false;
    }
  }
}