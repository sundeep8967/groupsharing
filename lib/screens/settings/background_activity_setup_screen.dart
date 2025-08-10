import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/background_activity_service.dart';
import '../../services/battery_optimization_service.dart';

class BackgroundActivitySetupScreen extends StatefulWidget {
  const BackgroundActivitySetupScreen({super.key});

  @override
  State<BackgroundActivitySetupScreen> createState() => _BackgroundActivitySetupScreenState();
}

class _BackgroundActivitySetupScreenState extends State<BackgroundActivitySetupScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isBackgroundActivityEnabled = false;
  Map<String, String> _deviceInfo = {};
  String _instructions = '';
  int _currentStep = 0;
  List<BackgroundActivityStep> _steps = [];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = await BackgroundActivityService.getDeviceInfo();
      final instructions = await BackgroundActivityService.getBackgroundActivityInstructions();
      final isEnabled = await BackgroundActivityService.isBackgroundActivityEnabled();
      
      setState(() {
        _deviceInfo = deviceInfo;
        _instructions = instructions;
        _isBackgroundActivityEnabled = isEnabled;
        _steps = _generateStepsForDevice(deviceInfo['manufacturer'] ?? 'unknown');
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading device info: $e')),
        );
      }
    }
  }

  List<BackgroundActivityStep> _generateStepsForDevice(String manufacturer) {
    switch (manufacturer) {
      case 'xiaomi':
      case 'redmi':
        return [
          BackgroundActivityStep(
            title: 'Battery Optimization',
            description: 'Disable battery optimization for unrestricted background activity',
            icon: Icons.battery_full,
            color: Colors.green,
            action: () => BatteryOptimizationService.requestDisableBatteryOptimization(),
          ),
          BackgroundActivityStep(
            title: 'Autostart Permission',
            description: 'Enable autostart to allow app restart after reboot',
            icon: Icons.restart_alt,
            color: Colors.blue,
            action: () => BatteryOptimizationService.requestAutoStartPermission(),
          ),
          BackgroundActivityStep(
            title: 'Background Activity',
            description: 'Allow background activity and pop-up windows',
            icon: Icons.apps,
            color: Colors.orange,
            action: () => BatteryOptimizationService.requestBackgroundAppPermission(),
          ),
        ];
        
      case 'oneplus':
        return [
          BackgroundActivityStep(
            title: 'Battery Optimization',
            description: 'Set battery usage to "Don\'t optimize"',
            icon: Icons.battery_full,
            color: Colors.green,
            action: () => BatteryOptimizationService.requestDisableBatteryOptimization(),
          ),
          BackgroundActivityStep(
            title: 'Auto-start Management',
            description: 'Enable auto-start for the app',
            icon: Icons.restart_alt,
            color: Colors.blue,
            action: () => BatteryOptimizationService.requestAutoStartPermission(),
          ),
          BackgroundActivityStep(
            title: 'Background Activity',
            description: 'Set battery usage to "Unrestricted"',
            icon: Icons.apps,
            color: Colors.orange,
            action: () => BatteryOptimizationService.requestBackgroundAppPermission(),
          ),
        ];
        
      case 'samsung':
        return [
          BackgroundActivityStep(
            title: 'Battery Optimization',
            description: 'Add app to "Apps not optimized" list',
            icon: Icons.battery_full,
            color: Colors.green,
            action: () => BatteryOptimizationService.requestDisableBatteryOptimization(),
          ),
          BackgroundActivityStep(
            title: 'Background Activity',
            description: 'Allow background activity in app settings',
            icon: Icons.apps,
            color: Colors.orange,
            action: () => BatteryOptimizationService.requestBackgroundAppPermission(),
          ),
          BackgroundActivityStep(
            title: 'Never Sleeping Apps',
            description: 'Add app to never sleeping apps list',
            icon: Icons.bedtime_off,
            color: Colors.purple,
            action: () => BatteryOptimizationService.requestDisableBatteryOptimization(),
          ),
        ];
        
      default:
        return [
          BackgroundActivityStep(
            title: 'Battery Optimization',
            description: 'Disable battery optimization for the app',
            icon: Icons.battery_full,
            color: Colors.green,
            action: () => BatteryOptimizationService.requestDisableBatteryOptimization(),
          ),
          BackgroundActivityStep(
            title: 'Background Activity',
            description: 'Enable background activity permissions',
            icon: Icons.apps,
            color: Colors.orange,
            action: () => BackgroundActivityService.requestBackgroundActivity(),
          ),
        ];
    }
  }

  Future<void> _executeStep(int stepIndex) async {
    if (stepIndex >= _steps.length) return;
    
    setState(() {
      _currentStep = stepIndex;
    });
    
    try {
      await _steps[stepIndex].action();
      
      // Wait a moment then check status
      await Future.delayed(const Duration(seconds: 2));
      await _checkBackgroundActivityStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error executing step: $e')),
        );
      }
    }
  }

  Future<void> _checkBackgroundActivityStatus() async {
    try {
      final isEnabled = await BackgroundActivityService.isBackgroundActivityEnabled();
      setState(() {
        _isBackgroundActivityEnabled = isEnabled;
      });
    } catch (e) {
      debugPrint('Error checking background activity status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Background Activity Setup'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Activity Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkBackgroundActivityStatus,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(),
              const SizedBox(height: 24),
              
              // Device Info Card
              _buildDeviceInfoCard(),
              const SizedBox(height: 24),
              
              // Steps
              if (!_isBackgroundActivityEnabled) ...[
                Text(
                  'Setup Steps',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  return _buildStepCard(step, index);
                }),
                const SizedBox(height: 24),
                
                // Instructions Card
                _buildInstructionsCard(),
              ] else ...[
                _buildSuccessCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isBackgroundActivityEnabled
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.orange.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isBackgroundActivityEnabled ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isBackgroundActivityEnabled ? Icons.check_circle : Icons.warning,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isBackgroundActivityEnabled 
                      ? 'Background Activity Enabled' 
                      : 'Background Activity Required',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBackgroundActivityEnabled
                      ? 'Your app can run in the background successfully!'
                      : 'Setup required for reliable location sharing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final manufacturer = _deviceInfo['manufacturer'] ?? 'Unknown';
    final model = _deviceInfo['model'] ?? 'Unknown';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Device Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Manufacturer: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(manufacturer.toUpperCase()),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Model: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(model),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(BackgroundActivityStep step, int index) {
    final isCurrentStep = index == _currentStep;
    
    return Card(
      elevation: isCurrentStep ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentStep 
            ? BorderSide(color: step.color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _executeStep(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  step.icon,
                  color: step.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${step.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: step.color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Detailed Instructions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _instructions,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Setup Complete!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your app is now configured for reliable background location sharing. '
              'The app will continue to work even when your phone is locked or the app is closed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundActivityStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Future<void> Function() action;

  BackgroundActivityStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.action,
  });
}