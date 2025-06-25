import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:groupsharing/providers/location_provider.dart';
import 'package:groupsharing/providers/auth_provider.dart' as app_auth;
import 'dart:async';

/// Simple debug screen to see what's happening with real-time updates
/// Add this as a new tab or screen in your app to see live debug info
class SimpleDebugScreen extends StatefulWidget {
  const SimpleDebugScreen({super.key});

  @override
  State<SimpleDebugScreen> createState() => _SimpleDebugScreenState();
}

class _SimpleDebugScreenState extends State<SimpleDebugScreen> {
  final List<String> _logs = [];
  StreamSubscription<QuerySnapshot>? _debugSubscription;
  int _updateCount = 0;
  
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
    _log('🔍 Starting debug listener...');
    
    _debugSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      _updateCount++;
      _log('📡 Firebase update #$_updateCount: ${snapshot.docs.length} users');
      
      int sharingCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isSharing = data['locationSharingEnabled'] ?? false;
        if (isSharing) {
          sharingCount++;
          final location = data['location'];
          _log('👤 ${doc.id.substring(0, 8)}: sharing=${isSharing}, location=${location != null ? "YES" : "NO"}');
        }
      }
      _log('✅ Total users sharing: $sharingCount');
    }, onError: (error) {
      _log('❌ Firebase error: $error');
    });
  }
  
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    if (mounted) {
      setState(() {
        _logs.insert(0, '[$timestamp] $message');
        if (_logs.length > 50) _logs.removeLast();
      });
    }
    // Also print to console
    debugPrint('SIMPLE_DEBUG: $message');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Real-time'),
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
              // Quick Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔄 Provider Tracking: ${locationProvider.isTracking}'),
                    Text('📍 User Locations: ${locationProvider.userLocations.length}'),
                    Text('📡 Firebase Updates: $_updateCount'),
                    Text('👤 Current User: ${authProvider.user?.uid.substring(0, 8) ?? "None"}'),
                  ],
                ),
              ),
              
              // Test Buttons
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
                              _log('🛑 Stopped tracking via button');
                            } else {
                              locationProvider.startTracking(user.uid);
                              _log('▶️ Started tracking via button');
                            }
                          } else {
                            _log('❌ No user logged in');
                          }
                        },
                        child: Text(locationProvider.isTracking ? 'Stop' : 'Start'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _log('🔄 Manual refresh requested');
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
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _logs.isEmpty
                      ? const Center(
                          child: Text(
                            'Waiting for debug logs...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Text(
                              _logs[index],
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            );
                          },
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

// Add this to your main app navigation to access the debug screen
// For example, add it as a floating action button or menu item:
/*
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleDebugScreen()),
    );
  },
  child: const Icon(Icons.bug_report),
)
*/