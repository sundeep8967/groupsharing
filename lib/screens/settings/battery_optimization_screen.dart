import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../services/battery_optimization_service.dart';

/// Battery Optimization Settings Screen
/// 
/// This screen allows users to manually configure battery optimization settings
/// for better location tracking reliability.
class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() => _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen> {
  bool _isLoading = false;
  bool? _isBatteryOptimizationDisabled;
  Map<String, dynamic>? _optimizationStatus;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimizationStatus();
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final isDisabled = await BatteryOptimizationService.isBatteryOptimizationDisabled();
      final status = await BatteryOptimizationService.getComprehensiveOptimizationStatus();
      
      setState(() {
        _isBatteryOptimizationDisabled = isDisabled;
        _optimizationStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking battery optimization: $e')),
        );
      }
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      final success = await locationProvider.requestBatteryOptimizationExemption();
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Battery optimization disabled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable in Settings manually for better reliability'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () {
                  BatteryOptimizationService.requestDisableBatteryOptimization();
                },
              ),
            ),
          );
        }
      }
      
      // Refresh status
      await _checkBatteryOptimizationStatus();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openAppSettings() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.openAppSettingsManually();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Optimization'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildActionsCard(),
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.battery_saver,
                  color: Colors.orange[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Battery Optimization',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'For the most reliable location sharing, disable battery optimization for this app. '
              'This ensures your location continues to be shared even when your phone tries to save battery.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isOptimized = _isBatteryOptimizationDisabled == false;
    final statusColor = isOptimized ? Colors.orange : Colors.green;
    final statusIcon = isOptimized ? Icons.warning : Icons.check_circle;
    final statusText = isOptimized 
        ? 'Battery optimization is enabled (may affect reliability)'
        : 'Battery optimization is disabled (optimal)';

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    final isOptimized = _isBatteryOptimizationDisabled == false;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            if (isOptimized) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestBatteryOptimizationExemption,
                  icon: const Icon(Icons.battery_saver_outlined),
                  label: const Text('Disable Battery Optimization'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openAppSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open App Settings'),
              ),
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _checkBatteryOptimizationStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why This Matters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildInfoItem(
              Icons.location_on,
              'Reliable Location Sharing',
              'Ensures your location is shared continuously with family and friends',
            ),
            
            _buildInfoItem(
              Icons.security,
              'Emergency Features',
              'Critical for emergency SOS and safety features to work properly',
            ),
            
            _buildInfoItem(
              Icons.notifications,
              'Real-time Updates',
              'Enables instant notifications and location updates',
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This setting is optional. Your app will work without it, but may be less reliable in the background.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}