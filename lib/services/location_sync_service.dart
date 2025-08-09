import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Holds minimal location data required for sync.
class TrackedLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final DateTime timestamp;

  TrackedLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'timestamp': Timestamp.fromDate(timestamp),
    }..removeWhere((_, v) => v == null);
  }
}

/// Syncs location updates to Firestore with offline queue + retry.
class LocationSyncService {
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity = Connectivity();

  bool _isConnected = true;
  final List<TrackedLocation> _pending = [];
  final String userId;

  LocationSyncService({required this.userId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _monitorConnectivity();
  }

  void _monitorConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      final prev = _isConnected;
      _isConnected = result != ConnectivityResult.none;
      if (!prev && _isConnected && _pending.isNotEmpty) {
        developer.log('Network restored; attempting to send queued location updates',
            name: 'LocationSyncService');
        _flushQueue();
      }
    });
  }

  Future<void> sendLocation(TrackedLocation loc) async {
    if (_isConnected) {
      try {
        await _pushToServer(loc);
      } catch (e) {
        developer.log('Send failed – queued: $e', name: 'LocationSyncService');
        _pending.add(loc);
      }
    } else {
      developer.log('Offline – queued location (${loc.latitude}, ${loc.longitude})',
          name: 'LocationSyncService');
      _pending.add(loc);
    }
  }

  Future<void> _pushToServer(TrackedLocation loc) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('locations')
        .add(loc.toMap());
  }

  Future<void> _flushQueue() async {
    final queue = List<TrackedLocation>.from(_pending);
    _pending.clear();

    for (final loc in queue) {
      try {
        await _pushToServer(loc);
      } catch (e) {
        developer.log('Resend failed – re-queued: $e', name: 'LocationSyncService');
        _pending.add(loc);
      }
    }
  }
}
