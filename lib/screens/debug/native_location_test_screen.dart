import 'package:flutter/material.dart';
import '../../services/native_background_location_service.dart';

class NativeLocationTestScreen extends StatefulWidget {
  @override
  _NativeLocationTestScreenState createState() => _NativeLocationTestScreenState();
}

class _NativeLocationTestScreenState extends State<NativeLocationTestScreen> {
  bool _isServiceInitialized = false;
  bool _isServiceRunning = false;
  String _status = 'Initializing...';
  String? _userId;
  Map<String, dynamic> _serviceStatus = {};
  Map<String, dynamic> _notificationInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  Future<void> _initializeTest() async {
    try {
      setState(() {
        _status = 'Initializing native background location service...';
      });

      // Use a test user ID
      _userId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

      // Initialize the native background location service
      final initialized = await NativeBackgroundLocationService.initialize();
      
      setState(() {
        _isServiceInitialized = initialized;
        _status = initialized ? 'Service initialized successfully' : 'Service initialization failed';
      });

      // Setup callbacks
      NativeBackgroundLocationService.onServiceStarted = () {
        setState(() {
          _status = 'Native background service started';
          _isServiceRunning = true;
        });
        _updateServiceInfo();
      };

      NativeBackgroundLocationService.onServiceStopped = () {
        setState(() {
          _status = 'Native background service stopped';
          _isServiceRunning = false;
        });
        _updateServiceInfo();
      };

      NativeBackgroundLocationService.onError = (error) {
        setState(() {
          _status = 'Error: $error';
        });
      };

      _updateServiceInfo();
    } catch (e) {
      setState(() {
        _status = 'Initialization error: $e';
      });
    }
  }

  void _updateServiceInfo() {
    setState(() {
      _serviceStatus = NativeBackgroundLocationService.getStatusInfo();
      _notificationInfo = NativeBackgroundLocationService.getNotificationInfo();
      _isServiceRunning = NativeBackgroundLocationService.isRunning;
    });
  }

  Future<void> _startService() async {
    if (_userId == null) {
      setState(() {
        _status = 'No user ID available';
      });
      return;
    }

    setState(() {
      _status = 'Starting native background location service...';
    });

    final started = await NativeBackgroundLocationService.startService(_userId!);
    
    setState(() {
      _status = started ? 'Service started successfully' : 'Failed to start service';
      _isServiceRunning = started;
    });

    _updateServiceInfo();
  }

  Future<void> _stopService() async {
    setState(() {
      _status = 'Stopping native background location service...';
    });

    final stopped = await NativeBackgroundLocationService.stopService();
    
    setState(() {
      _status = stopped ? 'Service stopped successfully' : 'Failed to stop service';
      _isServiceRunning = false;
    });

    _updateServiceInfo();
  }

  Future<void> _testUpdateNow() async {
    setState(() {
      _status = 'Testing Update Now functionality...';
    });

    final success = await NativeBackgroundLocationService.triggerUpdateNow();
    
    setState(() {
      _status = success ? 'Update Now functionality ready - check notification' : 'Update Now test failed';
    });

    _updateServiceInfo();
  }

  Future<void> _restartService() async {
    setState(() {
      _status = 'Restarting native background location service...';
    });

    final restarted = await NativeBackgroundLocationService.restartService();
    
    setState(() {
      _status = restarted ? 'Service restarted successfully' : 'Failed to restart service';
      _isServiceRunning = restarted;
    });

    _updateServiceInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Native Location Service Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text('Status: $_status'),
                    SizedBox(height: 4),
                    Text('User ID: ${_userId?.substring(0, 12) ?? 'None'}'),
                    SizedBox(height: 4),
                    Text('Service Initialized: $_isServiceInitialized'),
                    SizedBox(height: 4),
                    Text('Service Running: $_isServiceRunning'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Control Buttons
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Controls',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isServiceInitialized && !_isServiceRunning ? _startService : null,
                            child: Text('Start Service'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isServiceRunning ? _stopService : null,
                            child: Text('Stop Service'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isServiceRunning ? _testUpdateNow : null,
                            child: Text('Test Update Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isServiceInitialized ? _restartService : null,
                            child: Text('Restart Service'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateServiceInfo,
                        child: Text('Refresh Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Service Status Details
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    ..._serviceStatus.entries.map((entry) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text('${entry.key}: ${entry.value}'),
                    )).toList(),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Notification Information
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Persistent Notification Info',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text('Has Notification: ${_notificationInfo['hasNotification'] ?? false}'),
                    Text('Title: ${_notificationInfo['notificationTitle'] ?? 'N/A'}'),
                    Text('Content: ${_notificationInfo['notificationContent'] ?? 'N/A'}'),
                    Text('Has Update Now Button: ${_notificationInfo['hasUpdateNowButton'] ?? false}'),
                    Text('Has Stop Button: ${_notificationInfo['hasStopButton'] ?? false}'),
                    Text('Persists When App Closed: ${_notificationInfo['persistsWhenAppClosed'] ?? false}'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Instructions
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Instructions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    ...(_notificationInfo['instructions']?.cast<String>() ?? [
                      '1. Tap "Start Service" to begin the native background location service',
                      '2. Check notification panel - you should see "Location Sharing Active"',
                      '3. Expand the notification to see the "Update Now" and "Stop" buttons',
                      '4. Close this app completely (swipe away from recent apps)',
                      '5. Check notification panel - notification should still be visible',
                      '6. Tap "Update Now" in the notification - it should trigger immediate location update',
                      '7. Tap "Stop" in the notification - it should stop the service',
                      '8. Reopen the app - you can restart the service',
                    ]).map((instruction) => Text(instruction)).toList(),
                    SizedBox(height: 8),
                    Text(
                      'Expected Result: Persistent notification with working "Update Now" button that remains visible when app is closed',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
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