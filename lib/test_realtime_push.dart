import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:groupsharing/providers/location_provider.dart';
import 'package:groupsharing/providers/auth_provider.dart' as app_auth;
import 'dart:async';

/// Test screen to verify REAL-TIME PUSH NOTIFICATIONS are working
/// This tests that changes on one device instantly push to other devices
class TestRealtimePush extends StatefulWidget {
  const TestRealtimePush({super.key});

  @override
  State<TestRealtimePush> createState() => _TestRealtimePushState();
}

class _TestRealtimePushState extends State<TestRealtimePush> {
  final List<String> _pushLogs = [];
  final List<String> _performanceLogs = [];
  
  StreamSubscription<DatabaseEvent>? _testStatusSubscription;
  StreamSubscription<DatabaseEvent>? _testLocationSubscription;
  
  bool? _realtimeToggleStatus;
  Map<String, dynamic>? _realtimeLocationData;
  
  DateTime? _lastToggleTime;
  DateTime? _lastLocationTime;
  
  @override
  void initState() {
    super.initState();
    _startRealtimePushTesting();
  }
  
  @override
  void dispose() {
    _testStatusSubscription?.cancel();
    _testLocationSubscription?.cancel();
    super.dispose();
  }
  
  void _startRealtimePushTesting() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    if (userId == null) {
      _addPushLog('ERROR: No user logged in');
      return;
    }
    
    _addPushLog('Starting REAL-TIME PUSH testing for user: ${userId.substring(0, 8)}');
    
    // Test 1: Listen for toggle status changes with performance measurement
    _testStatusSubscription = FirebaseDatabase.instance
        .ref('users/$userId/locationSharingEnabled')
        .onValue
        .listen((event) {
      final now = DateTime.now();
      final value = event.snapshot.exists ? event.snapshot.value as bool? : null;
      
      setState(() => _realtimeToggleStatus = value);
      
      if (_lastToggleTime != null) {
        final latency = now.difference(_lastToggleTime!).inMilliseconds;
        _addPerformanceLog('Toggle push latency: ${latency}ms');
      }
      
      _addPushLog('PUSH RECEIVED: Toggle status = $value');
    });
    
    // Test 2: Listen for location changes with performance measurement
    _testLocationSubscription = FirebaseDatabase.instance
        .ref('locations/$userId')
        .onValue
        .listen((event) {
      final now = DateTime.now();
      final data = event.snapshot.exists ? event.snapshot.value as Map<dynamic, dynamic>? : null;
      
      setState(() => _realtimeLocationData = data?.cast<String, dynamic>());
      
      if (_lastLocationTime != null) {
        final latency = now.difference(_lastLocationTime!).inMilliseconds;
        _addPerformanceLog('Location push latency: ${latency}ms');
      }
      
      if (data != null) {
        _addPushLog('PUSH RECEIVED: Location = ${data['lat']}, ${data['lng']}');
      } else {
        _addPushLog('PUSH RECEIVED: Location cleared');
      }
    });
  }
  
  void _addPushLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _pushLogs.insert(0, '[$timestamp] $message');
      if (_pushLogs.length > 20) _pushLogs.removeLast();
    });
    print('PUSH_TEST: $message');
  }
  
  void _addPerformanceLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _performanceLogs.insert(0, '[$timestamp] $message');
      if (_performanceLogs.length > 10) _performanceLogs.removeLast();
    });
    print('PERFORMANCE: $message');
  }
  
  Future<void> _testTogglePush(bool value) async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    if (userId == null) return;
    
    _lastToggleTime = DateTime.now();
    _addPushLog('SENDING: Toggle change to $value');
    
    try {
      await FirebaseDatabase.instance
          .ref('users/$userId/locationSharingEnabled')
          .set(value);
      _addPushLog('SUCCESS: Toggle sent to Realtime DB');
    } catch (e) {
      _addPushLog('ERROR: Failed to send toggle - $e');
    }
  }
  
  Future<void> _testLocationPush() async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    if (userId == null) return;
    
    _lastLocationTime = DateTime.now();
    
    // Generate random location for testing
    final lat = 37.7749 + (DateTime.now().millisecond / 1000.0 - 0.5) * 0.01;
    final lng = -122.4194 + (DateTime.now().millisecond / 1000.0 - 0.5) * 0.01;
    
    _addPushLog('SENDING: Location change to $lat, $lng');
    
    try {
      await FirebaseDatabase.instance
          .ref('locations/$userId')
          .set({
        'lat': lat,
        'lng': lng,
        'isSharing': true,
        'updatedAt': ServerValue.timestamp,
      });
      _addPushLog('SUCCESS: Location sent to Realtime DB');
    } catch (e) {
      _addPushLog('ERROR: Failed to send location - $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Real-time Push'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() {
              _pushLogs.clear();
              _performanceLogs.clear();
            }),
          ),
        ],
      ),
      body: Consumer2<LocationProvider, app_auth.AuthProvider>(
        builder: (context, locationProvider, authProvider, _) {
          return Column(
            children: [
              // Status Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REAL-TIME PUSH NOTIFICATION TEST',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('User: ${authProvider.user?.uid?.substring(0, 8) ?? "Not logged in"}'),
                    Text('Provider Status: ${locationProvider.isTracking ? "ON" : "OFF"}'),
                    Text('Realtime Toggle: ${_realtimeToggleStatus ?? "NULL"}'),
                    if (_realtimeLocationData != null)
                      Text('Realtime Location: ${_realtimeLocationData!['lat']?.toStringAsFixed(4)}, ${_realtimeLocationData!['lng']?.toStringAsFixed(4)}')
                    else
                      const Text('Realtime Location: NULL'),
                  ],
                ),
              ),
              
              // Performance Metrics
              if (_performanceLogs.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PERFORMANCE METRICS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...(_performanceLogs.take(3).map((log) => Text(
                        log,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontFamily: 'monospace',
                        ),
                      ))),
                    ],
                  ),
                ),
              
              // Test Controls
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'PUSH NOTIFICATION TESTS',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Toggle Tests
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _testTogglePush(true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Push: Enable'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _testTogglePush(false),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Push: Disable'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Location Test
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _testLocationPush,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('Push: Random Location'),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Provider Test
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final user = authProvider.user;
                          if (user != null) {
                            if (locationProvider.isTracking) {
                              locationProvider.stopTracking();
                            } else {
                              locationProvider.startTracking(user.uid);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: Text(
                          locationProvider.isTracking 
                              ? 'Provider: Stop Tracking'
                              : 'Provider: Start Tracking',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Push Logs
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
                        'REAL-TIME PUSH LOGS:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _pushLogs.length,
                          itemBuilder: (context, index) {
                            final log = _pushLogs[index];
                            Color textColor = Colors.green;
                            
                            if (log.contains('ERROR')) {
                              textColor = Colors.red;
                            } else if (log.contains('PUSH RECEIVED')) {
                              textColor = Colors.cyan;
                            } else if (log.contains('SENDING')) {
                              textColor = Colors.yellow;
                            }
                            
                            return Text(
                              log,
                              style: TextStyle(
                                color: textColor,
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
}