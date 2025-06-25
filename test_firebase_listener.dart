import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Minimal test to verify Firebase real-time listeners are working
/// This bypasses all the complex provider logic and tests Firebase directly
class TestFirebaseListener extends StatefulWidget {
  const TestFirebaseListener({super.key});

  @override
  State<TestFirebaseListener> createState() => _TestFirebaseListenerState();
}

class _TestFirebaseListenerState extends State<TestFirebaseListener> {
  StreamSubscription<QuerySnapshot>? _subscription;
  List<Map<String, dynamic>> _users = [];
  int _updateCount = 0;
  
  @override
  void initState() {
    super.initState();
    _startListening();
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  
  void _startListening() {
    debugPrint('Starting Firebase listener...');
    
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      debugPrint('Firebase snapshot received: ${snapshot.docs.length} users');
      
      setState(() {
        _updateCount++;
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'locationSharingEnabled': data['locationSharingEnabled'] ?? false,
            'location': data['location'],
            'lastOnline': data['lastOnline'],
          };
        }).toList();
      });
      
      // Log sharing users
      final sharingUsers = _users.where((u) => u['locationSharingEnabled'] == true).toList();
      debugPrint('Users sharing location: ${sharingUsers.length}');
      for (final user in sharingUsers) {
        final location = user['location'];
        debugPrint('  ${user['id'].substring(0, 8)}: ${location != null ? "HAS LOCATION" : "NO LOCATION"}');
      }
    }, onError: (error) {
      debugPrint('Firebase listener error: $error');
    });
  }
  
  Future<void> _toggleRandomUser() async {
    if (_users.isEmpty) return;
    
    // Pick a random user
    final user = _users[DateTime.now().millisecond % _users.length];
    final userId = user['id'];
    final currentSharing = user['locationSharingEnabled'] ?? false;
    final newSharing = !currentSharing;
    
    debugPrint('Toggling user ${userId.substring(0, 8)} from $currentSharing to $newSharing');
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'locationSharingEnabled': newSharing,
        'locationSharingUpdatedAt': FieldValue.serverTimestamp(),
        'lastOnline': FieldValue.serverTimestamp(),
        if (newSharing) 'location': {
          'lat': 37.7749 + (DateTime.now().millisecond / 100000),
          'lng': -122.4194 + (DateTime.now().millisecond / 100000),
          'updatedAt': FieldValue.serverTimestamp(),
        } else 'location': null,
      });
      
      debugPrint('Successfully updated user $userId');
    } catch (e) {
      debugPrint('Error updating user: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final sharingUsers = _users.where((u) => u['locationSharingEnabled'] == true).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Listener Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _subscription?.cancel();
              _startListening();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Firebase Listener Stats', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Total Users: ${_users.length}'),
                    Text('Sharing Location: ${sharingUsers.length}'),
                    Text('Updates Received: $_updateCount'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _users.isNotEmpty ? _toggleRandomUser : null,
                child: const Text('Toggle Random User Location Sharing'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Users List
            Text('All Users:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isSharing = user['locationSharingEnabled'] ?? false;
                  final location = user['location'];
                  
                  return Card(
                    color: isSharing ? Colors.green.shade50 : Colors.grey.shade100,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSharing ? Colors.green : Colors.grey,
                        child: Icon(
                          isSharing ? Icons.location_on : Icons.location_off,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      title: Text('User ${user['id'].substring(0, 8)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSharing ? 'Sharing location' : 'Not sharing',
                            style: TextStyle(
                              color: isSharing ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (location != null && location['lat'] != null)
                            Text(
                              'Lat: ${location['lat'].toStringAsFixed(4)}, Lng: ${location['lng'].toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isSharing ? Icons.toggle_on : Icons.toggle_off,
                          color: isSharing ? Colors.green : Colors.grey,
                        ),
                        onPressed: () async {
                          final userId = user['id'];
                          final newSharing = !isSharing;
                          
                          await FirebaseFirestore.instance.collection('users').doc(userId).update({
                            'locationSharingEnabled': newSharing,
                            'locationSharingUpdatedAt': FieldValue.serverTimestamp(),
                            'lastOnline': FieldValue.serverTimestamp(),
                            if (newSharing) 'location': {
                              'lat': 37.7749 + (DateTime.now().millisecond / 100000),
                              'lng': -122.4194 + (DateTime.now().millisecond / 100000),
                              'updatedAt': FieldValue.serverTimestamp(),
                            } else 'location': null,
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}