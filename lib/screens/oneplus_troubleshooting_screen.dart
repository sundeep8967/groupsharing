import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ultra_persistent_location_service.dart';
import '../services/oneplus_optimization_service.dart';

class OnePlusTroubleshootingScreen extends StatefulWidget {
  const OnePlusTroubleshootingScreen({Key? key}) : super(key: key);

  @override
  State<OnePlusTroubleshootingScreen> createState() => _OnePlusTroubleshootingScreenState();
}

class _OnePlusTroubleshootingScreenState extends State<OnePlusTroubleshootingScreen> {
  Map<String, dynamic> _troubleshootingInfo = {};
  bool _isLoading = true;
  bool _isOnePlusDevice = false;

  @override
  void initState() {
    super.initState();
    _loadTroubleshootingInfo();
  }

  Future<void> _loadTroubleshootingInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isOnePlus = await OnePlusOptimizationService.isOnePlusDevice();
      final troubleshootingInfo = await UltraPersistentLocationService.getTroubleshootingInfo();
      
      setState(() {
        _isOnePlusDevice = isOnePlus;
        _troubleshootingInfo = troubleshootingInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _troubleshootingInfo = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Troubleshooting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTroubleshootingInfo,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyTroubleshootingInfo,
            tooltip: 'Copy Info',
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
                  _buildServiceStatusCard(),
                  const SizedBox(height: 16),
                  _buildOptimizationStatusCard(),
                  const SizedBox(height: 16),
                  if (_isOnePlusDevice) _buildOnePlusSpecificCard(),
                  if (_isOnePlusDevice) const SizedBox(height: 16),
                  _buildQuickActionsCard(),
                  const SizedBox(height: 16),
                  _buildTroubleshootingStepsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final deviceInfo = _troubleshootingInfo['deviceInfo'] as Map<String, dynamic>?;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isOnePlusDevice ? Icons.warning : Icons.phone_android,
                  color: _isOnePlusDevice ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Device Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (deviceInfo != null) ...[
              _buildInfoRow('Manufacturer', deviceInfo['manufacturer'] ?? 'Unknown'),
              _buildInfoRow('Brand', deviceInfo['brand'] ?? 'Unknown'),
              _buildInfoRow('Model', deviceInfo['model'] ?? 'Unknown'),
              _buildInfoRow('Android Version', deviceInfo['androidVersion'] ?? 'Unknown'),
              _buildInfoRow('SDK Level', deviceInfo['sdkInt']?.toString() ?? 'Unknown'),
              _buildInfoRow('Needs Ultra Persistent', 
                _troubleshootingInfo['needsUltraPersistent']?.toString() ?? 'Unknown'),
            ] else
              const Text('Device information not available'),
            
            if (_isOnePlusDevice) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OnePlus device detected. Special optimizations required for reliable background location.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    final serviceStatus = _troubleshootingInfo['serviceStatus'] as Map<String, dynamic>?;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  serviceStatus?['isTracking'] == true ? Icons.location_on : Icons.location_off,
                  color: serviceStatus?['isTracking'] == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Service Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (serviceStatus != null) ...[
              _buildStatusRow('Initialized', serviceStatus['isInitialized'] ?? false),
              _buildStatusRow('Tracking Active', serviceStatus['isTracking'] ?? false),
              _buildInfoRow('Current User', serviceStatus['currentUserId'] ?? 'None'),
              _buildStatusRow('Health Monitoring', serviceStatus['hasHealthMonitoring'] ?? false),
              _buildInfoRow('Platform', serviceStatus['platform'] ?? 'Unknown'),
              
              const SizedBox(height: 8),
              const Text('Service Health:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildStatusRow('Persistent Service', 
                _troubleshootingInfo['persistentServiceHealthy'] ?? false),
              _buildStatusRow('Background Service', 
                _troubleshootingInfo['backgroundServiceHealthy'] ?? false),
              
              if (_troubleshootingInfo['persistentServiceError'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Persistent Service Error: ${_troubleshootingInfo['persistentServiceError']}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              
              if (_troubleshootingInfo['backgroundServiceError'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Background Service Error: ${_troubleshootingInfo['backgroundServiceError']}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ] else
              const Text('Service status not available'),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizationStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_saver, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Optimization Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, bool>>(
              future: _isOnePlusDevice 
                ? OnePlusOptimizationService.checkOnePlusOptimizations()
                : Future.value(<String, bool>{}),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                
                final optimizations = snapshot.data ?? {};
                
                if (optimizations.isEmpty) {
                  return const Text('Optimization check not available for this device');
                }
                
                return Column(
                  children: [
                    _buildStatusRow('Battery Optimization Disabled', 
                      optimizations['battery_optimization'] ?? false),
                    _buildStatusRow('Auto-Start Enabled', 
                      optimizations['auto_start'] ?? false),
                    _buildStatusRow('Background Refresh Enabled', 
                      optimizations['background_refresh'] ?? false),
                    _buildStatusRow('App Lock Configured', 
                      optimizations['app_lock'] ?? false),
                    _buildStatusRow('Gaming Mode Configured', 
                      optimizations['gaming_mode'] ?? true),
                    _buildStatusRow('Zen Mode Configured', 
                      optimizations['zen_mode'] ?? true),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnePlusSpecificCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'OnePlus Specific Issues',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Common OnePlus issues that stop background location:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildIssueItem('Battery optimization is enabled', 
              'Go to Settings > Battery > Battery optimization > GroupSharing > Don\'t optimize'),
            _buildIssueItem('Auto-start is disabled', 
              'Go to Settings > Apps > Auto-start management > GroupSharing > Enable'),
            _buildIssueItem('Background app refresh is disabled', 
              'Go to Settings > Apps > App management > GroupSharing > Battery > Unrestricted'),
            _buildIssueItem('Sleep standby optimization is enabled', 
              'Go to Settings > Battery > More battery settings > Sleep standby optimization > Disable'),
            _buildIssueItem('App is locked in security settings', 
              'Go to Settings > Security > App lock > Make sure GroupSharing is NOT locked'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _restartServices,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restart Services'),
                ),
                if (_isOnePlusDevice)
                  ElevatedButton.icon(
                    onPressed: _openOnePlusSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('OnePlus Setup'),
                  ),
                ElevatedButton.icon(
                  onPressed: _openAppSettings,
                  icon: const Icon(Icons.app_settings_alt),
                  label: const Text('App Settings'),
                ),
                ElevatedButton.icon(
                  onPressed: _testLocationService,
                  icon: const Icon(Icons.location_searching),
                  label: const Text('Test Location'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingStepsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Troubleshooting Steps',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isOnePlusDevice) ...[
              const Text(
                'OnePlus Device Troubleshooting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...OnePlusOptimizationService.getOnePlusTroubleshootingSteps('OnePlus')
                  .asMap()
                  .entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${entry.key + 1}. ${entry.value}'),
                      )),
            ] else ...[
              const Text(
                'General Troubleshooting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Check location permissions are granted'),
              const Text('2. Ensure background location permission is enabled'),
              const Text('3. Disable battery optimization for GroupSharing'),
              const Text('4. Keep the app in recent apps list'),
              const Text('5. Restart the device if issues persist'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label),
          ),
          Text(
            status ? 'OK' : 'ISSUE',
            style: TextStyle(
              color: status ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueItem(String issue, String solution) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  issue,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              solution,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restartServices() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restarting location services...')),
      );
      
      // Restart the ultra persistent service
      await UltraPersistentLocationService.stopLocationTracking();
      await Future.delayed(const Duration(seconds: 2));
      
      // Get current user ID from saved state
      final savedState = _troubleshootingInfo['savedState'] as Map<String, dynamic>?;
      final userId = savedState?['userId'] as String?;
      
      if (userId != null) {
        await UltraPersistentLocationService.startLocationTracking(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services restarted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user ID found - please restart location sharing from main screen'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Refresh info
      await _loadTroubleshootingInfo();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restarting services: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openOnePlusSettings() async {
    try {
      await OnePlusOptimizationService.requestAllOnePlusOptimizations(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening OnePlus settings: $e')),
      );
    }
  }

  Future<void> _openAppSettings() async {
    try {
      const platform = MethodChannel('android_permissions');
      await platform.invokeMethod('openAppSettings');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening app settings: $e')),
      );
    }
  }

  Future<void> _testLocationService() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Testing location service...')),
      );
      
      // Get fresh troubleshooting info
      final info = await UltraPersistentLocationService.getTroubleshootingInfo();
      
      final serviceStatus = info['serviceStatus'] as Map<String, dynamic>?;
      final isTracking = serviceStatus?['isTracking'] ?? false;
      
      if (isTracking) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location service is running correctly'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location service is not running - check settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      await _loadTroubleshootingInfo();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing location service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyTroubleshootingInfo() async {
    try {
      final info = _troubleshootingInfo.toString();
      await Clipboard.setData(ClipboardData(text: info));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Troubleshooting info copied to clipboard')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error copying info: $e')),
      );
    }
  }
}