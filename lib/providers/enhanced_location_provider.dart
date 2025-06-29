import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/persistent_location_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/proximity_service.dart';
import '../utils/performance_optimizer.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced Location Provider that uses the Persistent Location Service
/// This provider ensures location tracking continues even when the app is killed
class EnhancedLocationProvider with ChangeNotifier {
  final LocationService _fallbackService = LocationService();
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  final PerformanceOptimizer _performanceOptimizer = PerformanceOptimizer();
  
  // State variables
  bool _isInitialized = false;
  bool _isTracking = false;
  bool _mounted = true;
  String? _currentUserId;
  String? _error;
  String _status = 'Initializing...';
  LatLng? _currentLocation;
  Map<String, LatLng> _userLocations = {};
  Map<String, bool> _userSharingStatus = {};
  
  // Subscriptions
  StreamSubscription<DatabaseEvent>? _realtimeLocationSubscription;
  StreamSubscription<DatabaseEvent>? _realtimeStatusSubscription;
  StreamSubscription<Position>? _fallbackLocationSubscription;
  
  // Timers
  Timer? _healthCheckTimer;
  Timer? _syncTimer;
  
  // Configuration
  static const Duration _healthCheckInterval = Duration(minutes: 2);
  static const Duration _syncInterval = Duration(seconds: 30);
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  bool get mounted => _mounted;
  String? get currentUserId => _currentUserId;
  String? get error => _error;
  String get status => _status;
  LatLng? get currentLocation => _currentLocation;
  Map<String, LatLng> get userLocations => _userLocations;
  Map<String, bool> get userSharingStatus => _userSharingStatus;
  
  /// Initialize the enhanced location provider
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('Initializing EnhancedLocationProvider');
      
      // Initialize performance optimizer
      await _performanceOptimizer.initialize();
      
      // Initialize notification service
      await NotificationService.initialize();
      
      // Initialize persistent location service
      final persistentInitialized = await PersistentLocationService.initialize();
      if (!persistentInitialized) {
        developer.log('Failed to initialize persistent location service, using fallback');
      }
      
      // Restore previous tracking state
      await _restoreTrackingState();
      
      // Start real-time listeners
      _startRealtimeListeners();
      
      // Start health monitoring
      _startHealthMonitoring();
      
      _isInitialized = true;
      _status = 'Ready';
      if (_mounted) notifyListeners();
      
      developer.log('EnhancedLocationProvider initialized successfully');
      return true;
    } catch (e) {
      developer.log('Failed to initialize EnhancedLocationProvider: $e');
      _error = 'Initialization failed: $e';
      _status = 'Error';
      if (_mounted) notifyListeners();
      return false;
    }
  }
  
  /// Start persistent location tracking
  Future<bool> startTracking(String userId) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isTracking && _currentUserId == userId) {
      developer.log('Already tracking for user: ${userId.substring(0, 8)}');
      return true;
    }
    
    try {
      developer.log('Starting enhanced location tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      _error = null;
      _status = 'Starting location tracking...';
      if (_mounted) notifyListeners();
      
      // Save tracking state
      await _saveTrackingState(userId, true);
      
      // Update Firebase status immediately
      await _updateLocationSharingStatus(userId, true);
      
      // Start persistent location service
      final persistentStarted = await PersistentLocationService.startTracking(
        userId: userId,
        onLocationUpdate: _handleLocationUpdate,
        onError: _handleLocationError,
        onServiceStopped: _handleServiceStopped,
      );
      
      if (!persistentStarted) {
        developer.log('Persistent service failed to start, using fallback');
        await _startFallbackTracking(userId);
      }
      
      // Start sync monitoring
      _startSyncMonitoring();
      
      _isTracking = true;
      _userSharingStatus[userId] = true;
      _status = 'Location sharing active';
      if (_mounted) notifyListeners();
      
      developer.log('Enhanced location tracking started successfully');
      return true;
    } catch (e) {
      developer.log('Failed to start enhanced location tracking: $e');
      _error = 'Failed to start tracking: $e';
      _status = 'Error';
      if (_mounted) notifyListeners();
      return false;
    }
  }
  
  /// Stop persistent location tracking
  Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('Stopping enhanced location tracking');
      
      _status = 'Stopping location tracking...';
      if (_mounted) notifyListeners();
      
      // Update Firebase status immediately
      if (_currentUserId != null) {
        await _updateLocationSharingStatus(_currentUserId!, false);
        _userSharingStatus[_currentUserId!] = false;
      }
      
      // Stop persistent location service
      await PersistentLocationService.stopTracking();
      
      // Stop fallback service
      await _stopFallbackTracking();
      
      // Stop sync monitoring
      _stopSyncMonitoring();
      
      // Save tracking state
      if (_currentUserId != null) {
        await _saveTrackingState(_currentUserId!, false);
      }
      
      // Clear proximity tracking
      ProximityService.clearProximityTracking();
      
      _isTracking = false;
      _currentLocation = null;
      _status = 'Location sharing stopped';
      if (_mounted) notifyListeners();
      
      developer.log('Enhanced location tracking stopped successfully');
      return true;
    } catch (e) {
      developer.log('Failed to stop enhanced location tracking: $e');
      _error = 'Failed to stop tracking: $e';
      if (_mounted) notifyListeners();
      return false;
    }
  }
  
  /// Check if a user is sharing their location
  bool isUserSharingLocation(String userId) {
    return _userSharingStatus[userId] == true && _userLocations.containsKey(userId);
  }
  
  /// Get current location for map display
  Future<void> getCurrentLocationForMap() async {
    if (_currentLocation != null) return;
    
    try {
      _status = 'Getting your location...';
      if (_mounted) notifyListeners();
      
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Location services are disabled';
        _status = 'Location services disabled';
        if (_mounted) notifyListeners();
        return;
      }
      
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          _error = 'Location permission denied';
          _status = 'Location permission denied';
          if (_mounted) notifyListeners();
          return;
        }
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentLocation = LatLng(position.latitude, position.longitude);
      _status = 'Location found';
      if (_mounted) notifyListeners();
    } catch (e) {
      developer.log('Error getting current location: $e');
      _error = 'Failed to get location: $e';
      _status = 'Location error';
      if (_mounted) notifyListeners();
    }
  }
  
  // Private methods
  
  Future<void> _restoreTrackingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('enhanced_location_tracking') ?? false;
      final userId = prefs.getString('enhanced_location_user_id');
      
      if (wasTracking && userId != null) {
        developer.log('Restoring tracking state for user: ${userId.substring(0, 8)}');
        _currentUserId = userId;
        
        // Check if persistent service can restore state
        final restored = await PersistentLocationService.restoreTrackingState();
        if (restored) {
          _isTracking = true;
          _userSharingStatus[userId] = true;
          _status = 'Location sharing restored';
        }
      }
    } catch (e) {
      developer.log('Error restoring tracking state: $e');
    }
  }
  
  Future<void> _saveTrackingState(String userId, bool isTracking) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enhanced_location_tracking', isTracking);
      await prefs.setString('enhanced_location_user_id', userId);
    } catch (e) {
      developer.log('Error saving tracking state: $e');
    }
  }
  
  void _startRealtimeListeners() {
    // Listen to all users' locations
    _realtimeLocationSubscription = _realtimeDb
        .ref('locations')
        .onValue
        .listen((event) {
      _handleRealtimeLocationUpdate(event);
    }, onError: (error) {
      developer.log('Error listening to realtime locations: $error');
    });
    
    // Listen to all users' sharing status
    _realtimeStatusSubscription = _realtimeDb
        .ref('users')
        .onValue
        .listen((event) {
      _handleRealtimeStatusUpdate(event);
    }, onError: (error) {
      developer.log('Error listening to realtime status: $error');
    });
  }
  
  void _handleRealtimeLocationUpdate(DatabaseEvent event) {
    if (!event.snapshot.exists) return;
    
    try {
      final locationsData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (locationsData == null) return;
      
      final updatedLocations = <String, LatLng>{};
      
      for (final entry in locationsData.entries) {
        final userId = entry.key as String;
        final locationData = entry.value as Map<dynamic, dynamic>?;
        
        if (locationData != null &&
            locationData.containsKey('lat') &&
            locationData.containsKey('lng') &&
            locationData['isSharing'] == true) {
          
          final lat = (locationData['lat'] as num).toDouble();
          final lng = (locationData['lng'] as num).toDouble();
          updatedLocations[userId] = LatLng(lat, lng);
        }
      }
      
      // Update current user's location if tracking
      if (_isTracking && _currentUserId != null && _currentLocation != null) {
        updatedLocations[_currentUserId!] = _currentLocation!;
      }
      
      _userLocations = updatedLocations;
      
      // Check proximity notifications
      if (_isTracking && _currentUserId != null && _currentLocation != null) {
        _checkProximityNotifications();
      }
      
      if (_mounted) notifyListeners();
    } catch (e) {
      developer.log('Error handling realtime location update: $e');
    }
  }
  
  void _handleRealtimeStatusUpdate(DatabaseEvent event) {
    if (!event.snapshot.exists) return;
    
    try {
      final usersData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (usersData == null) return;
      
      final updatedStatus = <String, bool>{};
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final entry in usersData.entries) {
        final userId = entry.key as String;
        final userData = entry.value as Map<dynamic, dynamic>?;
        
        if (userData != null) {
          final locationSharingEnabled = userData['locationSharingEnabled'] == true;
          final appUninstalled = userData['appUninstalled'] == true;
          
          // Check heartbeat for app activity
          bool isAppActive = true;
          if (locationSharingEnabled && userData.containsKey('lastHeartbeat')) {
            final lastHeartbeat = userData['lastHeartbeat'] as int?;
            if (lastHeartbeat != null) {
              final timeSinceHeartbeat = now - lastHeartbeat;
              if (timeSinceHeartbeat > 120000) { // 2 minutes
                isAppActive = false;
              }
            }
          }
          
          updatedStatus[userId] = locationSharingEnabled && !appUninstalled && isAppActive;
        }
      }
      
      _userSharingStatus = updatedStatus;
      if (_mounted) notifyListeners();
    } catch (e) {
      developer.log('Error handling realtime status update: $e');
    }
  }
  
  void _handleLocationUpdate(LatLng location) {
    if (!_isTracking || _currentUserId == null) return;
    
    _currentLocation = location;
    _userLocations[_currentUserId!] = location;
    
    // Check proximity notifications
    _checkProximityNotifications();
    
    if (_mounted) notifyListeners();
  }
  
  void _handleLocationError(String error) {
    developer.log('Location error from persistent service: $error');
    _error = error;
    if (_mounted) notifyListeners();
    
    // Try to restart with fallback service
    if (_isTracking && _currentUserId != null) {
      _startFallbackTracking(_currentUserId!);
    }
  }
  
  void _handleServiceStopped() {
    developer.log('Persistent location service stopped unexpectedly');
    
    if (_isTracking && _currentUserId != null) {
      // Try to restart the service
      Future.delayed(const Duration(seconds: 5), () {
        if (_isTracking && _currentUserId != null) {
          PersistentLocationService.startTracking(
            userId: _currentUserId!,
            onLocationUpdate: _handleLocationUpdate,
            onError: _handleLocationError,
            onServiceStopped: _handleServiceStopped,
          );
        }
      });
    }
  }
  
  Future<void> _startFallbackTracking(String userId) async {
    try {
      developer.log('Starting fallback location tracking');
      
      _fallbackLocationSubscription = await _fallbackService.startTracking(
        userId,
        (LatLng location) {
          _handleLocationUpdate(location);
        },
      );
    } catch (e) {
      developer.log('Error starting fallback tracking: $e');
    }
  }
  
  Future<void> _stopFallbackTracking() async {
    try {
      await _fallbackLocationSubscription?.cancel();
      await _fallbackService.stopTracking();
      _fallbackLocationSubscription = null;
    } catch (e) {
      developer.log('Error stopping fallback tracking: $e');
    }
  }
  
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }
  
  void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }
  
  Future<void> _performHealthCheck() async {
    if (!_isTracking || _currentUserId == null) return;
    
    try {
      // Check if persistent service is still healthy
      final isHealthy = PersistentLocationService.isTracking;
      
      if (!isHealthy) {
        developer.log('Health check failed, attempting to restart persistent service');
        
        await PersistentLocationService.startTracking(
          userId: _currentUserId!,
          onLocationUpdate: _handleLocationUpdate,
          onError: _handleLocationError,
          onServiceStopped: _handleServiceStopped,
        );
      }
    } catch (e) {
      developer.log('Error during health check: $e');
    }
  }
  
  void _startSyncMonitoring() {
    _syncTimer?.cancel();
    
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      _performSyncCheck();
    });
  }
  
  void _stopSyncMonitoring() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  Future<void> _performSyncCheck() async {
    if (!_isTracking || _currentUserId == null) return;
    
    try {
      // Ensure user status is correctly synced
      await _updateLocationSharingStatus(_currentUserId!, true);
      
      // Send heartbeat
      await _sendHeartbeat(_currentUserId!);
    } catch (e) {
      developer.log('Error during sync check: $e');
    }
  }
  
  Future<void> _updateLocationSharingStatus(String userId, bool isSharing) async {
    try {
      // Update Realtime Database for instant sync
      await _realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': isSharing,
        'lastSeen': ServerValue.timestamp,
      });
      
      // Update Firestore for persistence
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': isSharing,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      if (!isSharing) {
        // Clear location data when stopping
        await _realtimeDb.ref('locations/$userId').remove();
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'location': null,
        });
      }
    } catch (e) {
      developer.log('Error updating location sharing status: $e');
    }
  }
  
  Future<void> _sendHeartbeat(String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await _realtimeDb.ref('users/$userId').update({
        'lastHeartbeat': timestamp,
        'appUninstalled': false,
      });
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'appUninstalled': false,
      });
    } catch (e) {
      developer.log('Error sending heartbeat: $e');
    }
  }
  
  Future<void> _checkProximityNotifications() async {
    if (_currentLocation == null || _currentUserId == null) return;
    
    try {
      await ProximityService.checkProximityForAllFriends(
        userLocation: _currentLocation!,
        friendLocations: _userLocations,
        friendSharingStatus: _userSharingStatus,
        currentUserId: _currentUserId!,
      );
    } catch (e) {
      developer.log('Error checking proximity notifications: $e');
    }
  }
  
  @override
  void dispose() {
    developer.log('Disposing EnhancedLocationProvider');
    
    _mounted = false;
    
    // Stop all monitoring
    _stopHealthMonitoring();
    _stopSyncMonitoring();
    
    // Cancel subscriptions
    _realtimeLocationSubscription?.cancel();
    _realtimeStatusSubscription?.cancel();
    _fallbackLocationSubscription?.cancel();
    
    // Dispose performance optimizer
    _performanceOptimizer.dispose();
    
    super.dispose();
  }
}