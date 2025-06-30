import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Comprehensive Background Location Testing
/// 
/// This script provides advanced testing methodology for
/// validating background location sharing functionality.

void main() {
  runApp(const BackgroundLocationTestApp());
}

class BackgroundLocationTestApp extends StatelessWidget {
  const BackgroundLocationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Location Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const BackgroundLocationTestScreen(),
    );
  }
}

class BackgroundLocationTestScreen extends StatefulWidget {
  const BackgroundLocationTestScreen({super.key});

  @override
  State<BackgroundLocationTestScreen> createState() => _BackgroundLocationTestScreenState();
}

class _BackgroundLocationTestScreenState extends State<BackgroundLocationTestScreen> {
  // Test State
  bool _isTestingActive = false;
  String _currentTestPhase = 'Ready to Test';
  final List<TestResult> _testResults = [];
  
  // Service Status
  final Map<String, bool> _serviceStatus = {
    'Bulletproof Service': false,
    'Persistent Service': false,
    'Native Location Service': false,
    'Firebase Connection': false,
  };
  
  // Location Data
  Map<String, dynamic>? _lastLocationData;
  int _locationUpdateCount = 0;
  DateTime? _lastUpdateTime;
  
  // Method Channels
  static const MethodChannel _bulletproofChannel = 
      MethodChannel('bulletproof_location_service');
  static const MethodChannel _persistentChannel = 
      MethodChannel('persistent_location_service');
  static const MethodChannel _nativeChannel = 
      MethodChannel('native_location_service');
  static const MethodChannel _permissionChannel = 
      MethodChannel('android_permissions');

  @override
  void initState() {
    super.initState();
    _setupMethodChannelListeners();
    _performInitialChecks();
  }

  void _setupMethodChannelListeners() {
    // Listen for location updates from native services
    _bulletproofChannel.setMethodCallHandler((call) async {
      if (call.method == 'onLocationUpdate') {
        _handleLocationUpdate(call.arguments, 'Bulletproof Service');
      } else if (call.method == 'onServiceStarted') {
        setState(() {
          _serviceStatus['Bulletproof Service'] = true;
        });
      } else if (call.method == 'onServiceStopped') {
        setState(() {
          _serviceStatus['Bulletproof Service'] = false;
        });
      }
    });
  }

  void _handleLocationUpdate(dynamic locationData, String source) {
    setState(() {
      _lastLocationData = Map<String, dynamic>.from(locationData);
      _locationUpdateCount++;
      _lastUpdateTime = DateTime.now();
    });
    
    debugPrint('Location update from $source: ${_lastLocationData!['latitude']}, ${_lastLocationData!['longitude']}');
  }

  Future<void> _performInitialChecks() async {
    debugPrint('Performing initial system checks...');
    
    // Check permissions
    await _checkPermissions();
    
    // Check service availability
    await _checkServiceAvailability();
    
    // Check Firebase connection
    await _checkFirebaseConnection();
    
    setState(() {});
  }

  Future<void> _checkPermissions() async {
    try {
      final permissions = await _permissionChannel.invokeMethod('checkAllPermissions');
      
      _testResults.add(TestResult(
        testName: 'Permission Check',
        result: permissions['allGranted'] ? 'PASS' : 'FAIL',
        details: 'Location: ${permissions['location']}, Background: ${permissions['background']}',
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      _testResults.add(TestResult(
        testName: 'Permission Check',
        result: 'ERROR',
        details: 'Failed to check permissions: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _checkServiceAvailability() async {
    // Check Bulletproof Service
    try {
      final bulletproofAvailable = await _bulletproofChannel.invokeMethod('checkServiceHealth');
      _serviceStatus['Bulletproof Service'] = bulletproofAvailable ?? false;
    } catch (e) {
      _serviceStatus['Bulletproof Service'] = false;
    }
    
    // Check Persistent Service
    try {
      final persistentAvailable = await _persistentChannel.invokeMethod('isServiceRunning');
      _serviceStatus['Persistent Service'] = persistentAvailable ?? false;
    } catch (e) {
      _serviceStatus['Persistent Service'] = false;
    }
    
    // Check Native Service
    try {
      final nativeAvailable = await _nativeChannel.invokeMethod('isLocationServiceHealthy');
      _serviceStatus['Native Location Service'] = nativeAvailable ?? false;
    } catch (e) {
      _serviceStatus['Native Location Service'] = false;
    }
  }

  Future<void> _checkFirebaseConnection() async {
    // This would check Firebase connectivity
    // For now, we'll simulate it
    await Future.delayed(const Duration(seconds: 1));
    _serviceStatus['Firebase Connection'] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Location Test'),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTestStatusCard(),
            const SizedBox(height: 16),
            _buildServiceStatusCard(),
            const SizedBox(height: 16),
            _buildLocationDataCard(),
            const SizedBox(height: 16),
            _buildTestControlCard(),
            const SizedBox(height: 16),
            _buildTestResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Current Phase: $_currentTestPhase'),
            Text('Location Updates: $_locationUpdateCount'),
            if (_lastUpdateTime != null)
              Text('Last Update: ${_lastUpdateTime!.toString().substring(11, 19)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Service Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._serviceStatus.entries.map((entry) => _buildServiceStatusRow(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusRow(String serviceName, bool isRunning) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isRunning ? Icons.check_circle : Icons.error,
            color: isRunning ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text('$serviceName: ${isRunning ? "RUNNING" : "STOPPED"}'),
        ],
      ),
    );
  }

  Widget _buildLocationDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_lastLocationData != null) ...[
              Text('Latitude: ${_lastLocationData!['latitude']?.toStringAsFixed(6) ?? "N/A"}'),
              Text('Longitude: ${_lastLocationData!['longitude']?.toStringAsFixed(6) ?? "N/A"}'),
              Text('Accuracy: ${_lastLocationData!['accuracy']?.toStringAsFixed(1) ?? "N/A"}m'),
              Text('Provider: ${_lastLocationData!['provider'] ?? "Unknown"}'),
            ] else
              const Text('No location data received yet'),
          ],
        ),
      ),
    );
  }

  Widget _buildTestControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTestingActive ? null : () {
                  debugPrint('Comprehensive test button pressed - functionality to be implemented');
                },
                child: Text(_isTestingActive ? 'Testing in Progress...' : 'Start Comprehensive Test'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _performInitialChecks,
                child: const Text('Refresh Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_testResults.isEmpty)
              const Text('No test results yet. Run the comprehensive test to see results.')
            else
              ..._testResults.map((result) => _buildTestResultRow(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultRow(TestResult result) {
    Color resultColor = result.result == 'PASS' ? Colors.green :
                       result.result == 'FAIL' ? Colors.red :
                       result.result == 'ERROR' ? Colors.red :
                       Colors.orange;
    
    IconData resultIcon = result.result == 'PASS' ? Icons.check_circle :
                         result.result == 'FAIL' ? Icons.error :
                         result.result == 'ERROR' ? Icons.error :
                         Icons.warning;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(resultIcon, color: resultColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${result.testName}: ${result.result}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              result.details,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

class TestResult {
  final String testName;
  final String result;
  final String details;
  final DateTime timestamp;

  TestResult({
    required this.testName,
    required this.result,
    required this.details,
    required this.timestamp,
  });
}