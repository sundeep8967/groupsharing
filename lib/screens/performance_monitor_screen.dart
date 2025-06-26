import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/performance_optimizer.dart';

/// Performance monitoring screen to track optimization metrics
/// Shows real-time performance data and optimization status
class PerformanceMonitorScreen extends StatefulWidget {
  const PerformanceMonitorScreen({super.key});

  @override
  State<PerformanceMonitorScreen> createState() => _PerformanceMonitorScreenState();
}

class _PerformanceMonitorScreenState extends State<PerformanceMonitorScreen> {
  final PerformanceOptimizer _performanceOptimizer = PerformanceOptimizer();
  Timer? _refreshTimer;
  Map<String, dynamic> _performanceStatus = {};
  Map<String, Duration> _operationMetrics = {};
  List<String> _performanceLogs = [];

  @override
  void initState() {
    super.initState();
    _refreshPerformanceData();
    
    // Refresh data every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshPerformanceData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshPerformanceData() {
    if (mounted) {
      setState(() {
        _performanceStatus = _performanceOptimizer.getPerformanceStatus();
        _operationMetrics = _performanceOptimizer.getAllMetrics();
        _performanceLogs = _performanceOptimizer.getPerformanceLogs();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Monitor'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPerformanceData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Status Card
            _buildPerformanceStatusCard(),
            
            const SizedBox(height: 16),
            
            // Battery & Network Status
            _buildSystemStatusCard(),
            
            const SizedBox(height: 16),
            
            // Operation Metrics
            _buildOperationMetricsCard(),
            
            const SizedBox(height: 16),
            
            // Optimization Settings
            _buildOptimizationSettingsCard(),
            
            const SizedBox(height: 16),
            
            // Performance Logs
            _buildPerformanceLogsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceStatusCard() {
    final isLowPowerMode = _performanceStatus['isLowPowerMode'] ?? false;
    final isSlowNetwork = _performanceStatus['isSlowNetwork'] ?? false;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLowPowerMode || isSlowNetwork ? Icons.warning : Icons.check_circle,
                  color: isLowPowerMode || isSlowNetwork ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Performance Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildStatusRow(
              'Power Mode',
              isLowPowerMode ? 'LOW POWER' : 'NORMAL',
              isLowPowerMode ? Colors.orange : Colors.green,
            ),
            
            _buildStatusRow(
              'Network',
              isSlowNetwork ? 'SLOW/LIMITED' : 'FAST',
              isSlowNetwork ? Colors.orange : Colors.green,
            ),
            
            _buildStatusRow(
              'Memory',
              _performanceStatus['isLowMemoryDevice'] == true ? 'LOW' : 'NORMAL',
              _performanceStatus['isLowMemoryDevice'] == true ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            // Battery Status
            Row(
              children: [
                const Icon(Icons.battery_std, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Battery: ${_performanceStatus['batteryLevel'] ?? 'Unknown'}%'),
                const Spacer(),
                Text(
                  _performanceStatus['batteryState']?.toString().split('.').last ?? 'Unknown',
                  style: TextStyle(
                    color: _getBatteryStateColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Network Status
            Row(
              children: [
                const Icon(Icons.network_check, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Network: ${_performanceStatus['connectionType']?.toString().split('.').last ?? 'Unknown'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationMetricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operation Metrics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            if (_operationMetrics.isEmpty)
              const Text('No operations recorded yet')
            else
              ..._operationMetrics.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    Text(
                      '${entry.value.inMilliseconds}ms',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getPerformanceColor(entry.value.inMilliseconds),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizationSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optimization Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            _buildSettingRow(
              'Location Interval',
              '${_performanceOptimizer.getOptimizedLocationInterval().inSeconds}s',
            ),
            
            _buildSettingRow(
              'Location Accuracy',
              '${_performanceOptimizer.getOptimizedLocationAccuracy().toInt()}m',
            ),
            
            _buildSettingRow(
              'Map Cache Size',
              '${_performanceOptimizer.getOptimizedMapCacheSize()}MB',
            ),
            
            _buildSettingRow(
              'Firebase Interval',
              '${_performanceOptimizer.getOptimizedFirebaseUpdateInterval().inSeconds}s',
            ),
            
            _buildSettingRow(
              'Debounce Interval',
              '${_performanceOptimizer.getOptimizedDebounceInterval().inMilliseconds}ms',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceLogsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Logs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _performanceLogs.length,
                reverse: true, // Show newest logs first
                itemBuilder: (context, index) {
                  final log = _performanceLogs[_performanceLogs.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: Colors.green,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
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

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: '),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color _getBatteryStateColor() {
    final state = _performanceStatus['batteryState']?.toString().split('.').last;
    switch (state) {
      case 'charging':
        return Colors.green;
      case 'discharging':
        return Colors.orange;
      case 'full':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getPerformanceColor(int milliseconds) {
    if (milliseconds < 100) return Colors.green;
    if (milliseconds < 500) return Colors.orange;
    return Colors.red;
  }
}