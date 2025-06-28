import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/performance_optimizer.dart';
import '../services/notification_service.dart';
import '../services/proximity_service.dart';

/// Enhanced LocationProvider with REAL-TIME push notifications
/// This version uses Firebase Realtime Database for instant synchronization
class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  final PerformanceOptimizer _performanceOptimizer = PerformanceOptimizer();
  
  // Subscriptions for real-time updates
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _friendsLocationSubscription;
  StreamSubscription<DocumentSnapshot>? _userStatusSubscription;
  StreamSubscription<DatabaseEvent>? _realtimeStatusSubscription;
  StreamSubscription<DatabaseEvent>? _realtimeLocationSubscription;
  StreamSubscription<ServiceStatus>? _locationServiceSubscription;
  
  // State variables
  LatLng? _currentLocation;
  final List<String> _nearbyUsers = [];
  bool _isTracking = false;
  bool _isInitialized = false;
  bool _mounted = true;
  String? _error;
  String _status = 'Initializing...';
  String? _currentAddress;
  String? _city;
  String? _country;
  String? _postalCode;
  Map<String, LatLng> _userLocations = {};
  Map<String, bool> _userSharingStatus = {}; // Track real-time sharing status for each user
  VoidCallback? onLocationServiceDisabled;
  VoidCallback? onLocationServiceEnabled;
  
  // Prevent race conditions with local state changes
  DateTime? _lastLocalToggleTime;
  static const Duration _localToggleProtectionWindow = Duration(seconds: 3);
  
  // Location service state management
  bool _locationServiceEnabled = true;
  bool _wasTrackingBeforeServiceDisabled = false;
  String? _userIdForResumption;
  
  // Heartbeat mechanism to detect app uninstall
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30); // Shorter interval for faster detection
  
  // Debounce timer to prevent excessive notifications
  Timer? _notificationDebounceTimer;
  
  // Performance optimization
  DateTime? _lastLocationUpdate;
  DateTime? _lastFirebaseUpdate;

  // Getters
  LatLng? get currentLocation => _currentLocation;
  List<String> get nearbyUsers => _nearbyUsers;
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String get status => _status;
  String? get currentAddress => _currentAddress;
  String? get city => _city;
  String? get country => _country;
  String? get postalCode => _postalCode;
  Map<String, LatLng> get userLocations => _userLocations;
  Map<String, bool> get userSharingStatus => _userSharingStatus;
  bool get mounted => _mounted;
  bool get locationServiceEnabled => _locationServiceEnabled;

  // Check if a specific user is sharing their location
  bool isUserSharingLocation(String userId) {
    if (userId.isEmpty) return false;
    return _userSharingStatus[userId] == true && _userLocations.containsKey(userId);
  }

  // Guard to prevent multiple simultaneous location requests
  bool _isGettingLocation = false;
  DateTime? _lastLocationRequestTime;
  
  // Get current location for map display (without starting tracking)
  Future<void> getCurrentLocationForMap() async {
    if (_currentLocation != null) {
      _log('Current location already available: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
      return;
    }
    
    if (_isGettingLocation) {
      _log('Location request already in progress, skipping');
      return;
    }
    
    // Add cooldown period to prevent excessive requests
    final now = DateTime.now();
    if (_lastLocationRequestTime != null && 
        now.difference(_lastLocationRequestTime!) < const Duration(seconds: 5)) {
      _log('Location request too frequent, skipping (cooldown: 5s)');
      return;
    }
    
    _isGettingLocation = true;
    _log('=== GETTING CURRENT LOCATION FOR MAP ===');
    try {
      _status = 'Getting your location...';
      _log('Status: $_status');
      if (_mounted) notifyListeners();
      
      _log('Checking if location services are enabled...');
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _log('Location services enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        _error = 'Location services are disabled';
        _status = 'Location services disabled';
        _log('ERROR: $_error');
        if (_mounted) notifyListeners();
        return;
      }

      _log('Checking location permissions...');
      final permission = await Geolocator.checkPermission();
      _log('Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        _log('Requesting location permission...');
        final newPermission = await Geolocator.requestPermission();
        _log('New permission: $newPermission');
        
        if (newPermission == LocationPermission.denied) {
          _error = 'Location permission denied';
          _status = 'Location permission denied';
          _log('ERROR: $_error');
          if (_mounted) notifyListeners();
          return;
        }
      }

      _log('Getting current position...');
      _status = 'Finding your location...';
      if (_mounted) notifyListeners();
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentLocation = LatLng(position.latitude, position.longitude);
      _status = 'Location found';
      _log('SUCCESS: Current location set to ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
      
      if (_mounted) notifyListeners();
    } catch (e) {
      _log('ERROR getting current location: $e');
      _error = 'Failed to get location: ${e.toString()}';
      _status = 'Location error';
      if (_mounted) notifyListeners();
    } finally {
      _isGettingLocation = false;
      _lastLocationRequestTime = DateTime.now();
    }
  }

  // Set demo location for testing
  void setDemoLocation() {
    _log('=== SETTING DEMO LOCATION ===');
    // Use a demo location (San Francisco)
    _currentLocation = LatLng(37.7749, -122.4194);
    _status = 'Demo location set';
    _error = null;
    _log('Demo location set: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
    if (_mounted) notifyListeners();
  }

  // Get current user ID from SharedPreferences
  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  // Throttle logging to prevent excessive output
  DateTime? _lastLogTime;
  void _log(String message) {
    final now = DateTime.now();
    if (_lastLogTime == null || now.difference(_lastLogTime!) > const Duration(milliseconds: 100)) {
      debugPrint('REALTIME_PROVIDER: $message');
      _lastLogTime = now;
    }
  }

  // Start monitoring location service status changes
  void _startLocationServiceMonitoring() {
    _log('=== STARTING LOCATION SERVICE MONITORING ===');
    
    // Cancel existing subscription
    _locationServiceSubscription?.cancel();
    
    // Check initial status
    Geolocator.isLocationServiceEnabled().then((enabled) {
      _locationServiceEnabled = enabled;
      _log('Initial location service status: $enabled');
      if (_mounted) notifyListeners();
    });
    
    // Listen to service status changes
    _locationServiceSubscription = Geolocator.getServiceStatusStream().listen((status) {
      final wasEnabled = _locationServiceEnabled;
      _locationServiceEnabled = status == ServiceStatus.enabled;
      
      _log('Location service status changed: $status (enabled: $_locationServiceEnabled)');
      
      if (_mounted) notifyListeners();
      
      // Handle service disabled
      if (wasEnabled && !_locationServiceEnabled) {
        _handleLocationServiceDisabled();
      }
      // Handle service enabled
      else if (!wasEnabled && _locationServiceEnabled) {
        _handleLocationServiceEnabled();
      }
    }, onError: (error) {
      _log('Error monitoring location service status: $error');
    });
  }

  // Handle location service being disabled - IMMEDIATELY mark user as offline
  Future<void> _handleLocationServiceDisabled() async {
    _log('=== LOCATION SERVICE DISABLED ===');
    
    // Store current tracking state for resumption
    _wasTrackingBeforeServiceDisabled = _isTracking;
    
    if (_isTracking) {
      _log('Location service disabled while tracking - marking user as offline');
      _status = 'Location services disabled - you appear offline to friends';
      
      // Get current user ID
      final userId = await _getCurrentUserId();
      if (userId != null) {
        // IMMEDIATELY mark user as offline in both databases
        await _markUserAsOffline(userId);
        
        // Store user ID for resumption
        _userIdForResumption = userId;
      }
      
      // Pause location subscription but keep tracking state for resumption
      _locationSubscription?.pause();
      
      // Notify callback if set
      if (onLocationServiceDisabled != null) {
        onLocationServiceDisabled!();
      }
    } else {
      _status = 'Location services disabled';
    }
    
    if (_mounted) notifyListeners();
  }

  // Handle location service being enabled - resume tracking if it was active
  Future<void> _handleLocationServiceEnabled() async {
    _log('=== LOCATION SERVICE ENABLED ===');
    
    _status = 'Location services enabled';
    
    // Resume tracking if it was active before service was disabled
    if (_wasTrackingBeforeServiceDisabled && _userIdForResumption != null) {
      _log('Resuming location tracking after service re-enabled');
      _status = 'Resuming location tracking...';
      
      // Mark user as online first
      await _markUserAsOnline(_userIdForResumption!);
      
      // Resume location subscription if it was paused
      _locationSubscription?.resume();
      
      // If subscription was cancelled, restart tracking
      if (_locationSubscription == null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_mounted && _locationServiceEnabled) {
            _startTrackingInBackground(_userIdForResumption!);
          }
        });
      }
      
      // Reset the flag
      _wasTrackingBeforeServiceDisabled = false;
      
      // Notify callback if set
      if (onLocationServiceEnabled != null) {
        onLocationServiceEnabled!();
      }
    }
    
    if (_mounted) notifyListeners();
  }

  // Mark user as offline in both databases
  Future<void> _markUserAsOffline(String userId) async {
    _log('Marking user as offline: ${userId.substring(0, 8)}');
    try {
      // Remove from Realtime Database locations (makes user appear offline immediately)
      await _realtimeDb.ref('locations/$userId').remove();
      _log('Removed user from Realtime DB locations');
      
      // Update Realtime Database status to indicate location service is disabled
      await _realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': false,
        'locationServiceDisabled': true,
        'lastSeen': ServerValue.timestamp,
      });
      _log('Updated Realtime DB user status to offline');
      
      // Update Firestore to mark as offline
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': false,
        'locationServiceDisabled': true,
        'location': null, // Clear location data
        'lastSeen': FieldValue.serverTimestamp(),
        'lastOnline': FieldValue.serverTimestamp(),
      });
      _log('Updated Firestore user status to offline');
      
      // Update local state
      _userSharingStatus[userId] = false;
      _userLocations.remove(userId);
      
    } catch (e) {
      _log('Error marking user as offline: $e');
    }
  }

  // Mark user as online when location service is restored
  Future<void> _markUserAsOnline(String userId) async {
    _log('Marking user as online: ${userId.substring(0, 8)}');
    try {
      // Update Realtime Database status
      await _realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': true,
        'locationServiceDisabled': false,
        'appUninstalled': false,
        'lastSeen': ServerValue.timestamp,
        'lastHeartbeat': ServerValue.timestamp,
      });
      _log('Updated Realtime DB user status to online');
      
      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': true,
        'locationServiceDisabled': false,
        'appUninstalled': false,
        'lastOnline': FieldValue.serverTimestamp(),
        'lastHeartbeat': FieldValue.serverTimestamp(),
      });
      _log('Updated Firestore user status to online');
      
      // Update local state
      _userSharingStatus[userId] = true;
      
    } catch (e) {
      _log('Error marking user as online: $e');
    }
  }

  // Start heartbeat mechanism to detect app uninstall
  void _startHeartbeat(String userId) {
    _log('Starting heartbeat for user: ${userId.substring(0, 8)}');
    
    // Cancel existing heartbeat
    _heartbeatTimer?.cancel();
    
    // Start new heartbeat timer
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_mounted && _isTracking) {
        _sendHeartbeat(userId);
      } else {
        timer.cancel();
      }
    });
    
    // Send initial heartbeat
    _sendHeartbeat(userId);
  }

  // Send heartbeat to indicate app is still running
  Future<void> _sendHeartbeat(String userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Update heartbeat in Realtime Database with actual timestamp
      await _realtimeDb.ref('users/$userId/lastHeartbeat').set(now);
      
      // Also update other status fields
      await _realtimeDb.ref('users/$userId').update({
        'lastHeartbeat': now,
        'appUninstalled': false,
        'lastSeen': ServerValue.timestamp,
      });
      
      // Update heartbeat in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'appUninstalled': false, // Explicitly mark as not uninstalled
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      _log('Sent heartbeat for user: ${userId.substring(0, 8)} at $now');
    } catch (e) {
      _log('Error sending heartbeat: $e');
    }
  }

  // Stop heartbeat mechanism
  void _stopHeartbeat() {
    _log('Stopping heartbeat');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Debounced notification to prevent excessive rebuilds
  void _notifyListenersDebounced() {
    _notificationDebounceTimer?.cancel();
    final debounceInterval = _performanceOptimizer.getOptimizedDebounceInterval();
    _notificationDebounceTimer = Timer(debounceInterval, () {
      if (_mounted) {
        notifyListeners();
      }
    });
  }

  // Initialize provider with saved state
  Future<void> initialize() async {
    _log('=== INITIALIZE CALLED ===');
    if (_isInitialized) {
      _log('Already initialized, returning');
      return;
    }
    
    // Initialize performance optimizer
    await _performanceOptimizer.initialize();
    
    // Initialize notification service for proximity notifications
    await NotificationService.initialize();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLocationSharingEnabled = prefs.getBool('location_sharing_enabled') ?? false;
      final savedUserId = prefs.getString('user_id');
      
      _log('Saved preferences: sharing=$isLocationSharingEnabled, userId=${savedUserId?.substring(0, 8)}');
      
      // Set the tracking state immediately to prevent flickering
      _isTracking = isLocationSharingEnabled;
      _isInitialized = true;
      if (_mounted) notifyListeners();
      
      // Start monitoring location service status
      _startLocationServiceMonitoring();
      
      // Start listening to user status changes for real-time sync
      if (savedUserId != null) {
        _log('Starting REALTIME listeners for user: ${savedUserId.substring(0, 8)}');
        _startListeningToUserStatus(savedUserId);
        _listenToFriendsLocations(savedUserId);
        _listenToAllUsersStatus(); // Listen to all users' sharing status
      } else {
        _log('No saved user ID found');
      }
      
      // If location sharing was enabled and we have a user ID, restart tracking
      if (isLocationSharingEnabled && savedUserId != null) {
        _log('Auto-restarting location tracking');
        
        // Don't update Firebase status immediately - let startTracking handle it
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_mounted) {
            startTracking(savedUserId).catchError((e) {
              _log('Error restarting location tracking: $e');
              _isTracking = false;
              if (_mounted) notifyListeners();
              
              // Save the failed state to prevent auto-restart loop
              SharedPreferences.getInstance().then((prefs) {
                prefs.setBool('location_sharing_enabled', false);
              });
            });
          }
        });
      } else if (savedUserId != null) {
        // Only update status if tracking was explicitly disabled
        _updateLocationSharingStatus(savedUserId, false);
      }
      
    } catch (e) {
      _log('Error initializing LocationProvider: $e');
      _isInitialized = true;
      _isTracking = false;
      if (_mounted) notifyListeners();
    }
  }

  // Listen to user's own status changes for INSTANT real-time sync across devices
  void _startListeningToUserStatus(String userId) {
    _log('Setting up REALTIME user status listener for: ${userId.substring(0, 8)}');
    
    // Cancel existing subscriptions
    _userStatusSubscription?.cancel();
    _realtimeStatusSubscription?.cancel();
    
    // PRIMARY: Listen to Firebase Realtime Database for INSTANT updates (10-50ms)
    _realtimeStatusSubscription = _realtimeDb
        .ref('users/$userId/locationSharingEnabled')
        .onValue
        .listen((event) {
      _log('INSTANT STATUS UPDATE RECEIVED from Realtime DB');
      
      if (event.snapshot.exists) {
        final realtimeIsTracking = event.snapshot.value as bool? ?? false;
        _log('Realtime DB tracking status: $realtimeIsTracking, local: $_isTracking');
        
        // Only update if the realtime state is different from local state
        if (realtimeIsTracking != _isTracking) {
          // Check if we're in the protection window after a local toggle
          final now = DateTime.now();
          final isInProtectionWindow = _lastLocalToggleTime != null && 
              now.difference(_lastLocalToggleTime!) < _localToggleProtectionWindow;
          
          if (isInProtectionWindow) {
            _log('PROTECTION: Ignoring remote state change during local toggle protection window');
            return;
          }
          
          _log('INSTANT SYNC: Location sharing status changed to $realtimeIsTracking');
          _isTracking = realtimeIsTracking;
          
          // Update local preferences to match realtime DB
          SharedPreferences.getInstance().then((prefs) {
            prefs.setBool('location_sharing_enabled', realtimeIsTracking);
          });
          
          // Update status message - keep it neutral for map display
          _status = realtimeIsTracking 
              ? 'Location sharing enabled'
              : 'Ready to share location';
          
          if (_mounted) notifyListeners();
          
          // If tracking was enabled from another device, start local tracking
          if (realtimeIsTracking && _locationSubscription == null) {
            _log('Starting tracking from INSTANT remote change');
            _startTrackingInBackground(userId);
          }
          // If tracking was disabled from another device, stop local tracking
          else if (!realtimeIsTracking && _locationSubscription != null) {
            _log('Stopping tracking from INSTANT remote change');
            _stopTrackingInBackground();
          }
        }
      }
    }, onError: (error) {
      _log('Error listening to realtime status changes: $error');
    });
    
    // BACKUP: Keep Firestore listener for data consistency
    _userStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      _log('Firestore backup status received');
      if (snapshot.exists) {
        final data = snapshot.data();
        final firestoreIsTracking = data?['locationSharingEnabled'] as bool? ?? false;
        
        // Sync Firestore with Realtime DB if they're out of sync
        _realtimeDb.ref('users/$userId/locationSharingEnabled').get().then((realtimeSnapshot) {
          if (realtimeSnapshot.exists) {
            final realtimeIsTracking = realtimeSnapshot.value as bool? ?? false;
            if (firestoreIsTracking != realtimeIsTracking) {
              _log('Syncing Firestore ($firestoreIsTracking) with Realtime DB ($realtimeIsTracking)');
              FirebaseFirestore.instance.collection('users').doc(userId).update({
                'locationSharingEnabled': realtimeIsTracking,
              });
            }
          }
        });
      }
    }, onError: (error) {
      _log('Error listening to Firestore status changes: $error');
    });
  }

  // Listen to friends' locations with INSTANT real-time updates
  void _listenToFriendsLocations(String userId) {
    _log('=== SETTING UP REALTIME FRIENDS LOCATION LISTENER ===');
    _friendsLocationSubscription?.cancel();
    _realtimeLocationSubscription?.cancel();
    
    // PRIMARY: Listen to Firebase Realtime Database for INSTANT location updates
    _realtimeLocationSubscription = _realtimeDb
        .ref('locations')
        .onValue
        .listen((event) {
      _log('INSTANT LOCATION UPDATE RECEIVED from Realtime DB');
      
      if (event.snapshot.exists) {
        final locationsData = event.snapshot.value as Map<dynamic, dynamic>?;
        if (locationsData != null) {
          final updatedLocations = <String, LatLng>{};
          final updatedSharingStatus = <String, bool>{};
          
          for (final entry in locationsData.entries) {
            final otherUserId = entry.key as String;
            
            // Skip current user
            if (otherUserId == userId) continue;
            
            final locationData = entry.value as Map<dynamic, dynamic>?;
            if (locationData != null && 
                locationData.containsKey('lat') && 
                locationData.containsKey('lng')) {
              
              final isSharing = locationData['isSharing'] == true;
              updatedSharingStatus[otherUserId] = isSharing;
              
              if (isSharing) {
                final lat = (locationData['lat'] as num).toDouble();
                final lng = (locationData['lng'] as num).toDouble();
                updatedLocations[otherUserId] = LatLng(lat, lng);
                
                _log('INSTANT location for ${otherUserId.substring(0, 8)}: $lat, $lng (sharing: $isSharing)');
              } else {
                _log('User ${otherUserId.substring(0, 8)} stopped sharing location');
              }
            } else {
              // User has no location data - they are offline
              updatedSharingStatus[otherUserId] = false;
              _log('User ${otherUserId.substring(0, 8)} is offline (no location data)');
            }
          }
          
          // Preserve current user's location if it exists
          final currentUserLocation = _userLocations[userId];
          _userLocations = updatedLocations;
          if (currentUserLocation != null) {
            _userLocations[userId] = currentUserLocation;
          }
          
          // Update sharing status for all users
          _userSharingStatus = updatedSharingStatus;
          if (_isTracking) {
            _userSharingStatus[userId] = true; // Ensure current user's status is correct
          }
          
          _log('INSTANT UPDATE: ${_userLocations.length} users with locations, ${_userSharingStatus.length} users with status');
          
          // Check proximity for friends (500m range notifications)
          _checkProximityNotifications(userId);
          
          // Use debounced notification for location updates
          _notifyListenersDebounced();
        }
      }
    }, onError: (error) {
      _log('ERROR listening to realtime locations: $error');
    });
    
    // BACKUP: Keep Firestore listener for data consistency
    _friendsLocationSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('locationSharingEnabled', isEqualTo: true)
        .snapshots()
        .listen((query) {
      _log('FIRESTORE BACKUP: ${query.docs.length} users sharing location');
      
      // Only use Firestore data if Realtime DB data is not available
      if (_userLocations.isEmpty) {
        final updated = <String, LatLng>{};
        
        for (final doc in query.docs) {
          if (doc.id == userId) continue;
          
          final data = doc.data();
          if (data.containsKey('location') && data['location'] != null) {
            final locationData = data['location'] as Map<String, dynamic>;
            if (locationData.containsKey('lat') && locationData.containsKey('lng')) {
              updated[doc.id] = LatLng(locationData['lat'], locationData['lng']);
            }
          }
        }
        
        if (updated.isNotEmpty) {
          _log('FIRESTORE FALLBACK: Using backup data');
          final currentUserLocation = _userLocations[userId];
          _userLocations = updated;
          if (currentUserLocation != null) {
            _userLocations[userId] = currentUserLocation;
          }
          
          if (_mounted) {
            notifyListeners();
          }
        }
      }
    }, onError: (error) {
      _log('ERROR listening to Firestore locations: $error');
    });
  }

  // Listen to all users' sharing status for real-time updates
  void _listenToAllUsersStatus() {
    _log('=== SETTING UP REALTIME ALL USERS STATUS LISTENER ===');
    
    // Listen to all users' sharing status in real-time database
    _realtimeDb.ref('users').onValue.listen((event) {
      if (event.snapshot.exists) {
        final usersData = event.snapshot.value as Map<dynamic, dynamic>?;
        if (usersData != null) {
          final updatedSharingStatus = <String, bool>{..._userSharingStatus};
          bool hasChanges = false;
          final now = DateTime.now().millisecondsSinceEpoch;
          
          for (final entry in usersData.entries) {
            final userId = entry.key as String;
            final userData = entry.value as Map<dynamic, dynamic>?;
            
            if (userData != null) {
              // Check if app was uninstalled
              final appUninstalled = userData['appUninstalled'] == true;
              final locationSharingEnabled = userData['locationSharingEnabled'] == true;
              
              // Check heartbeat to detect app uninstall
              bool isAppActive = true;
              if (locationSharingEnabled && userData.containsKey('lastHeartbeat')) {
                final lastHeartbeat = userData['lastHeartbeat'] as int?;
                if (lastHeartbeat != null) {
                  final timeSinceHeartbeat = now - lastHeartbeat;
                  // If no heartbeat for more than 2 minutes, consider app uninstalled
                  if (timeSinceHeartbeat > 120000) { // 2 minutes in milliseconds
                    isAppActive = false;
                    _log('User ${userId.substring(0, 8)} heartbeat stale (${timeSinceHeartbeat}ms ago) - marking as offline');
                    
                    // Mark as uninstalled in database
                    _markUserAsUninstalledDueToStaleHeartbeat(userId);
                  }
                }
              }
              
              final isSharing = locationSharingEnabled && !appUninstalled && isAppActive;
              
              // Only update if status actually changed
              if (updatedSharingStatus[userId] != isSharing) {
                updatedSharingStatus[userId] = isSharing;
                hasChanges = true;
                
                if (appUninstalled || !isAppActive) {
                  _log('User ${userId.substring(0, 8)} is offline (uninstalled: $appUninstalled, inactive: ${!isAppActive})');
                  // Remove from locations as well
                  _userLocations.remove(userId);
                } else {
                  _log('User ${userId.substring(0, 8)} sharing status changed to: $isSharing');
                }
              }
            }
          }
          
          // Only notify if there were actual changes
          if (hasChanges) {
            _userSharingStatus = updatedSharingStatus;
            _notifyListenersDebounced();
          }
        }
      }
    }, onError: (error) {
      _log('ERROR listening to realtime user status: $error');
    });
  }

  // Check proximity for friends and trigger notifications if within 500m range
  Future<void> _checkProximityNotifications(String currentUserId) async {
    try {
      // Only check proximity if we have current location and are tracking
      if (_currentLocation == null || !_isTracking) {
        return;
      }
      
      // Check proximity for all friends
      await ProximityService.checkProximityForAllFriends(
        userLocation: _currentLocation!,
        friendLocations: _userLocations,
        friendSharingStatus: _userSharingStatus,
        currentUserId: currentUserId,
      );
      
    } catch (e) {
      _log('Error checking proximity notifications: $e');
    }
  }

  // Mark user as uninstalled due to stale heartbeat
  Future<void> _markUserAsUninstalledDueToStaleHeartbeat(String userId) async {
    try {
      // Update Realtime Database to mark as uninstalled
      await _realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': false,
        'appUninstalled': true,
        'lastSeen': ServerValue.timestamp,
        'uninstallReason': 'stale_heartbeat',
      });
      
      // Remove from locations
      await _realtimeDb.ref('locations/$userId').remove();
      
      // Update Firestore as well
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': false,
        'appUninstalled': true,
        'location': null,
        'lastSeen': FieldValue.serverTimestamp(),
        'uninstallReason': 'stale_heartbeat',
      });
      
      _log('Marked user ${userId.substring(0, 8)} as uninstalled due to stale heartbeat');
    } catch (e) {
      _log('Error marking user as uninstalled due to stale heartbeat: $e');
    }
  }

  // Start tracking location
  Future<void> startTracking(String userId) async {
    _log('=== START TRACKING CALLED ===');
    
    if (_isTracking) {
      _log('Already tracking, returning');
      return;
    }

    // Store user ID for potential resumption
    _userIdForResumption = userId;

    // Record local toggle time to prevent race conditions
    _lastLocalToggleTime = DateTime.now();
    _log('Recorded local toggle time for protection window');

    // Set tracking to true IMMEDIATELY for instant UI response
    _isTracking = true;
    _userSharingStatus[userId] = true; // Update sharing status immediately
    _error = null;
    _status = 'Starting location sharing...';
    if (_mounted) notifyListeners();

    // Save preference immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_enabled', true);
      await prefs.setString('user_id', userId);
      _log('Saved preferences');
    } catch (e) {
      _log('Error saving preferences: $e');
    }

    // Start listening to user status changes for real-time sync
    _startListeningToUserStatus(userId);
    
    // Start listening to all users' status if not already listening
    _listenToAllUsersStatus();

    // Update Firebase status immediately for INSTANT real-time status
    _updateLocationSharingStatus(userId, true);

    // Start heartbeat to detect app uninstall
    _startHeartbeat(userId);

    // Do the heavy work in the background
    _startTrackingInBackground(userId);
  }

  // Background method to handle the actual location tracking setup
  Future<void> _startTrackingInBackground(String userId) async {
    _log('Starting background tracking for: ${userId.substring(0, 8)}');
    try {
      _status = 'Checking location services...';
      if (_mounted) notifyListeners();

      // Check if location services are enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log('Location services are disabled');
        _error = 'Location services are disabled';
        _status = 'Location services are disabled';
        _isTracking = false;
        if (_mounted) notifyListeners();
        if (onLocationServiceDisabled != null) onLocationServiceDisabled!();
        return;
      }

      _status = 'Getting location permissions...';
      if (_mounted) notifyListeners();

      LatLng? lastLocation;

      _status = 'Starting location tracking...';
      if (_mounted) notifyListeners();

      _locationSubscription = await _locationService.startTracking(
        userId,
        (LatLng location) async {
          _performanceOptimizer.startOperation('location_update');
          _log('Location update received: ${location.latitude}, ${location.longitude}');
          
          // Check if location services are still enabled
          if (!_locationServiceEnabled) {
            _log('Location service disabled, cannot update location');
            _performanceOptimizer.endOperation('location_update');
            return;
          }
          
          final now = DateTime.now();
          
          // Performance-aware update intervals
          final optimizedInterval = _performanceOptimizer.getOptimizedLocationInterval();
          final optimizedDistance = _performanceOptimizer.getOptimizedLocationAccuracy();
          
          bool shouldUpdate = false;
          if (lastLocation == null || _lastLocationUpdate == null) {
            shouldUpdate = true;
          } else {
            final distance = const Distance().as(LengthUnit.Meter, lastLocation!, location);
            final timeDiff = now.difference(_lastLocationUpdate!);
            shouldUpdate = distance > optimizedDistance || timeDiff > optimizedInterval;
          }
          
          if (shouldUpdate) {
            lastLocation = location;
            _lastLocationUpdate = now;
            _currentLocation = location;
            _userLocations[userId] = location;
            _status = 'Location sharing active';
            _log('Updated current location (optimized)');
            
            // Performance-aware Firebase updates
            final firebaseInterval = _performanceOptimizer.getOptimizedFirebaseUpdateInterval();
            if (_lastFirebaseUpdate == null || 
                now.difference(_lastFirebaseUpdate!) > firebaseInterval) {
              await _updateLocationInBothDatabases(userId, location);
              _lastFirebaseUpdate = now;
            }
            
            await _getAddressFromCoordinates(location.latitude, location.longitude);
            
            // Check proximity for friends when user location updates
            _checkProximityNotifications(userId);
            
            if (_mounted) notifyListeners();
          }
          
          _performanceOptimizer.endOperation('location_update');
        },
      );

      _status = 'Location sharing active';
      if (_mounted) notifyListeners();

      // Listen to friends' locations (if not already listening)
      if (_friendsLocationSubscription == null) {
        _log('Setting up friends listener from background tracking');
        _listenToFriendsLocations(userId);
      }
    } catch (e) {
      _log('Error in background tracking: $e');
      _isTracking = false;
      _error = e.toString();
      _status = 'Error: ${e.toString()}';
      if (_mounted) notifyListeners();
    }
  }

  // Update location in BOTH databases for instant sync and persistence
  Future<void> _updateLocationInBothDatabases(String userId, LatLng location) async {
    try {
      // Update Realtime Database FIRST for instant push notifications
      await _realtimeDb.ref('locations/$userId').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'isSharing': true,
        'updatedAt': ServerValue.timestamp,
      });
      _log('Updated Realtime DB location');
      
      // Then update Firestore for persistence and queries
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'location': {
          'lat': location.latitude, 
          'lng': location.longitude, 
          'updatedAt': FieldValue.serverTimestamp()
        },
        'lastOnline': FieldValue.serverTimestamp(),
      });
      _log('Updated Firestore location');
    } catch (e) {
      _log('Error updating location in databases: $e');
    }
  }

  // Stop tracking location
  Future<void> stopTracking() async {
    _log('=== STOP TRACKING CALLED ===');
    
    // Record local toggle time to prevent race conditions
    _lastLocalToggleTime = DateTime.now();
    _log('Recorded local toggle time for protection window');
    
    // Set tracking to false IMMEDIATELY for instant UI response
    _isTracking = false;
    _status = 'Location sharing stopped';
    _error = null;
    
    // Update sharing status immediately
    final userId = await _getCurrentUserId();
    if (userId != null) {
      _userSharingStatus[userId] = false;
    }
    
    if (_mounted) notifyListeners();

    // Update Firebase status immediately for INSTANT real-time status
    if (userId != null) {
      _log('Updating Firebase status to false for: ${userId.substring(0, 8)}');
      _updateLocationSharingStatus(userId, false);
    }

    // Do cleanup in background
    _stopTrackingInBackground();
  }

  // Background method to handle cleanup
  Future<void> _stopTrackingInBackground() async {
    _log('Stopping background tracking');
    try {
      await _locationSubscription?.cancel();
      await _locationService.stopTracking();
      _locationSubscription = null;
      
      // Stop heartbeat mechanism
      _stopHeartbeat();
      
      // Clear proximity tracking when stopping location sharing
      ProximityService.clearProximityTracking();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_enabled', false);
      
      // Clear current user's location data but keep friends' locations
      _currentLocation = null;
      _nearbyUsers.clear();
      
      // Remove current user from both databases
      final currentUserId = await _getCurrentUserId();
      if (currentUserId != null) {
        _userLocations.remove(currentUserId);
        _userSharingStatus[currentUserId] = false; // Update sharing status
        
        // Clear from Realtime Database
        await _realtimeDb.ref('locations/$currentUserId').remove();
        _log('Removed user from Realtime DB');
      }
      
      _currentAddress = null;
      _city = null;
      _country = null;
      _postalCode = null;
      
      if (_mounted) notifyListeners();
    } catch (e) {
      _log('Error stopping tracking: $e');
    }
  }

  // Get address from coordinates
  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _currentAddress = '${place.street}, ${place.subLocality}';
        _city = place.locality;
        _country = place.country;
        _postalCode = place.postalCode;
        _status = 'Address updated';
      }
    } catch (e) {
      _error = 'Failed to get address: ${e.toString()}';
      _status = 'Error getting address';
    }
  }

  // Public method to get address for coordinates
  Future<Map<String, String?>> getAddressForCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return {
          'address': '${place.street}, ${place.subLocality}',
          'city': place.locality,
          'postalCode': place.postalCode,
        };
      }
      return {
        'address': 'Unknown location',
        'city': null,
        'postalCode': null,
      };
    } catch (e) {
      return {
        'address': 'Address unavailable',
        'city': null,
        'postalCode': null,
      };
    }
  }

  // Update location sharing status in BOTH databases for INSTANT real-time status
  Future<void> _updateLocationSharingStatus(String userId, bool isSharing) async {
    _log('Updating Firebase status: $isSharing for ${userId.substring(0, 8)}');
    try {
      // Update Realtime Database FIRST for INSTANT synchronization (10-50ms)
      await _realtimeDb.ref('users/$userId/locationSharingEnabled').set(isSharing);
      _log('Successfully updated Realtime DB status');
      
      // Then update Firestore for data persistence and queries
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': isSharing,
        'locationSharingUpdatedAt': FieldValue.serverTimestamp(),
        'lastOnline': FieldValue.serverTimestamp(),
        if (!isSharing) 'location': null, // Clear location when sharing is disabled
      });
      _log('Successfully updated Firestore status');
      
      // If stopping sharing, also clear from Realtime DB locations
      if (!isSharing) {
        await _realtimeDb.ref('locations/$userId').remove();
        _log('Cleared location from Realtime DB');
      }
    } catch (e) {
      _log('Error updating location sharing status: $e');
    }
  }

  // Clean up user data when app is being uninstalled or permanently closed
  Future<void> cleanupUserData() async {
    _log('=== CLEANUP USER DATA CALLED ===');
    try {
      final userId = await _getCurrentUserId();
      if (userId != null) {
        _log('Cleaning up data for user: ${userId.substring(0, 8)}');
        
        // Mark user as offline and clear all location data
        await _markUserAsOfflineForUninstall(userId);
        
        // Clear local preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        _log('Cleared local preferences');
      }
    } catch (e) {
      _log('Error during cleanup: $e');
    }
  }

  // Mark user as offline specifically for app uninstall/removal
  Future<void> _markUserAsOfflineForUninstall(String userId) async {
    _log('Marking user as offline for app uninstall: ${userId.substring(0, 8)}');
    try {
      // Remove from Realtime Database locations (makes user appear offline immediately)
      await _realtimeDb.ref('locations/$userId').remove();
      _log('Removed user from Realtime DB locations');
      
      // Update Realtime Database status to indicate app was uninstalled
      await _realtimeDb.ref('users/$userId').update({
        'locationSharingEnabled': false,
        'appUninstalled': true,
        'lastSeen': ServerValue.timestamp,
        'appLastActive': ServerValue.timestamp,
      });
      _log('Updated Realtime DB user status for uninstall');
      
      // Update Firestore to mark as offline due to uninstall
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': false,
        'appUninstalled': true,
        'location': null, // Clear location data
        'lastSeen': FieldValue.serverTimestamp(),
        'appLastActive': FieldValue.serverTimestamp(),
        'lastOnline': FieldValue.serverTimestamp(),
      });
      _log('Updated Firestore user status for uninstall');
      
    } catch (e) {
      _log('Error marking user as offline for uninstall: $e');
    }
  }

  @override
  void dispose() {
    _log('=== DISPOSE CALLED ===');
    _mounted = false; // Mark as unmounted first
    
    // Stop heartbeat mechanism
    _stopHeartbeat();
    
    // Clean up user data when app is being disposed
    cleanupUserData();
    
    // Dispose performance optimizer
    _performanceOptimizer.dispose();
    
    _notificationDebounceTimer?.cancel(); // Cancel debounce timer
    _locationSubscription?.cancel();
    _friendsLocationSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _realtimeStatusSubscription?.cancel();
    _realtimeLocationSubscription?.cancel();
    _locationServiceSubscription?.cancel();
    super.dispose();
  }
}