import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _friendsLocationSubscription;
  LatLng? _currentLocation;
  List<String> _nearbyUsers = [];
  bool _isTracking = false;
  bool _isInitialized = false;
  String? _error;
  String _status = 'Initializing...';
  String? _currentAddress;
  String? _city;
  String? _country;
  String? _postalCode;
  Map<String, LatLng> _userLocations = {}; // userId -> LatLng
  VoidCallback? onLocationServiceDisabled;

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

  // Initialize provider with saved state
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLocationSharingEnabled = prefs.getBool('location_sharing_enabled') ?? false;
      final savedUserId = prefs.getString('user_id');
      
      // Set the tracking state immediately to prevent flickering
      _isTracking = isLocationSharingEnabled;
      _isInitialized = true;
      notifyListeners();
      
      // If location sharing was enabled and we have a user ID, restart tracking
      if (isLocationSharingEnabled && savedUserId != null) {
        // Update Firebase status immediately
        _updateLocationSharingStatus(savedUserId, true);
        
        // Start tracking in the background
        Future.delayed(const Duration(milliseconds: 100), () {
          startTracking(savedUserId).catchError((e) {
            debugPrint('Error restarting location tracking: $e');
            // If restart fails, set tracking to false and update Firebase
            _isTracking = false;
            _updateLocationSharingStatus(savedUserId, false);
            notifyListeners();
          });
        });
      } else if (savedUserId != null) {
        // Ensure Firebase status is set to false if not tracking
        _updateLocationSharingStatus(savedUserId, false);
      }
      
    } catch (e) {
      debugPrint('Error initializing LocationProvider: $e');
      _isInitialized = true;
      _isTracking = false;
      notifyListeners();
    }
  }

  // Start tracking location
  Future<void> startTracking(String userId) async {
    if (_isTracking) return;

    // Set tracking to true IMMEDIATELY for instant UI response
    _isTracking = true;
    _error = null;
    _status = 'Starting location sharing...';
    notifyListeners();

    // Save preference immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_enabled', true);
      await prefs.setString('user_id', userId);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }

    // Update Firebase status immediately for real-time status
    _updateLocationSharingStatus(userId, true);

    // Do the heavy work in the background
    _startTrackingInBackground(userId);
  }

  // Background method to handle the actual location tracking setup
  Future<void> _startTrackingInBackground(String userId) async {
    try {
      _status = 'Checking location services...';
      notifyListeners();

      // Check if location services are enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Location services are disabled';
        _status = 'Location services are disabled';
        _isTracking = false; // Revert if services are disabled
        notifyListeners();
        if (onLocationServiceDisabled != null) onLocationServiceDisabled!();
        return;
      }

      _status = 'Getting location permissions...';
      notifyListeners();

      LatLng? lastLocation;
      DateTime lastUpdate = DateTime.now();
      const double minDistance = 20.0;
      const Duration minInterval = Duration(seconds: 5);

      _status = 'Starting location tracking...';
      notifyListeners();

      _locationSubscription = await _locationService.startTracking(
        userId,
        (LatLng location) async {
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
            await _getAddressFromCoordinates(location.latitude, location.longitude);
            await FirebaseFirestore.instance.collection('users').doc(userId).update({
              'location': {'lat': location.latitude, 'lng': location.longitude, 'updatedAt': FieldValue.serverTimestamp()},
              'lastOnline': FieldValue.serverTimestamp(),
            });
            notifyListeners();
          }
        },
      );

      _status = 'Location sharing active';
      notifyListeners();

      // Listen for nearby users and their locations
      _locationService.getNearbyUsers(userId, 5.0).listen((users) async {
        bool changed = false;
        // Remove users who are no longer nearby
        final toRemove = _userLocations.keys.where((id) => id != userId && !users.contains(id)).toList();
        for (final id in toRemove) {
          _userLocations.remove(id);
          changed = true;
        }
        // Add/update locations for new/nearby users
        for (final id in users) {
          if (id == userId) continue;
          final loc = await _locationService.getLastKnownLocation(id);
          if (loc != null && _userLocations[id] != loc) {
            _userLocations[id] = loc;
            changed = true;
          }
        }
        if (_nearbyUsers.length != users.length || !_nearbyUsers.every((u) => users.contains(u))) {
          _nearbyUsers = users;
          changed = true;
        }
        if (changed) notifyListeners();
      });

      // Listen to friends' locations
      _listenToFriendsLocations(userId);
    } catch (e) {
      _isTracking = false;
      _error = e.toString();
      _status = 'Error: ${e.toString()}';
      notifyListeners();
      debugPrint('Error in background tracking: $e');
    }
  }

  void _listenToFriendsLocations(String userId) {
    _friendsLocationSubscription?.cancel();
    _friendsLocationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((userDoc) {
      final data = userDoc.data();
      final List friends = data?['friends'] ?? [];
      if (friends.isEmpty) {
        _userLocations.clear();
        notifyListeners();
        return;
      }
      FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: friends)
          .snapshots()
          .listen((query) {
        final updated = <String, LatLng>{};
        for (final doc in query.docs) {
          final loc = doc['location'];
          if (loc != null && loc['lat'] != null && loc['lng'] != null) {
            updated[doc.id] = LatLng(loc['lat'], loc['lng']);
          }
        }
        _userLocations = updated;
        notifyListeners();
      });
    });
  }

  // Stop tracking location
  Future<void> stopTracking() async {
    // Set tracking to false IMMEDIATELY for instant UI response
    _isTracking = false;
    _status = 'Location sharing stopped';
    _error = null;
    notifyListeners();

    // Update Firebase status immediately for real-time status
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      _updateLocationSharingStatus(userId, false);
    }

    // Do cleanup in background
    _stopTrackingInBackground();
  }

  // Background method to handle cleanup
  Future<void> _stopTrackingInBackground() async {
    try {
      await _locationSubscription?.cancel();
      await _locationService.stopTracking();
      _locationSubscription = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_enabled', false);
      await prefs.remove('user_id');
      
      // Clear location data
      _currentLocation = null;
      _nearbyUsers.clear();
      _userLocations.clear();
      _currentAddress = null;
      _city = null;
      _country = null;
      _postalCode = null;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping tracking: $e');
    }
  }

  // Get last known location
  Future<LatLng?> getLastKnownLocation(String userId) async {
    return await _locationService.getLastKnownLocation(userId);
  }

  // Get user location by ID
  Future<LatLng?> getUserLocation(String userId) async {
    return await _locationService.getLastKnownLocation(userId);
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

  // Get address for specific coordinates
  Future<Map<String, String?>> getAddressForCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return {
          'address': '${place.street}, ${place.subLocality}',
          'city': place.locality,
          'country': place.country,
          'postalCode': place.postalCode,
        };
      }
      return {};
    } catch (e) {
      _error = 'Failed to get address: ${e.toString()}';
      return {};
    }
  }

  // Update location sharing status in Firebase for real-time status
  Future<void> _updateLocationSharingStatus(String userId, bool isSharing) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': isSharing,
        'locationSharingUpdatedAt': FieldValue.serverTimestamp(),
        'lastOnline': FieldValue.serverTimestamp(),
        if (!isSharing) 'location': null, // Clear location when sharing is disabled
      });
      debugPrint('Updated location sharing status: $isSharing for user: $userId');
    } catch (e) {
      debugPrint('Error updating location sharing status: $e');
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _friendsLocationSubscription?.cancel();
    super.dispose();
  }
}
