import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';
import '../models/smart_place.dart';
import '../services/notification_service.dart';

/// Life360-style smart places service with automatic detection and geofencing
class PlacesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  
  // State
  static String? _currentUserId;
  static final Map<String, SmartPlace> _userPlaces = {};
  static final Map<String, DateTime> _lastNotificationTime = {};
  static Timer? _analysisTimer;
  static StreamSubscription<Position>? _locationSubscription;
  
  // Place detection parameters
  static const double _homeDetectionRadius = 100.0; // meters
  static const Duration _placeDetectionTime = Duration(minutes: 10);
  static const int _minimumVisits = 3;
  static const Duration _notificationCooldown = Duration(minutes: 5);
  
  // Location history for analysis
  static final List<Position> _locationHistory = [];
  static const int _historySize = 100;
  
  // Callbacks
  static Function(SmartPlace place, bool arrived)? onPlaceEvent;
  static Function(SmartPlace place)? onPlaceDetected;

  /// Initialize places service
  static Future<bool> initialize(String userId) async {
    try {
      _log('Initializing places service for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      // Load existing places
      await _loadUserPlaces();
      
      // Start location monitoring for place detection
      await _startLocationMonitoring();
      
      // Start periodic analysis for automatic place detection
      _startPeriodicAnalysis();
      
      _log('Places service initialized successfully');
      return true;
    } catch (e) {
      _log('Error initializing places service: $e');
      return false;
    }
  }

  /// Load user's existing places from Firestore
  static Future<void> _loadUserPlaces() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('places')
          .get();

      _userPlaces.clear();
      for (final doc in snapshot.docs) {
        final place = SmartPlace.fromMap(doc.data());
        _userPlaces[place.id] = place;
      }

      _log('Loaded ${_userPlaces.length} places for user');
    } catch (e) {
      _log('Error loading user places: $e');
    }
  }

  /// Start monitoring location for place detection and geofencing
  static Future<void> _startLocationMonitoring() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _processLocationUpdate(position);
    });
  }

  /// Process location update for place detection and geofencing
  static void _processLocationUpdate(Position position) {
    // Add to location history
    _locationHistory.add(position);
    if (_locationHistory.length > _historySize) {
      _locationHistory.removeAt(0);
    }

    // Check geofences for existing places
    _checkGeofences(position);

    // Update user's current location in places context
    _updateCurrentLocation(position);
  }

  /// Check if user entered or left any geofences
  static void _checkGeofences(Position position) {
    for (final place in _userPlaces.values) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        place.latitude,
        place.longitude,
      );

      final isInside = distance <= place.radius;
      final wasInside = place.isUserInside;

      if (isInside && !wasInside) {
        // User arrived at place
        _handlePlaceArrival(place, position);
      } else if (!isInside && wasInside) {
        // User left place
        _handlePlaceDeparture(place, position);
      }
    }
  }

  /// Handle user arrival at a place
  static Future<void> _handlePlaceArrival(SmartPlace place, Position position) async {
    _log('User arrived at ${place.name}');

    // Update place state
    final updatedPlace = place.copyWith(
      isUserInside: true,
      lastVisit: DateTime.now(),
      visitCount: place.visitCount + 1,
    );
    
    _userPlaces[place.id] = updatedPlace;
    await _savePlaceToFirestore(updatedPlace);

    // Send notification if not in cooldown
    final lastNotification = _lastNotificationTime[place.id];
    final now = DateTime.now();
    
    if (lastNotification == null || 
        now.difference(lastNotification) > _notificationCooldown) {
      
      await _sendPlaceNotification(place, true);
      _lastNotificationTime[place.id] = now;
    }

    // Update real-time database
    await _updateRealtimeLocation(place, true);

    // Notify callback
    if (onPlaceEvent != null) {
      onPlaceEvent!(updatedPlace, true);
    }

    // Apply place-based automation
    await _applyPlaceAutomation(updatedPlace, true);
  }

  /// Handle user departure from a place
  static Future<void> _handlePlaceDeparture(SmartPlace place, Position position) async {
    _log('User left ${place.name}');

    // Update place state
    final updatedPlace = place.copyWith(
      isUserInside: false,
      lastDeparture: DateTime.now(),
    );
    
    _userPlaces[place.id] = updatedPlace;
    await _savePlaceToFirestore(updatedPlace);

    // Send notification if not in cooldown
    final lastNotification = _lastNotificationTime[place.id];
    final now = DateTime.now();
    
    if (lastNotification == null || 
        now.difference(lastNotification) > _notificationCooldown) {
      
      await _sendPlaceNotification(place, false);
      _lastNotificationTime[place.id] = now;
    }

    // Update real-time database
    await _updateRealtimeLocation(place, false);

    // Notify callback
    if (onPlaceEvent != null) {
      onPlaceEvent!(updatedPlace, false);
    }

    // Apply place-based automation
    await _applyPlaceAutomation(updatedPlace, false);
  }

  /// Send place arrival/departure notification
  static Future<void> _sendPlaceNotification(SmartPlace place, bool arrived) async {
    if (!place.notificationsEnabled) return;

    final title = arrived ? 'Arrived at ${place.name}' : 'Left ${place.name}';
    final body = arrived 
        ? 'You have arrived at ${place.name}'
        : 'You have left ${place.name}';

    await NotificationService.showNotification(
      title: title,
      body: body,
      payload: 'place_${place.id}_${arrived ? "arrived" : "left"}',
    );
  }

  /// Update real-time database with current place
  static Future<void> _updateRealtimeLocation(SmartPlace place, bool arrived) async {
    if (_currentUserId == null) return;

    try {
      await _realtimeDb.ref('users/$_currentUserId').update({
        'currentPlace': arrived ? {
          'id': place.id,
          'name': place.name,
          'type': place.type.toString(),
          'arrivedAt': ServerValue.timestamp,
        } : null,
        'lastPlaceUpdate': ServerValue.timestamp,
      });
    } catch (e) {
      _log('Error updating real-time location: $e');
    }
  }

  /// Apply place-based automation
  static Future<void> _applyPlaceAutomation(SmartPlace place, bool arrived) async {
    if (!place.automationEnabled) return;

    // Example automations (can be expanded)
    switch (place.type) {
      case PlaceType.work:
        if (arrived) {
          // Set phone to silent mode at work
          _log('Applying work automation: silent mode');
        }
        break;
      case PlaceType.home:
        if (arrived) {
          // Home automation (could integrate with smart home)
          _log('Applying home automation');
        }
        break;
      case PlaceType.school:
        if (arrived) {
          // School mode automation
          _log('Applying school automation');
        }
        break;
      default:
        break;
    }
  }

  /// Start periodic analysis for automatic place detection
  static void _startPeriodicAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _analyzeLocationPatterns();
    });
  }

  /// Analyze location patterns to detect new places
  static Future<void> _analyzeLocationPatterns() async {
    if (_locationHistory.length < 20) return;

    // Group nearby locations
    final clusters = _clusterLocations(_locationHistory);
    
    for (final cluster in clusters) {
      if (cluster.length >= _minimumVisits) {
        await _detectPotentialPlace(cluster);
      }
    }
  }

  /// Cluster nearby locations to find potential places
  static List<List<Position>> _clusterLocations(List<Position> locations) {
    final clusters = <List<Position>>[];
    final used = <bool>[];
    
    for (int i = 0; i < locations.length; i++) {
      used.add(false);
    }

    for (int i = 0; i < locations.length; i++) {
      if (used[i]) continue;

      final cluster = <Position>[locations[i]];
      used[i] = true;

      for (int j = i + 1; j < locations.length; j++) {
        if (used[j]) continue;

        final distance = Geolocator.distanceBetween(
          locations[i].latitude,
          locations[i].longitude,
          locations[j].latitude,
          locations[j].longitude,
        );

        if (distance <= _homeDetectionRadius) {
          cluster.add(locations[j]);
          used[j] = true;
        }
      }

      if (cluster.length >= _minimumVisits) {
        clusters.add(cluster);
      }
    }

    return clusters;
  }

  /// Detect potential new place from location cluster
  static Future<void> _detectPotentialPlace(List<Position> cluster) async {
    // Calculate center point
    double avgLat = 0;
    double avgLng = 0;
    
    for (final pos in cluster) {
      avgLat += pos.latitude;
      avgLng += pos.longitude;
    }
    
    avgLat /= cluster.length;
    avgLng /= cluster.length;

    // Check if this place already exists
    for (final existingPlace in _userPlaces.values) {
      final distance = Geolocator.distanceBetween(
        avgLat,
        avgLng,
        existingPlace.latitude,
        existingPlace.longitude,
      );
      
      if (distance <= existingPlace.radius) {
        return; // Place already exists
      }
    }

    // Get address for the location
    String placeName = 'Unknown Place';
    PlaceType placeType = PlaceType.other;
    
    try {
      final placemarks = await placemarkFromCoordinates(avgLat, avgLng);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        placeName = _generatePlaceName(placemark);
        placeType = _detectPlaceType(placemark);
      }
    } catch (e) {
      _log('Error getting address for detected place: $e');
    }

    // Create new smart place
    final newPlace = SmartPlace(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _currentUserId!,
      name: placeName,
      latitude: avgLat,
      longitude: avgLng,
      radius: _homeDetectionRadius,
      type: placeType,
      isAutoDetected: true,
      visitCount: cluster.length,
      createdAt: DateTime.now(),
    );

    // Save the new place
    _userPlaces[newPlace.id] = newPlace;
    await _savePlaceToFirestore(newPlace);

    _log('Detected new place: ${newPlace.name}');

    // Notify callback
    if (onPlaceDetected != null) {
      onPlaceDetected!(newPlace);
    }
  }

  /// Generate a meaningful place name from placemark
  static String _generatePlaceName(Placemark placemark) {
    if (placemark.name != null && placemark.name!.isNotEmpty) {
      return placemark.name!;
    }
    
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      return placemark.street!;
    }
    
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      return placemark.subLocality!;
    }
    
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      return placemark.locality!;
    }
    
    return 'Detected Place';
  }

  /// Detect place type from placemark
  static PlaceType _detectPlaceType(Placemark placemark) {
    final name = placemark.name?.toLowerCase() ?? '';
    final street = placemark.street?.toLowerCase() ?? '';
    
    // Simple heuristics for place type detection
    if (name.contains('home') || name.contains('house')) {
      return PlaceType.home;
    }
    
    if (name.contains('work') || name.contains('office') || 
        name.contains('company') || name.contains('business')) {
      return PlaceType.work;
    }
    
    if (name.contains('school') || name.contains('university') || 
        name.contains('college') || name.contains('academy')) {
      return PlaceType.school;
    }
    
    if (name.contains('gym') || name.contains('fitness') || 
        name.contains('sport')) {
      return PlaceType.gym;
    }
    
    if (name.contains('shop') || name.contains('store') || 
        name.contains('mall') || name.contains('market')) {
      return PlaceType.shopping;
    }
    
    return PlaceType.other;
  }

  /// Save place to Firestore
  static Future<void> _savePlaceToFirestore(SmartPlace place) async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('places')
          .doc(place.id)
          .set(place.toMap());
    } catch (e) {
      _log('Error saving place to Firestore: $e');
    }
  }

  /// Update current location context
  static void _updateCurrentLocation(Position position) {
    // This could be used for additional context-aware features
  }

  /// Create a new place manually
  static Future<SmartPlace?> createPlace({
    required String name,
    required double latitude,
    required double longitude,
    double radius = 100.0,
    PlaceType type = PlaceType.other,
    bool notificationsEnabled = true,
    bool automationEnabled = false,
  }) async {
    if (_currentUserId == null) return null;

    final place = SmartPlace(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _currentUserId!,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      type: type,
      notificationsEnabled: notificationsEnabled,
      automationEnabled: automationEnabled,
      isAutoDetected: false,
      createdAt: DateTime.now(),
    );

    _userPlaces[place.id] = place;
    await _savePlaceToFirestore(place);

    _log('Created new place: ${place.name}');
    return place;
  }

  /// Get all user places
  static List<SmartPlace> getUserPlaces() {
    return _userPlaces.values.toList();
  }

  /// Get place by ID
  static SmartPlace? getPlace(String placeId) {
    return _userPlaces[placeId];
  }

  /// Update place
  static Future<bool> updatePlace(SmartPlace place) async {
    _userPlaces[place.id] = place;
    await _savePlaceToFirestore(place);
    return true;
  }

  /// Delete place
  static Future<bool> deletePlace(String placeId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('places')
          .doc(placeId)
          .delete();
      
      _userPlaces.remove(placeId);
      _log('Deleted place: $placeId');
      return true;
    } catch (e) {
      _log('Error deleting place: $e');
      return false;
    }
  }

  /// Stop places service
  static Future<void> stop() async {
    _log('Stopping places service');
    
    await _locationSubscription?.cancel();
    _analysisTimer?.cancel();
    
    _userPlaces.clear();
    _locationHistory.clear();
    _lastNotificationTime.clear();
    _currentUserId = null;
    
    _log('Places service stopped');
  }

  /// Cleanup service
  static Future<void> cleanup() async {
    await stop();
  }

  static void _log(String message) {
    if (kDebugMode) {
      print('PLACES_SERVICE: $message');
    }
  }
}