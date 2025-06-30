import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/battery_optimization_service.dart';
import '../../services/oneplus_optimization_service.dart';
import 'comprehensive_debug_screen.dart';
import 'dart:io';

/// Background Location Fix Screen
/// 
/// This screen diagnoses and fixes background location issues
/// for different Android manufacturers and devices.
class BackgroundLocationFixScreen extends StatefulWidget {
  const BackgroundLocationFixScreen({super.key});

  @override
  State<BackgroundLocationFixScreen> createState() => _BackgroundLocationFixScreenState();
}

class _BackgroundLocationFixScreenState extends State<BackgroundLocationFixScreen> {
  bool _isLoading = true;
  String _deviceInfo = '';
  String _manufacturer = '';
  String _model = '';
  String _androidVersion = '';
  Map<String, bool> _permissionStatus = {};
  Map<String, bool> _optimizationStatus = {};
  List<String> _issues = [];
  List<String> _fixes = [];
  bool _isFixing = false;

  @override
  void initState() {
    super.initState();
    _diagnoseDevice();
  }

  Future<void> _diagnoseDevice() async {
    setState(() => _isLoading = true);
    
    try {
      // Get device information
      await _getDeviceInfo();
      
      // Check permissions
      await _checkPermissions();
      
      // Check optimizations
      await _checkOptimizations();
      
      // Analyze issues
      _analyzeIssues();
      
      // Generate fixes
      _generateFixes();
      
    } catch (e) {
      debugPrint('Error diagnosing device: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      setState(() {
        _manufacturer = androidInfo.manufacturer;
        _model = androidInfo.model;
        _androidVersion = androidInfo.version.release;
        _deviceInfo = '${androidInfo.manufacturer} ${androidInfo.model} (Android ${androidInfo.version.release})';
      });
    } catch (e) {
      setState(() {
        _deviceInfo = 'Unknown device';
      });
    }
  }

  Future<void> _checkPermissions() async {
    final permissions = <String, bool>{};
    
    try {
      // Basic location permission
      final location = await Permission.location.status;
      permissions['Location'] = location.isGranted;
      
      // Background location permission
      final backgroundLocation = await Permission.locationAlways.status;
      permissions['Background Location'] = backgroundLocation.isGranted;
      
      // Battery optimization
      final batteryOptimization = await Permission.ignoreBatteryOptimizations.status;
      permissions['Battery Optimization Disabled'] = batteryOptimization.isGranted;
      
      // Notification permission
      final notification = await Permission.notification.status;
      permissions['Notifications'] = notification.isGranted;
      
      // Check if location services are enabled
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      permissions['Location Services Enabled'] = locationEnabled;
      
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
    
    setState(() {
      _permissionStatus = permissions;
    });
  }

  Future<void> _checkOptimizations() async {
    final optimizations = <String, bool>{};
    
    try {
      // Battery optimization
      final batteryDisabled = await BatteryOptimizationService.isBatteryOptimizationDisabled();
      optimizations['Battery Optimization Disabled'] = batteryDisabled;
      
      // Device-specific checks
      if (_manufacturer.toLowerCase().contains('oneplus') || 
          _manufacturer.toLowerCase().contains('oppo')) {
        final oneplusOptimizations = await OnePlusOptimizationService.checkOnePlusOptimizations();
        optimizations.addAll(oneplusOptimizations);
      }
      
    } catch (e) {
      debugPrint('Error checking optimizations: $e');
    }
    
    setState(() {
      _optimizationStatus = optimizations;
    });
  }

  void _analyzeIssues() {
    final issues = <String>[];
    
    // Check permission issues
    _permissionStatus.forEach((key, value) {
      if (!value) {
        issues.add('Missing: $key');
      }
    });
    
    // Check optimization issues
    _optimizationStatus.forEach((key, value) {
      if (!value) {
        issues.add('Not optimized: $key');
      }
    });
    
    // Device-specific issues
    if (_manufacturer.toLowerCase().contains('oneplus')) {
      issues.add('OnePlus device detected - requires special setup');
    } else if (_manufacturer.toLowerCase().contains('xiaomi')) {
      issues.add('Xiaomi device detected - requires MIUI optimizations');
    } else if (_manufacturer.toLowerCase().contains('huawei')) {
      issues.add('Huawei device detected - requires EMUI optimizations');
    } else if (_manufacturer.toLowerCase().contains('samsung')) {
      issues.add('Samsung device detected - check Device Care settings');
    } else if (_manufacturer.toLowerCase().contains('oppo')) {
      issues.add('Oppo device detected - requires ColorOS optimizations');
    } else if (_manufacturer.toLowerCase().contains('vivo')) {
      issues.add('Vivo device detected - requires FunTouch OS optimizations');
    }
    
    setState(() {
      _issues = issues;
    });
  }

  void _generateFixes() {
    final fixes = <String>[];
    
    // Permission fixes
    if (!(_permissionStatus['Location'] ?? false)) {
      fixes.add('Grant location permission');
    }
    
    if (!(_permissionStatus['Background Location'] ?? false)) {
      fixes.add('Grant "Allow all the time" location permission');
    }
    
    if (!(_permissionStatus['Battery Optimization Disabled'] ?? false)) {
      fixes.add('Disable battery optimization for this app');
    }
    
    if (!(_permissionStatus['Location Services Enabled'] ?? false)) {
      fixes.add('Enable location services in device settings');
    }
    
    // Device-specific fixes
    if (_manufacturer.toLowerCase().contains('oneplus')) {
      fixes.addAll([
        'Enable Auto-start permission',
        'Disable App Lock for GroupSharing',
        'Set battery usage to "Unrestricted"',
        'Disable Sleep standby optimization',
      ]);
    } else if (_manufacturer.toLowerCase().contains('xiaomi')) {
      fixes.addAll([
        'Enable Autostart in Security app',
        'Disable battery optimization in Security app',
        'Add to Memory cleanup whitelist',
        'Disable MIUI optimization (Developer options)',
      ]);
    } else if (_manufacturer.toLowerCase().contains('huawei')) {
      fixes.addAll([
        'Enable Auto-launch in Phone Manager',
        'Add to Protected apps list',
        'Disable Power Genie optimization',
        'Set Launch to "Manage manually"',
      ]);
    } else if (_manufacturer.toLowerCase().contains('samsung')) {
      fixes.addAll([
        'Add to "Never sleeping apps" in Device Care',
        'Disable "Put unused apps to sleep"',
        'Set battery usage to "Unrestricted"',
        'Disable Adaptive Battery for this app',
      ]);
    }
    
    setState(() {
      _fixes = fixes;
    });
  }

  Future<void> _applyAutomaticFixes() async {
    setState(() => _isFixing = true);
    
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // Request location permission
      if (!(_permissionStatus['Location'] ?? false)) {
        await Permission.location.request();
      }
      
      // Request background location permission
      if (!(_permissionStatus['Background Location'] ?? false)) {
        await Permission.locationAlways.request();
      }
      
      // Request battery optimization exemption
      if (!(_permissionStatus['Battery Optimization Disabled'] ?? false)) {
        await locationProvider.requestBatteryOptimizationExemption();
      }
      
      // Request notification permission
      if (!(_permissionStatus['Notifications'] ?? false)) {
        await Permission.notification.request();
      }
      
      // Re-diagnose after fixes
      await _diagnoseDevice();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Automatic fixes applied! Check the manual steps below.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying fixes: $e')),
        );
      }
    } finally {
      setState(() => _isFixing = false);
    }
  }

  Future<void> _openDeviceSettings() async {
    try {
      if (_manufacturer.toLowerCase().contains('oneplus')) {
        // Try to open OnePlus-specific settings
        await OnePlusOptimizationService.requestAllOnePlusOptimizations(context);
      } else {
        // Open general app settings
        await openAppSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening settings: $e')),
        );
      }
    }
  }

  Future<void> _testBackgroundLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    try {
      // Start location tracking
      final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
      if (user != null) {
        await locationProvider.startTracking(user.uid);
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Background Test Started'),
              content: const Text(
                'Location tracking has been started. Now:\n\n'
                '1. Put the app in background\n'
                '2. Wait 2-3 minutes\n'
                '3. Check if location is still updating\n\n'
                'Come back to this screen to see the results.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting test: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Location Fix'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ComprehensiveDebugScreen(),
                ),
              );
            },
            tooltip: 'Advanced Debug',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _diagnoseDevice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeviceInfoCard(),
                  const SizedBox(height: 16),
                  _buildIssuesCard(),
                  const SizedBox(height: 16),
                  _buildPermissionStatusCard(),
                  const SizedBox(height: 16),
                  _buildFixesCard(),
                  const SizedBox(height: 16),
                  _buildActionsCard(),
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
            Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Device Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Device: $_deviceInfo'),
            Text('Manufacturer: $_manufacturer'),
            Text('Model: $_model'),
            Text('Android Version: $_androidVersion'),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesCard() {
    final hasIssues = _issues.isNotEmpty;
    
    return Card(
      color: hasIssues ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasIssues ? Icons.warning : Icons.check_circle,
                  color: hasIssues ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  hasIssues ? 'Issues Found (${_issues.length})' : 'No Issues Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasIssues ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            if (hasIssues) ...[
              const SizedBox(height: 12),
              ...(_issues.map((issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(issue)),
                  ],
                ),
              ))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permission Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...(_permissionStatus.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.cancel,
                    color: entry.value ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key)),
                  Text(
                    entry.value ? 'OK' : 'MISSING',
                    style: TextStyle(
                      color: entry.value ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ))),
          ],
        ),
      ),
    );
  }

  Widget _buildFixesCard() {
    if (_fixes.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Required Fixes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...(_fixes.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isFixing ? null : _applyAutomaticFixes,
                icon: _isFixing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isFixing ? 'Applying Fixes...' : 'Apply Automatic Fixes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openDeviceSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Device Settings'),
              ),
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testBackgroundLocation,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test Background Location'),
              ),
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ComprehensiveDebugScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Advanced Debug & Logging'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}