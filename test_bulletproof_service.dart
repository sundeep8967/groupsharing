import 'package:flutter/material.dart';
import 'lib/services/bulletproof_location_service.dart';

/// Test script for the Bulletproof Location Service
/// 
/// This script demonstrates how to use the bulletproof location service
/// and tests its functionality.
void main() {
  runApp(const BulletproofTestApp());
}

class BulletproofTestApp extends StatelessWidget {
  const BulletproofTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bulletproof Location Service Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BulletproofTestScreen(),
    );
  }
}

class BulletproofTestScreen extends StatefulWidget {
  const BulletproofTestScreen({super.key});

  @override
  _BulletproofTestScreenState createState() => _BulletproofTestScreenState();
}

class _BulletproofTestScreenState extends State<BulletproofTestScreen> {
  String _status = 'Not initialized';
  String _lastLocation = 'No location yet';
  String _lastError = 'No errors';
  bool _isTracking = false;
  
  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }
  
  void _setupCallbacks() {
    // Setup callbacks for the bulletproof location service
    BulletproofLocationService.onLocationUpdate = (location) {
      setState(() {
        _lastLocation = 'Lat: ${location.latitude.toStringAsFixed(6)}, '
                       'Lng: ${location.longitude.toStringAsFixed(6)}';
      });
    };
    
    BulletproofLocationService.onError = (error) {
      setState(() {
        _lastError = error;
      });
    };
    
    BulletproofLocationService.onStatusUpdate = (status) {
      setState(() {
        _status = status;
      });
    };
    
    BulletproofLocationService.onServiceStarted = () {
      setState(() {
        _isTracking = true;
        _status = 'Service started successfully';
      });
    };
    
    BulletproofLocationService.onServiceStopped = () {
      setState(() {
        _isTracking = false;
        _status = 'Service stopped';
      });
    };
    
    BulletproofLocationService.onPermissionRevoked = () {
      setState(() {
        _lastError = 'Location permissions were revoked';
      });
    };
  }
  
  Future<void> _initializeService() async {
    setState(() {
      _status = 'Initializing...';
    });
    
    final success = await BulletproofLocationService.initialize();
    setState(() {
      _status = success ? 'Initialized successfully' : 'Initialization failed';
    });
  }
  
  Future<void> _startTracking() async {
    setState(() {
      _status = 'Starting location tracking...';
    });
    
    // Use a test user ID
    const testUserId = 'test_user_12345';
    final success = await BulletproofLocationService.startTracking(testUserId);
    
    if (!success) {
      setState(() {
        _status = 'Failed to start tracking';
      });
    }
  }
  
  Future<void> _stopTracking() async {
    setState(() {
      _status = 'Stopping location tracking...';
    });
    
    final success = await BulletproofLocationService.stopTracking();
    setState(() {
      _status = success ? 'Tracking stopped' : 'Failed to stop tracking';
    });
  }
  
  Future<void> _restoreState() async {
    setState(() {
      _status = 'Restoring tracking state...';
    });
    
    await BulletproofLocationService.restoreTrackingState();
    setState(() {
      _isTracking = BulletproofLocationService.isTracking;
      _status = 'State restored';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulletproof Location Service Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Padding(
                padding: EdgeInsets.all(16.0),
),
                    ),
                    SizedBox(height: 8),
                    Text('Status: $_status'),
                    Text('Tracking: ${_isTracking ? 'Active' : 'Inactive'}'),
                    Text('User ID: ${BulletproofLocationService.currentUserId ?? 'None'}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Padding(
                padding: EdgeInsets.all(16.0),
),
                    ),
                    SizedBox(height: 8),
                    Text('Last Location: $_lastLocation'),
                    Text('Last Error: $_lastError'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeService,
              child: Text('Initialize Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTracking ? null : _startTracking,
              child: Text('Start Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTracking ? _stopTracking : null,
              child: Text('Stop Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _restoreState,
              child: Text('Restore State'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            Expanded(
  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Features',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
),
                      ),
                      SizedBox(height: 8),
                      Text('✓ Battery optimization handling'),
                      Text('✓ Permission monitoring'),
                      Text('✓ Foreground service implementation'),
                      Text('✓ Android 12+ restrictions handling'),
                      Text('✓ Service lifecycle management'),
                      Text('✓ Firebase retry mechanisms'),
                      Text('✓ Multi-layer fallback system'),
                      Text('✓ Device-specific optimizations'),
                      Text('✓ Health monitoring'),
                      Text('✓ Auto-restart capabilities'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    BulletproofLocationService.dispose();
    super.dispose();
  }
}