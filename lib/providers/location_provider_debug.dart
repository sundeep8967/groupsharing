import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced LocationProvider with extensive debugging
/// Replace your existing LocationProvider with this one to see detailed logs
class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _friendsLocationSubscription;
  StreamSubscription<DocumentSnapshot>? _userStatusSubscription;
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
  VoidCallback? onLocationServiceDisabled;

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
  bool get mounted => _mounted;

  void _log(String message) {
    print('LOCATION_PROVIDER_DEBUG: $message');
    debugPrint('LOCATION_PROVIDER_DEBUG: $message');
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
      
      // Start listening to user status changes for real-time sync
      if (savedUserId != null) {
        _log('Starting listeners for user: ${savedUserId.substring(0, 8)}');
        _startListeningToUserStatus(savedUserId);
        // Also start listening to friends' locations immediately
        _listenToFriendsLocations(savedUserId);
      } else {
        _log('No saved user ID found');
      }
      
      // If location sharing was enabled and we have a user ID, restart tracking
      if (isLocationSharingEnabled && savedUserId != null) {
        _log('Auto-restarting location tracking');
        // Update Firebase status immediately
        _updateLocationSharingStatus(savedUserId, true);
        
        // Start tracking in the background
        Future.delayed(const Duration(milliseconds: 100), () {
          startTracking(savedUserId).catchError((e) {
            _log('Error restarting location tracking: $e');
            // If restart fails, set tracking to false and update Firebase
            _isTracking = false;
            _updateLocationSharingStatus(savedUserId, false);
            if (_mounted) notifyListeners();
          });
        });
      } else if (savedUserId != null) {
        _log('Not auto-starting tracking, updating Firebase status to false');
        // Ensure Firebase status is set to false if not tracking
        _updateLocationSharingStatus(savedUserId, false);
      }
      
    } catch (e) {
      _log('Error initializing LocationProvider: $e');
      _isInitialized = true;
      _isTracking = false;
      if (_mounted) notifyListeners();
    }
  }

  // Listen to user's own status changes for real-time sync across devices
  void _startListeningToUserStatus(String userId) {
    _log('Setting up user status listener for: ${userId.substring(0, 8)}');
    _userStatusSubscription?.cancel();
    _userStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      _log('User status snapshot received, exists: ${snapshot.exists}');
      if (snapshot.exists) {
        final data = snapshot.data();
        final firestoreIsTracking = data?['locationSharingEnabled'] as bool? ?? false;
        
        _log('Firestore tracking status: $firestoreIsTracking, local: $_isTracking');
        
        // Only update if the Firestore state is different from local state
        if (firestoreIsTracking != _isTracking) {
          _log('Real-time sync: Location sharing status changed to $firestoreIsTracking');
          _isTracking = firestoreIsTracking;
          
          // Update local preferences to match Firestore
          SharedPreferences.getInstance().then((prefs) {
            prefs.setBool('location_sharing_enabled', firestoreIsTracking);
          });
          
          // Update status message
          _status = firestoreIsTracking 
              ? 'Location sharing enabled from another device'
              : 'Location sharing disabled from another device';
          
          if (_mounted) notifyListeners();
          
          // If tracking was enabled from another device, start local tracking
          if (firestoreIsTracking && _locationSubscription == null) {
            _log('Starting tracking from remote change');
            _startTrackingInBackground(userId);
          }
          // If tracking was disabled from another device, stop local tracking
          else if (!firestoreIsTracking && _locationSubscription != null) {
            _log('Stopping tracking from remote change');
            _stopTrackingInBackground();
          }
        }
      }
    }, onError: (error) {
      _log('Error listening to user status changes: $error');
    });
  }

  void _listenToFriendsLocations(String userId) {
    _log('=== SETTING UP FRIENDS LOCATION LISTENER ===');
    _log('User ID: ${userId.substring(0, 8)}');
    _friendsLocationSubscription?.cancel();
    
    // Listen to all users who are sharing their location
    _friendsLocationSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('locationSharingEnabled', isEqualTo: true)
        .snapshots()
        .listen((query) {
      _log('FRIENDS SNAPSHOT RECEIVED: ${query.docs.length} users sharing location');
      final updated = <String, LatLng>{};
      
      for (final doc in query.docs) {
        // Skip current user
        if (doc.id == userId) {
          _log('Skipping current user: ${doc.id.substring(0, 8)}');
          continue;
        }
        
        final data = doc.data();
        _log('Processing user ${doc.id.substring(0, 8)}');
        
        // Check if user has location data
        if (data.containsKey('location') && data['location'] != null) {
          final locationData = data['location'] as Map<String, dynamic>;
          if (locationData.containsKey('lat') && locationData.containsKey('lng')) {
            updated[doc.id] = LatLng(locationData['lat'], locationData['lng']);
            _log('Added location for user ${doc.id.substring(0, 8)}: ${locationData['lat']}, ${locationData['lng']}');
          } else {
            _log('User ${doc.id.substring(0, 8)} location missing lat/lng');
          }
        } else {
          _log('User ${doc.id.substring(0, 8)} has no location data');
        }
      }
      
      // Update user locations and notify listeners - but preserve current user's location
      final currentUserLocation = _userLocations[userId];
      _userLocations = updated;
      
      // Preserve current user's location if it exists
      if (currentUserLocation != null) {
        _userLocations[userId] = currentUserLocation;
        _log('Preserved current user location');
      }
      
      _log('FINAL USER LOCATIONS: ${_userLocations.length} users total');
      for (final entry in _userLocations.entries) {
        _log('  ${entry.key.substring(0, 8)}: ${entry.value.latitude.toStringAsFixed(4)}, ${entry.value.longitude.toStringAsFixed(4)}');
      }
      
      if (_mounted) {
        _log('Notifying listeners of location update');
        notifyListeners();
      } else {
        _log('NOT notifying listeners - provider not mounted');
      }
    }, onError: (error) {
      _log('ERROR listening to friends locations: $error');
    });
  }

  // Start tracking location
  Future<void> startTracking(String userId) async {
    _log('=== START TRACKING CALLED ===');
    _log('User ID: ${userId.substring(0, 8)}');
    _log('Already tracking: $_isTracking');
    
    if (_isTracking) {
      _log('Already tracking, returning');
      return;
    }

    // Set tracking to true IMMEDIATELY for instant UI response
    _isTracking = true;
    _error = null;
    _status = 'Starting location sharing...';
    _log('Set tracking to true, notifying listeners');
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

    // Update Firebase status immediately for real-time status
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
        _isTracking = false; // Revert if services are disabled
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
            _log('Updated current location and Firebase');
            await _getAddressFromCoordinates(location.latitude, location.longitude);
            await FirebaseFirestore.instance.collection('users').doc(userId).update({
              'location': {'lat': location.latitude, 'lng': location.longitude, 'updatedAt': FieldValue.serverTimestamp()},
              'lastOnline': FieldValue.serverTimestamp(),
            });
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
      } else {
        _log('Friends listener already active');
      }
    } catch (e) {
      _log('Error in background tracking: $e');
      _isTracking = false;
      _error = e.toString();
      _status = 'Error: ${e.toString()}';
      if (_mounted) notifyListeners();
    }
  }

  // Stop tracking location
  Future<void> stopTracking() async {
    _log('=== STOP TRACKING CALLED ===');
    // Set tracking to false IMMEDIATELY for instant UI response
    _isTracking = false;
    _status = 'Location sharing stopped';
    _error = null;
    if (_mounted) notifyListeners();

    // Update Firebase status immediately for real-time status
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
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
      
      // Remove only current user from userLocations, keep friends
      final currentUserId = prefs.getString('user_id');
      if (currentUserId != null) {
        _userLocations.remove(currentUserId);
        _log('Removed current user from locations, keeping ${_userLocations.length} friends');
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

  // Update location sharing status in Firebase for real-time status
  Future<void> _updateLocationSharingStatus(String userId, bool isSharing) async {
    _log('Updating Firebase status: $isSharing for ${userId.substring(0, 8)}');
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': isSharing,
        'locationSharingUpdatedAt': FieldValue.serverTimestamp(),
        'lastOnline': FieldValue.serverTimestamp(),
        if (!isSharing) 'location': null, // Clear location when sharing is disabled
      });
      _log('Successfully updated Firebase status');
    } catch (e) {
      _log('Error updating location sharing status: $e');
    }
  }

  @override
  void dispose() {
    _log('=== DISPOSE CALLED ===');
    _mounted = false; // Mark as unmounted first
    _locationSubscription?.cancel();
    _friendsLocationSubscription?.cancel();
    _userStatusSubscription?.cancel();
    super.dispose();
  }
}