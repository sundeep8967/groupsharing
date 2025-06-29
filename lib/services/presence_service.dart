import 'dart:developer' as developer;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Pure location-based presence service that determines online/offline status
/// Users are "online" ONLY when they are actively sharing their location
/// No app-focused presence - purely based on location sharing activity
class PresenceService {
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  
  // Consider user offline after 2 minutes of no location updates
  static const Duration _offlineThreshold = Duration(minutes: 2);
  
  /// Initialize presence service for a user
  /// This only sets up disconnect handlers - actual presence is managed by location sharing
  static Future<void> initialize(String userId) async {
    _log('Initializing location-based presence service for user: ${userId.substring(0, 8)}');
    
    // Set up disconnect handlers in Firebase Realtime Database
    await _setupDisconnectHandlers(userId);
    
    _log('Location-based presence service initialized - presence determined by location sharing');
  }
  
  /// Set up Firebase Realtime Database disconnect handlers
  /// These ensure users are marked offline when they disconnect unexpectedly
  static Future<void> _setupDisconnectHandlers(String userId) async {
    try {
      final userRef = _realtimeDb.ref('users/$userId');
      
      // Set up automatic offline detection using Firebase's built-in disconnect detection
      await userRef.onDisconnect().update({
        'locationSharingEnabled': false,
        'lastSeen': ServerValue.timestamp,
        'disconnectedAt': ServerValue.timestamp,
        'disconnectReason': 'network_disconnect',
      });
      
      // Also clear location data on disconnect
      await _realtimeDb.ref('locations/$userId').onDisconnect().remove();
      
      _log('Set up disconnect handlers for user: ${userId.substring(0, 8)}');
    } catch (e) {
      _log('Error setting up disconnect handlers: $e');
    }
  }
  
  
  /// Check if a user is online based on their location sharing status
  static bool isUserOnline(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    
    // Primary check: Is location sharing enabled?
    final locationSharingEnabled = userData['locationSharingEnabled'] as bool?;
    if (locationSharingEnabled != true) {
      return false; // Not sharing location = offline
    }
    
    // Secondary check: Recent location update (indicates active location sharing)
    final lastLocationUpdate = userData['lastLocationUpdate'] ?? userData['lastSeen'];
    if (lastLocationUpdate == null) return false;
    
    DateTime lastUpdateDate;
    if (lastLocationUpdate is int) {
      lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(lastLocationUpdate);
    } else if (lastLocationUpdate is Timestamp) {
      lastUpdateDate = lastLocationUpdate.toDate();
    } else {
      return false;
    }
    
    // User is online if they're sharing location AND have recent location updates
    final timeDiff = DateTime.now().difference(lastUpdateDate);
    final isOnline = timeDiff < _offlineThreshold;
    
    if (!isOnline) {
      _log('User appears offline - last location update ${timeDiff.inSeconds} seconds ago');
    }
    
    return isOnline;
  }
  
  /// Get formatted last seen text based on location sharing status
  static String getLastSeenText(Map<String, dynamic>? userData) {
    if (userData == null) return 'Never seen';
    
    // Check if user is sharing location
    final locationSharingEnabled = userData['locationSharingEnabled'] as bool?;
    if (locationSharingEnabled != true) {
      return 'Location not shared';
    }
    
    if (isUserOnline(userData)) {
      return 'Sharing location';
    }
    
    // If sharing is enabled but no recent updates, show when location was last updated
    final lastLocationUpdate = userData['lastLocationUpdate'] ?? userData['lastSeen'];
    if (lastLocationUpdate == null) return 'Location never updated';
    
    DateTime lastUpdateDate;
    if (lastLocationUpdate is int) {
      lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(lastLocationUpdate);
    } else if (lastLocationUpdate is Timestamp) {
      lastUpdateDate = lastLocationUpdate.toDate();
    } else {
      return 'Unknown';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastUpdateDate);
    
    if (difference.inMinutes < 1) {
      return 'Location updated just now';
    } else if (difference.inMinutes < 60) {
      return 'Location ${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return 'Location ${difference.inHours} hr ago';
    } else {
      return 'Location ${difference.inDays} days ago';
    }
  }
  
  /// Stop presence service
  static Future<void> stop() async {
    _log('Stopping location-based presence service');
    
    _log('Location-based presence service stopped - presence now determined by location sharing status');
  }
  
  /// Cleanup presence service
  static Future<void> cleanup() async {
    await stop();
  }
  
  static void _log(String message) {
    if (kDebugMode) {
      developer.log('PRESENCE_SERVICE: $message');
    }
  }
}