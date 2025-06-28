import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'lib/widgets/smooth_modern_map.dart';
import 'lib/providers/location_provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;

/// Test script to verify auto-centering functionality
/// This simulates the map behavior when user location becomes available
void main() {
  runApp(const AutoCenterMapTestApp());
}

class AutoCenterMapTestApp extends StatelessWidget {
  const AutoCenterMapTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto-Center Map Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ],
        child: const AutoCenterMapTestScreen(),
      ),
    );
  }
}

class AutoCenterMapTestScreen extends StatefulWidget {
  const AutoCenterMapTestScreen({super.key});

  @override
  State<AutoCenterMapTestScreen> createState() => _AutoCenterMapTestScreenState();
}

class _AutoCenterMapTestScreenState extends State<AutoCenterMapTestScreen> {
  LatLng? _simulatedUserLocation;
  bool _showUserLocation = false;

  // Simulate different locations for testing
  final List<LatLng> _testLocations = [
    const LatLng(37.7749, -122.4194), // San Francisco
    const LatLng(40.7128, -74.0060),  // New York
    const LatLng(51.5074, -0.1278),   // London
    const LatLng(35.6762, 139.6503),  // Tokyo
    const LatLng(-33.8688, 151.2093), // Sydney
  ];

  int _currentLocationIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Center Map Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Test Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Auto-Center Map Test',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Current location display
                if (_simulatedUserLocation != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Current Simulated Location:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${_simulatedUserLocation!.latitude.toStringAsFixed(4)}, '
                          'Lng: ${_simulatedUserLocation!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Test buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _simulateLocationAvailable,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Simulate Location Available'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _simulateLocationUnavailable,
                        icon: const Icon(Icons.location_off),
                        label: const Text('Remove Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                ElevatedButton.icon(
                  onPressed: _cycleTestLocations,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text('Change Location (${_currentLocationIndex + 1}/${_testLocations.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SmoothModernMap(
                  key: ValueKey('test_map_${_simulatedUserLocation?.toString() ?? "no_location"}'),
                  initialPosition: _simulatedUserLocation ?? const LatLng(37.7749, -122.4194),
                  userLocation: _showUserLocation ? _simulatedUserLocation : null,
                  markers: const {},
                  showUserLocation: _showUserLocation,
                  onMarkerTap: null,
                  onMapMoved: (center, zoom) {
                    debugPrint('Map moved to: ${center.latitude}, ${center.longitude} at zoom $zoom');
                  },
                ),
              ),
            ),
          ),
          
          // Status
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showUserLocation ? Icons.check_circle : Icons.cancel,
                      color: _showUserLocation ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showUserLocation ? 'User location visible' : 'User location hidden',
                      style: TextStyle(
                        color: _showUserLocation ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Expected behavior: Map should automatically center on user location when it becomes available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _simulateLocationAvailable() {
    setState(() {
      _simulatedUserLocation = _testLocations[_currentLocationIndex];
      _showUserLocation = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Location simulated - Map should auto-center'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _simulateLocationUnavailable() {
    setState(() {
      _simulatedUserLocation = null;
      _showUserLocation = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ Location removed'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cycleTestLocations() {
    setState(() {
      _currentLocationIndex = (_currentLocationIndex + 1) % _testLocations.length;
      if (_showUserLocation) {
        _simulatedUserLocation = _testLocations[_currentLocationIndex];
      }
    });
    
    final locationNames = [
      'San Francisco, CA',
      'New York, NY', 
      'London, UK',
      'Tokyo, Japan',
      'Sydney, Australia'
    ];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Changed to: ${locationNames[_currentLocationIndex]}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}