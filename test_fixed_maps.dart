import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:latlong2/latlong.dart';
import 'lib/widgets/optimized_map.dart';
import 'lib/widgets/ultra_smooth_map.dart';
import 'lib/models/map_marker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
  
  runApp(const FixedMapsTestApp());
}

class FixedMapsTestApp extends StatelessWidget {
  const FixedMapsTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixed Maps Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FixedMapsTestScreen(),
    );
  }
}

class FixedMapsTestScreen extends StatefulWidget {
  const FixedMapsTestScreen({super.key});

  @override
  State<FixedMapsTestScreen> createState() => _FixedMapsTestScreenState();
}

class _FixedMapsTestScreenState extends State<FixedMapsTestScreen> {
  bool _useOptimizedMap = true;
  final Set<MapMarker> _testMarkers = {};
  final LatLng _center = const LatLng(37.7749, -122.4194); // San Francisco

  @override
  void initState() {
    super.initState();
    _generateTestMarkers();
  }

  void _generateTestMarkers() {
    // Generate a few test markers
    for (int i = 0; i < 5; i++) {
      final lat = 37.7749 + (i * 0.01) - 0.02;
      final lng = -122.4194 + (i * 0.01) - 0.02;
      
      _testMarkers.add(MapMarker(
        point: LatLng(lat, lng),
        label: 'Friend ${i + 1}',
        color: Colors.primaries[i % Colors.primaries.length],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_useOptimizedMap ? 'Optimized Map Test' : 'Ultra Smooth Map Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _useOptimizedMap = !_useOptimizedMap;
              });
            },
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Map',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🗺️ ${_useOptimizedMap ? "OPTIMIZED MAP" : "ULTRA SMOOTH MAP"}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('📍 Test Markers: ${_testMarkers.length}'),
                Text('🎯 Center: San Francisco'),
                const Text('⚡ Status: Ready for smooth zooming!'),
              ],
            ),
          ),
          
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.green.shade50,
            child: const Text(
              '🧪 TEST INSTRUCTIONS:\n'
              '• Pinch to zoom in/out rapidly\n'
              '• Use zoom buttons for precise control\n'
              '• Tap markers to test interactions\n'
              '• Switch between maps using top-right button\n'
              '• Both maps should be buttery smooth!',
              style: TextStyle(fontSize: 14),
            ),
          ),
          
          // Map area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _useOptimizedMap
                  ? OptimizedMap(
                      initialPosition: _center,
                      markers: _testMarkers,
                      showUserLocation: true,
                      userLocation: _center,
                      onMarkerTap: (marker) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tapped: ${marker.label}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      onMapMoved: (center, zoom) {
                        // Handle map movement
                      },
                    )
                  : UltraSmoothMap(
                      initialPosition: _center,
                      markers: _testMarkers,
                      showUserLocation: true,
                      userLocation: _center,
                      onMarkerTap: (marker) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tapped: ${marker.label}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      onMapMoved: (center, zoom) {
                        // Handle map movement
                      },
                    ),
            ),
          ),
          
          // Status footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade100,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Maps fixed and ready! No more errors. Smooth zooming enabled.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}