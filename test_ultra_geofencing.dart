import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'lib/providers/ultra_geofencing_provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;
import 'lib/services/ultra_geofencing_service.dart';
import 'lib/models/geofence_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const UltraGeofencingTestApp());
}

class UltraGeofencingTestApp extends StatelessWidget {
  const UltraGeofencingTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => UltraGeofencingProvider()),
      ],
      child: MaterialApp(
        title: 'Ultra Geofencing Test',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const UltraGeofencingTestScreen(),
      ),
    );
  }
}

class UltraGeofencingTestScreen extends StatefulWidget {
  const UltraGeofencingTestScreen({super.key});

  @override
  State<UltraGeofencingTestScreen> createState() => _UltraGeofencingTestScreenState();
}

class _UltraGeofencingTestScreenState extends State<UltraGeofencingTestScreen> {
  final final List<String> _logs = [];
  LatLng? _currentLocation;
  final final List<GeofenceModel> _testGeofences = [];

  @override
  void initState() {
    super.initState();
    _testUltraGeofencing();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String()}: $message');
    });
    print(message);
  }

  Future<void> _testUltraGeofencing() async {
    try {
      _addLog('🚀 Starting Ultra Geofencing Test...');
      
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No authenticated user found');
        return;
      }
      
      _addLog('✅ Authenticated user: ${user.uid.substring(0, 8)}');
      
      // Get ultra geofencing provider
      final geofencingProvider = Provider.of<UltraGeofencingProvider>(context, listen: false);
      
      // Test ultra-geofencing service initialization
      _addLog('🔄 Testing Ultra Geofencing Service initialization...');
      final initialized = await UltraGeofencingService.initialize();
      _addLog(initialized ? '✅ Ultra Geofencing Service initialized' : '❌ Ultra Geofencing Service failed to initialize');
      
      // Test starting ultra-active tracking
      _addLog('🔄 Testing ultra-active tracking start...');
      final trackingStarted = await geofencingProvider.startUltraTracking(user.uid);
      _addLog(trackingStarted ? '✅ Ultra-active tracking started' : '❌ Ultra-active tracking failed to start');
      
      // Wait a bit for location
      await Future.delayed(const Duration(seconds: 5));
      
      // Create test geofences
      await _createTestGeofences(geofencingProvider);
      
      // Monitor status
      _monitorStatus(geofencingProvider);
      
      _addLog('✅ Ultra Geofencing Test setup completed!');
      
    } catch (e) {
      _addLog('❌ Error during test: $e');
    }
  }

  Future<void> _createTestGeofences(UltraGeofencingProvider geofencingProvider) async {
    try {
      _addLog('🔄 Creating test geofences...');
      
      // Get current location or use default
      final currentLoc = geofencingProvider.currentLocation ?? const LatLng(37.7749, -122.4194);
      _currentLocation = currentLoc;
      
      // Create geofences around current location
      final geofences = [
        {
          'id': 'home_5m',
          'name': 'Home (5m)',
          'center': currentLoc,
          'radius': 5.0,
        },
        {
          'id': 'work_10m',
          'name': 'Work (10m)',
          'center': LatLng(currentLoc.latitude + 0.0001, currentLoc.longitude + 0.0001), // ~11m away
          'radius': 10.0,
        },
        {
          'id': 'coffee_3m',
          'name': 'Coffee Shop (3m)',
          'center': LatLng(currentLoc.latitude - 0.0001, currentLoc.longitude - 0.0001), // ~11m away
          'radius': 3.0,
        },
      ];
      
      for (final geofenceData in geofences) {
        final added = await geofencingProvider.addGeofence(
          id: geofenceData['id'] as String,
          center: geofenceData['center'] as LatLng,
          radius: geofenceData['radius'] as double,
          name: geofenceData['name'] as String,
          metadata: {'type': 'test', 'created': DateTime.now().toIso8601String()},
        );
        
        if (added) {
          _addLog('✅ Added geofence: ${geofenceData['name']}');
          _testGeofences.add(GeofenceModel(
            id: geofenceData['id'] as String,
            center: geofenceData['center'] as LatLng,
            radius: geofenceData['radius'] as double,
            name: geofenceData['name'] as String,
          ));
        } else {
          _addLog('❌ Failed to add geofence: ${geofenceData['name']}');
        }
      }
      
      _addLog('📍 Created ${_testGeofences.length} test geofences around current location');
      
    } catch (e) {
      _addLog('❌ Error creating test geofences: $e');
    }
  }

  void _monitorStatus(UltraGeofencingProvider geofencingProvider) {
    // Monitor geofencing provider changes
    geofencingProvider.addListener(() {
      if (mounted) {
        setState(() {
          _currentLocation = geofencingProvider.currentLocation;
        });
      }
    });
  }

  Future<void> _simulateMovement() async {
    try {
      _addLog('🚶 Simulating movement to trigger geofences...');
      
      if (_currentLocation == null) {
        _addLog('❌ No current location available');
        return;
      }
      
      // Simulate movement by adding small test geofences
      final movements = [
        {'name': 'Move North', 'offset': const LatLng(0.00005, 0)}, // ~5.5m north
        {'name': 'Move East', 'offset': const LatLng(0, 0.00005)}, // ~5.5m east
        {'name': 'Move South', 'offset': const LatLng(-0.00005, 0)}, // ~5.5m south
        {'name': 'Move West', 'offset': const LatLng(0, -0.00005)}, // ~5.5m west
      ];
      
      for (int i = 0; i < movements.length; i++) {
        final movement = movements[i];
        final offset = movement['offset'] as LatLng;
        final newLocation = LatLng(
          _currentLocation!.latitude + offset.latitude,
          _currentLocation!.longitude + offset.longitude,
        );
        
        _addLog('📍 ${movement['name']}: ${newLocation.latitude}, ${newLocation.longitude}');
        
        // Create a temporary geofence at the new location to simulate movement
        await UltraGeofencingService.addGeofence(
          id: 'temp_movement_$i',
          center: newLocation,
          radius: 2.0,
          name: 'Movement Test $i',
        );
        
        await Future.delayed(const Duration(seconds: 3));
      }
      
    } catch (e) {
      _addLog('❌ Error simulating movement: $e');
    }
  }

  Future<void> _testGeofenceAccuracy() async {
    try {
      _addLog('🎯 Testing 5-meter geofence accuracy...');
      
      if (_currentLocation == null) {
        _addLog('❌ No current location available');
        return;
      }
      
      // Create precise geofences at different distances
      final precisionTests = [
        {'distance': 3.0, 'name': '3m Test'},
        {'distance': 5.0, 'name': '5m Test'},
        {'distance': 7.0, 'name': '7m Test'},
        {'distance': 10.0, 'name': '10m Test'},
      ];
      
      for (int i = 0; i < precisionTests.length; i++) {
        final test = precisionTests[i];
        final distance = test['distance'] as double;
        final name = test['name'] as String;
        
        // Calculate location at exact distance
        final bearing = (i * 90.0) * (3.14159 / 180.0); // 0°, 90°, 180°, 270°
        final earthRadius = 6371000.0; // Earth radius in meters
        
        final lat1 = _currentLocation!.latitude * (3.14159 / 180.0);
        final lng1 = _currentLocation!.longitude * (3.14159 / 180.0);
        
        final lat2 = math.asin(
          math.sin(lat1) * math.cos(distance / earthRadius) +
          math.cos(lat1) * math.sin(distance / earthRadius) * math.cos(bearing)
        );
        
        final lng2 = lng1 + math.atan2(
          math.sin(bearing) * math.sin(distance / earthRadius) * math.cos(lat1),
          math.cos(distance / earthRadius) - math.sin(lat1) * math.sin(lat2)
        );
        
        final testLocation = LatLng(
          lat2 * (180.0 / 3.14159),
          lng2 * (180.0 / 3.14159),
        );
        
        await UltraGeofencingService.addGeofence(
          id: 'precision_test_$i',
          center: testLocation,
          radius: 5.0,
          name: '$name (${distance}m away)',
        );
        
        _addLog('📍 Created $name at ${distance}m distance');
      }
      
    } catch (e) {
      _addLog('❌ Error testing geofence accuracy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ultra Geofencing Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status display
          Consumer<UltraGeofencingProvider>(
            builder: (context, geofencingProvider, child) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: geofencingProvider.ultraGeofencingEnabled 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : Colors.orange.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${geofencingProvider.status}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: geofencingProvider.ultraGeofencingEnabled ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text('Ultra Geofencing: ${geofencingProvider.ultraGeofencingEnabled ? "ENABLED" : "DISABLED"}'),
                    Text('Tracking: ${geofencingProvider.isTracking}'),
                    Text('Active Geofences: ${geofencingProvider.activeGeofences.length}'),
                    if (geofencingProvider.currentLocation != null)
                      Text('Location: ${geofencingProvider.currentLocation!.latitude.toStringAsFixed(6)}, ${geofencingProvider.currentLocation!.longitude.toStringAsFixed(6)}'),
                    if (geofencingProvider.error != null)
                      Text('Error: ${geofencingProvider.error}', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              );
            },
          ),
          
          // Geofence status
          Consumer<UltraGeofencingProvider>(
            builder: (context, geofencingProvider, child) {
              if (geofencingProvider.activeGeofences.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Geofence Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...geofencingProvider.activeGeofences.map((geofence) {
                      final isInside = geofencingProvider.isInsideGeofence(geofence.id);
                      return Text(
                        '${geofence.name}: ${isInside ? "INSIDE" : "OUTSIDE"}',
                        style: TextStyle(
                          color: isInside ? Colors.green : Colors.grey,
                          fontWeight: isInside ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
  child: const Text('Simulate Movement',
  child: ElevatedButton(
                    onPressed: _simulateMovement,
),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
  child: const Text('Test Accuracy',
  child: ElevatedButton(
                    onPressed: _testGeofenceAccuracy,
),
                  ),
                ),
              ],
            ),
          ),
          
          // Logs
          Expanded(
  padding: const EdgeInsets.all(8,
  child: Container(
              margin: const EdgeInsets.all(16),
),
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

