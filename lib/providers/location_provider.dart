import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../services/location_service.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  LatLng? _currentLocation;
  List<String> _nearbyUsers = [];
  bool _isTracking = false;
  String? _error;
  String _status = 'Initializing...';
  String? _currentAddress;
  String? _city;
  String? _country;
  String? _postalCode;
  Map<String, LatLng> _userLocations = {}; // userId -> LatLng

  LatLng? get currentLocation => _currentLocation;
  List<String> get nearbyUsers => _nearbyUsers;
  bool get isTracking => _isTracking;
  String? get error => _error;
  String get status => _status;
  String? get currentAddress => _currentAddress;
  String? get city => _city;
  String? get country => _country;
  String? get postalCode => _postalCode;
  Map<String, LatLng> get userLocations => _userLocations;

  // Start tracking location
  Future<void> startTracking(String userId) async {
    if (_isTracking) return;

    try {
      _error = null;
      _status = 'Getting location...';
      notifyListeners();

      LatLng? lastLocation;
      DateTime lastUpdate = DateTime.now();
      const double minDistance = 20.0;
      const Duration minInterval = Duration(seconds: 5);

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
            _status = 'Location updated';
            await _getAddressFromCoordinates(location.latitude, location.longitude);
            notifyListeners();
          }
        },
      );
      _isTracking = true;

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
    } catch (e) {
      _isTracking = false;
      _error = e.toString();
      _status = 'Error: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // Stop tracking location
  Future<void> stopTracking() async {
    await _locationSubscription?.cancel();
    await _locationService.stopTracking();
    _locationSubscription = null;
    _isTracking = false;
    notifyListeners();
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

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
