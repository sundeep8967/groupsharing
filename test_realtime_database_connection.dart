import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RealtimeDatabaseTestApp());
}

class RealtimeDatabaseTestApp extends StatelessWidget {
  const RealtimeDatabaseTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Database Test',
      home: const RealtimeDatabaseTestScreen(),
    );
  }
}

class RealtimeDatabaseTestScreen extends StatefulWidget {
  const RealtimeDatabaseTestScreen({super.key});

  @override
  State<RealtimeDatabaseTestScreen> createState() => _RealtimeDatabaseTestScreenState();
}

class _RealtimeDatabaseTestScreenState extends State<RealtimeDatabaseTestScreen> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final List<String> _logs = [];
  bool _isConnected = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _testRealtimeDatabase();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String()}: $message');
    });
    print(message);
  }

  Future<void> _testRealtimeDatabase() async {
    try {
      _addLog('🔄 Starting Realtime Database test...');
      
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No authenticated user found');
        return;
      }
      
      _currentUserId = user.uid;
      _addLog('✅ Authenticated user: ${user.uid.substring(0, 8)}');
      
      // Test connection
      _addLog('🔄 Testing database connection...');
      
      // Listen to connection state
      _database.ref('.info/connected').onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        setState(() {
          _isConnected = connected;
        });
        _addLog(connected ? '✅ Database connected' : '❌ Database disconnected');
      });
      
      // Test writing to users node
      _addLog('🔄 Testing write to users node...');
      await _database.ref('users/${user.uid}').set({
        'locationSharingEnabled': true,
        'lastSeen': ServerValue.timestamp,
        'testWrite': true,
      });
      _addLog('✅ Successfully wrote to users node');
      
      // Test writing to locations node
      _addLog('🔄 Testing write to locations node...');
      await _database.ref('locations/${user.uid}').set({
        'lat': 37.7749,
        'lng': -122.4194,
        'timestamp': ServerValue.timestamp,
        'isSharing': true,
        'accuracy': 10.0,
      });
      _addLog('✅ Successfully wrote to locations node');
      
      // Test reading from users node
      _addLog('🔄 Testing read from users node...');
      final usersSnapshot = await _database.ref('users').once();
      if (usersSnapshot.snapshot.exists) {
        final usersData = usersSnapshot.snapshot.value as Map<dynamic, dynamic>?;
        _addLog('✅ Successfully read users data: ${usersData?.keys.length ?? 0} users');
      } else {
        _addLog('⚠️ No users data found');
      }
      
      // Test reading from locations node
      _addLog('🔄 Testing read from locations node...');
      final locationsSnapshot = await _database.ref('locations').once();
      if (locationsSnapshot.snapshot.exists) {
        final locationsData = locationsSnapshot.snapshot.value as Map<dynamic, dynamic>?;
        _addLog('✅ Successfully read locations data: ${locationsData?.keys.length ?? 0} locations');
      } else {
        _addLog('⚠️ No locations data found');
      }
      
      // Test realtime listeners
      _addLog('🔄 Setting up realtime listeners...');
      
      // Listen to users changes
      _database.ref('users').onValue.listen((event) {
        if (event.snapshot.exists) {
          final usersData = event.snapshot.value as Map<dynamic, dynamic>?;
          _addLog('📡 Users data updated: ${usersData?.keys.length ?? 0} users');
        }
      }, onError: (error) {
        _addLog('❌ Error listening to users: $error');
      });
      
      // Listen to locations changes
      _database.ref('locations').onValue.listen((event) {
        if (event.snapshot.exists) {
          final locationsData = event.snapshot.value as Map<dynamic, dynamic>?;
          _addLog('📡 Locations data updated: ${locationsData?.keys.length ?? 0} locations');
        }
      }, onError: (error) {
        _addLog('❌ Error listening to locations: $error');
      });
      
      _addLog('✅ Realtime Database test completed successfully!');
      
    } catch (e) {
      _addLog('❌ Error during test: $e');
    }
  }

  Future<void> _updateLocation() async {
    if (_currentUserId == null) return;
    
    try {
      _addLog('🔄 Updating location...');
      await _database.ref('locations/$_currentUserId').update({
        'lat': 37.7749 + (DateTime.now().millisecondsSinceEpoch % 1000) / 100000,
        'lng': -122.4194 + (DateTime.now().millisecondsSinceEpoch % 1000) / 100000,
        'timestamp': ServerValue.timestamp,
        'isSharing': true,
      });
      _addLog('✅ Location updated successfully');
    } catch (e) {
      _addLog('❌ Error updating location: $e');
    }
  }

  Future<void> _toggleSharing() async {
    if (_currentUserId == null) return;
    
    try {
      _addLog('🔄 Toggling sharing status...');
      final snapshot = await _database.ref('users/$_currentUserId/locationSharingEnabled').once();
      final currentStatus = snapshot.snapshot.value as bool? ?? false;
      
      await _database.ref('users/$_currentUserId').update({
        'locationSharingEnabled': !currentStatus,
        'lastSeen': ServerValue.timestamp,
      });
      _addLog('✅ Sharing status toggled to ${!currentStatus}');
    } catch (e) {
      _addLog('❌ Error toggling sharing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Database Test'),
        backgroundColor: _isConnected ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            child: Text(
              _isConnected ? '✅ Connected to Realtime Database' : '❌ Disconnected from Realtime Database',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateLocation,
                    child: const Text('Update Location'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleSharing,
                    child: const Text('Toggle Sharing'),
                  ),
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
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}