import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../services/ultra_geofencing_service.dart';
import '../models/geofence_model.dart';

/// Ultra Geofencing Provider for 5-meter precision tracking
class UltraGeofencingProvider with ChangeNotifier {
  
  // State variables
  bool _isInitialized = false;
  bool _isTracking = false;
  bool _mounted = true;
  String? _currentUserId;
  String? _error;
  String _status = 'Initializing...';
  LatLng? _currentLocation;
  double _currentAccuracy = 0.0;
  
  // Geofencing state
  final List<GeofenceModel> _activeGeofences = [];
  final Map<String, bool> _geofenceStates = {};
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  bool get mounted => _mounted;
  String? get currentUserId => _currentUserId;
  String? get error => _error;
  String get status => _status;
  LatLng? get currentLocation => _currentLocation;
  double get currentAccuracy => _currentAccuracy;
  List<GeofenceModel> get activeGeofences => List.unmodifiable(_activeGeofences);
  Map<String, bool> get geofenceStates => Map.unmodifiable(_geofenceStates);
  bool get ultraGeofencingEnabled => _isTracking && _isInitialized;
  
  /// Initialize ultra geofencing
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      developer.log('Initializing UltraGeofencingProvider');
      
      final initialized = await UltraGeofencingService.initialize();
      if (!initialized) {
        _error = 'Failed to initialize ultra geofencing service';
        _status = 'Error';
        if (_mounted) notifyListeners();
        return false;
      }
      
      _isInitialized = true;
      _status = 'Ready';
      if (_mounted) notifyListeners();
      
      developer.log('UltraGeofencingProvider initialized successfully');
      return true;
    } catch (e) {
      developer.log('Failed to initialize UltraGeofencingProvider: $e');
      _error = 'Initialization failed: $e';
      _status = 'Error';
      if (_mounted) notifyListeners();
      return false;
    }
  }
  
  /// Start ultra-active tracking
  Future<bool> startUltraTracking(String userId) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (_isTracking && _currentUserId == userId) {
      developer.log('Already tracking for user: ${userId.substring(0, 8)}');
      return true;
    }
    
    try {
      developer.log('Starting ultra-active tracking for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      _error = null;
      _status = 'Starting ultra-geofencing...';
      if (_mounted) notifyListeners();
      
      final trackingStarted = await UltraGeofencingService.startUltraActiveTracking(
        userId: userId,
        ultraActive: true,
        onLocationUpdate: _handleLocationUpdate,
        onGeofenceEvent: _handleGeofenceEvent,
        onError: _handleError,
      );
      
      if (!trackingStarted) {
        _error = 'Failed to start ultra tracking';
        _status = 'Error';
        if (_mounted) notifyListeners();
        return false;
      }
      
      _isTracking = true;
      _status = 'Ultra-geofencing active (5m precision)';
      if (_mounted) notifyListeners();
      
      developer.log('Ultra-active tracking started successfully');
      return true;
    } catch (e) {
      developer.log('Failed to start ultra tracking: $e');
      _error = 'Failed to start tracking: $e';
      _status = 'Error';
      if (_mounted) notifyListeners();
      return false;
    }
  }
  
  /// Stop ultra-active tracking
  Future<bool> stopTracking() async {
    if (!_isTracking) return true;
    
    try {
      developer.log('Stopping ultra-active tracking');
      
      _status = 'Stopping ultra-geofencing...';
      if (_mounted) notifyListeners();
      
      final stopped = await UltraGeofencingService.stopTracking();
      
      _isTracking = false;
      _currentLocation = null;
      _currentAccuracy = 0.0;
      _activeGeofences.clear();
      _geofenceStates.clear();
      _status = 'Ultra-geofencing stopped';
      if (_mounted) notifyListeners();
      
      developer.log('Ultra-active tracking stopped successfully');
      return stopped;
    } catch (e) {
      developer.log('Failed to stop ultra tracking: $e');
      _error = 'Failed to stop tracking: $e';
      _status = 'Error';
      if (_mounted) notifyListeners();
      return false;
    }
  }
  
  /// Add a geofence
  Future<bool> addGeofence({
    required String id,
    required LatLng center,
    double radius = 5.0,
    String? name,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isTracking) {
      developer.log('Ultra-geofencing not active');
      return false;
    }
    
    try {
      final geofence = GeofenceModel(
        id: id,
        center: center,
        radius: radius,
        name: name ?? 'Geofence $id',
        metadata: metadata ?? {},
      );
      
      // Add to local list
      _activeGeofences.add(geofence);
      
      // Add to ultra-geofencing service
      final added = await UltraGeofencingService.addGeofence(
        id: id,
        center: center,
        radius: radius,
        name: geofence.name,
        metadata: metadata,
      );
      
      if (added && _mounted) {
        notifyListeners();
      }
      
      developer.log('Added geofence: $id at ${center.latitude}, ${center.longitude} (${radius}m)');
      return added;
    } catch (e) {
      developer.log('Error adding geofence: $e');
      return false;
    }
  }
  
  /// Remove a geofence
  Future<bool> removeGeofence(String id) async {
    try {
      _activeGeofences.removeWhere((g) => g.id == id);
      _geofenceStates.remove(id);
      
      if (_mounted) notifyListeners();
      
      developer.log('Removed geofence: $id');
      return true;
    } catch (e) {
      developer.log('Error removing geofence: $e');
      return false;
    }
  }
  
  /// Get geofence by ID
  GeofenceModel? getGeofence(String id) {
    try {
      return _activeGeofences.firstWhere((g) => g.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Check if user is inside a geofence
  bool isInsideGeofence(String geofenceId) {
    return _geofenceStates[geofenceId] ?? false;
  }
  
  /// Handle location updates from ultra geofencing service
  void _handleLocationUpdate(LatLng location, double accuracy) {
    if (!_isTracking || _currentUserId == null) return;
    
    _currentLocation = location;
    _currentAccuracy = accuracy;
    
    if (_mounted) notifyListeners();
    
    developer.log('Ultra location update: ${location.latitude}, ${location.longitude} (accuracy: ${accuracy}m)');
  }
  
  /// Handle geofence events
  void _handleGeofenceEvent(GeofenceModel geofence, bool entered) {
    if (!_isTracking || _currentUserId == null) return;
    
    _geofenceStates[geofence.id] = entered;
    
    // Update geofence in active list
    final index = _activeGeofences.indexWhere((g) => g.id == geofence.id);
    if (index >= 0) {
      _activeGeofences[index] = geofence.copyWith(isInside: entered);
    }
    
    if (_mounted) notifyListeners();
    
    developer.log('Geofence ${entered ? "ENTERED" : "EXITED"}: ${geofence.name}');
  }
  
  /// Handle errors from ultra geofencing service
  void _handleError(String error) {
    developer.log('Ultra geofencing error: $error');
    _error = error;
    if (_mounted) notifyListeners();
  }
  
  @override
  void dispose() {
    developer.log('Disposing UltraGeofencingProvider');
    _mounted = false;
    super.dispose();
  }
}