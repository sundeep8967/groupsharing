import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';

class BackgroundActivityService {
  static const MethodChannel _channel = MethodChannel('com.sundeep.groupsharing/battery_optimization');
  
  /// Get device manufacturer and model information
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'manufacturer': androidInfo.manufacturer.toLowerCase(),
          'model': androidInfo.model,
          'brand': androidInfo.brand.toLowerCase(),
        };
      }
      return {'manufacturer': 'ios', 'model': 'iPhone', 'brand': 'apple'};
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return {'manufacturer': 'unknown', 'model': 'Unknown', 'brand': 'unknown'};
    }
  }
  
  /// Check if background activity is enabled (device-specific)
  static Future<bool> isBackgroundActivityEnabled() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final status = await _channel.invokeMethod('getComprehensiveOptimizationStatus');
      final result = Map<String, dynamic>.from(status ?? {});
      
      // Check multiple indicators
      final batteryOptDisabled = result['batteryOptimizationDisabled'] ?? false;
      final autoStartEnabled = result['autoStartEnabled'] ?? false;
      final backgroundAppEnabled = result['backgroundAppEnabled'] ?? false;
      
      // For most devices, battery optimization disabled is the main indicator
      return batteryOptDisabled;
    } catch (e) {
      debugPrint('Error checking background activity status: $e');
      return false;
    }
  }
  
  /// Request background activity permission with device-specific approach
  static Future<void> requestBackgroundActivity() async {
    if (!Platform.isAndroid) return;
    
    final deviceInfo = await getDeviceInfo();
    final manufacturer = deviceInfo['manufacturer'] ?? 'unknown';
    
    try {
      switch (manufacturer) {
        case 'xiaomi':
        case 'redmi':
          await _channel.invokeMethod('requestBackgroundAppPermission');
          break;
        case 'oneplus':
        case 'oppo':
        case 'realme':
        case 'vivo':
          await _channel.invokeMethod('requestAutoStartPermission');
          break;
        case 'huawei':
        case 'honor':
          await _channel.invokeMethod('requestBackgroundAppPermission');
          break;
        case 'samsung':
          // Samsung uses battery optimization mainly
          await _channel.invokeMethod('requestDisableBatteryOptimization');
          break;
        default:
          // Generic approach - try battery optimization first
          await _channel.invokeMethod('requestDisableBatteryOptimization');
          break;
      }
    } catch (e) {
      debugPrint('Error requesting background activity: $e');
    }
  }
  
  /// Get device-specific instructions for enabling background activity
  static Future<String> getBackgroundActivityInstructions() async {
    final deviceInfo = await getDeviceInfo();
    final manufacturer = deviceInfo['manufacturer'] ?? 'unknown';
    final model = deviceInfo['model'] ?? 'Unknown';
    
    switch (manufacturer) {
      case 'xiaomi':
      case 'redmi':
        return '''
Xiaomi/Redmi $model Setup:

1. 🔋 Battery Optimization:
   Settings → Apps → Manage apps → GroupSharing → Battery saver → No restrictions

2. 🚀 Autostart:
   Settings → Apps → Permissions → Autostart → GroupSharing → Enable

3. 🔄 Background Activity:
   Settings → Apps → Manage apps → GroupSharing → Other permissions → Display pop-up windows while running in background → Enable

4. 📱 MIUI Optimization:
   Settings → Additional settings → Developer options → Turn off MIUI optimization

Critical: All 4 steps are required for Xiaomi devices!
        ''';
        
      case 'oneplus':
        return '''
OnePlus $model Setup:

1. 🔋 Battery Optimization:
   Settings → Battery → Battery optimization → GroupSharing → Don't optimize

2. 🚀 Auto-start:
   Settings → Apps → Auto-start management → GroupSharing → Enable

3. 🔄 Background Activity:
   Settings → Apps → App management → GroupSharing → Battery → Unrestricted

4. 📍 Location Permission:
   Settings → Privacy → Permission manager → Location → GroupSharing → Allow all the time

5. 😴 Sleep Standby:
   Settings → Battery → More battery settings → Sleep standby optimization → Disable

OnePlus devices are very aggressive - all steps are essential!
        ''';
        
      case 'oppo':
      case 'realme':
        return '''
$manufacturer $model Setup:

1. 🔋 Battery Optimization:
   Settings → Battery → Power saving mode → High performance mode

2. 🚀 Startup Manager:
   Settings → Apps → Startup manager → GroupSharing → Enable

3. 🔄 Background App Refresh:
   Settings → Apps → App management → GroupSharing → Battery → Unrestricted

4. 📱 Auto-start:
   Phone Manager → Privacy permissions → Startup manager → GroupSharing → Enable
        ''';
        
      case 'vivo':
        return '''
Vivo $model Setup:

1. 🔋 Background App Refresh:
   Settings → Battery → Background app refresh → GroupSharing → Allow

2. 🚀 Auto-start:
   Settings → More settings → Applications → Autostart → GroupSharing → Enable

3. 🔄 High Background Activity:
   Settings → Battery → High background power consumption → GroupSharing → Enable

4. 📱 iManager:
   iManager → App manager → Autostart management → GroupSharing → Enable
        ''';
        
      case 'huawei':
      case 'honor':
        return '''
$manufacturer $model Setup:

1. 🔋 Battery Optimization:
   Settings → Battery → App launch → GroupSharing → Manage manually → Enable all

2. 🚀 Startup Manager:
   Settings → Apps → Apps → GroupSharing → Battery → App launch → Manage manually

3. 🔄 Background Activity:
   Phone Manager → App launch → GroupSharing → Manage manually → Enable all toggles

4. 📱 Protected Apps:
   Phone Manager → Protected apps → GroupSharing → Enable
        ''';
        
      case 'samsung':
        return '''
Samsung $model Setup:

1. 🔋 Battery Optimization:
   Settings → Device care → Battery → More battery settings → Optimize battery usage → Apps not optimized → GroupSharing

2. 🔄 Background Activity:
   Settings → Apps → GroupSharing → Battery → Allow background activity

3. 📱 Auto-start:
   Settings → Apps → GroupSharing → Battery → Optimize battery usage → Disable

4. 😴 Put App to Sleep:
   Settings → Device care → Battery → Background app limits → Never sleeping apps → Add GroupSharing
        ''';
        
      default:
        return '''
$manufacturer $model Setup:

1. 🔋 Battery Optimization:
   Settings → Battery → Battery optimization → GroupSharing → Don't optimize

2. 🔄 Background Activity:
   Settings → Apps → GroupSharing → Battery → Allow background activity

3. 🚀 Auto-start (if available):
   Look for "Auto-start", "Startup manager", or "App launch" in Settings

4. 📱 App Settings:
   Settings → Apps → GroupSharing → Permissions → Allow all location permissions

Note: Steps may vary by device manufacturer and Android version.
        ''';
    }
  }
  
  /// Show comprehensive background activity setup dialog
  static Future<void> showBackgroundActivityDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    final isEnabled = await isBackgroundActivityEnabled();
    if (isEnabled) return; // Already enabled
    
    if (!context.mounted) return;
    
    final instructions = await getBackgroundActivityInstructions();
    final deviceInfo = await getDeviceInfo();
    final manufacturer = deviceInfo['manufacturer'] ?? 'unknown';
    final model = deviceInfo['model'] ?? 'Unknown';
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.settings_applications, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Background Activity Required',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your $manufacturer $model requires special setup for background location sharing.',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  instructions,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
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
              label: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                requestBackgroundActivity();
              },
            ),
          ],
        );
      },
    );
  }
  
  /// Check and prompt for background activity if needed
  static Future<void> checkAndPromptBackgroundActivity(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    try {
      final isEnabled = await isBackgroundActivityEnabled();
      if (!isEnabled && context.mounted) {
        await showBackgroundActivityDialog(context);
      }
    } catch (e) {
      debugPrint('Error in background activity check: $e');
    }
  }
}