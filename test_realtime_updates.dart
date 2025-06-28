import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple test to verify real-time location updates are working
/// 
/// This test creates a simple UI that shows:
/// 1. Current user's location sharing status
/// 2. List of all users sharing their location
/// 3. Real-time updates when locations change
/// 
/// To test:
/// 1. Run this on multiple devices/emulators
/// 2. Toggle location sharing on one device
/// 3. Verify other devices see the update immediately
/// 4. Move around and verify location updates appear on other devices

class RealtimeLocationTest extends StatefulWidget {
  final String userId;
  
  const RealtimeLocationTest({super.key, required this.userId});

  @override
  State<RealtimeLocationTest> createState() => _RealtimeLocationTestState();
}

class _RealtimeLocationTestState extends State<RealtimeLocationTest> {
  bool _isSharing = false;
  Map<String, Map<String, dynamic>> _allUsers = {};
  
  @override
  void initState() {
    super.initState();
    _listenToAllUsers();
    _loadCurrentUserStatus();
  }
  
  void _listenToAllUsers() {
    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      final users = <String, Map<String, dynamic>>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        users[doc.id] = {
          'locationSharingEnabled': data['locationSharingEnabled'] ?? false,
          'location': data['location'],
          'lastOnline': data['lastOnline'],
        };
      }
      
      setState(() {
        _allUsers = users;
      });
    });
  }
  
  void _loadCurrentUserStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    
    if (doc.exists) {
      setState(() {
        _isSharing = doc.data()?['locationSharingEnabled'] ?? false;
      });
    }
  }
  
  void _toggleLocationSharing() async {
    final newStatus = !_isSharing;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({
      'locationSharingEnabled': newStatus,
      'locationSharingUpdatedAt': FieldValue.serverTimestamp(),
      'lastOnline': FieldValue.serverTimestamp(),
      if (newStatus) 'location': {
        'lat': 37.7749 + (DateTime.now().millisecond / 100000), // Mock location with slight variation
        'lng': -122.4194 + (DateTime.now().millisecond / 100000),
        'updatedAt': FieldValue.serverTimestamp(),
      } else 'location': null,
    });
    
    setState(() {
      _isSharing = newStatus;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final sharingUsers = _allUsers.entries
        .where((entry) => entry.value['locationSharingEnabled'] == true)
        .toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Location Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current user status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Status (${widget.userId.substring(0, 8)})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Location Sharing: '),
                        Switch(
                          value: _isSharing,
                          onChanged: (_) => _toggleLocationSharing(),
                        ),
                        Text(_isSharing ? 'ON' : 'OFF'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // All users list
            Text(
              'All Users (${_allUsers.length} total, ${sharingUsers.length} sharing)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            
            const SizedBox(height: 8),
            
            Expanded(
              child: ListView.builder(
                itemCount: _allUsers.length,
                itemBuilder: (context, index) {
                  final entry = _allUsers.entries.elementAt(index);
                  final userId = entry.key;
                  final userData = entry.value;
                  final isSharing = userData['locationSharingEnabled'] ?? false;
                  final location = userData['location'];
                  
                  return Card(
                    color: userId == widget.userId 
                        ? Colors.blue.shade50 
                        : (isSharing ? Colors.green.shade50 : Colors.grey.shade100),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSharing ? Colors.green : Colors.grey,
                        child: Icon(
                          isSharing ? Icons.location_on : Icons.location_off,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        userId == widget.userId 
                            ? 'You (${userId.substring(0, 8)})' 
                            : 'User ${userId.substring(0, 8)}',
                        style: TextStyle(
                          fontWeight: userId == widget.userId 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSharing ? 'Sharing location' : 'Not sharing',
                            style: TextStyle(
                              color: isSharing ? Colors.green : Colors.grey,
                            ),
                          ),
                          if (location != null && location['lat'] != null)
                            Text(
                              'Lat: ${location['lat'].toStringAsFixed(4)}, '
                              'Lng: ${location['lng'].toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: isSharing 
                          ? const Icon(Icons.circle, color: Colors.green, size: 12)
                          : const Icon(Icons.circle, color: Colors.grey, size: 12),
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