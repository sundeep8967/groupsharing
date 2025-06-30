import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'lib/firebase_options.dart';
import 'lib/providers/location_provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LocationProviderTestApp());
}

class LocationProviderTestApp extends StatelessWidget {
  const LocationProviderTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Location Provider Test',
        home: const LocationProviderTestScreen(),
      ),
    );
  }
}

class LocationProviderTestScreen extends StatefulWidget {
  const LocationProviderTestScreen({super.key});

  @override
  State<LocationProviderTestScreen> createState() => _LocationProviderTestScreenState();
}

class _LocationProviderTestScreenState extends State<LocationProviderTestScreen> {
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _testLocationProvider();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String()}: $message');
    });
    print(message);
  }

  Future<void> _testLocationProvider() async {
    try {
      _addLog('🔄 Starting Location Provider test...');
      
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No authenticated user found');
        return;
      }
      
      _addLog('✅ Authenticated user: ${user.uid.substring(0, 8)}');
      
      // Get location provider
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // Test initialization
      _addLog('🔄 Testing location provider initialization...');
      final initialized = await locationProvider.initialize();
      _addLog(initialized ? '✅ Location provider initialized' : '❌ Location provider failed to initialize');
      
      // Test starting tracking
      _addLog('🔄 Testing location tracking start...');
      final trackingStarted = await locationProvider.startTracking(user.uid);
      _addLog(trackingStarted ? '✅ Location tracking started' : '❌ Location tracking failed to start');
      
      // Wait a bit and check status
      await Future.delayed(const Duration(seconds: 3));
      
      _addLog('📊 Location Provider Status:');
      _addLog('   - Is Initialized: ${locationProvider.isInitialized}');
      _addLog('   - Is Tracking: ${locationProvider.isTracking}');
      _addLog('   - Current User ID: ${locationProvider.currentUserId?.substring(0, 8) ?? 'null'}');
      _addLog('   - Status: ${locationProvider.status}');
      _addLog('   - Error: ${locationProvider.error ?? 'none'}');
      _addLog('   - Current Location: ${locationProvider.currentLocation}');
      _addLog('   - User Locations Count: ${locationProvider.userLocations.length}');
      _addLog('   - User Sharing Status Count: ${locationProvider.userSharingStatus.length}');
      
      // Test user sharing status
      final isSharing = locationProvider.isUserSharingLocation(user.uid);
      _addLog('   - Is User Sharing Location: $isSharing');
      
      _addLog('✅ Location Provider test completed!');
      
    } catch (e) {
      _addLog('❌ Error during test: $e');
    }
  }

  Future<void> _toggleTracking() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      if (locationProvider.isTracking) {
        _addLog('🔄 Stopping location tracking...');
        await locationProvider.stopTracking();
        _addLog('✅ Location tracking stopped');
      } else {
        _addLog('🔄 Starting location tracking...');
        await locationProvider.startTracking(user.uid);
        _addLog('✅ Location tracking started');
      }
    } catch (e) {
      _addLog('❌ Error toggling tracking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Provider Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status display
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: locationProvider.isTracking ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${locationProvider.status}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: locationProvider.isTracking ? Colors.green : Colors.red,
                      ),
                    ),
                    Text('Tracking: ${locationProvider.isTracking}'),
                    Text('Initialized: ${locationProvider.isInitialized}'),
                    Text('User Locations: ${locationProvider.userLocations.length}'),
                    Text('Sharing Status: ${locationProvider.userSharingStatus.length}'),
                    if (locationProvider.error != null)
                      Text('Error: ${locationProvider.error}', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              );
            },
          ),
          
          // Action button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer<LocationProvider>(
              builder: (context, locationProvider, child) {
                return ElevatedButton(
                  onPressed: _toggleTracking,
                  child: Text(locationProvider.isTracking ? 'Stop Tracking' : 'Start Tracking'),
                );
              },
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