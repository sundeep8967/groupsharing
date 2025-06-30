import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lib/services/bulletproof_location_service.dart';

/// iOS Test script for the Bulletproof Location Service
/// 
/// This script tests the iOS implementation of the bulletproof location service
/// and verifies cross-platform compatibility.
void main() {
  runApp(const BulletproofIOSTestApp());
}

class BulletproofIOSTestApp extends StatelessWidget {
  const BulletproofIOSTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bulletproof Location Service iOS Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BulletproofIOSTestScreen(),
    );
  }
}

class BulletproofIOSTestScreen extends StatefulWidget {
  const BulletproofIOSTestScreen({super.key});

  @override
  _BulletproofIOSTestScreenState createState() => _BulletproofIOSTestScreenState();
}

class _BulletproofIOSTestScreenState extends State<BulletproofIOSTestScreen> {
  String _status = 'Not initialized';
  String _lastLocation = 'No location yet';
  String _lastError = 'No errors';
  String _platformInfo = 'Unknown platform';
  bool _isTracking = false;
  bool _isIOS = false;
  
  // iOS-specific status
  String _permissionStatus = 'Unknown';
  String _backgroundStatus = 'Unknown';
  String _notificationStatus = 'Unknown';
  
  @override
  void initState() {
    super.initState();
    _checkPlatform();
    _setupCallbacks();
  }
  
  void _checkPlatform() async {
    try {
      final platform = Theme.of(context).platform;
      setState(() {
        _isIOS = platform == TargetPlatform.iOS;
        _platformInfo = _isIOS ? 'iOS' : 'Android/Other';
      });
      
      if (_isIOS) {
        await _checkIOSPermissions();
      }
    } catch (e) {
      setState(() {
        _platformInfo = 'Error detecting platform: $e';
      });
    }
  }
  
  Future<void> _checkIOSPermissions() async {
    if (!_isIOS) return;
    
    try {
      const permissionChannel = MethodChannel('bulletproof_permissions');
      
      final hasBackground = await permissionChannel.invokeMethod('checkBackgroundLocationPermission');
      final hasNotification = await permissionChannel.invokeMethod('checkNotificationPermission') ?? false;
      
      setState(() {
        _backgroundStatus = hasBackground ? 'Granted' : 'Not granted';
        _notificationStatus = hasNotification ? 'Granted' : 'Not granted';
        _permissionStatus = (hasBackground && hasNotification) ? 'All granted' : 'Missing permissions';
      });
    } catch (e) {
      setState(() {
        _permissionStatus = 'Error checking: $e';
      });
    }
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
        _status = 'iOS service started successfully';
      });
    };
    
    BulletproofLocationService.onServiceStopped = () {
      setState(() {
        _isTracking = false;
        _status = 'iOS service stopped';
      });
    };
    
    BulletproofLocationService.onPermissionRevoked = () {
      setState(() {
        _lastError = 'iOS location permissions were revoked';
      });
      _checkIOSPermissions();
    };
  }
  
  Future<void> _initializeService() async {
    setState(() {
      _status = 'Initializing iOS service...';
    });
    
    final success = await BulletproofLocationService.initialize();
    setState(() {
      _status = success ? 'iOS service initialized successfully' : 'iOS initialization failed';
    });
    
    if (_isIOS) {
      await _checkIOSPermissions();
    }
  }
  
  Future<void> _startTracking() async {
    setState(() {
      _status = 'Starting iOS location tracking...';
    });
    
    // Use a test user ID
    const testUserId = 'ios_test_user_12345';
    final success = await BulletproofLocationService.startTracking(testUserId);
    
    if (!success) {
      setState(() {
        _status = 'Failed to start iOS tracking';
      });
    }
    
    if (_isIOS) {
      await _checkIOSPermissions();
    }
  }
  
  Future<void> _stopTracking() async {
    setState(() {
      _status = 'Stopping iOS location tracking...';
    });
    
    final success = await BulletproofLocationService.stopTracking();
    setState(() {
      _status = success ? 'iOS tracking stopped' : 'Failed to stop iOS tracking';
    });
  }
  
  Future<void> _restoreState() async {
    setState(() {
      _status = 'Restoring iOS tracking state...';
    });
    
    await BulletproofLocationService.restoreTrackingState();
    setState(() {
      _isTracking = BulletproofLocationService.isTracking;
      _status = 'iOS state restored';
    });
  }
  
  Future<void> _requestIOSPermissions() async {
    if (!_isIOS) return;
    
    try {
      const permissionChannel = MethodChannel('bulletproof_permissions');
      
      setState(() {
        _status = 'Requesting iOS permissions...';
      });
      
      await permissionChannel.invokeMethod('requestBackgroundLocationPermission');
      await permissionChannel.invokeMethod('requestNotificationPermission');
      
      // Wait a moment and check again
      await Future.delayed(Duration(seconds: 2));
      await _checkIOSPermissions();
      
      setState(() {
        _status = 'iOS permission request completed';
      });
    } catch (e) {
      setState(() {
        _status = 'iOS permission request failed: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulletproof Location iOS Test'),
        backgroundColor: _isIOS ? Colors.blue : Colors.grey,
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
                      'Platform Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Padding(
                padding: EdgeInsets.all(16.0),
),
                    ),
                    SizedBox(height: 8),
                    Text('Platform: $_platformInfo'),
                    Text('iOS Optimized: ${_isIOS ? 'Yes' : 'No'}'),
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
            if (_isIOS) ...[
              SizedBox(height: 16),
              Card(
  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'iOS Permissions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Padding(
                  padding: EdgeInsets.all(16.0),
),
                      ),
                      SizedBox(height: 8),
                      Text('Overall: $_permissionStatus'),
                      Text('Background Location: $_backgroundStatus'),
                      Text('Notifications: $_notificationStatus'),
                    ],
                  ),
                ),
              ),
            ],
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
              child: Text('Initialize iOS Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            if (_isIOS) ...[
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _requestIOSPermissions,
                child: Text('Request iOS Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTracking ? null : _startTracking,
              child: Text('Start iOS Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTracking ? _stopTracking : null,
              child: Text('Stop iOS Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _restoreState,
              child: Text('Restore iOS State'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            Expanded(
  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'iOS-Specific Features',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
),
                      ),
                      SizedBox(height: 8),
                      Text('✓ Core Location integration'),
                      Text('✓ Background location updates'),
                      Text('✓ Significant location changes'),
                      Text('✓ Background task scheduling'),
                      Text('✓ App lifecycle management'),
                      Text('✓ Permission monitoring'),
                      Text('✓ Health monitoring'),
                      Text('✓ Firebase integration'),
                      Text('✓ Notification support'),
                      Text('✓ State persistence'),
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