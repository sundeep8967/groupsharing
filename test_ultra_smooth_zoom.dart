import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'lib/widgets/smooth_modern_map.dart';
import 'lib/models/map_marker.dart';

void main() {
  runApp(const UltraSmoothZoomTestApp());
}

class UltraSmoothZoomTestApp extends StatelessWidget {
  const UltraSmoothZoomTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultra-Smooth Zoom Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const UltraSmoothZoomTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class UltraSmoothZoomTestScreen extends StatefulWidget {
  const UltraSmoothZoomTestScreen({super.key});

  @override
  State<UltraSmoothZoomTestScreen> createState() => _UltraSmoothZoomTestScreenState();
}

class _UltraSmoothZoomTestScreenState extends State<UltraSmoothZoomTestScreen> {
  final LatLng _center = const LatLng(37.7749, -122.4194); // San Francisco
  
  // Test markers
  final Set<MapMarker> _testMarkers = {
    MapMarker(
      id: 'marker1',
      point: const LatLng(37.7849, -122.4094),
      label: 'Friend 1',
      color: Colors.blue,
    ),
    MapMarker(
      id: 'marker2', 
      point: const LatLng(37.7649, -122.4294),
      label: 'Friend 2',
      color: Colors.green,
    ),
    MapMarker(
      id: 'marker3',
      point: const LatLng(37.7749, -122.4394),
      label: 'Friend 3', 
      color: Colors.red,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Ultra-Smooth Zoom Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showTestInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Test Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎯 ZOOM PERFORMANCE TEST',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Pinch to zoom in/out rapidly\n'
                  '• Use +/- buttons for precise zoom\n'
                  '• Should be buttery smooth at 60fps\n'
                  '• No lag, stuttering, or frame drops',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          
          // Ultra-Smooth Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SmoothModernMap(
                  initialPosition: _center,
                  userLocation: _center,
                  markers: _testMarkers,
                  showUserLocation: true,
                  onMarkerTap: (marker) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tapped: ${marker.label}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  onMapMoved: (center, zoom) {
                    // Optional: Track map movements
                  },
                ),
              ),
            ),
          ),
          
          // Performance Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ULTRA-SMOOTH MODE ACTIVE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Optimized for 60fps zoom performance',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTestInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚀 Ultra-Smooth Zoom Optimizations'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Performance Optimizations Applied:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('✅ Instant zoom (no animation lag)'),
              Text('✅ Markers hidden during zoom'),
              Text('✅ Magnetometer paused during zoom'),
              Text('✅ UI overlays minimized during zoom'),
              Text('✅ RepaintBoundary optimizations'),
              Text('✅ Debounced updates (50ms)'),
              Text('✅ Tile fade disabled'),
              Text('✅ High-performance mode toggle'),
              SizedBox(height: 12),
              Text(
                'Expected Result:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Buttery smooth 60fps zoom with zero lag!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}