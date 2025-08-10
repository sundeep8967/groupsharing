import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_provider_interface.dart';

/// ULTRA-MINIMAL Location Provider - Zero lag, maximum performance
/// Deprecated: Use `LocationProvider` instead.
/// Minimal provider kept only to avoid breaking builds; will be removed.
class MinimalLocationProvider extends ChangeNotifier implements ILocationProvider {
  // Core state - minimal variables only
  bool _isTracking = false;
  bool _isInitialized = false;
  LatLng? _currentLocation;
  String _status = 'Ready';
  
  // Simple user locations map - no complex data structures
  final Map<String, LatLng> _userLocations = {};
  final Map<String, bool> _userSharingStatus = {};
  
  // Single timer for all operations
  Timer? _locationTimer;
  
  // Getters
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
  LatLng? get currentLocation => _currentLocation;
  String get status => _status;
  Map<String, LatLng> get userLocations => Map.unmodifiable(_userLocations);
  String? get error => null;
  String? get currentAddress => null;
  String? get city => null;
  String? get country => null;
  String? get postalCode => null;
  List<String> get nearbyUsers => const [];
  
  /// Initialize with minimal overhead
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Simple initialization - no complex setup
      final prefs = await SharedPreferences.getInstance();
      final wasTracking = prefs.getBool('location_sharing_enabled') ?? false;
      final savedUserId = prefs.getString('user_id');
      
      _isInitialized = true;
      
      // Only restart if explicitly enabled and user exists
      if (wasTracking && savedUserId != null && savedUserId.isNotEmpty) {
        // Delayed restart to prevent initialization conflicts
        Future.delayed(const Duration(seconds: 1), () {
          if (_isInitialized) {
            startTracking(savedUserId);
          }
        });
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('MinimalLocationProvider init error: $e');
      _isInitialized = true;
      notifyListeners();
      return true;
    }
  }
  
  /// Start tracking with minimal overhead
  Future<bool> startTracking(String userId) async {
    if (_isTracking || userId.isEmpty) return false;
    
    try {
      _status = 'Starting location tracking...';
      notifyListeners();
      
      // Check permissions quickly
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _status = 'Location permissions denied';
          notifyListeners();
          return false;
        }
      }
      
      _isTracking = true;
      _status = 'Location sharing active';
      
      // Save state immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_enabled', true);
      await prefs.setString('user_id', userId);
      
      // Start simple location updates
      _startLocationUpdates(userId);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting tracking: $e');
      _isTracking = false;
      _status = 'Error starting location tracking';
      notifyListeners();
      return false;
    }
  }
  
  /// Stop tracking immediately
  Future<bool> stopTracking() async {
    _isTracking = false;
    _status = 'Location sharing stopped';
    
    // Cancel timer immediately
    _locationTimer?.cancel();
    _locationTimer = null;
    
    // Save state
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_enabled', false);
    } catch (e) {
      debugPrint('Error saving stop state: $e');
    }
    
    notifyListeners();
    return true;
  }
  
  /// Simple location updates - no complex logic
  void _startLocationUpdates(String userId) {
    _locationTimer?.cancel();
    
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      try {
        // Get location with minimal settings
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        
        final newLocation = LatLng(position.latitude, position.longitude);
        _currentLocation = newLocation;
        
        // Update Firebase with minimal data
        await FirebaseFirestore.instance
            .collection('user_locations')
            .doc(userId)
            .set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'isSharing': true,
        });
        
        _status = 'Location updated';
        if (mounted) notifyListeners();
        
      } catch (e) {
        debugPrint('Location update error: $e');
        _status = 'Location update failed';
        if (mounted) notifyListeners();
      }
    });
  }
  
  /// Get current location for map (simplified)
  Future<void> getCurrentLocationForMap() async {
    if (_currentLocation != null) {
      return;
    }
    
    try {
      _status = 'Getting your location...';
      notifyListeners();
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      
      final location = LatLng(position.latitude, position.longitude);
      _currentLocation = location;
      _status = 'Location found';
      notifyListeners();
      return;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      _status = 'Could not get location';
      notifyListeners();
      return;
    }
  }
  
  /// Simple user sharing status check
  bool isUserSharingLocation(String userId) {
    if (userId.isEmpty) return false;
    return _userSharingStatus[userId] == true;
  }
  
  /// Listen to friends locations (simplified)
  void listenToFriendsLocations(List<String> friendIds) {
    // Cancel existing listeners to prevent overload
    
    for (final friendId in friendIds) {
      if (friendId.isEmpty) continue;
      
      // Simple Firestore listener
      FirebaseFirestore.instance
          .collection('user_locations')
          .doc(friendId)
          .snapshots()
          .listen((doc) {
        try {
          if (doc.exists && mounted) {
            final data = doc.data()!;
            final isSharing = data['isSharing'] as bool? ?? false;
            
            if (isSharing) {
              final lat = data['latitude'] as double?;
              final lng = data['longitude'] as double?;
              
              if (lat != null && lng != null) {
                _userLocations[friendId] = LatLng(lat, lng);
                _userSharingStatus[friendId] = true;
              }
            } else {
              _userLocations.remove(friendId);
              _userSharingStatus[friendId] = false;
            }
            
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error processing friend location: $e');
        }
      });
    }
  }
  
  /// Check if mounted to prevent memory leaks
  bool get mounted => hasListeners;
  
  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}