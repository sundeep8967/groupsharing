import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/comprehensive_location_fix_service.dart';
import '../../services/persistent_foreground_notification_service.dart';
import '../../services/background_location_debug_service.dart';
import 'dart:io';

/// Comprehensive Debug Screen
/// 
/// This screen provides comprehensive debugging and diagnostics for
/// the integrated location services and notification system.
class ComprehensiveDebugScreen extends StatefulWidget {
  const ComprehensiveDebugScreen({super.key});

  @override
  State<ComprehensiveDebugScreen> createState() => _ComprehensiveDebugScreenState();
}

class _ComprehensiveDebugScreenState extends State<ComprehensiveDebugScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _comprehensiveStatus = {};
  Map<String, dynamic> _notificationStatus = {};
  List<String> _availableServices = [];
  String? _activeService;
  bool _isDebugging = false;
  List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    
    try {
      // Get comprehensive service status
      _comprehensiveStatus = ComprehensiveLocationFixService.getStatusInfo();
      
      // Get notification service status
      _notificationStatus = PersistentForegroundNotificationService.getStatusInfo();
      
      // Get available services
      _availableServices = ComprehensiveLocationFixService.getAvailableServices();
      
      // Get active service
      _activeService = ComprehensiveLocationFixService.activeService;
      
    } catch (e) {
      debugPrint('Error loading status: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _startDebugging() async {
    setState(() => _isDebugging = true);
    
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      await BackgroundLocationDebugService.startDebugging(
        userId: authProvider.user?.uid,
        locationProvider: locationProvider,
      );
      
      // Listen to debug logs
      BackgroundLocationDebugService.debugLogsStream.listen((logEntry) {
        setState(() {
          _debugLogs.add('${logEntry.timestamp}: ${logEntry.message}');
        });
      });
      
    } catch (e) {
      debugPrint('Error starting debugging: $e');
    }
  }

  Future<void> _stopDebugging() async {
    setState(() => _isDebugging = false);
    
    try {
      await BackgroundLocationDebugService.stopDebugging();
    } catch (e) {
      debugPrint('Error stopping debugging: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprehensive Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isDebugging ? Icons.stop : Icons.play_arrow),
            onPressed: _isDebugging ? _stopDebugging : _startDebugging,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatus,
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
                  _buildServiceStatusCard(),
                  const SizedBox(height: 16),
                  _buildNotificationStatusCard(),
                  const SizedBox(height: 16),
                  _buildAvailableServicesCard(),
                  const SizedBox(height: 16),
                  _buildDebugControlsCard(),
                  const SizedBox(height: 16),
                  if (_debugLogs.isNotEmpty) _buildDebugLogsCard(),
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
            const Text(
              'Comprehensive Location Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Initialized', _comprehensiveStatus['isInitialized'] ?? false),
            _buildStatusRow('Tracking', _comprehensiveStatus['isTracking'] ?? false),
            _buildStatusRow('Active Service', _activeService ?? 'None'),
            _buildStatusRow('Current User', _comprehensiveStatus['currentUserId'] ?? 'None'),
            _buildStatusRow('Last Location Update', _comprehensiveStatus['lastLocationUpdate'] ?? 'Never'),
            _buildStatusRow('Platform', _comprehensiveStatus['platform'] ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Persistent Notification Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Initialized', _notificationStatus['isInitialized'] ?? false),
            _buildStatusRow('Notification Active', _notificationStatus['isNotificationActive'] ?? false),
            _buildStatusRow('Foreground Service Running', _notificationStatus['isForegroundServiceRunning'] ?? false),
            _buildStatusRow('Location Sharing', _notificationStatus['isLocationSharing'] ?? false),
            _buildStatusRow('Friends Count', _notificationStatus['friendsCount']?.toString() ?? '0'),
            _buildStatusRow('Location Status', _notificationStatus['locationStatus'] ?? 'Unknown'),
            if (_notificationStatus['currentLocation'] != null)
              _buildStatusRow('Current Location', 
                '${_notificationStatus['currentLocation']['lat']?.toStringAsFixed(4)}, ${_notificationStatus['currentLocation']['lng']?.toStringAsFixed(4)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableServicesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_availableServices.isEmpty)
              const Text('No services available', style: TextStyle(color: Colors.red))
            else
              ..._availableServices.map((service) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      service == _activeService ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: service == _activeService ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(service),
                    const Spacer(),
                    if (service != _activeService)
                      ElevatedButton(
                        onPressed: () => _switchToService(service),
                        child: const Text('Switch'),
                      ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDebugging ? _stopDebugging : _startDebugging,
                    icon: Icon(_isDebugging ? Icons.stop : Icons.play_arrow),
                    label: Text(_isDebugging ? 'Stop Debug' : 'Start Debug'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDebugging ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearLogs,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Logs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testNotification,
                    icon: const Icon(Icons.notifications),
                    label: const Text('Test Notification'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportLogs,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Logs'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugLogsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Debug Logs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${_debugLogs.length} entries'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: _debugLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(
                      _debugLogs[index],
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value) {
    Color? valueColor;
    if (value is bool) {
      valueColor = value ? Colors.green : Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchToService(String serviceName) async {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      if (authProvider.user?.uid != null) {
        final success = await ComprehensiveLocationFixService.switchToService(
          serviceName, 
          authProvider.user!.uid,
        );
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to $serviceName')),
          );
          _loadStatus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to switch to $serviceName')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error switching service: $e')),
      );
    }
  }

  void _clearLogs() {
    setState(() {
      _debugLogs.clear();
    });
  }

  Future<void> _testNotification() async {
    try {
      await PersistentForegroundNotificationService.updateLocationStatus(
        status: 'Test notification update',
        friendsCount: 99,
        isSharing: true,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification test sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification test failed: $e')),
      );
    }
  }

  Future<void> _exportLogs() async {
    try {
      final logs = _debugLogs.join('\n');
      await Clipboard.setData(ClipboardData(text: logs));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export logs: $e')),
      );
    }
  }
}