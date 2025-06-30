import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lib/services/bulletproof_location_service.dart';
import 'lib/providers/location_provider.dart';
import 'package:provider/provider.dart';

/// Background Location Persistence Test
/// 
/// This test verifies that location tracking persists across app restarts
/// and background/foreground transitions.
void main() {
  runApp(const $1());
}

class BackgroundPersistenceTestApp extends StatelessWidget {
  const BackgroundPersistenceTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider(),
      child: MaterialApp(
        title: 'Background Persistence Test',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        home: const BackgroundPersistenceTestScreen(),
      ),
    );
  }
}

class BackgroundPersistenceTestScreen extends StatefulWidget {
  const BackgroundPersistenceTestScreen({super.key});

  @override
  _BackgroundPersistenceTestScreenState createState() => _BackgroundPersistenceTestScreenState();
}

class _BackgroundPersistenceTestScreenState extends State<BackgroundPersistenceTestScreen> with WidgetsBindingObserver {
  String _status = 'Initializing...';
  String _lastLocation = 'No location yet';
  String _lastError = 'No errors';
  String _serviceHealth = 'Unknown';
  bool _isTracking = false;
  bool _isInitialized = false;
  
  // State restoration tracking
  String _restorationStatus = 'Not checked';
  String _backgroundStatus = 'Unknown';
  // Removed unused field
  DateTime? _lastUpdateTime;
  
  // Test user ID
  final String testUserId = 'test_background_user_12345';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTest();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    setState(() {
      switch (state) {
        case AppLifecycleState.resumed:
          _backgroundStatus = 'App resumed - checking persistence';
          break;
        case AppLifecycleState.paused:
          _backgroundStatus = 'App paused - background tracking should continue';
          break;
        case AppLifecycleState.inactive:
          _backgroundStatus = 'App inactive';
          break;
        case AppLifecycleState.detached:
          _backgroundStatus = 'App detached - background tracking should persist';
          break;
        case AppLifecycleState.hidden:
          _backgroundStatus = 'App hidden';
          break;
      }
    });
    
    // When app resumes, check if tracking persisted
    if (state == AppLifecycleState.resumed) {
      _checkPersistenceOnResume();
    }
  }
  
  Future<void> _initializeTest() async {
    setState(() {
      _status = 'Initializing bulletproof location service...';
    });
    
    try {
      // Initialize bulletproof service
      final initialized = await BulletproofLocationService.initialize();
      setState(() {
        _isInitialized = initialized;
        _status = initialized ? 'Service initialized successfully' : 'Service initialization failed';
      });
      
      if (initialized) {
        // Setup callbacks
        _setupCallbacks();
        
        // Check if there's previous state to restore
        await _checkRestorationState();
      }
    } catch (e) {
      setState(() {
        _status = 'Initialization error: $e';
        _lastError = e.toString();
      });
    }
  }
  
  void _setupCallbacks() {
    BulletproofLocationService.onLocationUpdate = (location) {
      setState(() {
        _lastLocation = 'Lat: ${location.latitude.toStringAsFixed(6)}, '
                       'Lng: ${location.longitude.toStringAsFixed(6)}';
        _locationUpdateCount++;
        _lastUpdateTime = DateTime.now();
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
        _status = 'Background location tracking started';
      });
    };
    
    BulletproofLocationService.onServiceStopped = () {
      setState(() {
        _isTracking = false;
        _status = 'Background location tracking stopped';
      });
    };
    
    BulletproofLocationService.onPermissionRevoked = () {
      setState(() {
        _lastError = 'Location permissions were revoked';
      });
    };
  }
  
  Future<void> _checkRestorationState() async {
    try {
      final shouldRestore = await BulletproofLocationService.shouldRestoreTracking();
      final userId = await BulletproofLocationService.getRestoreUserId();
      
      setState(() {
        if (shouldRestore && userId != null) {
          _restorationStatus = 'Previous state found for user: ${userId.substring(0, 8)}';
          _isTracking = BulletproofLocationService.isTracking;
        } else {
          _restorationStatus = 'No previous state to restore';
        }
      });
      
      // If there's state to restore, restore it
      if (shouldRestore) {
        await _restoreTracking();
      }
    } catch (e) {
      setState(() {
        _restorationStatus = 'Error checking restoration state: $e';
      });
    }
  }
  
  Future<void> _restoreTracking() async {
    setState(() {
      _status = 'Restoring previous tracking state...';
    });
    
    try {
      final restored = await BulletproofLocationService.restoreTrackingState();
      setState(() {
        if (restored) {
          _isTracking = true;
          _status = 'Previous tracking state restored successfully';
          _restorationStatus = 'State restoration successful';
        } else {
          _status = 'Failed to restore previous tracking state';
          _restorationStatus = 'State restoration failed';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error restoring tracking state: $e';
        _restorationStatus = 'Restoration error: $e';
      });
    }
  }
  
  Future<void> _startTracking() async {
    setState(() {
      _status = 'Starting background location tracking...';
    });
    
    try {
      final success = await BulletproofLocationService.startTracking(testUserId);
      if (!success) {
        setState(() {
          _status = 'Failed to start background location tracking';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error starting tracking: $e';
        _lastError = e.toString();
      });
    }
  }
  
  Future<void> _stopTracking() async {
    setState(() {
      _status = 'Stopping background location tracking...';
    });
    
    try {
      final success = await BulletproofLocationService.stopTracking();
      setState(() {
        if (success) {
          _isTracking = false;
          _status = 'Background location tracking stopped';
        } else {
          _status = 'Failed to stop background location tracking';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error stopping tracking: $e';
        _lastError = e.toString();
      });
    }
  }
  
  Future<void> _checkServiceHealth() async {
    try {
      final isHealthy = await BulletproofLocationService.checkServiceHealth();
      setState(() {
        _serviceHealth = isHealthy ? 'Healthy' : 'Unhealthy';
      });
    } catch (e) {
      setState(() {
        _serviceHealth = 'Error: $e';
      });
    }
  }
  
  Future<void> _checkPersistenceOnResume() async {
    setState(() {
      _backgroundStatus = 'Checking persistence after resume...';
    });
    
    try {
      // Check if service is still tracking
      final isTracking = BulletproofLocationService.isTracking;
      final isHealthy = await BulletproofLocationService.checkServiceHealth();
      
      setState(() {
        _isTracking = isTracking;
        _serviceHealth = isHealthy ? 'Healthy' : 'Unhealthy';
        
        if (isTracking && isHealthy) {
          _backgroundStatus = 'SUCCESS: Background tracking persisted!';
        } else if (isTracking && !isHealthy) {
          _backgroundStatus = 'WARNING: Tracking active but service unhealthy';
        } else {
          _backgroundStatus = 'ISSUE: Background tracking did not persist';
        }
      });
      
      // If tracking didn't persist, try to restore it
      if (!isTracking) {
        await _restoreTracking();
      }
    } catch (e) {
      setState(() {
        _backgroundStatus = 'Error checking persistence: $e';
      });
    }
  }
  
  Future<void> _simulateAppKill() async {
    setState(() {
      _status = 'Simulating app termination...';
    });
    
    // This simulates what happens when the app is killed
    // In a real scenario, the native service should continue running
    try {
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        _status = 'App termination simulated - background service should continue';
        _backgroundStatus = 'Native service should be running in background';
      });
    } catch (e) {
      setState(() {
        _status = 'Error simulating app kill: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Background Persistence Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
                    Text('Initialized: ${_isInitialized ? 'Yes' : 'No'}'),
                    Text('Tracking: ${_isTracking ? 'Active' : 'Inactive'}'),
                    Text('Health: $_serviceHealth'),
                    Text('Status: $_status'),
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
                      'Background Persistence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Padding(
                padding: EdgeInsets.all(16.0),
),
                    ),
                    SizedBox(height: 8),
                    Text('Restoration: $_restorationStatus'),
                    Text('Background: $_backgroundStatus'),
                    Text('Updates: $_locationUpdateCount'),
                    Text('Last Update: ${_lastUpdateTime?.toString() ?? 'Never'}'),
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
              onPressed: _isTracking ? null : _startTracking,
              child: Text('Start Background Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTracking ? _stopTracking : null,
              child: Text('Stop Background Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkServiceHealth,
              child: Text('Check Service Health'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkPersistenceOnResume,
              child: Text('Check Persistence'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _simulateAppKill,
              child: Text('Simulate App Termination'),
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
                        'Test Instructions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
  child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
),
                      ),
                      SizedBox(height: 8),
                      Text('1. Start background tracking'),
                      Text('2. Minimize the app (home button)'),
                      Text('3. Wait 30 seconds'),
                      Text('4. Return to app'),
                      Text('5. Check if tracking persisted'),
                      Text('6. Try force-closing the app'),
                      Text('7. Reopen and check restoration'),
                      SizedBox(height: 16),
                      Text(
                        'Expected Results:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('• Location updates continue in background'),
                      Text('• Service health remains good'),
                      Text('• State restores after app restart'),
                      Text('• Firebase updates continue'),
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
}