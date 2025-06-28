import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'lib/providers/auth_provider.dart' as app_auth;
import 'lib/providers/location_provider.dart';
import 'lib/widgets/optimized_map.dart';
import 'lib/models/map_marker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
  
  runApp(const SmoothZoomTestApp());
}

class SmoothZoomTestApp extends StatelessWidget {
  const SmoothZoomTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Smooth Zoom Performance Test',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const SmoothZoomTestScreen(),
      ),
    );
  }
}

class SmoothZoomTestScreen extends StatefulWidget {
  const SmoothZoomTestScreen({super.key});

  @override
  State<SmoothZoomTestScreen> createState() => _SmoothZoomTestScreenState();
}

class _SmoothZoomTestScreenState extends State<SmoothZoomTestScreen> {
  final Set<MapMarker> _testMarkers = {};
  LatLng _currentCenter = const LatLng(37.7749, -122.4194); // San Francisco
  double _currentZoom = 15.0;
  int _frameCount = 0;
  DateTime? _lastFrameTime;
  double _fps = 0.0;

  @override
  void initState() {
    super.initState();
    _generateTestMarkers();
    _startFpsCounter();
  }

  void _generateTestMarkers() {
    // Generate test markers around San Francisco
    final random = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 10; i++) {
      final lat = 37.7749 + (i * 0.01) - 0.05;
      final lng = -122.4194 + (i * 0.01) - 0.05;
      
      _testMarkers.add(MapMarker(
        point: LatLng(lat, lng),
        label: 'Friend ${i + 1}',
        color: Colors.primaries[i % Colors.primaries.length],
      ));
    }
  }

  void _startFpsCounter() {
    // Simple FPS counter
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final deltaTime = now.difference(_lastFrameTime!).inMicroseconds / 1000000.0;
      if (deltaTime > 0) {
        _fps = 1.0 / deltaTime;
      }
    }
    _lastFrameTime = now;
    _frameCount++;
    
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback(_onFrame);
    }
  }

  void _testAutoZoom() {
    // Automated zoom test
    HapticFeedback.mediumImpact();
    
    double targetZoom = 10.0;
    const duration = Duration(milliseconds: 100);
    
    Timer.periodic(duration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      targetZoom += 0.5;
      if (targetZoom > 18.0) {
        targetZoom = 10.0;
      }
      
      setState(() {
        _currentZoom = targetZoom;
      });
      
      if (timer.tick > 20) { // Stop after 20 iterations
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smooth Zoom Performance Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _testAutoZoom,
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Auto Zoom Test',
          ),
        ],
      ),
      body: Column(
        children: [
          // Performance metrics
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎯 ZOOM PERFORMANCE TEST',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📊 FPS: ${_fps.toStringAsFixed(1)}'),
                          Text('🔍 Zoom: ${_currentZoom.toStringAsFixed(1)}'),
                          Text('📍 Markers: ${_testMarkers.length}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🖼️ Frames: $_frameCount'),
                          Text('📱 Center: ${_currentCenter.latitude.toStringAsFixed(4)}'),
                          Text('⚡ Status: ${_fps > 55 ? "SMOOTH" : _fps > 30 ? "OK" : "LAGGY"}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Test instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.green.shade50,
            child: const Text(
              '🧪 TEST INSTRUCTIONS:\n'
              '• Pinch to zoom in/out rapidly\n'
              '• Watch FPS counter (should stay above 55)\n'
              '• Tap auto-zoom button for stress test\n'
              '• Zoom should feel buttery smooth!',
              style: TextStyle(fontSize: 14),
            ),
          ),
          
          // Map area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OptimizedMap(
                initialPosition: _currentCenter,
                markers: _testMarkers,
                showUserLocation: true,
                userLocation: _currentCenter,
                onMarkerTap: (marker) {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tapped: ${marker.label}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                onMapMoved: (center, zoom) {
                  setState(() {
                    _currentCenter = center;
                    _currentZoom = zoom;
                  });
                },
              ),
            ),
          ),
          
          // Performance status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _fps > 55 
                ? Colors.green.shade100 
                : _fps > 30 
                    ? Colors.orange.shade100 
                    : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  _fps > 55 
                      ? Icons.check_circle 
                      : _fps > 30 
                          ? Icons.warning 
                          : Icons.error,
                  color: _fps > 55 
                      ? Colors.green 
                      : _fps > 30 
                          ? Colors.orange 
                          : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _fps > 55 
                      ? '✅ EXCELLENT: Buttery smooth zooming!'
                      : _fps > 30 
                          ? '⚠️ GOOD: Acceptable performance'
                          : '❌ POOR: Zoom lag detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _fps > 55 
                        ? Colors.green.shade800
                        : _fps > 30 
                            ? Colors.orange.shade800
                            : Colors.red.shade800,
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