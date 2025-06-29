import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/driving_session.dart';

/// Life360-style driving detection service
/// Detects when users are driving using motion sensors, speed, and location patterns
class DrivingDetectionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  
  // Subscriptions
  static StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  static StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  static StreamSubscription<Position>? _locationSubscription;
  
  // State
  static bool _isInitialized = false;
  static bool _isDriving = false;
  static String? _currentUserId;
  static DrivingSession? _currentSession;
  
  // Driving detection parameters
  static const double _drivingSpeedThreshold = 5.0; // m/s (18 km/h)
  static const double _stoppedSpeedThreshold = 1.0; // m/s (3.6 km/h)
  static const Duration _drivingConfirmationTime = Duration(seconds: 30);
  static const Duration _stoppedConfirmationTime = Duration(minutes: 2);
  
  // Motion detection parameters
  static const double _accelerationThreshold = 2.0; // m/s²
  static const double _gyroscopeThreshold = 0.5; // rad/s
  
  // Data buffers for analysis
  static final List<double> _speedBuffer = [];
  static final List<double> _accelerationBuffer = [];
  static final List<Position> _locationBuffer = [];
  static const int _bufferSize = 20;
  
  // Timers
  static Timer? _drivingConfirmationTimer;
  static Timer? _stoppedConfirmationTimer;
  static Timer? _analysisTimer;
  
  // Callbacks
  static Function(bool isDriving, DrivingSession? session)? onDrivingStateChanged;
  static Function(double speed, double maxSpeed)? onSpeedChanged;
  static Function(String event, Map<String, dynamic> data)? onDrivingEvent;

  /// Initialize driving detection service
  static Future<bool> initialize(String userId) async {
    try {
      _log('Initializing driving detection service for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      // Start sensor monitoring
      await _startSensorMonitoring();
      
      // Start location monitoring for speed detection
      await _startLocationMonitoring();
      
      // Start periodic analysis
      _startPeriodicAnalysis();
      
      _isInitialized = true;
      _log('Driving detection service initialized successfully');
      return true;
    } catch (e) {
      _log('Error initializing driving detection service: $e');
      return false;
    }
  }

  /// Start monitoring accelerometer and gyroscope
  static Future<void> _startSensorMonitoring() async {
    // Monitor accelerometer for driving patterns
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Add to buffer
      _accelerationBuffer.add(acceleration);
      if (_accelerationBuffer.length > _bufferSize) {
        _accelerationBuffer.removeAt(0);
      }
    });

    // Monitor gyroscope for turning patterns
    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      final rotation = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Detect significant rotation (turning while driving)
      if (rotation > _gyroscopeThreshold && _isDriving) {
        _recordDrivingEvent('turn', {
          'rotation': rotation,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  /// Start monitoring location for speed detection
  static Future<void> _startLocationMonitoring() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _processLocationUpdate(position);
    });
  }

  /// Process location update for driving detection
  static void _processLocationUpdate(Position position) {
    // Add to location buffer
    _locationBuffer.add(position);
    if (_locationBuffer.length > _bufferSize) {
      _locationBuffer.removeAt(0);
    }

    // Calculate speed (m/s)
    final speed = position.speed;
    _speedBuffer.add(speed);
    if (_speedBuffer.length > _bufferSize) {
      _speedBuffer.removeAt(0);
    }

    // Notify speed change
    if (onSpeedChanged != null && _speedBuffer.isNotEmpty) {
      final maxSpeed = _speedBuffer.reduce(max);
      onSpeedChanged!(speed, maxSpeed);
    }

    // Update current session if driving
    if (_isDriving && _currentSession != null) {
      _updateCurrentSession(position, speed);
    }

    // Analyze driving state
    _analyzeDrivingState();
  }

  /// Analyze current driving state based on speed and motion
  static void _analyzeDrivingState() {
    if (_speedBuffer.isEmpty || _accelerationBuffer.isEmpty) return;

    final avgSpeed = _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;
    final avgAcceleration = _accelerationBuffer.reduce((a, b) => a + b) / _accelerationBuffer.length;

    final bool speedIndicatesDriving = avgSpeed > _drivingSpeedThreshold;
    final bool motionIndicatesDriving = avgAcceleration > _accelerationThreshold;
    final bool shouldBeDriving = speedIndicatesDriving && motionIndicatesDriving;

    if (shouldBeDriving && !_isDriving) {
      // Start driving confirmation timer
      _drivingConfirmationTimer?.cancel();
      _drivingConfirmationTimer = Timer(_drivingConfirmationTime, () {
        _startDriving();
      });
    } else if (!shouldBeDriving && _isDriving) {
      // Start stopped confirmation timer
      _stoppedConfirmationTimer?.cancel();
      _stoppedConfirmationTimer = Timer(_stoppedConfirmationTime, () {
        _stopDriving();
      });
    }
  }

  /// Start a driving session
  static Future<void> _startDriving() async {
    if (_isDriving || _currentUserId == null) return;

    _log('Starting driving session');
    _isDriving = true;

    // Create new driving session
    _currentSession = DrivingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _currentUserId!,
      startTime: DateTime.now(),
      startLocation: _locationBuffer.isNotEmpty ? _locationBuffer.last : null,
      isActive: true,
    );

    // Update user status in Firebase
    await _updateDrivingStatus(true);

    // Notify listeners
    if (onDrivingStateChanged != null) {
      onDrivingStateChanged!(true, _currentSession);
    }

    // Record driving event
    _recordDrivingEvent('driving_started', {
      'sessionId': _currentSession!.id,
      'startTime': _currentSession!.startTime.millisecondsSinceEpoch,
    });
  }

  /// Stop the current driving session
  static Future<void> _stopDriving() async {
    if (!_isDriving || _currentSession == null || _currentUserId == null) return;

    _log('Stopping driving session');
    _isDriving = false;

    // Complete current session
    _currentSession = _currentSession!.copyWith(
      endTime: DateTime.now(),
      endLocation: _locationBuffer.isNotEmpty ? _locationBuffer.last : null,
      isActive: false,
    );

    // Calculate session statistics
    _calculateSessionStats();

    // Save session to Firestore
    await _saveDrivingSession(_currentSession!);

    // Update user status in Firebase
    await _updateDrivingStatus(false);

    // Notify listeners
    if (onDrivingStateChanged != null) {
      onDrivingStateChanged!(false, _currentSession);
    }

    // Record driving event
    _recordDrivingEvent('driving_stopped', {
      'sessionId': _currentSession!.id,
      'endTime': _currentSession!.endTime?.millisecondsSinceEpoch,
      'duration': _currentSession!.duration?.inMinutes,
      'distance': _currentSession!.distance,
      'maxSpeed': _currentSession!.maxSpeed,
    });

    _currentSession = null;
  }

  /// Update current driving session with new location data
  static void _updateCurrentSession(Position position, double speed) {
    if (_currentSession == null) return;

    // Update max speed
    final currentMaxSpeed = _currentSession!.maxSpeed ?? 0.0;
    if (speed > currentMaxSpeed) {
      _currentSession = _currentSession!.copyWith(maxSpeed: speed);
    }

    // Update distance
    if (_currentSession!.route.isNotEmpty) {
      final lastPosition = _currentSession!.route.last;
      final distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        position.latitude,
        position.longitude,
      );
      
      final currentDistance = _currentSession!.distance ?? 0.0;
      _currentSession = _currentSession!.copyWith(
        distance: currentDistance + distance,
      );
    }

    // Add to route
    _currentSession = _currentSession!.copyWith(
      route: [..._currentSession!.route, position],
    );

    // Detect driving events
    _detectDrivingEvents(speed);
  }

  /// Detect driving events (hard braking, rapid acceleration, speeding)
  static void _detectDrivingEvents(double currentSpeed) {
    if (_speedBuffer.length < 3) return;

    final previousSpeed = _speedBuffer[_speedBuffer.length - 2];
    final speedChange = currentSpeed - previousSpeed;
    
    // Hard braking detection
    if (speedChange < -3.0) { // Deceleration > 3 m/s²
      _recordDrivingEvent('hard_braking', {
        'speed': currentSpeed,
        'previousSpeed': previousSpeed,
        'deceleration': speedChange.abs(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    
    // Rapid acceleration detection
    if (speedChange > 3.0) { // Acceleration > 3 m/s²
      _recordDrivingEvent('rapid_acceleration', {
        'speed': currentSpeed,
        'previousSpeed': previousSpeed,
        'acceleration': speedChange,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    
    // Speeding detection (over 30 m/s = 108 km/h)
    if (currentSpeed > 30.0) {
      _recordDrivingEvent('speeding', {
        'speed': currentSpeed,
        'speedKmh': currentSpeed * 3.6,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Calculate session statistics
  static void _calculateSessionStats() {
    if (_currentSession == null) return;

    // Calculate duration
    final duration = _currentSession!.endTime?.difference(_currentSession!.startTime);
    
    // Calculate average speed
    double avgSpeed = 0.0;
    if (_speedBuffer.isNotEmpty) {
      avgSpeed = _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;
    }

    _currentSession = _currentSession!.copyWith(
      duration: duration,
      averageSpeed: avgSpeed,
    );
  }

  /// Save driving session to Firestore
  static Future<void> _saveDrivingSession(DrivingSession session) async {
    try {
      await _firestore
          .collection('users')
          .doc(session.userId)
          .collection('driving_sessions')
          .doc(session.id)
          .set(session.toMap());
      
      _log('Driving session saved: ${session.id}');
    } catch (e) {
      _log('Error saving driving session: $e');
    }
  }

  /// Update user driving status in Firebase
  static Future<void> _updateDrivingStatus(bool isDriving) async {
    if (_currentUserId == null) return;

    try {
      // Update Realtime Database for instant updates
      await _realtimeDb.ref('users/$_currentUserId').update({
        'isDriving': isDriving,
        'drivingStatusUpdated': ServerValue.timestamp,
      });

      // Update Firestore for persistence
      await _firestore.collection('users').doc(_currentUserId).update({
        'isDriving': isDriving,
        'drivingStatusUpdated': FieldValue.serverTimestamp(),
      });

      _log('Updated driving status: $isDriving');
    } catch (e) {
      _log('Error updating driving status: $e');
    }
  }

  /// Record a driving event
  static void _recordDrivingEvent(String event, Map<String, dynamic> data) {
    _log('Driving event: $event - $data');
    
    if (onDrivingEvent != null) {
      onDrivingEvent!(event, data);
    }

    // Save to Firestore for analytics
    if (_currentUserId != null) {
      _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('driving_events')
          .add({
        'event': event,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'sessionId': _currentSession?.id,
      }).catchError((e) {
        _log('Error saving driving event: $e');
        // Return a dummy DocumentReference to satisfy the type
        return _firestore.collection('dummy').doc('dummy');
      });
    }
  }

  /// Start periodic analysis
  static void _startPeriodicAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isInitialized) {
        _analyzeDrivingState();
      } else {
        timer.cancel();
      }
    });
  }

  /// Get current driving status
  static bool get isDriving => _isDriving;
  
  /// Get current driving session
  static DrivingSession? get currentSession => _currentSession;

  /// Stop driving detection service
  static Future<void> stop() async {
    _log('Stopping driving detection service');
    
    // Stop current session if active
    if (_isDriving) {
      await _stopDriving();
    }
    
    // Cancel subscriptions
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _locationSubscription?.cancel();
    
    // Cancel timers
    _drivingConfirmationTimer?.cancel();
    _stoppedConfirmationTimer?.cancel();
    _analysisTimer?.cancel();
    
    // Clear state
    _isInitialized = false;
    _isDriving = false;
    _currentUserId = null;
    _currentSession = null;
    
    // Clear buffers
    _speedBuffer.clear();
    _accelerationBuffer.clear();
    _locationBuffer.clear();
    
    _log('Driving detection service stopped');
  }

  /// Cleanup service
  static Future<void> cleanup() async {
    await stop();
  }

  static void _log(String message) {
    if (kDebugMode) {
      print('DRIVING_DETECTION: $message');
    }
  }
}