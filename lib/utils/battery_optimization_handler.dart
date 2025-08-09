import 'package:flutter/services.dart';

/// Helper to communicate with native Android for battery optimization settings.
/// iOS always returns `true` because the concept does not apply.
class BatteryOptimizationHandler {
  static const MethodChannel _channel =
      MethodChannel('com.sundeep.groupsharing/battery_optimization');

  /// Returns `true` if battery optimization is already disabled for this app.
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool? disabled =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return disabled ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens system settings page to exclude the app from battery optimization.
  static Future<void> requestDisableBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestDisableBatteryOptimization');
    } on PlatformException {
      // ignore; user stays in app
    }
  }
}
