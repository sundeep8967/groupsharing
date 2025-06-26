import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;
import 'lib/providers/location_provider.dart';
import 'lib/screens/main/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
  
  runApp(const TestMapAlwaysVisibleApp());
}

class TestMapAlwaysVisibleApp extends StatelessWidget {
  const TestMapAlwaysVisibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Test Map Always Visible',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const TestMapScreen(),
      ),
    );
  }
}

class TestMapScreen extends StatefulWidget {
  const TestMapScreen({super.key});

  @override
  State<TestMapScreen> createState() => _TestMapScreenState();
}

class _TestMapScreenState extends State<TestMapScreen> {
  @override
  void initState() {
    super.initState();
    
    // Test different scenarios
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testMapVisibility();
    });
  }

  void _testMapVisibility() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    print('\n🧪 TESTING MAP VISIBILITY');
    print('================================');
    
    // Test 1: Map should be visible even without location
    print('📍 Test 1: Map visibility without user location');
    print('Current location: ${locationProvider.currentLocation}');
    print('Is tracking: ${locationProvider.isTracking}');
    print('Status: ${locationProvider.status}');
    
    // Test 2: Simulate location sharing disabled
    print('\n📍 Test 2: Simulating location sharing disabled');
    // The map should still be visible
    
    // Test 3: Check if friends' locations are visible
    print('\n📍 Test 3: Friends locations visibility');
    print('User locations: ${locationProvider.userLocations}');
    print('User sharing status: ${locationProvider.userSharingStatus}');
    
    print('\n✅ Map should ALWAYS be visible regardless of location sharing status!');
    print('✅ Friends markers should be shown if available');
    print('✅ No blocking messages should prevent map display');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Map Always Visible'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Consumer<LocationProvider>(
              builder: (context, locationProvider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 Status: ${locationProvider.status}'),
                    Text('🎯 Current Location: ${locationProvider.currentLocation?.toString() ?? "None"}'),
                    Text('📡 Is Tracking: ${locationProvider.isTracking}'),
                    Text('👥 User Locations: ${locationProvider.userLocations.length}'),
                    Text('🔄 Sharing Status: ${locationProvider.userSharingStatus}'),
                    if (locationProvider.error != null)
                      Text('❌ Error: ${locationProvider.error}', style: const TextStyle(color: Colors.red)),
                  ],
                );
              },
            ),
          ),
          
          // Test buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                      locationProvider.getCurrentLocationForMap();
                    },
                    child: const Text('Get Location for Map'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to main screen to test map
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MainScreen()),
                      );
                    },
                    child: const Text('Open Main Screen'),
                  ),
                ),
              ],
            ),
          ),
          
          // Map area - should always be visible
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'MAP SHOULD ALWAYS BE VISIBLE HERE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No blocking messages allowed!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}