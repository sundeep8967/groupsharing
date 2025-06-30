import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// LIVE Background Location Diagnostic Tool
/// Run this to test if background location actually works on your device
void main() {
  runApp(const BackgroundLocationTester());
}

class BackgroundLocationTester extends StatelessWidget {
  const BackgroundLocationTester({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Location Tester',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const TestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String _status = 'Ready to test';
  String _lastLocation = 'None';
  String _locationCount = '0';
  bool _isTesting = false;
  Timer? _testTimer;
  StreamSubscription<Position>? _positionStream;
  int _updateCount = 0;
  DateTime? _lastUpdate;

  @override
  void dispose() {
    _testTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _startBackgroundTest() async {
    setState(() {
      _status = 'Checking permissions...';
      _isTesting = true;
      _updateCount = 0;
    });

    try {
      // Check location permission
      var permission = await Permission.location.status;
      if (!permission.isGranted) {
        permission = await Permission.location.request();
        if (!permission.isGranted) {
          setState(() => _status = '❌ Location permission denied');
          return;
        }
      }

      // Check background location permission
      var backgroundPermission = await Permission.locationAlways.status;
      if (!backgroundPermission.isGranted) {
        backgroundPermission = await Permission.locationAlways.request();
        if (!backgroundPermission.isGranted) {
          setState(() => _status = '❌ Background location permission denied');
          return;
        }
      }

      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _status = '❌ Location services disabled');
        return;
      }

      setState(() => _status = '✅ Starting background location test...');

      // Start position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
          timeLimit: Duration(seconds: 30),
        ),
      ).listen(
        (Position position) {
          _updateCount++;
          _lastUpdate = DateTime.now();
          setState(() {
            _lastLocation = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
            _locationCount = '$_updateCount';
            _status = '🟢 Background location working! Last update: ${_lastUpdate!.toLocal().toString().split('.')[0]}';
          });
          developer.log('📍 Location update #$_updateCount: $position');
        },
        onError: (error) {
          setState(() => _status = '❌ Location stream error: $error');
          developer.log('❌ Location error: $error');
        },
      );

      // Start test timer to check if updates stop
      _testTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (_lastUpdate != null) {
          final timeSinceLastUpdate = DateTime.now().difference(_lastUpdate!);
          if (timeSinceLastUpdate.inSeconds > 30) {
            setState(() => _status = '⚠️ No location updates for ${timeSinceLastUpdate.inSeconds}s - Background location may be broken');
          }
        }
      });

    } catch (e) {
      setState(() => _status = '❌ Error: $e');
      developer.log('❌ Test error: $e');
    }
  }

  void _stopTest() {
    _testTimer?.cancel();
    _positionStream?.cancel();
    setState(() {
      _isTesting = false;
      _status = 'Test stopped';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Location Tester'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Background Location Test',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will test if background location actually works on your device. '
                      'Start the test, then minimize the app and wait.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _status.startsWith('❌') ? Colors.red :
                               _status.startsWith('✅') || _status.startsWith('🟢') ? Colors.green :
                               _status.startsWith('⚠️') ? Colors.orange : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Location Updates:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_locationCount, style: const TextStyle(fontSize: 18, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastLocation,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (!_isTesting)
              ElevatedButton.icon(
                onPressed: _startBackgroundTest,
                icon: const Icon(Icons.play_arrow),
                label: const Text('START BACKGROUND TEST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _stopTest,
                icon: const Icon(Icons.stop),
                label: const Text('STOP TEST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            
            const SizedBox(height: 16),
            
            const Card(
              color: Colors.orange,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔥 TESTING INSTRUCTIONS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Tap "START BACKGROUND TEST"\n'
                      '2. Wait for location updates to start\n'
                      '3. Minimize the app (press home button)\n'
                      '4. Wait 2-3 minutes\n'
                      '5. Come back to check if updates continued\n'
                      '6. If updates stopped = background location broken',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}