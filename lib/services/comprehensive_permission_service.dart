import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';

/// Comprehensive Permission Service that ensures ALL necessary permissions are granted
/// Keeps asking until user grants all permissions required for background location
class ComprehensivePermissionService {
  static const String _tag = 'ComprehensivePermissionService';
  
  // Platform channels for native permission requests
  static const MethodChannel _androidChannel = MethodChannel('android_permissions');
  
  // Permission state tracking
  static bool _allPermissionsGranted = false;
  static Map<String, bool> _permissionStatus = {};
  static int _permissionRequestAttempts = 0;
  static const int _maxAttempts = 10; // Keep trying up to 10 times
  
  /// Check if all necessary permissions are granted
  static bool get allPermissionsGranted => _allPermissionsGranted;
  
  /// Get current permission status
  static Map<String, bool> get permissionStatus => Map.from(_permissionStatus);
  
  /// Request all necessary permissions with persistent prompting
  static Future<bool> requestAllPermissions(BuildContext context) async {
    developer.log('[$_tag] Starting comprehensive permission request');
    
    _permissionRequestAttempts++;
    
    if (_permissionRequestAttempts > _maxAttempts) {
      developer.log('[$_tag] Maximum permission attempts reached');
      await _showMaxAttemptsDialog(context);
      return false;
    }
    
    try {
      // Step 1: Basic location permissions
      final basicLocationGranted = await _requestBasicLocationPermissions(context);
      if (!basicLocationGranted) {
        await _showPermissionExplanationDialog(context, 'Basic Location');
        return false;
      }
      
      // Step 2: Background location permission
      final backgroundLocationGranted = await _requestBackgroundLocationPermission(context);
      if (!backgroundLocationGranted) {
        await _showPermissionExplanationDialog(context, 'Background Location');
        return false;
      }
      
      // Step 3: Battery optimization (Android)
      if (Platform.isAndroid) {
        final batteryOptimizationDisabled = await _requestBatteryOptimizationDisable(context);
        if (!batteryOptimizationDisabled) {
          await _showBatteryOptimizationDialog(context);
          return false;
        }
      }
      
      // Step 4: Auto-start permissions (Android manufacturers)
      if (Platform.isAndroid) {
        final autoStartGranted = await _requestAutoStartPermission(context);
        if (!autoStartGranted) {
          await _showAutoStartDialog(context);
          return false;
        }
      }
      
      // Step 5: Notification permissions
      final notificationGranted = await _requestNotificationPermissions(context);
      if (!notificationGranted) {
        await _showPermissionExplanationDialog(context, 'Notifications');
        return false;
      }
      
      // Step 6: iOS specific permissions
      if (Platform.isIOS) {
        final iosSpecificGranted = await _requestIOSSpecificPermissions(context);
        if (!iosSpecificGranted) {
          await _showPermissionExplanationDialog(context, 'iOS Background App Refresh');
          return false;
        }
      }
      
      // Final verification
      final allGranted = await _verifyAllPermissions();
      _allPermissionsGranted = allGranted;
      
      if (allGranted) {
        developer.log('[$_tag] All permissions granted successfully!');
        await _showSuccessDialog(context);
        return true;
      } else {
        developer.log('[$_tag] Some permissions still missing, will retry');
        await _showRetryDialog(context);
        return false;
      }
      
    } catch (e) {
      developer.log('[$_tag] Error requesting permissions: $e');
      await _showErrorDialog(context, e.toString());
      return false;
    }
  }
  
  /// Request basic location permissions
  static Future<bool> _requestBasicLocationPermissions(BuildContext context) async {
    developer.log('[$_tag] Requesting basic location permissions');
    
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showLocationServiceDialog(context);
        return false;
      }
      
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        await _showLocationPermissionExplanation(context);
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied) {
        _permissionStatus['location_basic'] = false;
        return false;
      }
      
      if (permission == LocationPermission.deniedForever) {
        await _showLocationPermissionDeniedForeverDialog(context);
        return false;
      }
      
      _permissionStatus['location_basic'] = true;
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error requesting basic location permissions: $e');
      _permissionStatus['location_basic'] = false;
      return false;
    }
  }
  
  /// Request background location permission
  static Future<bool> _requestBackgroundLocationPermission(BuildContext context) async {
    developer.log('[$_tag] Requesting background location permission');
    
    try {
      if (Platform.isAndroid) {
        // Android background location permission
        final permission = await Permission.locationAlways.request();
        final granted = permission == PermissionStatus.granted;
        
        if (!granted) {
          await _showAndroidBackgroundLocationDialog(context);
        }
        
        _permissionStatus['location_background'] = granted;
        return granted;
        
      } else if (Platform.isIOS) {
        // iOS always location permission
        LocationPermission permission = await Geolocator.checkPermission();
        
        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
          await _showIOSAlwaysLocationDialog(context);
          permission = await Geolocator.requestPermission();
        }
        
        // For iOS, we need "Always" permission for background location
        if (permission == LocationPermission.whileInUse) {
          await _showIOSUpgradeToAlwaysDialog(context);
          // On iOS, user must manually change to "Always" in Settings
          await AppSettings.openAppSettings();
          return false;
        }
        
        final granted = permission == LocationPermission.always;
        _permissionStatus['location_background'] = granted;
        return granted;
      }
      
      return false;
      
    } catch (e) {
      developer.log('[$_tag] Error requesting background location permission: $e');
      _permissionStatus['location_background'] = false;
      return false;
    }
  }
  
  /// Request battery optimization disable (Android)
  static Future<bool> _requestBatteryOptimizationDisable(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    developer.log('[$_tag] Requesting battery optimization disable');
    
    try {
      // Check if already disabled
      final result = await _androidChannel.invokeMethod('isBatteryOptimizationDisabled');
      if (result == true) {
        _permissionStatus['battery_optimization'] = true;
        return true;
      }
      
      // Show explanation and request
      await _showBatteryOptimizationExplanation(context);
      
      // Request disable battery optimization
      await _androidChannel.invokeMethod('requestDisableBatteryOptimization');
      
      // Wait a moment for user action
      await Future.delayed(const Duration(seconds: 2));
      
      // Check again
      final finalResult = await _androidChannel.invokeMethod('isBatteryOptimizationDisabled');
      final granted = finalResult == true;
      
      _permissionStatus['battery_optimization'] = granted;
      return granted;
      
    } catch (e) {
      developer.log('[$_tag] Error requesting battery optimization disable: $e');
      _permissionStatus['battery_optimization'] = false;
      return false;
    }
  }
  
  /// Request auto-start permission (Android manufacturers)
  static Future<bool> _requestAutoStartPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    developer.log('[$_tag] Requesting auto-start permission');
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      
      // Check if this manufacturer requires auto-start permission
      final requiresAutoStart = ['xiaomi', 'huawei', 'oppo', 'vivo', 'oneplus', 'realme']
          .contains(manufacturer);
      
      if (!requiresAutoStart) {
        _permissionStatus['auto_start'] = true;
        return true;
      }
      
      await _showAutoStartExplanation(context, manufacturer);
      
      // Try to open auto-start settings
      try {
        await _androidChannel.invokeMethod('openAutoStartSettings');
      } catch (e) {
        developer.log('[$_tag] Could not open auto-start settings: $e');
        // Fallback to app settings
        await AppSettings.openAppSettings();
      }
      
      // For now, assume user granted it (we can't reliably check)
      _permissionStatus['auto_start'] = true;
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error requesting auto-start permission: $e');
      _permissionStatus['auto_start'] = false;
      return false;
    }
  }
  
  /// Request notification permissions
  static Future<bool> _requestNotificationPermissions(BuildContext context) async {
    developer.log('[$_tag] Requesting notification permissions');
    
    try {
      final permission = await Permission.notification.request();
      final granted = permission == PermissionStatus.granted;
      
      if (!granted) {
        await _showNotificationPermissionDialog(context);
      }
      
      _permissionStatus['notifications'] = granted;
      return granted;
      
    } catch (e) {
      developer.log('[$_tag] Error requesting notification permissions: $e');
      _permissionStatus['notifications'] = false;
      return false;
    }
  }
  
  /// Request iOS specific permissions
  static Future<bool> _requestIOSSpecificPermissions(BuildContext context) async {
    if (!Platform.isIOS) return true;
    
    developer.log('[$_tag] Requesting iOS specific permissions');
    
    try {
      // Check background app refresh
      await _showIOSBackgroundAppRefreshDialog(context);
      
      // We can't programmatically check background app refresh status
      // So we assume user enabled it after showing instructions
      _permissionStatus['ios_background_refresh'] = true;
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error requesting iOS specific permissions: $e');
      _permissionStatus['ios_background_refresh'] = false;
      return false;
    }
  }
  
  /// Verify all permissions are granted
  static Future<bool> _verifyAllPermissions() async {
    developer.log('[$_tag] Verifying all permissions');
    
    try {
      // Re-check all permissions
      final basicLocation = await _checkBasicLocationPermission();
      final backgroundLocation = await _checkBackgroundLocationPermission();
      final notifications = await _checkNotificationPermission();
      
      bool batteryOptimization = true;
      bool autoStart = true;
      bool iosBackgroundRefresh = true;
      
      if (Platform.isAndroid) {
        batteryOptimization = await _checkBatteryOptimizationDisabled();
        autoStart = true; // Assume granted for now
      }
      
      if (Platform.isIOS) {
        iosBackgroundRefresh = true; // Assume granted for now
      }
      
      final allGranted = basicLocation && 
                        backgroundLocation && 
                        notifications && 
                        batteryOptimization && 
                        autoStart && 
                        iosBackgroundRefresh;
      
      developer.log('[$_tag] Permission verification result: $allGranted');
      developer.log('[$_tag] Basic location: $basicLocation');
      developer.log('[$_tag] Background location: $backgroundLocation');
      developer.log('[$_tag] Notifications: $notifications');
      developer.log('[$_tag] Battery optimization: $batteryOptimization');
      developer.log('[$_tag] Auto-start: $autoStart');
      developer.log('[$_tag] iOS background refresh: $iosBackgroundRefresh');
      
      return allGranted;
      
    } catch (e) {
      developer.log('[$_tag] Error verifying permissions: $e');
      return false;
    }
  }
  
  // Permission check methods
  static Future<bool> _checkBasicLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> _checkBackgroundLocationPermission() async {
    try {
      if (Platform.isAndroid) {
        final permission = await Permission.locationAlways.status;
        return permission == PermissionStatus.granted;
      } else if (Platform.isIOS) {
        final permission = await Geolocator.checkPermission();
        return permission == LocationPermission.always;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> _checkNotificationPermission() async {
    try {
      final permission = await Permission.notification.status;
      return permission == PermissionStatus.granted;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> _checkBatteryOptimizationDisabled() async {
    try {
      final result = await _androidChannel.invokeMethod('isBatteryOptimizationDisabled');
      return result == true;
    } catch (e) {
      return false;
    }
  }
  
  // Dialog methods for user education and guidance
  
  static Future<void> _showLocationServiceDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📍 Location Services Required'),
        content: const Text(
          'Location services are disabled on your device. Please enable them to use location sharing.\n\n'
          'This is required for the app to work like Google Maps and Life360.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showLocationPermissionExplanation(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📍 Location Permission Needed'),
        content: const Text(
          'GroupSharing needs location access to share your location with family members.\n\n'
          'This works exactly like Find My Friends, Life360, or Google Maps.\n\n'
          'Your location is only shared with people you choose.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showLocationPermissionDeniedForeverDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('❌ Location Permission Required'),
        content: const Text(
          'Location permission was permanently denied. Please enable it manually in Settings.\n\n'
          'Go to: Settings > Apps > GroupSharing > Permissions > Location > Allow'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showAndroidBackgroundLocationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔄 Background Location Required'),
        content: const Text(
          'For location sharing to work when the app is closed (like Life360), we need background location permission.\n\n'
          'Please select "Allow all the time" in the next dialog.'
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
  
  static Future<void> _showIOSAlwaysLocationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📍 Always Location Required'),
        content: const Text(
          'For background location sharing (like Find My Friends), please select "Always" when prompted.\n\n'
          'This allows location sharing even when the app is closed.'
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
  
  static Future<void> _showIOSUpgradeToAlwaysDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⬆️ Upgrade to Always Location'),
        content: const Text(
          'You currently have "While Using App" permission. For background location sharing, please:\n\n'
          '1. Go to Settings > Privacy & Security > Location Services\n'
          '2. Find GroupSharing\n'
          '3. Select "Always"\n\n'
          'This enables location sharing when the app is closed.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showBatteryOptimizationExplanation(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔋 Battery Optimization'),
        content: const Text(
          'To ensure location sharing works reliably (like Life360), please disable battery optimization for this app.\n\n'
          'This prevents Android from stopping location updates to save battery.'
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
  
  static Future<void> _showBatteryOptimizationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔋 Battery Optimization Required'),
        content: const Text(
          'Please disable battery optimization for reliable background location:\n\n'
          '1. Find GroupSharing in the list\n'
          '2. Select "Don\'t optimize"\n'
          '3. Tap Done\n\n'
          'This ensures location sharing works when the app is closed.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I\'ll Do It'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showAutoStartExplanation(BuildContext context, String manufacturer) async {
    String instructions = '';
    
    switch (manufacturer) {
      case 'xiaomi':
        instructions = '1. Go to Security > Autostart\n2. Find GroupSharing\n3. Enable autostart';
        break;
      case 'huawei':
        instructions = '1. Go to Phone Manager > App Launch\n2. Find GroupSharing\n3. Enable "Manage manually"';
        break;
      case 'oppo':
      case 'realme':
        instructions = '1. Go to Settings > Battery > App Energy Saver\n2. Find GroupSharing\n3. Disable energy saver';
        break;
      case 'vivo':
        instructions = '1. Go to Settings > Battery > Background App Refresh\n2. Find GroupSharing\n3. Enable background refresh';
        break;
      default:
        instructions = '1. Find app management settings\n2. Find GroupSharing\n3. Enable autostart/background running';
    }
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('🚀 Auto-Start Permission ($manufacturer)'),
        content: Text(
          'For reliable background location on $manufacturer devices, please enable auto-start:\n\n'
          '$instructions\n\n'
          'This ensures the app can restart after device reboot.'
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
  
  static Future<void> _showAutoStartDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚀 Auto-Start Settings'),
        content: const Text(
          'Please enable auto-start for GroupSharing in the settings that just opened.\n\n'
          'This ensures location sharing continues working after device restart.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showNotificationPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔔 Notification Permission'),
        content: const Text(
          'Notifications are needed to:\n\n'
          '• Show when location sharing is active\n'
          '• Alert you when friends are nearby\n'
          '• Provide emergency notifications\n\n'
          'Please enable notifications for the best experience.'
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
  
  static Future<void> _showIOSBackgroundAppRefreshDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔄 Background App Refresh'),
        content: const Text(
          'For reliable background location sharing, please ensure Background App Refresh is enabled:\n\n'
          '1. Go to Settings > General > Background App Refresh\n'
          '2. Make sure it\'s enabled globally\n'
          '3. Find GroupSharing and enable it\n\n'
          'This allows location updates when the app is closed.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showPermissionExplanationDialog(BuildContext context, String permissionType) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('❌ $permissionType Permission Required'),
        content: Text(
          '$permissionType permission is required for location sharing to work properly.\n\n'
          'Without this permission, the app cannot function like Google Maps or Life360.\n\n'
          'Please grant this permission to continue.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showRetryDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔄 Almost There!'),
        content: const Text(
          'Some permissions are still missing. Let\'s try again to ensure location sharing works perfectly.\n\n'
          'This is necessary for the app to work like Life360 and Google Maps.'
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
  
  static Future<void> _showSuccessDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✅ All Permissions Granted!'),
        content: const Text(
          'Perfect! All necessary permissions have been granted.\n\n'
          'Your location sharing will now work reliably, even when the app is closed, just like Life360 and Google Maps!\n\n'
          '🎉 You\'re all set!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Start Using App'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showMaxAttemptsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Permissions Required'),
        content: const Text(
          'The app requires all permissions to function properly.\n\n'
          'You can manually grant permissions in Settings > Apps > GroupSharing > Permissions.\n\n'
          'Without these permissions, location sharing cannot work when the app is closed.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _showErrorDialog(BuildContext context, String error) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('❌ Permission Error'),
        content: Text(
          'An error occurred while requesting permissions:\n\n$error\n\n'
          'Please try again or grant permissions manually in Settings.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  /// Reset permission request attempts (call when user manually grants permissions)
  static void resetAttempts() {
    _permissionRequestAttempts = 0;
  }
  
  /// Get detailed permission status for debugging
  static Future<Map<String, dynamic>> getDetailedPermissionStatus() async {
    return {
      'allGranted': _allPermissionsGranted,
      'attempts': _permissionRequestAttempts,
      'permissions': _permissionStatus,
      'basicLocation': await _checkBasicLocationPermission(),
      'backgroundLocation': await _checkBackgroundLocationPermission(),
      'notifications': await _checkNotificationPermission(),
      'batteryOptimization': Platform.isAndroid ? await _checkBatteryOptimizationDisabled() : true,
    };
  }
}