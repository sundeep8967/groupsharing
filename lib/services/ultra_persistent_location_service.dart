import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Ultra Persistent Location Service
/// Specifically designed for OnePlus and other aggressive battery optimization devices
/// Uses multiple strategies to ensure location sharing continues in background
class UltraPersistentLocationService {
  static const String _tag = 'UltraPersistentLocationService';
  
  // Method channels
  static const MethodChannel _persistentChannel = MethodChannel('persistent_location_service');
  static const MethodChannel _backgroundChannel = MethodChannel('background_location');
  
  // State tracking
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static String? _currentUserId;
  static Timer? _healthCheckTimer;
  static Timer? _restartTimer;
  
  // Callbacks
  static Function(String message)? onStatusUpdate;
  static Function(String error)? onError;
  static Function()? onServiceStarted;
  static Function()? onServiceStopped;
  
  /// Initialize the ultra persistent location service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Ultra Persistent Location Service');
      
      if (Platform.isAndroid) {
        // Check if device needs ultra persistent service
        final needsUltraPersistent = await _needsUltraPersistentService();
        
        if (needsUltraPersistent) {
          developer.log('[$_tag] Device requires ultra persistent service');
          await _initializeAndroidUltraPersistent();
        } else {
          developer.log('[$_tag] Device uses standard background service');
          await _initializeStandardService();
        }
      } else if (Platform.isIOS) {
        await _initializeIOSService();
      }
      
      _isInitialized = true;
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error initializing service: $e');
      onError?.call('Failed to initialize: $e');
      return false;
    }
  }
  
  /// Start ultra persistent location tracking
  static Future<bool> startLocationTracking(String userId) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isTracking && _currentUserId == userId) {
      developer.log('[$_tag] Location tracking already active for user');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting ultra persistent location tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      if (Platform.isAndroid) {
        final needsUltraPersistent = await _needsUltraPersistentService();
        
        if (needsUltraPersistent) {
          // Start both services for maximum reliability
          await _startAndroidUltraPersistentService(userId);
          await _startAndroidBackgroundService(userId);
        } else {
          await _startAndroidBackgroundService(userId);
        }
      } else if (Platform.isIOS) {
        await _startIOSService(userId);
      }
      
      // Start health monitoring
      _startHealthMonitoring();
      
      // Save state
      await _saveServiceState(true, userId);
      
      _isTracking = true;
      onServiceStarted?.call();
      onStatusUpdate?.call('Ultra persistent location tracking started');
      
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error starting location tracking: $e');
      onError?.call('Failed to start tracking: $e');
      return false;
    }
  }
  
  /// Stop ultra persistent location tracking
  static Future<bool> stopLocationTracking() async {
    if (!_isTracking) {
      developer.log('[$_tag] Location tracking not active');
      return true;
    }
    
    try {
      developer.log('[$_tag] Stopping ultra persistent location tracking');
      
      if (Platform.isAndroid) {
        await _stopAndroidUltraPersistentService();
        await _stopAndroidBackgroundService();
      } else if (Platform.isIOS) {
        await _stopIOSService();
      }
      
      // Stop health monitoring
      _stopHealthMonitoring();
      
      // Clear state
      await _saveServiceState(false, null);
      
      _isTracking = false;
      _currentUserId = null;
      onServiceStopped?.call();
      onStatusUpdate?.call('Ultra persistent location tracking stopped');
      
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error stopping location tracking: $e');
      onError?.call('Failed to stop tracking: $e');
      return false;
    }
  }
  
  /// Check if ultra persistent service is needed
  static Future<bool> _needsUltraPersistentService() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();
      
      // OnePlus and Oppo devices need ultra persistent service
      final needsUltraPersistent = manufacturer.contains('oneplus') || 
                                   brand.contains('oneplus') ||
                                   manufacturer.contains('oppo') ||
                                   manufacturer.contains('realme') ||
                                   manufacturer.contains('vivo');
      
      developer.log('[$_tag] Device: $manufacturer $brand, needs ultra persistent: $needsUltraPersistent');
      return needsUltraPersistent;
      
    } catch (e) {
      developer.log('[$_tag] Error checking device info: $e');
      return false;
    }
  }
  
  /// Initialize Android ultra persistent service
  static Future<void> _initializeAndroidUltraPersistent() async {
    try {
      await _persistentChannel.invokeMethod('initialize');
      developer.log('[$_tag] Android ultra persistent service initialized');
    } catch (e) {
      developer.log('[$_tag] Error initializing Android ultra persistent service: $e');
      throw e;
    }
  }
  
  /// Initialize standard Android service
  static Future<void> _initializeStandardService() async {
    try {
      await _backgroundChannel.invokeMethod('initialize');
      developer.log('[$_tag] Standard Android service initialized');
    } catch (e) {
      developer.log('[$_tag] Error initializing standard service: $e');
      throw e;
    }
  }
  
  /// Initialize iOS service
  static Future<void> _initializeIOSService() async {
    try {
      await _persistentChannel.invokeMethod('initialize');
      developer.log('[$_tag] iOS service initialized');
    } catch (e) {
      developer.log('[$_tag] Error initializing iOS service: $e');
      throw e;
    }
  }
  
  /// Start Android ultra persistent service
  static Future<void> _startAndroidUltraPersistentService(String userId) async {
    try {
      await _persistentChannel.invokeMethod('startPersistentService', {
        'userId': userId,
      });
      developer.log('[$_tag] Android ultra persistent service started');
    } catch (e) {
      developer.log('[$_tag] Error starting Android ultra persistent service: $e');
      throw e;
    }
  }
  
  /// Start Android background service
  static Future<void> _startAndroidBackgroundService(String userId) async {
    try {
      await _backgroundChannel.invokeMethod('start', {
        'userId': userId,
      });
      developer.log('[$_tag] Android background service started');
    } catch (e) {
      developer.log('[$_tag] Error starting Android background service: $e');
      // Don't throw - this is backup service
    }
  }
  
  /// Start iOS service
  static Future<void> _startIOSService(String userId) async {
    try {
      await _persistentChannel.invokeMethod('startLocationTracking', {
        'userId': userId,
      });
      developer.log('[$_tag] iOS service started');
    } catch (e) {
      developer.log('[$_tag] Error starting iOS service: $e');
      throw e;
    }
  }
  
  /// Stop Android ultra persistent service
  static Future<void> _stopAndroidUltraPersistentService() async {
    try {
      await _persistentChannel.invokeMethod('stopPersistentService');
      developer.log('[$_tag] Android ultra persistent service stopped');
    } catch (e) {
      developer.log('[$_tag] Error stopping Android ultra persistent service: $e');
    }
  }
  
  /// Stop Android background service
  static Future<void> _stopAndroidBackgroundService() async {
    try {
      await _backgroundChannel.invokeMethod('stop');
      developer.log('[$_tag] Android background service stopped');
    } catch (e) {
      developer.log('[$_tag] Error stopping Android background service: $e');
    }
  }
  
  /// Stop iOS service
  static Future<void> _stopIOSService() async {
    try {
      await _persistentChannel.invokeMethod('stopLocationTracking');
      developer.log('[$_tag] iOS service stopped');
    } catch (e) {
      developer.log('[$_tag] Error stopping iOS service: $e');
    }
  }
  
  /// Start health monitoring
  static void _startHealthMonitoring() {
    _stopHealthMonitoring();
    
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      await _performHealthCheck();
    });
    
    developer.log('[$_tag] Health monitoring started');
  }
  
  /// Stop health monitoring
  static void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
  }
  
  /// Perform health check
  static Future<void> _performHealthCheck() async {
    if (!_isTracking || _currentUserId == null) return;
    
    try {
      developer.log('[$_tag] Performing health check');
      
      bool isHealthy = false;
      
      if (Platform.isAndroid) {
        final needsUltraPersistent = await _needsUltraPersistentService();
        
        if (needsUltraPersistent) {
          // Check ultra persistent service
          try {
            isHealthy = await _persistentChannel.invokeMethod('isServiceHealthy') ?? false;
          } catch (e) {
            developer.log('[$_tag] Ultra persistent service health check failed: $e');
            isHealthy = false;
          }
        } else {
          // Check standard service
          try {
            isHealthy = await _backgroundChannel.invokeMethod('isServiceHealthy') ?? false;
          } catch (e) {
            developer.log('[$_tag] Background service health check failed: $e');
            isHealthy = false;
          }
        }
      } else if (Platform.isIOS) {
        try {
          isHealthy = await _persistentChannel.invokeMethod('isServiceHealthy') ?? false;
        } catch (e) {
          developer.log('[$_tag] iOS service health check failed: $e');
          isHealthy = false;
        }
      }
      
      if (!isHealthy) {
        developer.log('[$_tag] Service unhealthy - scheduling restart');
        onStatusUpdate?.call('Service unhealthy - restarting...');
        await _scheduleServiceRestart();
      } else {
        developer.log('[$_tag] Service healthy');
        onStatusUpdate?.call('Service healthy and running');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error performing health check: $e');
      onError?.call('Health check failed: $e');
    }
  }
  
  /// Schedule service restart
  static Future<void> _scheduleServiceRestart() async {
    if (_restartTimer != null) return; // Already scheduled
    
    _restartTimer = Timer(const Duration(seconds: 10), () async {
      await _restartServices();
      _restartTimer = null;
    });
  }
  
  /// Restart services
  static Future<void> _restartServices() async {
    if (!_isTracking || _currentUserId == null) return;
    
    try {
      developer.log('[$_tag] Restarting services');
      onStatusUpdate?.call('Restarting location services...');
      
      final userId = _currentUserId!;
      
      // Stop current services
      if (Platform.isAndroid) {
        await _stopAndroidUltraPersistentService();
        await _stopAndroidBackgroundService();
      } else if (Platform.isIOS) {
        await _stopIOSService();
      }
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 2));
      
      // Restart services
      if (Platform.isAndroid) {
        final needsUltraPersistent = await _needsUltraPersistentService();
        
        if (needsUltraPersistent) {
          await _startAndroidUltraPersistentService(userId);
          await _startAndroidBackgroundService(userId);
        } else {
          await _startAndroidBackgroundService(userId);
        }
      } else if (Platform.isIOS) {
        await _startIOSService(userId);
      }
      
      onStatusUpdate?.call('Location services restarted');
      developer.log('[$_tag] Services restarted successfully');
      
    } catch (e) {
      developer.log('[$_tag] Error restarting services: $e');
      onError?.call('Failed to restart services: $e');
    }
  }
  
  /// Save service state
  static Future<void> _saveServiceState(bool isEnabled, String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ultra_persistent_enabled', isEnabled);
      if (userId != null) {
        await prefs.setString('ultra_persistent_user_id', userId);
      } else {
        await prefs.remove('ultra_persistent_user_id');
      }
      await prefs.setInt('ultra_persistent_last_update', DateTime.now().millisecondsSinceEpoch);
      
      developer.log('[$_tag] Service state saved: enabled=$isEnabled, userId=${userId?.substring(0, 8) ?? "null"}');
    } catch (e) {
      developer.log('[$_tag] Error saving service state: $e');
    }
  }
  
  /// Restore service state
  static Future<bool> restoreServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('ultra_persistent_enabled') ?? false;
      final userId = prefs.getString('ultra_persistent_user_id');
      
      if (isEnabled && userId != null) {
        developer.log('[$_tag] Restoring service state for user: ${userId.substring(0, 8)}');
        return await startLocationTracking(userId);
      }
      
      return false;
    } catch (e) {
      developer.log('[$_tag] Error restoring service state: $e');
      return false;
    }
  }
  
  /// Get service status
  static Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isTracking': _isTracking,
      'currentUserId': _currentUserId?.substring(0, 8),
      'hasHealthMonitoring': _healthCheckTimer != null,
      'platform': Platform.operatingSystem,
    };
  }
  
  /// Get troubleshooting information
  static Future<Map<String, dynamic>> getTroubleshootingInfo() async {
    final info = <String, dynamic>{};
    
    try {
      info['serviceStatus'] = getServiceStatus();
      
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        info['deviceInfo'] = {
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
        };
        
        info['needsUltraPersistent'] = await _needsUltraPersistentService();
        
        // Check service health
        try {
          info['persistentServiceHealthy'] = await _persistentChannel.invokeMethod('isServiceHealthy') ?? false;
        } catch (e) {
          info['persistentServiceHealthy'] = false;
          info['persistentServiceError'] = e.toString();
        }
        
        try {
          info['backgroundServiceHealthy'] = await _backgroundChannel.invokeMethod('isServiceHealthy') ?? false;
        } catch (e) {
          info['backgroundServiceHealthy'] = false;
          info['backgroundServiceError'] = e.toString();
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      info['savedState'] = {
        'enabled': prefs.getBool('ultra_persistent_enabled') ?? false,
        'userId': prefs.getString('ultra_persistent_user_id')?.substring(0, 8),
        'lastUpdate': prefs.getInt('ultra_persistent_last_update'),
      };
      
    } catch (e) {
      info['error'] = e.toString();
    }
    
    return info;
  }
  
  /// Dispose resources
  static void dispose() {
    _stopHealthMonitoring();
    _isInitialized = false;
    _isTracking = false;
    _currentUserId = null;
    onStatusUpdate = null;
    onError = null;
    onServiceStarted = null;
    onServiceStopped = null;
  }
}