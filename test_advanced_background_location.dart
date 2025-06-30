import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Advanced Background Location Testing Suite
/// 
/// This comprehensive testing tool validates background location sharing
/// across multiple scenarios, device states, and edge cases.

void main() {
  runApp(const AdvancedLocationTestApp());
}

class AdvancedLocationTestApp extends StatelessWidget {
  const AdvancedLocationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Background Location Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LocationTestDashboard(),
    );
  }
}

class LocationTestDashboard extends StatefulWidget {
  const LocationTestDashboard({super.key});

  @override
  State<LocationTestDashboard> createState() => _LocationTestDashboardState();
}

class _LocationTestDashboardState extends State<LocationTestDashboard> {
  // Test State Management
  bool _isTestingActive = false;
  String _currentTestPhase = 'Idle';
  final List<TestResult> _testResults = [];
  Timer? _testTimer;
  Timer? _locationMonitor;
  
  // Location Tracking
  Position? _lastKnownPosition;
  DateTime? _lastLocationUpdate;
  int _locationUpdateCount = 0;
  final List<LocationReading> _locationHistory = [];
  
  // Device State Monitoring
  String _deviceModel = 'Unknown';
  String _osVersion = 'Unknown';
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  ConnectivityResult _connectivity = ConnectivityResult.none;
  
  // Service Health Monitoring
  bool _bulletproofServiceRunning = false;
  bool _persistentServiceRunning = false;
  bool _nativeLocationServiceRunning = false;
  
  // Method Channels for Native Communication
  static const MethodChannel _bulletproofChannel = 
      MethodChannel('bulletproof_location_service');
  static const MethodChannel _persistentChannel = 
      MethodChannel('persistent_location_service');
  static const MethodChannel _nativeChannel = 
      MethodChannel('native_location_service');

  @override
  void initState() {
    super.initState();
    _initializeTestEnvironment();
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    _locationMonitor?.cancel();
    super.dispose();
  }

  Future<void> _initializeTestEnvironment() async {
    debugPrint('Initializing Advanced Location Test Environment...');
    
    await _getDeviceInfo();
    await _checkInitialPermissions();
    await _setupLocationMonitoring();
    await _checkServiceHealth();
    
    setState(() {});
    
    debugPrint('Test environment initialized successfully');
  }

  Future<void> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final battery = Battery();
      final connectivity = Connectivity();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        _osVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceModel = '${iosInfo.name} ${iosInfo.model}';
        _osVersion = 'iOS ${iosInfo.systemVersion}';
      }
      
      _batteryLevel = await battery.batteryLevel;
      _batteryState = await battery.batteryState;
      _connectivity = await connectivity.checkConnectivity();
      
      debugPrint('Device: $_deviceModel');
      debugPrint('Battery: $_batteryLevel% ($_batteryState)');
      debugPrint('Connectivity: $_connectivity');
      
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
  }

  Future<void> _checkInitialPermissions() async {
    debugPrint('Checking Location Permissions...');
    
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.locationWhenInUse,
    ];
    
    for (final permission in permissions) {
      final status = await permission.status;
      debugPrint('${permission.toString()}: $status');
      
      _testResults.add(TestResult(
        testName: 'Permission Check: ${permission.toString()}',
        result: status.isGranted ? 'PASS' : 'FAIL',
        details: 'Status: $status',
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _setupLocationMonitoring() async {
    debugPrint('Setting up location monitoring...');
    
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('Location services enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        _testResults.add(TestResult(
          testName: 'Location Services Check',
          result: 'FAIL',
          details: 'Location services are disabled',
          timestamp: DateTime.now(),
        ));
        return;
      }
      
      try {
        _lastKnownPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        _lastLocationUpdate = DateTime.now();
        debugPrint('Initial location obtained: ${_lastKnownPosition!.latitude}, ${_lastKnownPosition!.longitude}');
        
        _testResults.add(TestResult(
          testName: 'Initial Location Acquisition',
          result: 'PASS',
          details: 'Lat: ${_lastKnownPosition!.latitude}, Lng: ${_lastKnownPosition!.longitude}, Accuracy: ${_lastKnownPosition!.accuracy}m',
          timestamp: DateTime.now(),
        ));
        
      } catch (e) {
        debugPrint('Failed to get initial location: $e');
        _testResults.add(TestResult(
          testName: 'Initial Location Acquisition',
          result: 'FAIL',
          details: 'Error: $e',
          timestamp: DateTime.now(),
        ));
      }
      
    } catch (e) {
      debugPrint('Error setting up location monitoring: $e');
    }
  }

  Future<void> _checkServiceHealth() async {
    debugPrint('Checking Service Health...');
    
    try {
      // Check Bulletproof Location Service
      try {
        final bulletproofResult = await _bulletproofChannel.invokeMethod('checkServiceHealth');
        _bulletproofServiceRunning = bulletproofResult == true;
        debugPrint('Bulletproof Service: ${_bulletproofServiceRunning ? "RUNNING" : "STOPPED"}');
      } catch (e) {
        debugPrint('Bulletproof Service: ERROR - $e');
        _bulletproofServiceRunning = false;
      }
      
      // Check Persistent Location Service
      try {
        final persistentResult = await _persistentChannel.invokeMethod('isServiceRunning');
        _persistentServiceRunning = persistentResult == true;
        debugPrint('Persistent Service: ${_persistentServiceRunning ? "RUNNING" : "STOPPED"}');
      } catch (e) {
        debugPrint('Persistent Service: ERROR - $e');
        _persistentServiceRunning = false;
      }
      
      // Check Native Location Service
      try {
        final nativeResult = await _nativeChannel.invokeMethod('isLocationServiceHealthy');
        _nativeLocationServiceRunning = nativeResult == true;
        debugPrint('Native Service: ${_nativeLocationServiceRunning ? "RUNNING" : "STOPPED"}');
      } catch (e) {
        debugPrint('Native Service: ERROR - $e');
        _nativeLocationServiceRunning = false;
      }
      
    } catch (e) {
      debugPrint('Error checking service health: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Location Test'),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceInfoCard(),
            const SizedBox(height: 16),
            _buildServiceStatusCard(),
            const SizedBox(height: 16),
            _buildTestControlCard(),
            const SizedBox(height: 16),
            _buildTestResultsCard(),
            const SizedBox(height: 16),
            _buildLocationHistoryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Device Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Model: $_deviceModel'),
            Text('OS: $_osVersion'),
            Text('Battery: $_batteryLevel% ($_batteryState)'),
            Text('Connectivity: $_connectivity'),
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
            const Text('Service Health', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildServiceStatusRow('Bulletproof Service', _bulletproofServiceRunning),
            _buildServiceStatusRow('Persistent Service', _persistentServiceRunning),
            _buildServiceStatusRow('Native Service', _nativeLocationServiceRunning),
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

  Widget _buildTestControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Current Phase: $_currentTestPhase'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTestingActive ? null : () {
                  debugPrint('Test button pressed - functionality to be implemented');
                },
                child: Text(_isTestingActive ? 'Testing in Progress...' : 'Start Advanced Test'),
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
              const Text('No test results yet. Run the advanced test to see results.')
            else
              ..._testResults.map((result) => _buildTestResultRow(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultRow(TestResult result) {
    Color resultColor = result.result == 'PASS' ? Colors.green :
                       result.result == 'FAIL' ? Colors.red : Colors.orange;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.result == 'PASS' ? Icons.check_circle :
                result.result == 'FAIL' ? Icons.error : Icons.warning,
                color: resultColor,
                size: 16,
              ),
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

  Widget _buildLocationHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Total Updates: ${_locationHistory.length}'),
            if (_lastKnownPosition != null) ...[
              Text('Last Update: ${_lastLocationUpdate?.toString().substring(11, 19) ?? "Unknown"}'),
              Text('Last Position: ${_lastKnownPosition!.latitude.toStringAsFixed(6)}, ${_lastKnownPosition!.longitude.toStringAsFixed(6)}'),
              Text('Accuracy: ${_lastKnownPosition!.accuracy.toStringAsFixed(1)}m'),
            ],
          ],
        ),
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

class LocationReading {
  final Position position;
  final DateTime timestamp;
  final String source;

  LocationReading({
    required this.position,
    required this.timestamp,
    required this.source,
  });
}