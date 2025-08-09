import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/oneplus_optimization_service.dart';
import '../services/comprehensive_permission_service.dart';

class OnePlusPermissionScreen extends StatefulWidget {
  const OnePlusPermissionScreen({Key? key}) : super(key: key);

  @override
  State<OnePlusPermissionScreen> createState() => _OnePlusPermissionScreenState();
}

class _OnePlusPermissionScreenState extends State<OnePlusPermissionScreen> {
  bool _isOnePlusDevice = false;
  String _deviceModel = '';
  Map<String, bool> _optimizationStatus = {};
  bool _isLoading = true;
  bool _allOptimizationsComplete = false;
  int _currentStep = 0;

  final List<OnePlusOptimizationStep> _steps = [
    OnePlusOptimizationStep(
      title: '🔋 Battery Optimization',
      description: 'Disable battery optimization to prevent the app from being killed',
      isRequired: true,
      key: 'battery_optimization',
    ),
    OnePlusOptimizationStep(
      title: '🚀 Auto-Start Permission',
      description: 'Allow the app to start automatically after device reboot',
      isRequired: true,
      key: 'auto_start',
    ),
    OnePlusOptimizationStep(
      title: '🔄 Background App Refresh',
      description: 'Enable background activity for continuous location updates',
      isRequired: true,
      key: 'background_refresh',
    ),
    OnePlusOptimizationStep(
      title: '🔒 App Lock Settings',
      description: 'Ensure the app is not locked by OnePlus security features',
      isRequired: true,
      key: 'app_lock',
    ),
    OnePlusOptimizationStep(
      title: '🎮 Gaming Mode',
      description: 'Configure gaming mode to allow background location',
      isRequired: false,
      key: 'gaming_mode',
    ),
    OnePlusOptimizationStep(
      title: '🧘 Zen Mode',
      description: 'Configure zen mode to allow location sharing',
      isRequired: false,
      key: 'zen_mode',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeOnePlusCheck();
  }

  Future<void> _initializeOnePlusCheck() async {
    try {
      final isOnePlus = await OnePlusOptimizationService.isOnePlusDevice();
      final model = await OnePlusOptimizationService.getOnePlusModel();
      
      setState(() {
        _isOnePlusDevice = isOnePlus;
        _deviceModel = model;
      });

      if (isOnePlus) {
        await _checkOptimizationStatus();
      }
    } catch (e) {
      debugPrint('Error initializing OnePlus check: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkOptimizationStatus() async {
    try {
      final status = await OnePlusOptimizationService.checkOnePlusOptimizations();
      setState(() {
        _optimizationStatus = status;
        _allOptimizationsComplete = _checkAllRequiredOptimizations();
      });
    } catch (e) {
      debugPrint('Error checking optimization status: $e');
    }
  }

  bool _checkAllRequiredOptimizations() {
    for (final step in _steps) {
      if (step.isRequired && (_optimizationStatus[step.key] != true)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _performOptimizationStep(OnePlusOptimizationStep step) async {
    setState(() {
      _currentStep = _steps.indexOf(step);
    });

    try {
      switch (step.key) {
        case 'battery_optimization':
          await _handleBatteryOptimization();
          break;
        case 'auto_start':
          await _handleAutoStart();
          break;
        case 'background_refresh':
          await _handleBackgroundRefresh();
          break;
        case 'app_lock':
          await _handleAppLock();
          break;
        case 'gaming_mode':
          await _handleGamingMode();
          break;
        case 'zen_mode':
          await _handleZenMode();
          break;
      }
      
      // Recheck status after user action
      await Future.delayed(const Duration(seconds: 2));
      await _checkOptimizationStatus();
      
    } catch (e) {
      _showErrorDialog('Error performing optimization step: $e');
    }
  }

  Future<void> _handleBatteryOptimization() async {
    await _showStepDialog(
      '🔋 Battery Optimization',
      'Your OnePlus $_deviceModel has aggressive battery optimization that will stop location sharing.\n\n'
      'Please follow these steps:\n\n'
      '1. Find "GroupSharing" in the list\n'
      '2. Select "Don\'t optimize"\n'
      '3. Tap "Done"\n\n'
      'This is CRITICAL for background location to work!',
    );

    try {
      const platform = MethodChannel('android_permissions');
      await platform.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
    }
  }

  Future<void> _handleAutoStart() async {
    await _showStepDialog(
      '🚀 Auto-Start Permission',
      'Your OnePlus $_deviceModel requires auto-start permission.\n\n'
      'Please follow these steps:\n\n'
      '1. Find "GroupSharing" in the list\n'
      '2. Enable the toggle\n'
      '3. Go back to this app\n\n'
      'This allows the app to restart after device reboot.',
    );

    try {
      const platform = MethodChannel('oneplus_optimization');
      await platform.invokeMethod('openOnePlusAutoStart');
    } catch (e) {
      debugPrint('Error opening auto-start settings: $e');
    }
  }

  Future<void> _handleBackgroundRefresh() async {
    await _showStepDialog(
      '🔄 Background App Refresh',
      'Your OnePlus $_deviceModel needs background app refresh enabled.\n\n'
      'Please follow these steps:\n\n'
      '1. Go to "Battery" > "Battery optimization"\n'
      '2. Find "GroupSharing" > "Don\'t optimize"\n'
      '3. Go to "App management" > "Background app refresh"\n'
      '4. Enable for "GroupSharing"\n\n'
      'This ensures location updates continue in background.',
    );

    try {
      const platform = MethodChannel('oneplus_optimization');
      await platform.invokeMethod('openOnePlusBackgroundSettings');
    } catch (e) {
      debugPrint('Error opening background settings: $e');
    }
  }

  Future<void> _handleAppLock() async {
    await _showStepDialog(
      '🔒 App Lock Settings',
      'Your OnePlus $_deviceModel has app lock features that can interfere.\n\n'
      'Please check these settings:\n\n'
      '1. Go to "Security" > "App lock"\n'
      '2. Make sure "GroupSharing" is NOT locked\n'
      '3. If it\'s locked, disable it\n\n'
      'App lock can prevent background services from running.',
    );

    try {
      const platform = MethodChannel('oneplus_optimization');
      await platform.invokeMethod('openOnePlusAppLockSettings');
    } catch (e) {
      debugPrint('Error opening app lock settings: $e');
    }
  }

  Future<void> _handleGamingMode() async {
    await _showStepDialog(
      '🎮 Gaming Mode',
      'If you use Gaming Mode on your OnePlus $_deviceModel:\n\n'
      'Please follow these steps:\n\n'
      '1. Go to "Gaming Mode" settings\n'
      '2. Add "GroupSharing" to exceptions\n'
      '3. Allow background activity\n\n'
      'This prevents Gaming Mode from stopping location sharing.',
    );

    try {
      const platform = MethodChannel('oneplus_optimization');
      await platform.invokeMethod('openOnePlusGamingMode');
    } catch (e) {
      debugPrint('Gaming mode settings not available');
    }
  }

  Future<void> _handleZenMode() async {
    await _showStepDialog(
      '🧘 Zen Mode',
      'If you use Zen Mode on your OnePlus $_deviceModel:\n\n'
      'Please follow these steps:\n\n'
      '1. Go to "Zen Mode" settings\n'
      '2. Add "GroupSharing" to allowed apps\n'
      '3. Enable location access during Zen Mode\n\n'
      'This ensures location sharing works even in Zen Mode.',
    );
  }

  Future<void> _showStepDialog(String title, String content) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSetupGuide() {
    final guide = OnePlusOptimizationService.getOnePlusSetupGuide(_deviceModel);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('OnePlus $_deviceModel Setup Guide'),
        content: SingleChildScrollView(
          child: Text(
            guide,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: guide));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Setup guide copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Check'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isOnePlusDevice) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Compatibility'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
                SizedBox(height: 16),
                Text(
                  'Your device doesn\'t require OnePlus-specific optimizations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'You can proceed with the standard permission setup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('OnePlus $_deviceModel Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showSetupGuide,
            tooltip: 'Setup Guide',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkOptimizationStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _allOptimizationsComplete ? Colors.green.shade50 : Colors.orange.shade50,
            child: Column(
              children: [
                Icon(
                  _allOptimizationsComplete ? Icons.check_circle : Icons.warning,
                  size: 48,
                  color: _allOptimizationsComplete ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 8),
                Text(
                  _allOptimizationsComplete 
                    ? '✅ OnePlus Setup Complete!'
                    : '⚠️ OnePlus Setup Required',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _allOptimizationsComplete
                    ? 'Your OnePlus device is optimized for background location sharing.'
                    : 'Your OnePlus device needs optimization for reliable background location.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          
          // Steps list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                final isCompleted = _optimizationStatus[step.key] == true;
                final isCurrent = index == _currentStep;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: isCurrent ? 4 : 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCompleted 
                        ? Colors.green 
                        : step.isRequired 
                          ? Colors.orange 
                          : Colors.grey.shade300,
                      child: Icon(
                        isCompleted ? Icons.check : Icons.settings,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      step.title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.description),
                        if (step.isRequired)
                          const Text(
                            'Required',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _performOptimizationStep(step),
                          child: const Text('Setup'),
                        ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_allOptimizationsComplete)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete Setup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final success = await OnePlusOptimizationService.requestAllOnePlusOptimizations(context);
                          if (success) {
                            await _checkOptimizationStatus();
                          }
                        },
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Auto Setup All'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Skip for Now'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnePlusOptimizationStep {
  final String title;
  final String description;
  final bool isRequired;
  final String key;

  OnePlusOptimizationStep({
    required this.title,
    required this.description,
    required this.isRequired,
    required this.key,
  });
}