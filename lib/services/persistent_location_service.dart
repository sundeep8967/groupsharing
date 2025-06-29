import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Persistent Location Service that continues working even when app is killed
/// This service implements a comprehensive background location system similar to flutter_background_geolocation
class PersistentLocationService {
  static const String _channelName = 'persistent_location_service';
  static const MethodChannel _channel = MethodChannel(_channelName);
  
  // Isolate for background processing
  static SendPort? _isolateSendPort;
  static Isolate? _backgroundIsolate;
  static ReceivePort? _receivePort;
  
  // Service state
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static String? _currentUserId;
  
  // Configuration
  static const Duration _locationInterval = Duration(seconds: 15);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const double _distanceFilter = 10.0; // meters
  static const LocationAccuracy _desiredAccuracy = LocationAccuracy.high;
  
  // Callbacks
  static Function(LatLng)? _onLocationUpdate;
  static Function(String)? _onError;
  static Function()? _onServiceStopped;
  
  /// Initialize the persistent location service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('Initializing PersistentLocationService');
      
      // Initialize native platform channels
      await _initializePlatformChannels();
      
      // Initialize background isolate for location processing
      await _initializeBackgroundIsolate();
      
      // Register background task handlers
      await _registerBackgroundHandlers();
      
      _isInitialized = true;
      developer.log('PersistentLocationService initialized successfully');
      return true;
    } catch (e) {
      developer.log('Failed to initialize PersistentLocationService: $e');
      return false;
    }
  }
  
  /// Start persistent location tracking
  static Future<bool> startTracking({
    required String userId,
    Function(LatLng)? onLocationUpdate,
    Function(String)? onError,
    Function()? onServiceStopped,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isTracking) {
      developer.log('Location tracking already active');
      return true;
    }
    
    try {
      developer.log('Starting persistent location tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      _onLocationUpdate = onLocationUpdate;
      _onError = onError;
      _onServiceStopped = onServiceStopped;
      
      // Check permissions
      final hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) {
        _onError?.call('Location permissions denied');
        return false;
      }
      
      // Save tracking state
      await _saveTrackingState(userId, true);
      
      // Start native background service
      final nativeStarted = await _startNativeBackgroundService(userId);
      if (!nativeStarted) {
        developer.log('Failed to start native background service, using Flutter fallback');
      }
      
      // Start Flutter-based tracking as primary or fallback
      await _startFlutterLocationTracking();
      
      // Start background isolate processing
      await _startBackgroundProcessing();
      
      // Start watchdog to monitor service health
      await _startWatchdog();
      
      _isTracking = true;
      developer.log('Persistent location tracking started successfully');
      return true;
    } catch (e) {
      developer.log('Failed to start persistent location tracking: $e');
      _onError?.call('Failed to start location tracking: $e');
      return false;
    }
  }
  
  /// Stop persistent location tracking
  static Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('Stopping persistent location tracking');
      
      // Save tracking state
      if (_currentUserId != null) {
        await _saveTrackingState(_currentUserId!, false);
      }
      
      // Stop native background service
      await _stopNativeBackgroundService();
      
      // Stop Flutter location tracking
      await _stopFlutterLocationTracking();
      
      // Stop background processing
      await _stopBackgroundProcessing();
      
      // Stop watchdog
      await _stopWatchdog();
      
      // Clear user data from location databases
      if (_currentUserId != null) {
        await _clearUserLocationData(_currentUserId!);
      }
      
      _isTracking = false;
      _currentUserId = null;
      
      developer.log('Persistent location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('Failed to stop persistent location tracking: $e');
      return false;
    }
  }
  
  /// Check if location tracking is currently active
  static bool get isTracking => _isTracking;
  
  /// Get current user ID
  static String? get currentUserId => _currentUserId;
  
  // Private methods
  
  static Future<void> _initializePlatformChannels() async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLocationUpdate':
          final lat = call.arguments['latitude'] as double;
          final lng = call.arguments['longitude'] as double;
          final location = LatLng(lat, lng);
          _onLocationUpdate?.call(location);
          await _processLocationUpdate(location);
          break;
        case 'onError':
          final error = call.arguments['error'] as String;
          _onError?.call(error);
          break;
        case 'onServiceStopped':
          _onServiceStopped?.call();
          _isTracking = false;
          break;
      }
    });
  }
  
  static Future<void> _initializeBackgroundIsolate() async {
    if (_backgroundIsolate != null) return;
    
    _receivePort = ReceivePort();
    _backgroundIsolate = await Isolate.spawn(
      _backgroundIsolateEntryPoint,
      _receivePort!.sendPort,
    );
    
    // Listen for messages from background isolate
    _receivePort!.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
      } else if (message is Map<String, dynamic>) {
        _handleBackgroundMessage(message);
      } else if (message is Map) {
        _handleBackgroundMessage(Map<String, dynamic>.from(message));
      }
    });
  }
  
  static void _backgroundIsolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);
    
    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        _processBackgroundTask(message, mainSendPort);
      } else if (message is Map) {
        _processBackgroundTask(Map<String, dynamic>.from(message), mainSendPort);
      }
    });
  }
  
  static void _processBackgroundTask(Map<String, dynamic> task, SendPort mainSendPort) {
    // Process background tasks like location updates, sync operations, etc.
    final taskType = task['type'] as String;
    
    switch (taskType) {
      case 'location_update':
        _processBackgroundLocationUpdate(task, mainSendPort);
        break;
      case 'sync_data':
        _processBackgroundSync(task, mainSendPort);
        break;
      case 'heartbeat':
        _processBackgroundHeartbeat(task, mainSendPort);
        break;
    }
  }
  
  static void _processBackgroundLocationUpdate(Map<String, dynamic> task, SendPort mainSendPort) {
    // Process location updates in background isolate
    try {
      final lat = task['latitude'] as double;
      final lng = task['longitude'] as double;
      final userId = task['userId'] as String;
      final timestamp = task['timestamp'] as int;
      
      // Send processed location back to main isolate
      mainSendPort.send(<String, dynamic>{
        'type': 'location_processed',
        'latitude': lat,
        'longitude': lng,
        'userId': userId,
        'timestamp': timestamp,
      });
    } catch (e) {
      mainSendPort.send(<String, dynamic>{
        'type': 'error',
        'message': 'Failed to process location update: $e',
      });
    }
  }
  
  static void _processBackgroundSync(Map<String, dynamic> task, SendPort mainSendPort) {
    // Handle background data synchronization
    // This would include syncing with Firebase, handling offline data, etc.
  }
  
  static void _processBackgroundHeartbeat(Map<String, dynamic> task, SendPort mainSendPort) {
    // Process heartbeat in background
    final userId = task['userId'] as String;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    mainSendPort.send(<String, dynamic>{
      'type': 'heartbeat_processed',
      'userId': userId,
      'timestamp': timestamp,
    });
  }
  
  static void _handleBackgroundMessage(Map<String, dynamic> message) {
    final messageType = message['type'] as String;
    
    switch (messageType) {
      case 'location_processed':
        final lat = message['latitude'] as double;
        final lng = message['longitude'] as double;
        final location = LatLng(lat, lng);
        _onLocationUpdate?.call(location);
        break;
      case 'error':
        final errorMessage = message['message'] as String;
        _onError?.call(errorMessage);
        break;
      case 'heartbeat_processed':
        _sendHeartbeatToFirebase(message);
        break;
    }
  }
  
  static Future<void> _registerBackgroundHandlers() async {
    // Register background task handlers for when app is killed
    if (Platform.isAndroid) {
      await _channel.invokeMethod('registerBackgroundHandlers');
    } else if (Platform.isIOS) {
      await _channel.invokeMethod('registerBackgroundLocationHandler');
    }
  }
  
  static Future<bool> _checkAndRequestPermissions() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return false;
      }
      
      // For Android, also request background location permission
      if (Platform.isAndroid) {
        final backgroundPermission = await _requestBackgroundLocationPermission();
        if (!backgroundPermission) {
          developer.log('Background location permission denied, but continuing with foreground');
        }
      }
      
      return true;
    } catch (e) {
      developer.log('Error checking permissions: $e');
      return false;
    }
  }
  
  static Future<bool> _requestBackgroundLocationPermission() async {
    try {
      return await _channel.invokeMethod('requestBackgroundLocationPermission') ?? false;
    } catch (e) {
      developer.log('Error requesting background location permission: $e');
      return false;
    }
  }
  
  static Future<void> _saveTrackingState(String userId, bool isTracking) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('persistent_location_tracking', isTracking);
      await prefs.setString('persistent_location_user_id', userId);
      await prefs.setInt('tracking_start_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      developer.log('Error saving tracking state: $e');
    }
  }
  
  static Future<bool> _startNativeBackgroundService(String userId) async {
    try {
      final result = await _channel.invokeMethod('startBackgroundLocationService', <String, dynamic>{
        'userId': userId,
        'locationInterval': _locationInterval.inMilliseconds,
        'distanceFilter': _distanceFilter,
        'desiredAccuracy': _desiredAccuracy.index,
      });
      return result == true;
    } catch (e) {
      developer.log('Error starting native background service: $e');
      return false;
    }
  }
  
  static Future<void> _stopNativeBackgroundService() async {
    try {
      await _channel.invokeMethod('stopBackgroundLocationService');
    } catch (e) {
      developer.log('Error stopping native background service: $e');
    }
  }
  
  static StreamSubscription<Position>? _locationSubscription;
  
  static Future<void> _startFlutterLocationTracking() async {
    try {
      final locationSettings = LocationSettings(
        accuracy: _desiredAccuracy,
        distanceFilter: _distanceFilter.round(),
      );
      
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          final location = LatLng(position.latitude, position.longitude);
          _onLocationUpdate?.call(location);
          _processLocationUpdate(location);
        },
        onError: (error) {
          developer.log('Flutter location stream error: $error');
          _onError?.call('Location stream error: $error');
        },
      );
    } catch (e) {
      developer.log('Error starting Flutter location tracking: $e');
      _onError?.call('Failed to start location tracking: $e');
    }
  }
  
  static Future<void> _stopFlutterLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }
  
  static Future<void> _startBackgroundProcessing() async {
    if (_isolateSendPort == null) return;
    
    // Start periodic background tasks
    Timer.periodic(_heartbeatInterval, (timer) {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      _isolateSendPort?.send(<String, dynamic>{
        'type': 'heartbeat',
        'userId': _currentUserId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }
  
  static Future<void> _stopBackgroundProcessing() async {
    // Background processing will stop when _isTracking becomes false
  }
  
  static Timer? _watchdogTimer;
  
  static Future<void> _startWatchdog() async {
    _watchdogTimer?.cancel();
    
    _watchdogTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      // Check if services are still running
      final isHealthy = await _checkServiceHealth();
      if (!isHealthy) {
        developer.log('Service health check failed, attempting restart');
        await _restartServices();
      }
    });
  }
  
  static Future<void> _stopWatchdog() async {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }
  
  static Future<bool> _checkServiceHealth() async {
    try {
      // Check if native service is running
      final nativeHealthy = await _channel.invokeMethod('isServiceHealthy') ?? false;
      
      // Check if Flutter location stream is active
      final flutterHealthy = _locationSubscription != null && !_locationSubscription!.isPaused;
      
      // Check if background isolate is responsive
      final isolateHealthy = _isolateSendPort != null;
      
      return nativeHealthy || flutterHealthy || isolateHealthy;
    } catch (e) {
      developer.log('Error checking service health: $e');
      return false;
    }
  }
  
  static Future<void> _restartServices() async {
    try {
      developer.log('Restarting location services');
      
      if (_currentUserId == null) return;
      
      // Stop current services
      await _stopNativeBackgroundService();
      await _stopFlutterLocationTracking();
      
      // Restart services
      await _startNativeBackgroundService(_currentUserId!);
      await _startFlutterLocationTracking();
      
      developer.log('Location services restarted successfully');
    } catch (e) {
      developer.log('Error restarting services: $e');
      _onError?.call('Service restart failed: $e');
    }
  }
  
  static Future<void> _processLocationUpdate(LatLng location) async {
    if (_currentUserId == null) return;
    
    try {
      // Send to background isolate for processing
      _isolateSendPort?.send(<String, dynamic>{
        'type': 'location_update',
        'latitude': location.latitude,
        'longitude': location.longitude,
        'userId': _currentUserId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Also update Firebase directly for immediate sync
      await _updateFirebaseLocation(_currentUserId!, location);
    } catch (e) {
      developer.log('Error processing location update: $e');
    }
  }
  
  static Future<void> _updateFirebaseLocation(String userId, LatLng location) async {
    try {
      final realtimeDb = FirebaseDatabase.instance;
      
      // Update Realtime Database for instant sync
      await realtimeDb.ref('locations/$userId').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'isSharing': true,
        'updatedAt': ServerValue.timestamp,
        'source': 'persistent_service',
      });
      
      // Update Firestore for persistence
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'lastOnline': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Error updating Firebase location: $e');
    }
  }
  
  static Future<void> _sendHeartbeatToFirebase(Map<String, dynamic> heartbeatData) async {
    try {
      final userId = heartbeatData['userId'] as String;
      final timestamp = heartbeatData['timestamp'] as int;
      
      final realtimeDb = FirebaseDatabase.instance;
      
      await realtimeDb.ref('users/$userId').update({
        'lastHeartbeat': timestamp,
        'appUninstalled': false,
        'lastSeen': ServerValue.timestamp,
      });
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'appUninstalled': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Error sending heartbeat to Firebase: $e');
    }
  }
  
  static Future<void> _clearUserLocationData(String userId) async {
    try {
      final realtimeDb = FirebaseDatabase.instance;
      
      // Remove from Realtime Database
      await realtimeDb.ref('locations/$userId').remove();
      
      // Update status in both databases
      await realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': false,
        'lastSeen': ServerValue.timestamp,
      });
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': false,
        'location': null,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Error clearing user location data: $e');
    }
  }
  
  /// Restore tracking state on app restart
  static Future<bool> restoreTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('persistent_location_tracking') ?? false;
      final userId = prefs.getString('persistent_location_user_id');
      
      if (wasTracking && userId != null) {
        developer.log('Restoring location tracking for user: ${userId.substring(0, 8)}');
        return await startTracking(userId: userId);
      }
      
      return false;
    } catch (e) {
      developer.log('Error restoring tracking state: $e');
      return false;
    }
  }
  
  /// Cleanup when app is being terminated
  static Future<void> cleanup() async {
    try {
      await stopTracking();
      
      // Kill background isolate
      _backgroundIsolate?.kill(priority: Isolate.immediate);
      _backgroundIsolate = null;
      _receivePort?.close();
      _receivePort = null;
      _isolateSendPort = null;
      
      _isInitialized = false;
    } catch (e) {
      developer.log('Error during cleanup: $e');
    }
  }
}