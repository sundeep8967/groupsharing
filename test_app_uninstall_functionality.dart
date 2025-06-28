import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/location_provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;

/// Test script to verify app uninstall functionality
/// This tests that users appear offline when the app is uninstalled
class AppUninstallTestScreen extends StatefulWidget {
  const AppUninstallTestScreen({super.key});

  @override
  State<AppUninstallTestScreen> createState() => _AppUninstallTestScreenState();
}

class _AppUninstallTestScreenState extends State<AppUninstallTestScreen> {
  String _testLog = '';
  bool _isTestRunning = false;

  void _log(String message) {
    setState(() {
      _testLog += '${DateTime.now().toIso8601String()}: $message\n';
    });
    print('APP_UNINSTALL_TEST: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Uninstall Test'),
        backgroundColor: Colors.red,
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
                        _buildStatusRow('Tracking Active', locationProvider.isTracking),
                        _buildStatusRow('Provider Initialized', locationProvider.isInitialized),
                        _buildStatusRow('Location Service Enabled', locationProvider.locationServiceEnabled),
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
                
                // Heartbeat Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Heartbeat Mechanism',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The app sends heartbeat signals every 30 seconds to indicate it\'s still running. '
                          'When the app is uninstalled or terminated, these heartbeats stop. '
                          'If no heartbeat is received for 2 minutes, the user is marked as offline.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Heartbeat Status: ${locationProvider.isTracking ? "Active" : "Inactive"}',
                          style: TextStyle(
                            color: locationProvider.isTracking ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                          onPressed: _isTestRunning ? null : () => _runUninstallTest(locationProvider, authProvider),
                          child: Text(_isTestRunning ? 'Test Running...' : 'Run App Uninstall Test'),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        ElevatedButton(
                          onPressed: () => _simulateAppTermination(locationProvider),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Simulate App Termination', style: TextStyle(color: Colors.white)),
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
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Uninstall Test Instructions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Start location sharing on this device\n'
                          '2. Ask a friend to also start sharing\n'
                          '3. Verify you can see each other online\n'
                          '4. Use "Simulate App Termination" to test cleanup\n'
                          '5. OR actually uninstall the app\n'
                          '6. Check that you appear offline to your friend\n'
                          '7. Reinstall and verify you can come back online',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Note: The heartbeat mechanism sends signals every 30 seconds. '
                            'If no heartbeat is received for 2 minutes, the user is automatically marked as offline.',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
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

  Future<void> _runUninstallTest(LocationProvider locationProvider, app_auth.AuthProvider authProvider) async {
    if (_isTestRunning) return;
    
    setState(() {
      _isTestRunning = true;
    });
    
    try {
      _log('=== STARTING APP UNINSTALL TEST ===');
      
      final user = authProvider.user;
      if (user == null) {
        _log('ERROR: No authenticated user found');
        return;
      }
      
      _log('User ID: ${user.uid.substring(0, 8)}...');
      
      // Test 1: Start location tracking
      _log('Test 1: Starting location tracking');
      if (!locationProvider.isTracking) {
        await locationProvider.startTracking(user.uid);
        _log('Location tracking started');
      } else {
        _log('Location tracking already active');
      }
      
      // Wait for tracking to stabilize
      await Future.delayed(const Duration(seconds: 3));
      
      // Test 2: Verify heartbeat is active
      _log('Test 2: Verifying heartbeat mechanism');
      _log('Heartbeat should be sending every 30 seconds');
      _log('If no heartbeat for 2 minutes, user will be marked offline');
      
      // Test 3: Check current status
      _log('Test 3: Current status verification');
      _log('Tracking active: ${locationProvider.isTracking}');
      _log('Friends online: ${locationProvider.userLocations.length}');
      
      // Test 4: Instructions for manual testing
      _log('Test 4: Manual testing steps');
      _log('1. Ensure a friend can see you online');
      _log('2. Use "Simulate App Termination" button to test cleanup');
      _log('3. OR actually uninstall the app from device settings');
      _log('4. Ask friend to verify you appear offline');
      _log('5. Reinstall app to test coming back online');
      
      _log('=== APP UNINSTALL TEST SETUP COMPLETED ===');
      _log('Continue with manual testing steps above');
      
    } catch (e) {
      _log('ERROR during test: $e');
    } finally {
      setState(() {
        _isTestRunning = false;
      });
    }
  }

  Future<void> _simulateAppTermination(LocationProvider locationProvider) async {
    _log('=== SIMULATING APP TERMINATION ===');
    
    try {
      // Call the cleanup method directly
      await locationProvider.cleanupUserData();
      _log('App termination cleanup completed');
      _log('User should now appear offline to friends');
      _log('This simulates what happens when the app is uninstalled');
      
    } catch (e) {
      _log('ERROR during app termination simulation: $e');
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
        title: 'App Uninstall Test',
        theme: ThemeData(
          primarySwatch: Colors.red,
          useMaterial3: true,
        ),
        home: const AppUninstallTestScreen(),
      ),
    ),
  );
}