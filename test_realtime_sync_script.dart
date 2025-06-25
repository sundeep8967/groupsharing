import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Simple script to test real-time synchronization
/// Run this with: flutter run test_realtime_sync_script.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RealtimeSyncTestApp());
}

class RealtimeSyncTestApp extends StatelessWidget {
  const RealtimeSyncTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Sync Test',
      home: const RealtimeSyncTest(),
    );
  }
}

class RealtimeSyncTest extends StatefulWidget {
  const RealtimeSyncTest({super.key});

  @override
  State<RealtimeSyncTest> createState() => _RealtimeSyncTestState();
}

class _RealtimeSyncTestState extends State<RealtimeSyncTest> {
  final String testUserId = 'test_user_123';
  final List<String> _logs = [];
  
  StreamSubscription<DatabaseEvent>? _realtimeSubscription;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  
  bool? _realtimeValue;
  bool? _firestoreValue;
  
  @override
  void initState() {
    super.initState();
    _startListening();
  }
  
  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
  
  void _startListening() {
    _log('Starting listeners for test user: $testUserId');
    
    // Listen to Realtime Database
    _realtimeSubscription = FirebaseDatabase.instance
        .ref('users/$testUserId/locationSharingEnabled')
        .onValue
        .listen((event) {
      final value = event.snapshot.exists ? event.snapshot.value as bool? : null;
      setState(() => _realtimeValue = value);
      _log('Realtime DB: $value');
    });
    
    // Listen to Firestore
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(testUserId)
        .snapshots()
        .listen((snapshot) {
      final value = snapshot.exists ? snapshot.data()?['locationSharingEnabled'] as bool? : null;
      setState(() => _firestoreValue = value);
      _log('Firestore: $value');
    });
  }
  
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 20) _logs.removeLast();
    });
    print('SYNC_TEST: $message');
  }
  
  Future<void> _updateRealtimeDB(bool value) async {
    _log('Updating Realtime DB to: $value');
    try {
      await FirebaseDatabase.instance
          .ref('users/$testUserId/locationSharingEnabled')
          .set(value);
      _log('Realtime DB update successful');
    } catch (e) {
      _log('Realtime DB update failed: $e');
    }
  }
  
  Future<void> _updateFirestore(bool value) async {
    _log('Updating Firestore to: $value');
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(testUserId)
          .set({
        'locationSharingEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _log('Firestore update successful');
    } catch (e) {
      _log('Firestore update failed: $e');
    }
  }
  
  Future<void> _updateBoth(bool value) async {
    _log('Updating both databases to: $value');
    await Future.wait([
      _updateRealtimeDB(value),
      _updateFirestore(value),
    ]);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Sync Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Text('Test User ID: $testUserId', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        title: 'Realtime DB',
                        value: _realtimeValue,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatusCard(
                        title: 'Firestore',
                        value: _firestoreValue,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isInSync() ? Colors.green.shade50 : Colors.red.shade50,
                    border: Border.all(
                      color: _isInSync() ? Colors.green : Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _isInSync() ? '✅ In Sync' : '❌ Out of Sync',
                    style: TextStyle(
                      color: _isInSync() ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
                        onPressed: () => _updateRealtimeDB(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('RT DB: TRUE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateRealtimeDB(false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('RT DB: FALSE'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateFirestore(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Firestore: TRUE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateFirestore(false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Firestore: FALSE'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateBoth(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: const Text('Both: TRUE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateBoth(false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: const Text('Both: FALSE'),
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
                    'Logs:',
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
      ),
    );
  }
  
  bool _isInSync() {
    if (_realtimeValue == null && _firestoreValue == null) return true;
    return _realtimeValue == _firestoreValue;
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final bool? value;
  final Color color;
  
  const _StatusCard({
    required this.title,
    required this.value,
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
            value == null ? 'NULL' : (value! ? 'TRUE' : 'FALSE'),
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