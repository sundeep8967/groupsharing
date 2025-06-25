import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:groupsharing/providers/location_provider.dart';
import 'package:groupsharing/providers/auth_provider.dart' as app_auth;
import 'dart:async';

/// Test screen to verify instant synchronization across devices
/// This screen shows real-time updates from both Realtime Database and Firestore
class TestInstantSync extends StatefulWidget {
  const TestInstantSync({super.key});

  @override
  State<TestInstantSync> createState() => _TestInstantSyncState();
}

class _TestInstantSyncState extends State<TestInstantSync> {
  final List<String> _logs = [];
  StreamSubscription<DatabaseEvent>? _realtimeSubscription;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  
  bool? _realtimeStatus;
  bool? _firestoreStatus;
  bool? _providerStatus;
  
  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }
  
  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
  
  void _startMonitoring() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    if (userId == null) {
      _log('No user logged in');
      return;
    }
    
    _log('Starting monitoring for user: ${userId.substring(0, 8)}');
    
    // Monitor Realtime Database
    _realtimeSubscription = FirebaseDatabase.instance
        .ref('users/$userId/locationSharingEnabled')
        .onValue
        .listen((event) {
      final status = event.snapshot.exists ? event.snapshot.value as bool? : null;
      setState(() => _realtimeStatus = status);
      _log('Realtime DB update: $status');
    });
    
    // Monitor Firestore
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      final status = snapshot.exists ? (snapshot.data()?['locationSharingEnabled'] as bool?) : null;
      setState(() => _firestoreStatus = status);
      _log('Firestore update: $status');
    });
  }
  
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 30) _logs.removeLast();
    });
    debugPrint('SYNC_TEST: $message');
  }
  
  Future<void> _testDirectUpdate(bool value) async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    if (userId == null) return;
    
    _log('Testing direct update to: $value');
    
    try {
      // Update Realtime Database directly
      await FirebaseDatabase.instance
          .ref('users/$userId/locationSharingEnabled')
          .set(value);
      _log('Direct Realtime DB update successful');
      
      // Update Firestore directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'locationSharingEnabled': value});
      _log('Direct Firestore update successful');
    } catch (e) {
      _log('Error in direct update: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Instant Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Consumer2<LocationProvider, app_auth.AuthProvider>(
        builder: (context, locationProvider, authProvider, _) {
          _providerStatus = locationProvider.isTracking;
          
          return Column(
            children: [
              // Status Cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        title: 'Realtime DB',
                        status: _realtimeStatus,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusCard(
                        title: 'Firestore',
                        status: _firestoreStatus,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusCard(
                        title: 'Provider',
                        status: _providerStatus,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Sync Status
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isInSync() ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(
                    color: _isInSync() ? Colors.green : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isInSync() ? '✅ All sources in sync' : '❌ Sources out of sync',
                  style: TextStyle(
                    color: _isInSync() ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Control Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final user = authProvider.user;
                              if (user != null) {
                                if (locationProvider.isTracking) {
                                  locationProvider.stopTracking();
                                  _log('Provider: Stopped tracking');
                                } else {
                                  locationProvider.startTracking(user.uid);
                                  _log('Provider: Started tracking');
                                }
                              }
                            },
                            child: Text(locationProvider.isTracking ? 'Stop via Provider' : 'Start via Provider'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _testDirectUpdate(true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Direct Enable'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _testDirectUpdate(false),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Direct Disable'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Logs
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Real-time Logs:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Text(
                              _logs[index],
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  bool _isInSync() {
    if (_realtimeStatus == null || _firestoreStatus == null || _providerStatus == null) {
      return false;
    }
    return _realtimeStatus == _firestoreStatus && _firestoreStatus == _providerStatus;
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final bool? status;
  final Color color;
  
  const _StatusCard({
    required this.title,
    required this.status,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status == null ? 'NULL' : (status! ? 'ON' : 'OFF'),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}