import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('com.sundeep.groupsharing/battery_optimization');

  /// Check if battery optimization is disabled for the app
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true; // iOS doesn't have this concept
    
    try {
      final bool isDisabled = await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return isDisabled;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request user to disable battery optimization
  static Future<void> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      debugPrint('Error requesting battery optimization disable: $e');
    }
  }

  /// Show dialog to educate user about battery optimization
  static Future<void> showBatteryOptimizationDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    final bool isOptimized = !(await isBatteryOptimizationDisabled());
    if (!isOptimized) return; // Already disabled, no need to show dialog

    if (!context.mounted) return; // Check if context is still valid

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Battery Optimization'),
          content: const Text(
            'For continuous location sharing, please disable battery optimization for this app. '
            'This ensures your location is shared even when the app is in the background.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Disable'),
              onPressed: () {
                Navigator.of(context).pop();
                requestDisableBatteryOptimization();
              },
            ),
          ],
        );
      },
    );
  }

  /// Check and prompt for battery optimization if needed
  static Future<void> checkAndPromptBatteryOptimization(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    try {
      final bool isDisabled = await isBatteryOptimizationDisabled();
      if (!isDisabled && context.mounted) {
        await showBatteryOptimizationDialog(context);
      }
      
      // Also check device-specific optimizations
      await checkDeviceSpecificOptimizations(context);
    } catch (e) {
      debugPrint('Error in battery optimization check: $e');
    }
  }
  
  /// Check device-specific battery optimizations
  static Future<void> checkDeviceSpecificOptimizations(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('checkDeviceSpecificOptimizations');
    } catch (e) {
      debugPrint('Error checking device-specific optimizations: $e');
    }
  }
  
  /// Request auto-start permission (OnePlus, Oppo, Vivo, Realme)
  static Future<void> requestAutoStartPermission() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('requestAutoStartPermission');
    } catch (e) {
      debugPrint('Error requesting auto-start permission: $e');
    }
  }
  
  /// Request background app permission (Xiaomi, Huawei)
  static Future<void> requestBackgroundAppPermission() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('requestBackgroundAppPermission');
    } catch (e) {
      debugPrint('Error requesting background app permission: $e');
    }
  }
  
  /// Get comprehensive battery optimization status
  static Future<Map<String, dynamic>> getComprehensiveOptimizationStatus() async {
    if (!Platform.isAndroid) {
      return {
        'batteryOptimizationDisabled': true,
        'autoStartEnabled': true,
        'backgroundAppEnabled': true,
        'deviceManufacturer': 'iOS',
      };
    }
    
    try {
      final result = await _channel.invokeMethod('getComprehensiveOptimizationStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('Error getting comprehensive optimization status: $e');
      return {
        'batteryOptimizationDisabled': false,
        'autoStartEnabled': false,
        'backgroundAppEnabled': false,
        'error': e.toString(),
      };
    }
  }

  /// Open background activity settings directly
  static Future<void> openBackgroundActivitySettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      // Try to open background activity settings directly
      await _channel.invokeMethod('openBackgroundActivitySettings');
    } catch (e) {
      debugPrint('Error opening background activity settings: $e');
      // Fallback to background app permission
      await requestBackgroundAppPermission();
    }
  }

  /// Show comprehensive background activity dialog with direct navigation
  static Future<void> showBackgroundActivitySetupDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    final status = await getComprehensiveOptimizationStatus();
    final isOptimized = !(status['batteryOptimizationDisabled'] ?? false);
    
    if (!isOptimized) return; // Already optimized
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.settings_applications, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Background Activity Required'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your device needs special setup for background location sharing.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To ensure reliable location sharing when the app is closed:\n\n'
                '• Disable battery optimization\n'
                '• Enable background activity\n'
                '• Allow auto-start (if available)\n\n'
                'Tap "Setup Now" to be guided through each step.',
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Setup Now'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/background-activity-setup');
              },
            ),
          ],
        );
      },
    );
  }
}