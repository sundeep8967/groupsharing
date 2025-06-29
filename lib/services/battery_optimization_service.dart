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
    } catch (e) {
      debugPrint('Error in battery optimization check: $e');
    }
  }
}