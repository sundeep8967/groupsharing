import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'lib/widgets/smooth_modern_map.dart';
import 'lib/models/map_marker.dart';

void main() {
  runApp(const SmoothMapTestApp());
}

class SmoothMapTestApp extends StatelessWidget {
  const SmoothMapTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smooth Map Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SmoothMapTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SmoothMapTestScreen extends StatelessWidget {
  const SmoothMapTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Ultra-Smooth Map Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Column(
                children: [
                  Text(
                    '✅ ULTRA-SMOOTH ZOOM ACTIVE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Test pinch zoom and +/- buttons for smooth 60fps performance',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SmoothModernMap(
                  initialPosition: const LatLng(37.7749, -122.4194), // San Francisco
                  userLocation: const LatLng(37.7749, -122.4194),
                  markers: {
                    MapMarker(
                      id: 'test1',
                      point: const LatLng(37.7849, -122.4094),
                      label: 'Test Marker',
                      color: Colors.red,
                    ),
                  },
                  showUserLocation: true,
                  onMarkerTap: (marker) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tapped: ${marker.label}')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}