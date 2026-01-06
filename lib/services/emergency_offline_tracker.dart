import 'dart:async';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';

/// Emergency offline tracker for safety - ensures family knows last location when offline
class EmergencyOfflineTracker {
  static const String _tag = 'EmergencyOfflineTracker';
  static const String _lastKnownLocationKey = 'emergency_last_location';
  static const String _offlineTimestampKey = 'emergency_offline_timestamp';
  
  static Timer? _offlineCheckTimer;
  static StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  static bool _isCurrentlyOffline = false;
  static String? _currentUserId;
  
  /// Initialize emergency offline tracking
  static Future<void> initialize(String userId) async {
    _currentUserId = userId;
    developer.log('[$_tag] Initializing emergency offline tracker for user: $userId');
    
    // Start monitoring connectivity
    await _startConnectivityMonitoring();
    
    // Set up periodic offline checks
    _startOfflineChecks();
    
    // Restore any pending offline state
    await _restoreOfflineState();
  }
  
  /// Start monitoring connectivity changes
  static Future<void> _startConnectivityMonitoring() async {
    final connectivity = Connectivity();
    
    // Check initial state
    final result = await connectivity.checkConnectivity();
    await _handleConnectivityChange(result);
    
    // Listen for changes
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }
  
  /// Handle connectivity changes
  static Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    final wasOffline = _isCurrentlyOffline;
    _isCurrentlyOffline = result == ConnectivityResult.none;
    
    if (!wasOffline && _isCurrentlyOffline) {
      // Just went offline - emergency protocol
      await _handleGoingOffline();
    } else if (wasOffline && !_isCurrentlyOffline) {
      // Just came back online - update family
      await _handleComingOnline();
    }
  }
  
  /// Handle going offline - CRITICAL for safety
  static Future<void> _handleGoingOffline() async {
    if (_currentUserId == null) return;
    
    developer.log('[$_tag] 🚨 GOING OFFLINE - Activating emergency protocol');
    
    try {
      // CRITICAL: Get current location immediately before losing signal
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // Shorter timeout - we might lose signal fast
      ).timeout(const Duration(seconds: 8));
      
      final offlineTime = DateTime.now().millisecondsSinceEpoch;
      
      // Store offline data locally FIRST (this always works)
      await _storeOfflineDataLocally(position, offlineTime);
      
      // Try multiple Firebase update strategies (some might work even with poor signal)
      await _attemptFirebaseUpdates(position, offlineTime);
      
      // Set up background task to retry Firebase updates
      await _scheduleOfflineRetries(position, offlineTime);
      
      developer.log('[$_tag] Emergency offline protocol activated - Location: ${position.latitude}, ${position.longitude}');
      
    } catch (e) {
      developer.log('[$_tag] Error getting location during offline: $e');
      // CRITICAL: Still save offline timestamp even without location
      await _storeOfflineDataLocally(null, DateTime.now().millisecondsSinceEpoch);
      await _scheduleOfflineRetries(null, DateTime.now().millisecondsSinceEpoch);
    }
  }
  
  /// Store offline data locally (always works)
  static Future<void> _storeOfflineDataLocally(Position? position, int offlineTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store offline timestamp
      await prefs.setInt(_offlineTimestampKey, offlineTime);
      
      // Store location if available
      if (position != null) {
        await prefs.setString(_lastKnownLocationKey, 
          '${position.latitude},${position.longitude},$offlineTime');
        
        // Store additional location details
        await prefs.setString('emergency_location_details', 
          '${position.latitude},${position.longitude},${position.accuracy},${position.altitude},$offlineTime');
      }
      
      // Store device state info
      await prefs.setString('emergency_device_state', 
        'offline,$offlineTime,${DateTime.now().toIso8601String()}');
      
      developer.log('[$_tag] Offline data stored locally successfully');
    } catch (e) {
      developer.log('[$_tag] Error storing offline data locally: $e');
    }
  }
  
  /// Attempt multiple Firebase update strategies
  static Future<void> _attemptFirebaseUpdates(Position? position, int offlineTime) async {
    // Strategy 1: Quick Realtime Database update (fastest)
    try {
      await FirebaseDatabase.instance.ref('emergency_status/${_currentUserId}').set({
        'status': 'going_offline',
        'timestamp': offlineTime,
        'lastLocation': position != null ? {
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
        } : null,
        'deviceState': 'losing_connectivity',
      }).timeout(const Duration(seconds: 3));
      
      developer.log('[$_tag] Quick Firebase update successful');
    } catch (e) {
      developer.log('[$_tag] Quick Firebase update failed: $e');
    }
    
    // Strategy 2: Firestore update with offline persistence
    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
        'emergencyStatus': 'offline',
        'lastKnownLocation': position != null ? {
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': offlineTime,
        } : null,
        'wentOfflineAt': FieldValue.serverTimestamp(),
        'deviceState': 'offline',
      }).timeout(const Duration(seconds: 5));
      
      developer.log('[$_tag] Firestore offline update successful');
    } catch (e) {
      developer.log('[$_tag] Firestore offline update failed: $e');
    }
  }
  
  /// Schedule background retries to update Firebase when signal returns
  static Future<void> _scheduleOfflineRetries(Position? position, int offlineTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store retry data
      await prefs.setString('emergency_retry_data', 
        '${_currentUserId},$offlineTime,${position?.latitude ?? 0},${position?.longitude ?? 0}');
      
      // Set flag for app restart detection
      await prefs.setBool('emergency_offline_pending', true);
      
      developer.log('[$_tag] Offline retry scheduled');
    } catch (e) {
      developer.log('[$_tag] Error scheduling offline retries: $e');
    }
  }
  
  /// Handle coming back online
  static Future<void> _handleComingOnline() async {
    if (_currentUserId == null) return;
    
    developer.log('[$_tag] ✅ BACK ONLINE - Notifying family');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineTimestamp = prefs.getInt(_offlineTimestampKey);
      
      if (offlineTimestamp != null) {
        final offlineDuration = DateTime.now().millisecondsSinceEpoch - offlineTimestamp;
        
        // Update Firebase that user is back online
        await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
          'isOnline': true,
          'lastOnline': FieldValue.serverTimestamp(),
          'backOnlineAt': FieldValue.serverTimestamp(),
          'wasOfflineFor': offlineDuration, // Duration in milliseconds
          'emergencyStatus': 'safe', // Indicate user is safe
        });
        
        // Send notification to family that user is back online
        await _notifyFamilyBackOnline(offlineDuration);
        
        // Clear offline data
        await prefs.remove(_offlineTimestampKey);
        await prefs.remove(_lastKnownLocationKey);
        
        developer.log('[$_tag] Family notified - was offline for ${(offlineDuration / 1000 / 60).round()} minutes');
      }
    } catch (e) {
      developer.log('[$_tag] Error handling back online: $e');
    }
  }
  
  /// Update offline status in Firebase
  static Future<void> _updateOfflineStatus(Position position, int offlineTime) async {
    if (_currentUserId == null) return;
    
    try {
      // Update Firestore with offline status and last known location
      await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
        'isOnline': false,
        'wentOfflineAt': FieldValue.serverTimestamp(),
        'lastKnownLocation': {
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': offlineTime,
        },
        'emergencyStatus': 'offline', // Mark as potentially in need of help
        'lastLocationBeforeOffline': {
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': offlineTime,
        }
      });
      
      // Also update Realtime Database for immediate family notification
      await FirebaseDatabase.instance.ref('emergency_status/${_currentUserId}').set({
        'status': 'offline',
        'lastLocation': {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        'offlineAt': offlineTime,
        'needsCheck': true, // Flag for family to check on user
      });
      
    } catch (e) {
      developer.log('[$_tag] Could not update Firebase (already offline): $e');
    }
  }
  
  /// Notify family that user is back online
  static Future<void> _notifyFamilyBackOnline(int offlineDurationMs) async {
    if (_currentUserId == null) return;
    
    try {
      // Clear emergency status
      await FirebaseDatabase.instance.ref('emergency_status/${_currentUserId}').set({
        'status': 'online',
        'backOnlineAt': DateTime.now().millisecondsSinceEpoch,
        'wasOfflineFor': offlineDurationMs,
        'needsCheck': false,
      });
      
      // Send push notification to family members
      // This would integrate with your FCM service
      developer.log('[$_tag] Should send notification: User back online after ${(offlineDurationMs / 1000 / 60).round()} minutes');
      
    } catch (e) {
      developer.log('[$_tag] Error notifying family: $e');
    }
  }
  
  /// Start periodic offline checks
  static void _startOfflineChecks() {
    _offlineCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkOfflineStatus();
    });
  }
  
  /// Check if user has been offline too long
  static Future<void> _checkOfflineStatus() async {
    if (!_isCurrentlyOffline || _currentUserId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineTimestamp = prefs.getInt(_offlineTimestampKey);
      
      if (offlineTimestamp != null) {
        final offlineDuration = DateTime.now().millisecondsSinceEpoch - offlineTimestamp;
        final offlineMinutes = offlineDuration / 1000 / 60;
        
        // If offline for more than 30 minutes, escalate emergency status
        if (offlineMinutes > 30) {
          await _escalateEmergencyStatus(offlineDuration.round());
        }
      }
    } catch (e) {
      developer.log('[$_tag] Error checking offline status: $e');
    }
  }
  
  /// Escalate emergency status for prolonged offline
  static Future<void> _escalateEmergencyStatus(int offlineDurationMs) async {
    if (_currentUserId == null) return;
    
    try {
      // Try to update emergency status (might fail if still offline)
      await FirebaseDatabase.instance.ref('emergency_status/${_currentUserId}').update({
        'status': 'emergency',
        'offlineDuration': offlineDurationMs,
        'needsUrgentCheck': true,
        'escalatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      developer.log('[$_tag] 🚨 EMERGENCY: User offline for ${(offlineDurationMs / 1000 / 60).round()} minutes');
      
    } catch (e) {
      developer.log('[$_tag] Could not escalate emergency status: $e');
    }
  }
  
  /// Restore offline state on app restart
  static Future<void> _restoreOfflineState() async {
    if (_currentUserId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineTimestamp = prefs.getInt(_offlineTimestampKey);
      final hasPendingOffline = prefs.getBool('emergency_offline_pending') ?? false;
      
      if (offlineTimestamp != null) {
        // App was closed while offline - restore state
        final offlineDuration = DateTime.now().millisecondsSinceEpoch - offlineTimestamp;
        developer.log('[$_tag] Restoring offline state - was offline for ${(offlineDuration / 1000 / 60).round()} minutes');
        
        // Check if we're still offline
        final connectivity = Connectivity();
        final result = await connectivity.checkConnectivity();
        
        if (result == ConnectivityResult.none) {
          _isCurrentlyOffline = true;
          // Still offline - continue emergency protocol
          await _escalateEmergencyStatus(offlineDuration.round());
        } else {
          // Back online - notify family and retry failed updates
          await _handleComingOnline();
          
          // Process any pending offline updates
          if (hasPendingOffline) {
            await _processPendingOfflineUpdates();
          }
        }
      }
      
      // Start heartbeat system for server-side offline detection
      await _startHeartbeatSystem();
      
    } catch (e) {
      developer.log('[$_tag] Error restoring offline state: $e');
    }
  }
  
  /// Process pending offline updates that failed when going offline
  static Future<void> _processPendingOfflineUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final retryData = prefs.getString('emergency_retry_data');
      
      if (retryData != null) {
        final parts = retryData.split(',');
        if (parts.length >= 4) {
          final userId = parts[0];
          final offlineTime = int.parse(parts[1]);
          final lat = double.parse(parts[2]);
          final lng = double.parse(parts[3]);
          
          // Now that we're back online, update Firebase with the offline event
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'emergencyStatus': 'was_offline',
            'lastKnownLocation': lat != 0 && lng != 0 ? {
              'lat': lat,
              'lng': lng,
              'timestamp': offlineTime,
            } : null,
            'wentOfflineAt': Timestamp.fromMillisecondsSinceEpoch(offlineTime),
            'backOnlineAt': FieldValue.serverTimestamp(),
            'offlineDuration': DateTime.now().millisecondsSinceEpoch - offlineTime,
          });
          
          developer.log('[$_tag] Processed pending offline update for $userId');
        }
        
        // Clear retry data
        await prefs.remove('emergency_retry_data');
        await prefs.setBool('emergency_offline_pending', false);
      }
    } catch (e) {
      developer.log('[$_tag] Error processing pending offline updates: $e');
    }
  }
  
  /// Start heartbeat system for server-side offline detection
  static Future<void> _startHeartbeatSystem() async {
    if (_currentUserId == null) return;
    
    try {
      // Send initial heartbeat
      await _sendHeartbeat();
      
      // Set up periodic heartbeats every 30 seconds
      Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (_currentUserId != null) {
          await _sendHeartbeat();
        } else {
          timer.cancel();
        }
      });
      
      // Set up Firebase disconnect detection
      await _setupFirebaseDisconnectDetection();
      
      developer.log('[$_tag] Heartbeat system started');
    } catch (e) {
      developer.log('[$_tag] Error starting heartbeat system: $e');
    }
  }
  
  /// Send heartbeat to Firebase
  static Future<void> _sendHeartbeat() async {
    if (_currentUserId == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Update Realtime Database with heartbeat
      await FirebaseDatabase.instance.ref('heartbeats/${_currentUserId}').set({
        'timestamp': timestamp,
        'status': 'online',
        'lastSeen': timestamp,
      });
      
      // Also update Firestore
      await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'isOnline': true,
        'emergencyStatus': 'safe',
      });
      
    } catch (e) {
      // Heartbeat failed - might be going offline
      developer.log('[$_tag] Heartbeat failed: $e');
    }
  }
  
  /// Set up Firebase disconnect detection (server-side)
  static Future<void> _setupFirebaseDisconnectDetection() async {
    if (_currentUserId == null) return;
    
    try {
      // Set up automatic offline detection when Firebase connection is lost
      await FirebaseDatabase.instance.ref('heartbeats/${_currentUserId}').onDisconnect().update({
        'status': 'offline',
        'disconnectedAt': ServerValue.timestamp,
        'lastSeen': ServerValue.timestamp,
      });
      
      // Also set emergency status on disconnect
      await FirebaseDatabase.instance.ref('emergency_status/${_currentUserId}').onDisconnect().update({
        'status': 'offline',
        'disconnectedAt': ServerValue.timestamp,
        'needsCheck': true,
        'detectedBy': 'firebase_disconnect',
      });
      
      developer.log('[$_tag] Firebase disconnect detection set up');
    } catch (e) {
      developer.log('[$_tag] Error setting up disconnect detection: $e');
    }
  }
  
  /// Get emergency status for family members
  static Stream<Map<String, dynamic>?> getEmergencyStatus(String userId) {
    return FirebaseDatabase.instance
        .ref('emergency_status/$userId')
        .onValue
        .map((event) => event.snapshot.value as Map<String, dynamic>?);
  }
  
  /// Cleanup
  static Future<void> dispose() async {
    _offlineCheckTimer?.cancel();
    await _connectivitySubscription?.cancel();
    _currentUserId = null;
    _isCurrentlyOffline = false;
  }
}