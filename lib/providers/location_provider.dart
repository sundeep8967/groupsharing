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

  LatLng? get currentLocation => _currentLocation;
  List<String> get nearbyUsers => _nearbyUsers;
  bool get isTracking => _isTracking;
  String? get error => _error;
  String get status => _status;
  String? get currentAddress => _currentAddress;
  String? get city => _city;
  String? get country => _country;
  String? get postalCode => _postalCode;

  // Start tracking location
  Future<void> startTracking(String userId) async {
    if (_isTracking) return;

    try {
      _error = null;
      _status = 'Getting location...';
      notifyListeners();

      _locationSubscription = await _locationService.startTracking(
        userId,
        (LatLng location) async {
          _currentLocation = location;
          _status = 'Location updated';
          // Get address when location updates
          await _getAddressFromCoordinates(location.latitude, location.longitude);
          notifyListeners();
        },
      );
      
      _isTracking = true;
      
      // Listen for nearby users
      _locationService.getNearbyUsers(userId, 5.0).listen((users) {
        _nearbyUsers = users;
        notifyListeners();
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
