import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';

/// Persistent Foreground Notification Service
/// 
/// This service creates a persistent, non-swipable foreground notification that:
/// 1. Shows location sharing status
/// 2. Cannot be dismissed by user
/// 3. Keeps the app alive in background
/// 4. Provides quick actions for location control
/// 5. Updates in real-time with location status
/// 6. Implements Android 8.0+ foreground service requirements
class PersistentForegroundNotificationService {
  static const String _tag = 'PersistentForegroundNotificationService';
  
  // Method channels for native notification handling
  static const MethodChannel _notificationChannel = MethodChannel('persistent_foreground_notification');
  static const MethodChannel _foregroundServiceChannel = MethodChannel('persistent_foreground_service');
  
  // Service state
  static bool _isInitialized = false;
  static bool _isNotificationActive = false;
  static bool _isForegroundServiceRunning = false;
  static String? _currentUserId;
  static Timer? _updateTimer;
  static Timer? _heartbeatTimer;
  
  // Notification state
  static String _notificationTitle = 'Location Sharing Active';
  static String _notificationContent = 'Sharing your location with friends and family';
  static String _locationStatus = 'Initializing...';
  static int _friendsCount = 0;
  static bool _isLocationSharing = false;
  static LatLng? _currentLocation;
  static DateTime? _lastLocationUpdate;
  
  // Configuration
  static const int _notificationId = 12345;
  static const String _channelId = 'location_sharing_persistent';
  static const String _channelName = 'Location Sharing';
  static const String _channelDescription = 'Persistent notification for location sharing';
  static const Duration _updateInterval = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(minutes: 1);
  
  // Callbacks
  static Function(String action)? onNotificationAction;
  static Function()? onServiceStarted;
  static Function()? onServiceStopped;
  static Function(String error)? onError;
  
  /// Initialize the persistent foreground notification service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Persistent Foreground Notification Service');
      
      // Check platform support
      if (!Platform.isAndroid) {
        developer.log('[$_tag] iOS platform - using iOS-specific implementation');
        return await _initializeIOS();
      }
      
      // Setup method channels
      await _setupMethodChannels();
      
      // Initialize native notification system
      await _initializeNativeNotification();
      
      // Request necessary permissions
      await _requestNotificationPermissions();
      
      _isInitialized = true;
      developer.log('[$_tag] Persistent Foreground Notification Service initialized successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize notification service: $e');
      return false;
    }
  }
  
  /// Start persistent notification with location sharing status
  static Future<bool> startPersistentNotification(String userId) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isNotificationActive) {
      developer.log('[$_tag] Notification already active for user: ${userId.substring(0, 8)}');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting persistent notification for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      // Start foreground service first
      final serviceStarted = await _startForegroundService(userId);
      if (!serviceStarted) {
        developer.log('[$_tag] Failed to start foreground service');
        return false;
      }
      
      // Create and show persistent notification
      await _createPersistentNotification();
      
      // Start update timers
      _startUpdateTimers();
      
      // Save notification state
      await _saveNotificationState(true, userId);
      
      _isNotificationActive = true;
      onServiceStarted?.call();
      
      developer.log('[$_tag] Persistent notification started successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to start persistent notification: $e');
      onError?.call('Failed to start notification: $e');
      return false;
    }
  }
  
  /// Stop persistent notification
  static Future<bool> stopPersistentNotification() async {
    if (!_isNotificationActive) return true;
    
    try {
      developer.log('[$_tag] Stopping persistent notification');
      
      // Stop timers
      _updateTimer?.cancel();
      _heartbeatTimer?.cancel();
      
      // Stop foreground service
      await _stopForegroundService();
      
      // Remove notification
      await _removeNotification();
      
      // Clear state
      await _saveNotificationState(false, null);
      
      _isNotificationActive = false;
      _currentUserId = null;
      
      onServiceStopped?.call();
      
      developer.log('[$_tag] Persistent notification stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to stop persistent notification: $e');
      onError?.call('Failed to stop notification: $e');
      return false;
    }
  }
  
  /// Update notification with current location status
  static Future<void> updateLocationStatus({
    LatLng? location,
    String? status,
    int? friendsCount,
    bool? isSharing,
  }) async {
    if (!_isNotificationActive) return;
    
    try {
      // Update internal state
      if (location != null) {
        _currentLocation = location;
        _lastLocationUpdate = DateTime.now();
      }
      if (status != null) _locationStatus = status;
      if (friendsCount != null) _friendsCount = friendsCount;
      if (isSharing != null) _isLocationSharing = isSharing;
      
      // Update notification content
      await _updateNotificationContent();
      
      developer.log('[$_tag] Location status updated: $_locationStatus');
    } catch (e) {
      developer.log('[$_tag] Failed to update location status: $e');
    }
  }
  
  /// Force notification to be non-dismissible
  static Future<void> makeNotificationPersistent() async {
    try {
      await _notificationChannel.invokeMethod('makeNotificationPersistent', {
        'notificationId': _notificationId,
        'channelId': _channelId,
      });
      
      developer.log('[$_tag] Notification made persistent and non-dismissible');
    } catch (e) {
      developer.log('[$_tag] Failed to make notification persistent: $e');
    }
  }
  
  // MARK: - Private Implementation
  
  /// Setup method channels
  static Future<void> _setupMethodChannels() async {
    try {
      // Notification channel handler
      _notificationChannel.setMethodCallHandler((call) async {
        try {
          return await _handleNotificationCall(call);
        } catch (e) {
          developer.log('[$_tag] Error in notification handler: $e');
          return {'error': e.toString()};
        }
      });
      
      // Foreground service channel handler
      _foregroundServiceChannel.setMethodCallHandler((call) async {
        try {
          return await _handleForegroundServiceCall(call);
        } catch (e) {
          developer.log('[$_tag] Error in foreground service handler: $e');
          return {'error': e.toString()};
        }
      });
      
      developer.log('[$_tag] Method channels setup completed');
    } catch (e) {
      developer.log('[$_tag] Failed to setup method channels: $e');
      throw e;
    }
  }
  
  /// Initialize native notification system
  static Future<void> _initializeNativeNotification() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      final initParams = {
        'channelId': _channelId,
        'channelName': _channelName,
        'channelDescription': _channelDescription,
        'notificationId': _notificationId,
        'sdkVersion': androidInfo.version.sdkInt,
        'packageName': 'com.sundeep.groupsharing',
        'enablePersistentMode': true,
        'enableNonDismissible': true,
        'enableForegroundService': true,
      };
      
      await _notificationChannel.invokeMethod('initializeNotification', initParams);
      developer.log('[$_tag] Native notification system initialized');
    } catch (e) {
      developer.log('[$_tag] Failed to initialize native notification: $e');
      // Don't throw - allow service to continue
    }
  }
  
  /// Request notification permissions
  static Future<void> _requestNotificationPermissions() async {
    try {
      // Request notification permission (Android 13+)
      final notificationPermission = await Permission.notification.status;
      if (!notificationPermission.isGranted) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          developer.log('[$_tag] Notification permission denied');
        }
      }
      
      // Request exact alarm permission (Android 12+)
      final alarmPermission = await Permission.scheduleExactAlarm.status;
      if (!alarmPermission.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
      
      developer.log('[$_tag] Notification permissions requested');
    } catch (e) {
      developer.log('[$_tag] Failed to request permissions: $e');
    }
  }
  
  /// Start foreground service
  static Future<bool> _startForegroundService(String userId) async {
    try {
      final params = {
        'userId': userId,
        'notificationId': _notificationId,
        'channelId': _channelId,
        'title': _notificationTitle,
        'content': _notificationContent,
        'enablePersistentMode': true,
        'enableAutoRestart': true,
        'enableWakeLock': true,
      };
      
      final result = await _foregroundServiceChannel.invokeMethod('startForegroundService', params);
      _isForegroundServiceRunning = result == true;
      
      developer.log('[$_tag] Foreground service started: $_isForegroundServiceRunning');
      return _isForegroundServiceRunning;
    } catch (e) {
      developer.log('[$_tag] Failed to start foreground service: $e');
      return false;
    }
  }
  
  /// Stop foreground service
  static Future<void> _stopForegroundService() async {
    try {
      if (_isForegroundServiceRunning) {
        await _foregroundServiceChannel.invokeMethod('stopForegroundService');
        _isForegroundServiceRunning = false;
        developer.log('[$_tag] Foreground service stopped');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to stop foreground service: $e');
    }
  }
  
  /// Create persistent notification
  static Future<void> _createPersistentNotification() async {
    try {
      final notificationData = await _buildNotificationData();
      
      await _notificationChannel.invokeMethod('createPersistentNotification', notificationData);
      
      // Make notification non-dismissible
      await makeNotificationPersistent();
      
      developer.log('[$_tag] Persistent notification created');
    } catch (e) {
      developer.log('[$_tag] Failed to create persistent notification: $e');
    }
  }
  
  /// Build notification data
  static Map<String, dynamic> _buildNotificationData() {
    final timeSinceUpdate = _lastLocationUpdate != null 
        ? DateTime.now().difference(_lastLocationUpdate!).inMinutes
        : 0;
    
    final locationText = _currentLocation != null 
        ? 'Location: ${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}'
        : 'Location: Not available';
    
    final statusText = _isLocationSharing 
        ? 'Sharing with $_friendsCount friends'
        : 'Location sharing paused';
    
    final updateText = timeSinceUpdate > 0 
        ? 'Updated ${timeSinceUpdate}m ago'
        : 'Just updated';
    
    return {
      'notificationId': _notificationId,
      'channelId': _channelId,
      'title': _notificationTitle,
      'content': '$statusText • $updateText',
      'bigText': '$statusText\n$locationText\nStatus: $_locationStatus\n$updateText',
      'subText': 'GroupSharing',
      'ongoing': true,
      'autoCancel': false,
      'priority': 'high',
      'category': 'service',
      'visibility': 'public',
      'showWhen': true,
      'when': DateTime.now().millisecondsSinceEpoch,
      'enableLights': false,
      'enableVibration': false,
      'enableSound': false,
      'actions': [
        {
          'id': 'pause_sharing',
          'title': _isLocationSharing ? 'Pause Sharing' : 'Resume Sharing',
          'icon': _isLocationSharing ? 'pause' : 'play',
        },
        {
          'id': 'open_app',
          'title': 'Open App',
          'icon': 'open',
        },
        {
          'id': 'view_friends',
          'title': 'View Friends',
          'icon': 'people',
        },
      ],
      'largeIcon': 'location_sharing',
      'smallIcon': 'notification_icon',
      'color': 0xFF2196F3, // Blue color
      'enablePersistent': true,
      'enableNonDismissible': true,
    };
  }
  
  /// Update notification content
  static Future<void> _updateNotificationContent() async {
    try {
      final notificationData = _buildNotificationData();
      
      await _notificationChannel.invokeMethod('updateNotification', notificationData);
      
      developer.log('[$_tag] Notification content updated');
    } catch (e) {
      developer.log('[$_tag] Failed to update notification content: $e');
    }
  }
  
  /// Remove notification
  static Future<void> _removeNotification() async {
    try {
      await _notificationChannel.invokeMethod('removeNotification', {
        'notificationId': _notificationId,
      });
      
      developer.log('[$_tag] Notification removed');
    } catch (e) {
      developer.log('[$_tag] Failed to remove notification: $e');
    }
  }
  
  /// Start update timers
  static void _startUpdateTimers() {
    // Update timer for notification content
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_updateInterval, (_) {
      _updateNotificationContent();
    });
    
    // Heartbeat timer to keep service alive
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
    
    developer.log('[$_tag] Update timers started');
  }
  
  /// Send heartbeat to keep service alive
  static Future<void> _sendHeartbeat() async {
    try {
      await _foregroundServiceChannel.invokeMethod('sendHeartbeat', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isLocationSharing': _isLocationSharing,
        'friendsCount': _friendsCount,
      });
    } catch (e) {
      developer.log('[$_tag] Failed to send heartbeat: $e');
    }
  }
  
  /// Save notification state
  static Future<void> _saveNotificationState(bool isActive, String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('persistent_notification_active', isActive);
      if (userId != null) {
        await prefs.setString('persistent_notification_user_id', userId);
      } else {
        await prefs.remove('persistent_notification_user_id');
      }
    } catch (e) {
      developer.log('[$_tag] Failed to save notification state: $e');
    }
  }
  
  /// Restore notification state
  static Future<bool> shouldRestoreNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasActive = prefs.getBool('persistent_notification_active') ?? false;
      final userId = prefs.getString('persistent_notification_user_id');
      return wasActive && userId != null;
    } catch (e) {
      developer.log('[$_tag] Failed to check restore state: $e');
      return false;
    }
  }
  
  /// Get restore user ID
  static Future<String?> getRestoreUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('persistent_notification_user_id');
    } catch (e) {
      developer.log('[$_tag] Failed to get restore user ID: $e');
      return null;
    }
  }
  
  /// Initialize iOS-specific implementation
  static Future<bool> _initializeIOS() async {
    try {
      // iOS doesn't have persistent notifications like Android
      // Use background app refresh and local notifications instead
      developer.log('[$_tag] iOS implementation initialized');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize iOS implementation: $e');
      return false;
    }
  }
  
  // MARK: - Method Call Handlers
  
  /// Handle notification method calls
  static Future<dynamic> _handleNotificationCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationAction':
        final action = call.arguments['action'] as String?;
        if (action != null) {
          developer.log('[$_tag] Notification action: $action');
          onNotificationAction?.call(action);
          await _handleNotificationAction(action);
        }
        break;
        
      case 'onNotificationDismissed':
        developer.log('[$_tag] Notification dismissed - recreating...');
        // Immediately recreate the notification if it was dismissed
        await _createPersistentNotification();
        break;
        
      case 'onNotificationCreated':
        developer.log('[$_tag] Notification created successfully');
        break;
        
      case 'onNotificationError':
        final error = call.arguments['error'] as String? ?? 'Unknown notification error';
        developer.log('[$_tag] Notification error: $error');
        onError?.call(error);
        break;
    }
  }
  
  /// Handle foreground service method calls
  static Future<dynamic> _handleForegroundServiceCall(MethodCall call) async {
    switch (call.method) {
      case 'onServiceStarted':
        _isForegroundServiceRunning = true;
        developer.log('[$_tag] Foreground service started');
        onServiceStarted?.call();
        break;
        
      case 'onServiceStopped':
        _isForegroundServiceRunning = false;
        developer.log('[$_tag] Foreground service stopped');
        onServiceStopped?.call();
        break;
        
      case 'onServiceKilled':
        developer.log('[$_tag] Foreground service killed - attempting restart...');
        // Attempt to restart the service
        if (_currentUserId != null) {
          await _startForegroundService(_currentUserId!);
        }
        break;
        
      case 'onServiceError':
        final error = call.arguments['error'] as String? ?? 'Unknown service error';
        developer.log('[$_tag] Foreground service error: $error');
        onError?.call(error);
        break;
    }
  }
  
  /// Handle notification actions
  static Future<void> _handleNotificationAction(String action) async {
    switch (action) {
      case 'pause_sharing':
        // Toggle location sharing
        _isLocationSharing = !_isLocationSharing;
        await _updateNotificationContent();
        developer.log('[$_tag] Location sharing toggled: $_isLocationSharing');
        break;
        
      case 'open_app':
        // Open the main app
        await _foregroundServiceChannel.invokeMethod('openApp');
        break;
        
      case 'view_friends':
        // Open friends screen
        await _foregroundServiceChannel.invokeMethod('openApp', {'screen': 'friends'});
        break;
    }
  }
  
  // MARK: - Public Getters
  
  static bool get isInitialized => _isInitialized;
  static bool get isNotificationActive => _isNotificationActive;
  static bool get isForegroundServiceRunning => _isForegroundServiceRunning;
  static String? get currentUserId => _currentUserId;
  static String get locationStatus => _locationStatus;
  static int get friendsCount => _friendsCount;
  static bool get isLocationSharing => _isLocationSharing;
  static LatLng? get currentLocation => _currentLocation;
  
  /// Get notification status info
  static Map<String, dynamic> getStatusInfo() {
    return {
      'isInitialized': _isInitialized,
      'isNotificationActive': _isNotificationActive,
      'isForegroundServiceRunning': _isForegroundServiceRunning,
      'currentUserId': _currentUserId,
      'locationStatus': _locationStatus,
      'friendsCount': _friendsCount,
      'isLocationSharing': _isLocationSharing,
      'currentLocation': _currentLocation != null 
          ? {'lat': _currentLocation!.latitude, 'lng': _currentLocation!.longitude}
          : null,
      'lastLocationUpdate': _lastLocationUpdate?.toIso8601String(),
    };
  }
  
  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await stopPersistentNotification();
      _isInitialized = false;
    } catch (e) {
      developer.log('[$_tag] Error disposing service: $e');
    }
  }
}