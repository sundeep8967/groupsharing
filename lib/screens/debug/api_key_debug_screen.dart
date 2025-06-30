import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_key_validator.dart';
import '../../config/api_keys.dart';

/// Debug screen for API key validation and configuration
class ApiKeyDebugScreen extends StatefulWidget {
  const ApiKeyDebugScreen({super.key});

  @override
  State<ApiKeyDebugScreen> createState() => _ApiKeyDebugScreenState();
}

class _ApiKeyDebugScreenState extends State<ApiKeyDebugScreen> {
  ValidationReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _validateKeys();
  }

  Future<void> _validateKeys() async {
    setState(() => _isLoading = true);
    
    // Add a small delay to show loading state
    await Future.delayed(const Duration(milliseconds: 500));
    
    final report = ApiKeyValidator.validateAllKeys();
    
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Key Debug'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _validateKeys,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_report == null) {
      return const Center(
        child: Text('Failed to validate API keys'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallStatus(),
          const SizedBox(height: 24),
          _buildReadinessCard(),
          const SizedBox(height: 24),
          _buildCategoryCard('Firebase Configuration', _report!.firebaseStatus),
          const SizedBox(height: 16),
          _buildCategoryCard('Map Services', _report!.mapServicesStatus),
          const SizedBox(height: 16),
          _buildCategoryCard('Third-party Services', _report!.thirdPartyStatus),
          const SizedBox(height: 16),
          _buildCategoryCard('Security', _report!.securityStatus),
          const SizedBox(height: 16),
          _buildCategoryCard('Push Notifications', _report!.pushNotificationStatus),
          const SizedBox(height: 24),
          _buildSetupInstructions(),
          const SizedBox(height: 24),
          _buildEnvironmentInfo(),
        ],
      ),
    );
  }

  Widget _buildOverallStatus() {
    final status = _report!.overallStatus;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getStatusDescription(status),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCard() {
    final isReady = _report!.isReadyToRun;
    final color = isReady ? Colors.green : Colors.orange;

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.warning,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Readiness',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isReady
                  ? 'Your app is ready to run! All critical API keys are configured.'
                  : 'Some critical API keys are missing. Check the setup instructions below.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!isReady && _report!.criticalMissingKeys.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Missing: ${_report!.criticalMissingKeys.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, Map<String, ValidationResult> results) {
    return Card(
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${results.values.where((r) => r.status == ValidationStatus.valid).length}/${results.length} configured',
        ),
        children: results.entries.map((entry) {
          return _buildKeyResult(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildKeyResult(String keyName, ValidationResult result) {
    final color = _getStatusColor(result.status);
    final icon = _getStatusIcon(result.status);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(keyName),
      subtitle: Text(result.message),
      trailing: result.status == ValidationStatus.valid
          ? IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(keyName),
              tooltip: 'Copy key info',
            )
          : null,
    );
  }

  Widget _buildSetupInstructions() {
    final instructions = ApiKeyValidator.getSetupInstructions(_report!);
    
    if (instructions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Setup Instructions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...instructions.map((instruction) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  instruction,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environment Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Environment', ApiKeys.environment),
            _buildInfoRow('Debug Mode', ApiKeys.debugMode.toString()),
            _buildInfoRow('Log Level', ApiKeys.logLevel),
            _buildInfoRow('Project ID', ApiKeys.projectId),
            _buildInfoRow('Bundle ID', ApiKeys.iosBundleId),
            const SizedBox(height: 16),
            Text(
              'Feature Flags',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Driving Detection', ApiKeys.enableDrivingDetection.toString()),
            _buildInfoRow('Emergency Features', ApiKeys.enableEmergencyFeatures.toString()),
            _buildInfoRow('Geofencing', ApiKeys.enableGeofencing.toString()),
            _buildInfoRow('Smart Places', ApiKeys.enableSmartPlaces.toString()),
            _buildInfoRow('Battery Optimization', ApiKeys.enableBatteryOptimization.toString()),
            _buildInfoRow('Offline Mode', ApiKeys.enableOfflineMode.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.valid:
        return Colors.green;
      case ValidationStatus.invalid:
        return Colors.red;
      case ValidationStatus.missing:
        return Colors.orange;
      case ValidationStatus.optional:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.valid:
        return Icons.check_circle;
      case ValidationStatus.invalid:
        return Icons.error;
      case ValidationStatus.missing:
        return Icons.warning;
      case ValidationStatus.optional:
        return Icons.info;
    }
  }

  String _getStatusDescription(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.valid:
        return 'All critical API keys are properly configured';
      case ValidationStatus.invalid:
        return 'Some API keys are invalid or missing';
      case ValidationStatus.missing:
        return 'Critical API keys are missing';
      case ValidationStatus.optional:
        return 'Only optional API keys are configured';
    }
  }

  void _copyToClipboard(String keyName) {
    Clipboard.setData(ClipboardData(text: keyName));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $keyName to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}