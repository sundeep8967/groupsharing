import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OnePlus Optimization Service
/// Handles OnePlus-specific battery optimization and background restrictions
/// that prevent location sharing from working properly
class OnePlusOptimizationService {
  static const String _tag = 'OnePlusOptimizationService';
  static const MethodChannel _channel = MethodChannel('oneplus_optimization');
  
  /// Check if device is OnePlus
  static Future<bool> isOnePlusDevice() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();
      
      return manufacturer.contains('oneplus') || 
             brand.contains('oneplus') ||
             manufacturer.contains('oppo'); // OnePlus is owned by Oppo
    } catch (e) {
      developer.log('[$_tag] Error checking device: $e');
      return false;
    }
  }
  
  /// Get OnePlus device model for specific optimizations
  static Future<String> getOnePlusModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.model;
    } catch (e) {
      return 'Unknown OnePlus';
    }
  }
  
  /// Check all OnePlus-specific optimizations
  static Future<Map<String, bool>> checkOnePlusOptimizations() async {
    final results = <String, bool>{};
    
    try {
      // Battery optimization
      results['battery_optimization'] = await _checkBatteryOptimization();
      
      // Auto-start permission
      results['auto_start'] = await _checkAutoStartPermission();
      
      // Background app refresh
      results['background_refresh'] = await _checkBackgroundAppRefresh();
      
      // App lock (OnePlus specific)
      results['app_lock'] = await _checkAppLockSettings();
      
      // Gaming mode restrictions
      results['gaming_mode'] = await _checkGamingModeRestrictions();
      
      // Zen mode restrictions
      results['zen_mode'] = await _checkZenModeRestrictions();
      
      developer.log('[$_tag] OnePlus optimization check results: $results');
      return results;
      
    } catch (e) {
      developer.log('[$_tag] Error checking OnePlus optimizations: $e');
      return results;
    }
  }
  
  /// Request all OnePlus optimizations with step-by-step guidance
  static Future<bool> requestAllOnePlusOptimizations(BuildContext context) async {
    try {
      final model = await getOnePlusModel();
      developer.log('[$_tag] Requesting OnePlus optimizations for model: $model');
      
      // Step 1: Battery optimization
      final batteryOpt = await _requestBatteryOptimization(context, model);
      if (!batteryOpt) return false;
      
      // Step 2: Auto-start permission
      final autoStart = await _requestAutoStartPermission(context, model);
      if (!autoStart) return false;
      
      // Step 3: Background app refresh
      final backgroundRefresh = await _requestBackgroundAppRefresh(context, model);
      if (!backgroundRefresh) return false;
      
      // Step 4: App lock settings
      final appLock = await _requestAppLockSettings(context, model);
      if (!appLock) return false;
      
      // Step 5: Gaming mode settings
      await _requestGamingModeSettings(context, model);
      
      // Step 6: Zen mode settings
      await _requestZenModeSettings(context, model);
      
      // Step 7: Additional OnePlus-specific settings
      await _requestAdditionalOnePlusSettings(context, model);
      
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error requesting OnePlus optimizations: $e');
      return false;
    }
  }
  
  /// Check battery optimization status
  static Future<bool> _checkBatteryOptimization() async {
    try {
      final result = await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return result == true;
    } catch (e) {
      developer.log('[$_tag] Error checking battery optimization: $e');
      return false;
    }
  }
  
  /// Check auto-start permission
  static Future<bool> _checkAutoStartPermission() async {
    try {
      // OnePlus doesn't provide API to check this, so we assume false
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('oneplus_autostart_granted') ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check background app refresh
  static Future<bool> _checkBackgroundAppRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('oneplus_background_refresh_granted') ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check app lock settings
  static Future<bool> _checkAppLockSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('oneplus_app_lock_configured') ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check gaming mode restrictions
  static Future<bool> _checkGamingModeRestrictions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('oneplus_gaming_mode_configured') ?? true; // Default to true
    } catch (e) {
      return true;
    }
  }
  
  /// Check zen mode restrictions
  static Future<bool> _checkZenModeRestrictions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('oneplus_zen_mode_configured') ?? true; // Default to true
    } catch (e) {
      return true;
    }
  }
  
  /// Request battery optimization disable
  static Future<bool> _requestBatteryOptimization(BuildContext context, String model) async {
    await _showOnePlusBatteryDialog(context, model);
    
    try {
      await _channel.invokeMethod('requestDisableBatteryOptimization');
      await Future.delayed(const Duration(seconds: 3));
      return await _checkBatteryOptimization();
    } catch (e) {
      developer.log('[$_tag] Error requesting battery optimization: $e');
      return false;
    }
  }
  
  /// Request auto-start permission
  static Future<bool> _requestAutoStartPermission(BuildContext context, String model) async {
    await _showOnePlusAutoStartDialog(context, model);
    
    try {
      // Try to open OnePlus auto-start settings
      await _openOnePlusAutoStartSettings();
      
      // Mark as granted (user confirmation)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('oneplus_autostart_granted', true);
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Error requesting auto-start: $e');
      return false;
    }
  }
  
  /// Request background app refresh
  static Future<bool> _requestBackgroundAppRefresh(BuildContext context, String model) async {
    await _showOnePlusBackgroundRefreshDialog(context, model);
    
    try {
      await _openOnePlusBackgroundSettings();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('oneplus_background_refresh_granted', true);
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Error requesting background refresh: $e');
      return false;
    }
  }
  
  /// Request app lock settings
  static Future<bool> _requestAppLockSettings(BuildContext context, String model) async {
    await _showOnePlusAppLockDialog(context, model);
    
    try {
      await _openOnePlusAppLockSettings();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('oneplus_app_lock_configured', true);
      
      return true;
    } catch (e) {
      developer.log('[$_tag] Error configuring app lock: $e');
      return false;
    }
  }
  
  /// Request gaming mode settings
  static Future<void> _requestGamingModeSettings(BuildContext context, String model) async {
    await _showOnePlusGamingModeDialog(context, model);
    
    try {
      await _openOnePlusGamingModeSettings();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('oneplus_gaming_mode_configured', true);
    } catch (e) {
      developer.log('[$_tag] Error configuring gaming mode: $e');
    }
  }
  
  /// Request zen mode settings
  static Future<void> _requestZenModeSettings(BuildContext context, String model) async {
    await _showOnePlusZenModeDialog(context, model);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('oneplus_zen_mode_configured', true);
    } catch (e) {
      developer.log('[$_tag] Error configuring zen mode: $e');
    }
  }
  
  /// Request additional OnePlus settings
  static Future<void> _requestAdditionalOnePlusSettings(BuildContext context, String model) async {
    await _showOnePlusAdditionalSettingsDialog(context, model);
  }
  
  /// Open OnePlus auto-start settings
  static Future<void> _openOnePlusAutoStartSettings() async {
    try {
      // Try OnePlus specific auto-start settings
      await _channel.invokeMethod('openOnePlusAutoStart');
    } catch (e) {
      try {
        // Fallback to generic auto-start
        await _channel.invokeMethod('openAutoStartSettings');
      } catch (e2) {
        // Final fallback to app settings
        await AppSettings.openAppSettings();
      }
    }
  }
  
  /// Open OnePlus background settings
  static Future<void> _openOnePlusBackgroundSettings() async {
    try {
      await _channel.invokeMethod('openOnePlusBackgroundSettings');
    } catch (e) {
      await AppSettings.openAppSettings();
    }
  }
  
  /// Open OnePlus app lock settings
  static Future<void> _openOnePlusAppLockSettings() async {
    try {
      await _channel.invokeMethod('openOnePlusAppLockSettings');
    } catch (e) {
      await AppSettings.openAppSettings();
    }
  }
  
  /// Open OnePlus gaming mode settings
  static Future<void> _openOnePlusGamingModeSettings() async {
    try {
      await _channel.invokeMethod('openOnePlusGamingMode');
    } catch (e) {
      developer.log('[$_tag] Could not open gaming mode settings: $e');
    }
  }
  
  // Dialog methods for user guidance
  
  static Future<void> _showOnePlusBatteryDialog(BuildContext context, String model) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔋 OnePlus Battery Optimization'),
        content: Text(
          'Your $model has aggressive battery optimization that stops location sharing.\n\n'
          'Please follow these steps:\n\n'
          '1. Find "GroupSharing" in the list\n'
          '2. Select "Don\'t optimize"\n'
          '3. Tap "Done"\n\n'
          'This is CRITICAL for background location to work!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showOnePlusAutoStartDialog(BuildContext context, String model) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚀 OnePlus Auto-Start Permission'),
        content: Text(
          'Your $model requires auto-start permission for background location.\n\n'
          'Please follow these steps:\n\n'
          '1. Go to "Auto-start management" or "Startup manager"\n'
          '2. Find "GroupSharing"\n'
          '3. Enable the toggle\n\n'
          'This allows the app to restart after device reboot.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showOnePlusBackgroundRefreshDialog(BuildContext context, String model) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔄 OnePlus Background App Refresh'),
        content: Text(
          'Your $model needs background app refresh enabled.\n\n'
          'Please follow these steps:\n\n'
          '1. Go to "Battery" > "Battery optimization"\n'
          '2. Find "GroupSharing"\n'
          '3. Select "Don\'t optimize"\n'
          '4. Go to "App management" > "Background app refresh"\n'
          '5. Enable for "GroupSharing"\n\n'
          'This ensures location updates continue in background.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showOnePlusAppLockDialog(BuildContext context, String model) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔒 OnePlus App Lock Settings'),
        content: Text(
          'Your $model has app lock features that can interfere with background location.\n\n'
          'Please check these settings:\n\n'
          '1. Go to "Security" > "App lock"\n'
          '2. Make sure "GroupSharing" is NOT locked\n'
          '3. If it\'s locked, disable it\n\n'
          'App lock can prevent background services from running.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Check Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showOnePlusGamingModeDialog(BuildContext context, String model) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎮 OnePlus Gaming Mode'),
        content: Text(
          'Your $model has Gaming Mode that can restrict background apps.\n\n'
          'If you use Gaming Mode, please:\n\n'
          '1. Go to "Gaming Mode" settings\n'
          '2. Add "GroupSharing" to exceptions\n'
          '3. Allow background activity\n\n'
          'This prevents Gaming Mode from stopping location sharing.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I\'ll Check This'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showOnePlusZenModeDialog(BuildContext context, String model) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🧘 OnePlus Zen Mode'),
        content: Text(
          'Your $model has Zen Mode that can restrict apps.\n\n'
          'If you use Zen Mode, please:\n\n'
          '1. Go to "Zen Mode" settings\n'
          '2. Add "GroupSharing" to allowed apps\n'
          '3. Enable location access during Zen Mode\n\n'
          'This ensures location sharing works even in Zen Mode.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showOnePlusAdditionalSettingsDialog(BuildContext context, String model) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚙️ Additional OnePlus Settings'),
        content: Text(
          'Your $model has additional settings that may affect background location:\n\n'
          '📱 Check these settings manually:\n\n'
          '• Settings > Battery > More battery settings > Sleep standby optimization (Disable)\n'
          '• Settings > Apps > App management > GroupSharing > Battery > Battery optimization (Don\'t optimize)\n'
          '• Settings > Privacy > Permission manager > Location > GroupSharing (Allow all the time)\n'
          '• Settings > Apps > Special app access > Device admin apps (Check if needed)\n\n'
          'These ensure maximum compatibility with your OnePlus device.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I\'ll Check These'),
          ),
        ],
      ),
    );
  }
  
  /// Get OnePlus-specific troubleshooting steps
  static List<String> getOnePlusTroubleshootingSteps(String model) {
    return [
      '1. Settings > Battery > Battery optimization > GroupSharing > Don\'t optimize',
      '2. Settings > Apps > App management > GroupSharing > Battery > Unrestricted',
      '3. Settings > Apps > Auto-start management > GroupSharing > Enable',
      '4. Settings > Privacy > Permission manager > Location > GroupSharing > Allow all the time',
      '5. Settings > Security > App lock > Make sure GroupSharing is NOT locked',
      '6. Settings > Battery > More battery settings > Sleep standby optimization > Disable',
      '7. Check Gaming Mode settings if you use it',
      '8. Check Zen Mode settings if you use it',
      '9. Restart your device after making changes',
      '10. Test location sharing for 5-10 minutes with app in background',
    ];
  }
  
  /// Create a comprehensive OnePlus setup guide
  static String getOnePlusSetupGuide(String model) {
    return '''
🔧 OnePlus $model Setup Guide for Background Location

Your OnePlus device has very aggressive power management that can stop location sharing. Follow ALL these steps:

🔋 CRITICAL BATTERY SETTINGS:
1. Settings > Battery > Battery optimization
2. Find "GroupSharing" > Select "Don't optimize"
3. Settings > Battery > More battery settings
4. Disable "Sleep standby optimization"

🚀 AUTO-START PERMISSION:
1. Settings > Apps > Auto-start management
2. Find "GroupSharing" > Enable toggle
3. Or: Settings > Apps > Startup manager > Enable GroupSharing

📍 LOCATION PERMISSIONS:
1. Settings > Privacy > Permission manager > Location
2. Find "GroupSharing" > Select "Allow all the time"
3. Make sure "Use precise location" is enabled

🔒 APP RESTRICTIONS:
1. Settings > Security > App lock
2. Make sure GroupSharing is NOT locked
3. Settings > Apps > App management > GroupSharing
4. Battery > Select "Unrestricted"
5. Mobile data > Enable "Background data"

🎮 GAMING MODE (if you use it):
1. Gaming Mode settings > Add GroupSharing to exceptions
2. Allow background activity for GroupSharing

🧘 ZEN MODE (if you use it):
1. Zen Mode settings > Add GroupSharing to allowed apps

✅ VERIFICATION STEPS:
1. Restart your device after making all changes
2. Open GroupSharing and start location sharing
3. Put app in background for 5-10 minutes
4. Check if location is still updating on other device

⚠️ If location still stops working:
- Check for any "Smart" or "AI" power management features
- Look for "App hibernation" or "App sleeping" settings
- Disable any "Adaptive battery" features for GroupSharing
- Contact support with your exact OnePlus model number

This setup is required because OnePlus devices are designed to maximize battery life by aggressively stopping background apps.
''';
  }
}