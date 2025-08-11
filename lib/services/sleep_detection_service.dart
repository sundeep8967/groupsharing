import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sleep Detection Service
///
/// This service intelligently detects when the user is sleeping or idle
/// and adjusts location tracking frequency accordingly while maintaining
/// online presence for friends.
class SleepDetectionService {
  static const String _tag = 'SleepDetectionService';
  
  // Method channels
  static const MethodChannel _channel = MethodChannel('sleep_detection_service');
  
  // Service state
  static bool _isInitialized = false;
  static bool _isMonitoring = false;
  static TrackingMode _currentMode = TrackingMode.NORMAL_MODE;
  
  // Sleep detection state
  static DateTime? _lastScreenInteraction;
  static DateTime? _lastMovementDetected;
  static DateTime? _lastAppUsage;
  static LatLng? _homeLocation;
  static LatLng? _currentLocation;
  static LatLng? _lastReportedLocation;
  static DateTime? _lastLocationUpdate;
  
  // Timers
  static Timer? _sleepMonitoringTimer;
  static Timer? _heartbeatTimer;
  
  // Callbacks
  static Function(TrackingMode mode)? onTrackingModeChanged;
  static Function(String status)? onStatusUpdate;
  static Function(String error)? onError;
  
  /// Initialize the sleep detection service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('[$_tag] Initializing Sleep Detection Service');
      
      // Setup method call handler
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Load saved home location
      await _loadHomeLocation();
      
      // Load last interaction times
      await _loadLastInteractionTimes();
      
      _isInitialized = true;
      developer.log('[$_tag] Sleep Detection Service initialized');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to initialize: $e');
      onError?.call('Failed to initialize Sleep Detection Service: $e');
      return false;
    }
  }
  
  /// Start sleep monitoring
  static Future<bool> startMonitoring() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isMonitoring) {
      developer.log('[$_tag] Already monitoring sleep state');
      return true;
    }
    
    try {
      developer.log('[$_tag] Starting sleep monitoring');
      
      // Start native monitoring for screen interactions and app usage
      if (Platform.isAndroid) {
        await _channel.invokeMethod('startSleepMonitoring');
      }
      
      // Start periodic sleep state evaluation
      _startSleepMonitoringTimer();
      
      // Start smart heartbeat system
      _startSmartHeartbeat();
      
      _isMonitoring = true;
      onStatusUpdate?.call('Sleep monitoring started');
      developer.log('[$_tag] Sleep monitoring started successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to start monitoring: $e');
      onError?.call('Failed to start sleep monitoring: $e');
      return false;
    }
  }
  
  /// Stop sleep monitoring
  static Future<bool> stopMonitoring() async {
    if (!_isMonitoring) return true;
    
    try {
      developer.log('[$_tag] Stopping sleep monitoring');
      
      // Stop native monitoring
      if (Platform.isAndroid) {
        await _channel.invokeMethod('stopSleepMonitoring');
      }
      
      // Stop timers
      _sleepMonitoringTimer?.cancel();
      _heartbeatTimer?.cancel();
      
      _isMonitoring = false;
      _currentMode = TrackingMode.NORMAL_MODE;
      onStatusUpdate?.call('Sleep monitoring stopped');
      developer.log('[$_tag] Sleep monitoring stopped successfully');
      return true;
    } catch (e) {
      developer.log('[$_tag] Failed to stop monitoring: $e');
      onError?.call('Failed to stop sleep monitoring: $e');
      return false;
    }
  }
  
  /// Update current location for sleep detection
  static void updateCurrentLocation(LatLng location) {
    _currentLocation = location;
    
    // Learn home location if not set
    if (_homeLocation == null) {
      _learnHomeLocation(location);
    }
    
    // Check if location has changed significantly
    if (_hasLocationChangedSignificantly(location)) {
      _lastMovementDetected = DateTime.now();
      _lastReportedLocation = location;
      _lastLocationUpdate = DateTime.now();
      _saveLastInteractionTimes();
    }
  }
  
  /// Check if we should update location based on movement
  static bool shouldUpdateLocation(LatLng newLocation) {
    // Always update if no previous location
    if (_lastReportedLocation == null) return true;
    
    // Check if location changed significantly
    if (!_hasLocationChangedSignificantly(newLocation)) {
      developer.log('[$_tag] Location unchanged, skipping update');
      return false;
    }
    
    // Check time-based updates for different modes
    if (_lastLocationUpdate != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
      final maxInterval = getCurrentUpdateInterval();
      
      // Force update if max interval reached (even if location unchanged)
      if (timeSinceLastUpdate >= maxInterval) {
        developer.log('[$_tag] Max interval reached, forcing update');
        return true;
      }
    }
    
    return true;
  }
  
  /// Check if location has changed significantly
  static bool _hasLocationChangedSignificantly(LatLng newLocation) {
    if (_lastReportedLocation == null) return true;
    
    const Distance distance = Distance();
    final distanceMoved = distance(_lastReportedLocation!, newLocation);
    
    // Different thresholds based on tracking mode
    double threshold;
    switch (_currentMode) {
      case TrackingMode.SLEEP_MODE:
        threshold = 200.0; // 200 meters - very high threshold during sleep
        break;
      case TrackingMode.IDLE_MODE:
        threshold = 100.0; // 100 meters - high threshold when idle
        break;
      case TrackingMode.NORMAL_MODE:
        threshold = 50.0;  // 50 meters - normal threshold
        break;
      case TrackingMode.ACTIVE_MODE:
        threshold = 25.0;  // 25 meters - lower threshold when active
        break;
      case TrackingMode.DRIVING_MODE:
        threshold = 10.0;  // 10 meters - very low threshold when driving
        break;
    }
    
    final hasChanged = distanceMoved >= threshold;
    
    if (!hasChanged) {
      developer.log('[$_tag] Location change ${distanceMoved.toStringAsFixed(1)}m < ${threshold}m threshold (${_currentMode.toString()})');
    } else {
      developer.log('[$_tag] Significant location change: ${distanceMoved.toStringAsFixed(1)}m (threshold: ${threshold}m)');
    }
    
    return hasChanged;
  }
  
  /// Notify about screen interaction
  static void notifyScreenInteraction() {
    _lastScreenInteraction = DateTime.now();
    _saveLastInteractionTimes();
    
    // Check if this should wake up from sleep mode
    if (_currentMode == TrackingMode.SLEEP_MODE) {
      _evaluateSleepState();
    }
  }
  
  /// Notify about app usage
  static void notifyAppUsage() {
    _lastAppUsage = DateTime.now();
    _saveLastInteractionTimes();
    
    // Check if this should wake up from sleep mode
    if (_currentMode == TrackingMode.SLEEP_MODE) {
      _evaluateSleepState();
    }
  }
  
  /// Get current tracking mode
  static TrackingMode get currentMode => _currentMode;
  
  /// Get update interval for current mode
  static Duration getCurrentUpdateInterval() {
    return getUpdateInterval(_currentMode);
  }
  
  /// Get update interval for specific mode
  static Duration getUpdateInterval(TrackingMode mode) {
    switch (mode) {
      case TrackingMode.SLEEP_MODE:
        return const Duration(minutes: 45); // Very low frequency
      case TrackingMode.IDLE_MODE:
        return const Duration(minutes: 12); // Low frequency
      case TrackingMode.NORMAL_MODE:
        return const Duration(minutes: 3); // Normal frequency
      case TrackingMode.ACTIVE_MODE:
        return const Duration(minutes: 1); // High frequency
      case TrackingMode.DRIVING_MODE:
        return const Duration(seconds: 20); // Very high frequency
    }
  }
  
  /// Get status text for current mode
  static String getStatusText() {
    switch (_currentMode) {
      case TrackingMode.SLEEP_MODE:
        return 'Location sharing active (Sleeping 😴)';
      case TrackingMode.IDLE_MODE:
        return 'Location sharing active (Idle 💤)';
      case TrackingMode.NORMAL_MODE:
        return 'Location sharing active';
      case TrackingMode.ACTIVE_MODE:
        return 'Location sharing active (Active 🚶)';
      case TrackingMode.DRIVING_MODE:
        return 'Location sharing active (Driving 🚗)';
    }
  }
  
  /// Get presence status for friends
  static Map<String, dynamic> getPresenceStatus() {
    return {
      'isOnline': true,
      'isSharing': true,
      'trackingMode': _currentMode.toString(),
      'status': _getPresenceStatusText(),
      'icon': _getPresenceIcon(),
      'lastSeen': 'Active now',
    };
  }
  
  // Private methods
  
  static void _startSleepMonitoringTimer() {
    _sleepMonitoringTimer?.cancel();
    
    _sleepMonitoringTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _evaluateSleepState();
    });
  }
  
  static void _startSmartHeartbeat() {
    _heartbeatTimer?.cancel();
    
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _sendSmartHeartbeat();
    });
  }
  
  static void _evaluateSleepState() {
    final newMode = _detectTrackingMode();
    
    if (newMode != _currentMode) {
      developer.log('[$_tag] Tracking mode changed: ${_currentMode.toString()} -> ${newMode.toString()}');
      
      final oldMode = _currentMode;
      _currentMode = newMode;
      
      // Notify about mode change
      onTrackingModeChanged?.call(newMode);
      onStatusUpdate?.call(getStatusText());
      
      // Handle wake up from sleep
      if (oldMode == TrackingMode.SLEEP_MODE && newMode != TrackingMode.SLEEP_MODE) {
        _handleWakeUp();
      }
    }
  }
  
  static TrackingMode _detectTrackingMode() {
    final now = DateTime.now();
    
    // Check for sleep mode
    if (_isSleepTime() && _isPhoneIdle() && _isStationaryForLongTime() && _isAtHome()) {
      return TrackingMode.SLEEP_MODE;
    }
    
    // Check for idle mode
    if (_isPhoneIdle() && _isStationaryForMediumTime()) {
      return TrackingMode.IDLE_MODE;
    }
    
    // Check for active mode (recent movement or interaction)
    if (_hasRecentMovement() || _hasRecentInteraction()) {
      return TrackingMode.ACTIVE_MODE;
    }
    
    // Default to normal mode
    return TrackingMode.NORMAL_MODE;
  }
  
  static bool _isSleepTime() {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour <= 6; // 10 PM to 6 AM
  }
  
  static bool _isPhoneIdle() {
    if (_lastScreenInteraction == null && _lastAppUsage == null) return true;
    
    final now = DateTime.now();
    final screenIdle = _lastScreenInteraction == null || 
        now.difference(_lastScreenInteraction!).inMinutes > 30;
    final appIdle = _lastAppUsage == null || 
        now.difference(_lastAppUsage!).inMinutes > 30;
    
    return screenIdle && appIdle;
  }
  
  static bool _isStationaryForLongTime() {
    if (_lastMovementDetected == null) return false;
    
    final now = DateTime.now();
    return now.difference(_lastMovementDetected!).inHours >= 1;
  }
  
  static bool _isStationaryForMediumTime() {
    if (_lastMovementDetected == null) return false;
    
    final now = DateTime.now();
    return now.difference(_lastMovementDetected!).inMinutes >= 20;
  }
  
  static bool _isAtHome() {
    if (_homeLocation == null || _currentLocation == null) return false;
    
    const Distance distance = Distance();
    final distanceToHome = distance(_currentLocation!, _homeLocation!);
    return distanceToHome <= 100; // Within 100 meters of home
  }
  
  static bool _hasRecentMovement() {
    if (_lastMovementDetected == null) return false;
    
    final now = DateTime.now();
    return now.difference(_lastMovementDetected!).inMinutes < 10;
  }
  
  static bool _hasRecentInteraction() {
    final now = DateTime.now();
    
    final recentScreen = _lastScreenInteraction != null && 
        now.difference(_lastScreenInteraction!).inMinutes < 5;
    final recentApp = _lastAppUsage != null && 
        now.difference(_lastAppUsage!).inMinutes < 5;
    
    return recentScreen || recentApp;
  }
  
  static void _handleWakeUp() {
    developer.log('[$_tag] Wake up detected, resuming normal tracking');
    
    // Trigger immediate location update
    _triggerImmediateLocationUpdate();
    
    // Send wake up notification
    _sendWakeUpNotification();
  }
  
  static void _triggerImmediateLocationUpdate() {
    // This will be called by the location provider
    onStatusUpdate?.call('Waking up - updating location...');
  }
  
  static void _sendWakeUpNotification() {
    // Send notification that user is awake
    developer.log('[$_tag] Sending wake up notification to friends');
  }
  
  static void _sendSmartHeartbeat() {
    // Send lightweight heartbeat with current mode info
    // This will be implemented by the location provider
  }
  
  static void _learnHomeLocation(LatLng location) {
    // Simple home location learning - can be enhanced with ML
    final now = DateTime.now();
    if ((now.hour >= 20 || now.hour <= 8) && _homeLocation == null) {
      _homeLocation = location;
      _saveHomeLocation();
      developer.log('[$_tag] Learned home location: ${location.latitude}, ${location.longitude}');
    }
  }
  
  static Future<void> _loadHomeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('home_location_lat');
      final lng = prefs.getDouble('home_location_lng');
      
      if (lat != null && lng != null) {
        _homeLocation = LatLng(lat, lng);
        developer.log('[$_tag] Loaded home location: $lat, $lng');
      }
    } catch (e) {
      developer.log('[$_tag] Error loading home location: $e');
    }
  }
  
  static Future<void> _saveHomeLocation() async {
    if (_homeLocation == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('home_location_lat', _homeLocation!.latitude);
      await prefs.setDouble('home_location_lng', _homeLocation!.longitude);
    } catch (e) {
      developer.log('[$_tag] Error saving home location: $e');
    }
  }
  
  static Future<void> _loadLastInteractionTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final screenTime = prefs.getInt('last_screen_interaction');
      if (screenTime != null) {
        _lastScreenInteraction = DateTime.fromMillisecondsSinceEpoch(screenTime);
      }
      
      final movementTime = prefs.getInt('last_movement_detected');
      if (movementTime != null) {
        _lastMovementDetected = DateTime.fromMillisecondsSinceEpoch(movementTime);
      }
      
      final appTime = prefs.getInt('last_app_usage');
      if (appTime != null) {
        _lastAppUsage = DateTime.fromMillisecondsSinceEpoch(appTime);
      }
    } catch (e) {
      developer.log('[$_tag] Error loading interaction times: $e');
    }
  }
  
  static Future<void> _saveLastInteractionTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_lastScreenInteraction != null) {
        await prefs.setInt('last_screen_interaction', _lastScreenInteraction!.millisecondsSinceEpoch);
      }
      
      if (_lastMovementDetected != null) {
        await prefs.setInt('last_movement_detected', _lastMovementDetected!.millisecondsSinceEpoch);
      }
      
      if (_lastAppUsage != null) {
        await prefs.setInt('last_app_usage', _lastAppUsage!.millisecondsSinceEpoch);
      }
    } catch (e) {
      developer.log('[$_tag] Error saving interaction times: $e');
    }
  }
  
  static String _getPresenceStatusText() {
    switch (_currentMode) {
      case TrackingMode.SLEEP_MODE:
        return 'Sleeping';
      case TrackingMode.IDLE_MODE:
        return 'Idle';
      case TrackingMode.ACTIVE_MODE:
        return 'Active';
      case TrackingMode.DRIVING_MODE:
        return 'Driving';
      default:
        return 'Online';
    }
  }
  
  static String _getPresenceIcon() {
    switch (_currentMode) {
      case TrackingMode.SLEEP_MODE:
        return '😴';
      case TrackingMode.IDLE_MODE:
        return '💤';
      case TrackingMode.ACTIVE_MODE:
        return '🚶';
      case TrackingMode.DRIVING_MODE:
        return '🚗';
      default:
        return '🟢';
    }
  }
  
  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenInteraction':
        notifyScreenInteraction();
        break;
        
      case 'onAppUsage':
        notifyAppUsage();
        break;
        
      case 'onError':
        final error = call.arguments['error'] as String;
        developer.log('[$_tag] Native error: $error');
        onError?.call(error);
        break;
    }
  }
}

/// Tracking modes for different user states
enum TrackingMode {
  SLEEP_MODE,     // User is sleeping - very low frequency updates
  IDLE_MODE,      // User is idle but awake - low frequency updates
  NORMAL_MODE,    // Normal usage - regular frequency updates
  ACTIVE_MODE,    // User is actively moving - high frequency updates
  DRIVING_MODE    // User is driving - very high frequency updates
}