import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Enhanced LocationProvider with REAL-TIME push notifications
/// This version uses Firebase Realtime Database for instant synchronization
class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  
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
  
  // Location service state management
  bool _locationServiceEnabled = true;
  bool _wasTrackingBeforeServiceDisabled = false;
  String? _userIdForResumption;
  
  // Debounce timer to prevent excessive notifications
  Timer? _notificationDebounceTimer;

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
    return _userSharingStatus[userId] == true;
  }

  // Get current location for map display (without starting tracking)
  Future<void> getCurrentLocationForMap() async {
    if (_currentLocation != null) {
      _log('Current location already available: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      return;
    }
    
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
      _log('SUCCESS: Current location set to ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      
      if (_mounted) notifyListeners();
    } catch (e) {
      _log('ERROR getting current location: $e');
      _error = 'Failed to get location: ${e.toString()}';
      _status = 'Location error';
      if (_mounted) notifyListeners();
    }
  }

  // Set demo location for testing
  void setDemoLocation() {
    _log('=== SETTING DEMO LOCATION ===');
    // Use a demo location (San Francisco)
    _currentLocation = LatLng(37.7749, -122.4194);
    _status = 'Demo location set';
    _error = null;
    _log('Demo location set: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
    if (_mounted) notifyListeners();
  }

  // Get current user ID from SharedPreferences
  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  void _log(String message) {
    debugPrint('REALTIME_PROVIDER: $message');
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
        'lastSeen': ServerValue.timestamp,
      });
      _log('Updated Realtime DB user status to online');
      
      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': true,
        'locationServiceDisabled': false,
        'lastOnline': FieldValue.serverTimestamp(),
      });
      _log('Updated Firestore user status to online');
      
      // Update local state
      _userSharingStatus[userId] = true;
      
    } catch (e) {
      _log('Error marking user as online: $e');
    }
  }

  // Debounced notification to prevent excessive rebuilds
  void _notifyListenersDebounced() {
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = Timer(const Duration(milliseconds: 100), () {
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
        _updateLocationSharingStatus(savedUserId, true);
        
        Future.delayed(const Duration(milliseconds: 100), () {
          startTracking(savedUserId).catchError((e) {
            _log('Error restarting location tracking: $e');
            _isTracking = false;
            _updateLocationSharingStatus(savedUserId, false);
            if (_mounted) notifyListeners();
          });
        });
      } else if (savedUserId != null) {
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
          _log('INSTANT SYNC: Location sharing status changed to $realtimeIsTracking');
          _isTracking = realtimeIsTracking;
          
          // Update local preferences to match realtime DB
          SharedPreferences.getInstance().then((prefs) {
            prefs.setBool('location_sharing_enabled', realtimeIsTracking);
          });
          
          // Update status message
          _status = realtimeIsTracking 
              ? 'Location sharing enabled from another device'
              : 'Location sharing disabled from another device';
          
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
          
          for (final entry in usersData.entries) {
            final userId = entry.key as String;
            final userData = entry.value as Map<dynamic, dynamic>?;
            
            if (userData != null && userData.containsKey('locationSharingEnabled')) {
              final isSharing = userData['locationSharingEnabled'] == true;
              
              // Only update if status actually changed
              if (updatedSharingStatus[userId] != isSharing) {
                updatedSharingStatus[userId] = isSharing;
                hasChanges = true;
                _log('User ${userId.substring(0, 8)} sharing status changed to: $isSharing');
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

  // Start tracking location
  Future<void> startTracking(String userId) async {
    _log('=== START TRACKING CALLED ===');
    
    if (_isTracking) {
      _log('Already tracking, returning');
      return;
    }

    // Store user ID for potential resumption
    _userIdForResumption = userId;

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
      DateTime lastUpdate = DateTime.now();
      const double minDistance = 20.0;
      const Duration minInterval = Duration(seconds: 5);

      _status = 'Starting location tracking...';
      if (_mounted) notifyListeners();

      _locationSubscription = await _locationService.startTracking(
        userId,
        (LatLng location) async {
          _log('Location update received: ${location.latitude}, ${location.longitude}');
          
          // Check if location services are still enabled
          if (!_locationServiceEnabled) {
            _log('Location service disabled, cannot update location');
            return;
          }
          
          final now = DateTime.now();
          bool shouldUpdate = false;
          if (lastLocation == null) {
            shouldUpdate = true;
          } else {
            final distance = const Distance().as(LengthUnit.Meter, lastLocation!, location);
            final timeDiff = now.difference(lastUpdate);
            shouldUpdate = distance > minDistance || timeDiff > minInterval;
          }
          if (shouldUpdate) {
            lastLocation = location;
            lastUpdate = now;
            _currentLocation = location;
            _userLocations[userId] = location;
            _status = 'Location sharing active';
            _log('Updated current location');
            
            // Update BOTH databases for instant sync and persistence
            await _updateLocationInBothDatabases(userId, location);
            await _getAddressFromCoordinates(location.latitude, location.longitude);
            
            if (_mounted) notifyListeners();
          }
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

  @override
  void dispose() {
    _log('=== DISPOSE CALLED ===');
    _mounted = false; // Mark as unmounted first
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