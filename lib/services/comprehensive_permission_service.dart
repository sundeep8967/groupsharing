import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Comprehensive permission service for handling all app permissions
class ComprehensivePermissionService {
  static bool _allPermissionsGranted = false;
  
  /// Check if all permissions are granted
  static bool get allPermissionsGranted => _allPermissionsGranted;
  
  /// Get detailed permission status
  static Future<Map<String, dynamic>> getDetailedPermissionStatus() async {
    try {
      // Check location permissions
      final locationPermission = await Permission.location.status;
      final locationAlwaysPermission = await Permission.locationAlways.status;
      
      // Check notification permissions
      final notificationPermission = await Permission.notification.status;
      
      // Battery optimization (Android only)
      PermissionStatus? batteryIgnoreStatus;
      if (Platform.isAndroid) {
        batteryIgnoreStatus = await Permission.ignoreBatteryOptimizations.status;
      }

      // Check other permissions
      final phonePermission = await Permission.phone.status;
      final storagePermission = await Permission.storage.status;
      
      final allGranted = locationPermission.isGranted &&
          locationAlwaysPermission.isGranted &&
          notificationPermission.isGranted;
      
      _allPermissionsGranted = allGranted;
      
      // Provide both legacy flat keys and a nested `permissions` map used by UI
      return {
        'allGranted': allGranted,
        'location': locationPermission.isGranted,
        'locationAlways': locationAlwaysPermission.isGranted,
        'notification': notificationPermission.isGranted,
        'phone': phonePermission.isGranted,
        'storage': storagePermission.isGranted,
        'permissions': {
          'location_basic': locationPermission.isGranted,
          'location_background': locationAlwaysPermission.isGranted,
          'battery_optimization': Platform.isAndroid ? (batteryIgnoreStatus?.isGranted ?? false) : true,
          'auto_start': false, // cannot be detected reliably; user must acknowledge via protection screen
          'notifications': notificationPermission.isGranted,
          'ios_background_refresh': Platform.isIOS ? await _iosBackgroundRefreshEnabled() : true,
        },
      };
    } catch (e) {
      debugPrint('Error getting permission status: $e');
      return {
        'allGranted': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Request all necessary permissions
  static Future<bool> requestAllPermissions() async {
    try {
      debugPrint('Starting comprehensive permission request...');
      
      // Step 1: Basic location permission
      debugPrint('Requesting basic location permission...');
      final locationResult = await Permission.location.request();
      debugPrint('Location permission result: $locationResult');
      
      if (!locationResult.isGranted) {
        debugPrint('Basic location permission denied');
        return false;
      }
      
      // Step 2: Background location permission (critical for the app)
      debugPrint('Requesting background location permission...');
      final backgroundResult = await Permission.locationAlways.request();
      debugPrint('Background location result: $backgroundResult');
      if (!backgroundResult.isGranted && backgroundResult.isPermanentlyDenied) {
        debugPrint('Background location permanently denied, opening app settings');
        await openSystemAppSettings();
        return false;
      }
      
      // Step 3: Notification permissions
      debugPrint('Requesting notification permission...');
      final notificationResult = await Permission.notification.request();
      debugPrint('Notification permission result: $notificationResult');
      
      // Step 4: Battery optimization (Android specific)
      if (Platform.isAndroid) {
        debugPrint('Requesting battery optimization exemption...');
        final batteryResult = await Permission.ignoreBatteryOptimizations.request();
        debugPrint('Battery optimization result: $batteryResult');
      }
      
      // Step 5: Device-specific permissions
      await _requestDeviceSpecificPermissions();
      
      // Check final status
      final status = await getDetailedPermissionStatus();
      final allGranted = status['allGranted'] ?? false;
      
      debugPrint('Final permission status: $allGranted');
      return allGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Request device-specific permissions for better background performance
  static Future<void> _requestDeviceSpecificPermissions() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        
        debugPrint('Device manufacturer: $manufacturer');
        
        // OnePlus, Oppo, Vivo, Realme devices need auto-start permission
        if (manufacturer.contains('oneplus') || 
            manufacturer.contains('oppo') || 
            manufacturer.contains('vivo') || 
            manufacturer.contains('realme')) {
          debugPrint('Detected $manufacturer device - requesting auto-start permission');
          // Note: Auto-start permission usually requires opening device settings
          // The permission_handler plugin doesn't directly support this
        }
        
        // Xiaomi devices need additional permissions
        if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
          debugPrint('Detected Xiaomi device - requesting additional permissions');
          // Xiaomi has MIUI-specific permissions that need special handling
        }
        
        // Huawei devices
        if (manufacturer.contains('huawei') || manufacturer.contains('honor')) {
          debugPrint('Detected Huawei device - requesting additional permissions');
          // Huawei has EMUI-specific permissions
        }
      }
    } catch (e) {
      debugPrint('Error requesting device-specific permissions: $e');
    }
  }
  
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }
  
  /// Open app settings (system)
  static Future<void> openSystemAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  // iOS background app refresh state (best-effort)
  static Future<bool> _iosBackgroundRefreshEnabled() async {
    if (!Platform.isIOS) return true;
    try {
      // permission_handler does not expose this directly; assume enabled and let UX educate
      return true;
    } catch (_) {
      return true;
    }
  }
}