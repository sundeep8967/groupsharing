import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:groupsharing/providers/location_provider.dart';
import 'package:groupsharing/providers/auth_provider.dart' as app_auth;

/// Debug screen to monitor real-time location updates
/// This will help us see exactly what's happening with the Firebase listeners
class DebugRealtimeLocation extends StatefulWidget {
  const DebugRealtimeLocation({super.key});

  @override
  State<DebugRealtimeLocation> createState() => _DebugRealtimeLocationState();
}

class _DebugRealtimeLocationState extends State<DebugRealtimeLocation> {
  final List<String> _logs = [];
  StreamSubscription<QuerySnapshot>? _debugSubscription;
  
  @override
  void initState() {
    super.initState();
    _startDebugListener();
  }
  
  @override
  void dispose() {
    _debugSubscription?.cancel();
    super.dispose();
  }
  
  void _startDebugListener() {
    _log('Starting debug listener...');
    
    _debugSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      _log('Firebase snapshot received: ${snapshot.docs.length} users');
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isSharing = data['locationSharingEnabled'] ?? false;
        final location = data['location'];
        
        if (isSharing) {
          _log('User ${doc.id.substring(0, 8)}: sharing=${isSharing}, location=${location != null ? "YES" : "NO"}');
        }
      }
    }, onError: (error) {
      _log('ERROR: $error');
    });
  }
  
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 50) _logs.removeLast();
    });
    debugPrint('DEBUG: $message');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Real-time Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Consumer2<LocationProvider, app_auth.AuthProvider>(
        builder: (context, locationProvider, authProvider, _) {
          return Column(
            children: [
              // Provider Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Provider Status:', style: Theme.of(context).textTheme.titleMedium),
                    Text('Tracking: ${locationProvider.isTracking}'),
                    Text('User Locations: ${locationProvider.userLocations.length}'),
                    Text('Status: ${locationProvider.status}'),
                    if (locationProvider.error != null)
                      Text('Error: ${locationProvider.error}', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              
              // User Locations
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.green.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Locations (${locationProvider.userLocations.length}):', 
                         style: Theme.of(context).textTheme.titleMedium),
                    ...locationProvider.userLocations.entries.map((entry) =>
                      Text('${entry.key.substring(0, 8)}: ${entry.value.latitude.toStringAsFixed(4)}, ${entry.value.longitude.toStringAsFixed(4)}')
                    ),
                  ],
                ),
              ),
              
              // Control Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final user = authProvider.user;
                          if (user != null) {
                            if (locationProvider.isTracking) {
                              locationProvider.stopTracking();
                              _log('Stopped tracking via button');
                            } else {
                              locationProvider.startTracking(user.uid);
                              _log('Started tracking via button');
                            }
                          }
                        },
                        child: Text(locationProvider.isTracking ? 'Stop Tracking' : 'Start Tracking'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _log('Manual refresh requested');
                          // Force a manual update
                          setState(() {});
                        },
                        child: const Text('Refresh'),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Debug Logs
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Debug Logs:', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
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