import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'lib/providers/location_provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;

/// Test script to verify offline functionality when location services are disabled
/// This tests that users appear offline to friends when location is turned off
class OfflineFunctionalityTestScreen extends StatefulWidget {
  const OfflineFunctionalityTestScreen({super.key});

  @override
  State<OfflineFunctionalityTestScreen> createState() => _OfflineFunctionalityTestScreenState();
}

class _OfflineFunctionalityTestScreenState extends State<OfflineFunctionalityTestScreen> {
  String _testLog = '';
  bool _isTestRunning = false;

  void _log(String message) {
    setState(() {
      _testLog += '${DateTime.now().toIso8601String()}: $message\n';
    });
    print('OFFLINE_TEST: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Functionality Test'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<LocationProvider, app_auth.AuthProvider>(
        builder: (context, locationProvider, authProvider, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow('Location Service Enabled', locationProvider.locationServiceEnabled),
                        _buildStatusRow('Tracking Active', locationProvider.isTracking),
                        _buildStatusRow('Provider Initialized', locationProvider.isInitialized),
                        const SizedBox(height: 8),
                        Text('Status: ${locationProvider.status}'),
                        if (locationProvider.error != null)
                          Text('Error: ${locationProvider.error}', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        Text('Friends Online: ${locationProvider.userLocations.length}'),
                        Text('Sharing Status: ${locationProvider.userSharingStatus.length} users'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Friends Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Friends Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (locationProvider.userSharingStatus.isEmpty)
                          const Text('No friends found')
                        else
                          ...locationProvider.userSharingStatus.entries.map((entry) {
                            final userId = entry.key;
                            final isSharing = entry.value;
                            final hasLocation = locationProvider.userLocations.containsKey(userId);
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isSharing && hasLocation ? Icons.location_on : Icons.location_off,
                                    color: isSharing && hasLocation ? Colors.green : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${userId.substring(0, 8)}... - ${isSharing && hasLocation ? 'Online' : 'Offline'}',
                                      style: TextStyle(
                                        color: isSharing && hasLocation ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Test Controls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Controls',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        ElevatedButton(
                          onPressed: _isTestRunning ? null : () => _runOfflineTest(locationProvider, authProvider),
                          child: Text(_isTestRunning ? 'Test Running...' : 'Run Offline Test'),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        ElevatedButton(
                          onPressed: () async {
                            _log('Opening location settings...');
                            await Geolocator.openLocationSettings();
                          },
                          child: const Text('Open Location Settings'),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _testLog = '';
                            });
                          },
                          child: const Text('Clear Log'),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Test Instructions
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Instructions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Start location sharing\n'
                          '2. Ask a friend to also start sharing\n'
                          '3. Verify you can see each other online\n'
                          '4. Turn off location services on your phone\n'
                          '5. Check that you appear offline to your friend\n'
                          '6. Turn location services back on\n'
                          '7. Verify you appear online again',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Test Log
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Test Log',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                _testLog.isEmpty ? 'No test logs yet...' : _testLog,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _runOfflineTest(LocationProvider locationProvider, app_auth.AuthProvider authProvider) async {
    if (_isTestRunning) return;
    
    setState(() {
      _isTestRunning = true;
    });
    
    try {
      _log('=== STARTING OFFLINE FUNCTIONALITY TEST ===');
      
      final user = authProvider.user;
      if (user == null) {
        _log('ERROR: No authenticated user found');
        return;
      }
      
      _log('User ID: ${user.uid.substring(0, 8)}...');
      
      // Test 1: Check initial location service status
      _log('Test 1: Checking initial location service status');
      final initialStatus = await Geolocator.isLocationServiceEnabled();
      _log('Initial location service enabled: $initialStatus');
      
      // Test 2: Start location tracking if not already active
      _log('Test 2: Ensuring location tracking is active');
      if (!locationProvider.isTracking) {
        await locationProvider.startTracking(user.uid);
        _log('Location tracking started');
      } else {
        _log('Location tracking already active');
      }
      
      // Wait for tracking to stabilize
      await Future.delayed(const Duration(seconds: 3));
      
      // Test 3: Check current status
      _log('Test 3: Checking current status');
      _log('Service enabled: ${locationProvider.locationServiceEnabled}');
      _log('Tracking active: ${locationProvider.isTracking}');
      _log('Friends online: ${locationProvider.userLocations.length}');
      
      // Test 4: Monitor for location service changes
      _log('Test 4: Monitoring for location service changes');
      _log('Now turn off location services on your device...');
      _log('Watch the status above - you should appear offline to friends');
      
      // Test 5: Instructions for manual verification
      _log('Test 5: Manual verification steps');
      _log('1. Turn off location services in device settings');
      _log('2. Check that "Location Service Enabled" shows false');
      _log('3. Ask a friend to verify you appear offline');
      _log('4. Turn location services back on');
      _log('5. Check that you appear online again');
      
      _log('=== OFFLINE FUNCTIONALITY TEST SETUP COMPLETED ===');
      _log('Continue with manual testing steps above');
      
    } catch (e) {
      _log('ERROR during test: $e');
    } finally {
      setState(() {
        _isTestRunning = false;
      });
    }
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Offline Functionality Test',
        theme: ThemeData(
          primarySwatch: Colors.orange,
          useMaterial3: true,
        ),
        home: const OfflineFunctionalityTestScreen(),
      ),
    ),
  );
}