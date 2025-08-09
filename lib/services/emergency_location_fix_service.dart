import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';

/// Emergency Location Fix Service
/// 
/// This service provides immediate fixes for background location issues
/// across different Android manufacturers and devices.
class EmergencyLocationFixService {
  static const String _tag = 'EmergencyLocationFixService';
  static const MethodChannel _channel = MethodChannel('emergency_location_fix');
  
  /// Apply emergency fixes for background location
  static Future<EmergencyFixResult> applyEmergencyFixes() async {
    developer.log('[$_tag] Starting emergency location fixes...');
    
    final result = EmergencyFixResult();
    
    try {
      // Get device info
      final deviceInfo = await _getDeviceInfo();
      result.deviceInfo = deviceInfo;
      
      // Apply universal fixes
      await _applyUniversalFixes(result);
      
      // Apply device-specific fixes
      await _applyDeviceSpecificFixes(deviceInfo, result);
      
      // Test location services
      await _testLocationServices(result);
      
      result.success = true;
      result.message = 'Emergency fixes applied successfully!';
      
    } catch (e) {
      result.success = false;
      result.message = 'Error applying fixes: $e';
      developer.log('[$_tag] Error: $e');
    }
    
    return result;
  }
  
  /// Get device information
  static Future<DeviceInfo> _getDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;
      
      return DeviceInfo(
        manufacturer: androidInfo.manufacturer.toLowerCase(),
        model: androidInfo.model,
        androidVersion: androidInfo.version.release,
        sdkInt: androidInfo.version.sdkInt,
      );
    } catch (e) {
      return DeviceInfo(
        manufacturer: 'unknown',
        model: 'unknown',
        androidVersion: 'unknown',
        sdkInt: 0,
      );
    }
  }
  
  /// Apply universal Android fixes
  static Future<void> _applyUniversalFixes(EmergencyFixResult result) async {
    developer.log('[$_tag] Applying universal fixes...');
    
    // 1. Request location permissions
    try {
      final locationStatus = await Permission.location.request();
      result.fixes['Location Permission'] = locationStatus.isGranted;
      
      if (locationStatus.isGranted) {
        // Request background location permission
        final backgroundStatus = await Permission.locationAlways.request();
        result.fixes['Background Location Permission'] = backgroundStatus.isGranted;
      }
    } catch (e) {
      result.fixes['Location Permission'] = false;
      developer.log('[$_tag] Location permission error: $e');
    }
    
    // 2. Request battery optimization exemption
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
      result.fixes['Battery Optimization Disabled'] = batteryStatus.isGranted;
    } catch (e) {
      result.fixes['Battery Optimization Disabled'] = false;
      developer.log('[$_tag] Battery optimization error: $e');
    }
    
    // 3. Request notification permission
    try {
      final notificationStatus = await Permission.notification.request();
      result.fixes['Notification Permission'] = notificationStatus.isGranted;
    } catch (e) {
      result.fixes['Notification Permission'] = false;
      developer.log('[$_tag] Notification permission error: $e');
    }
    
    // 4. Check location services
    try {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      result.fixes['Location Services Enabled'] = locationEnabled;
      
      if (!locationEnabled) {
        result.manualSteps.add('Enable Location Services in device settings');
      }
    } catch (e) {
      result.fixes['Location Services Enabled'] = false;
      developer.log('[$_tag] Location services check error: $e');
    }
  }
  
  /// Apply device-specific fixes
  static Future<void> _applyDeviceSpecificFixes(DeviceInfo deviceInfo, EmergencyFixResult result) async {
    developer.log('[$_tag] Applying device-specific fixes for ${deviceInfo.manufacturer}...');
    
    if (deviceInfo.manufacturer.contains('oneplus') || deviceInfo.manufacturer.contains('oppo')) {
      await _applyOnePlusFixes(result);
    } else if (deviceInfo.manufacturer.contains('xiaomi')) {
      await _applyXiaomiFixes(result);
    } else if (deviceInfo.manufacturer.contains('samsung')) {
      await _applySamsungFixes(result);
    } else if (deviceInfo.manufacturer.contains('huawei')) {
      await _applyHuaweiFixes(result);
    } else if (deviceInfo.manufacturer.contains('vivo')) {
      await _applyVivoFixes(result);
    } else {
      result.manualSteps.add('Check manufacturer-specific battery optimization settings');
    }
  }
  
  /// Apply OnePlus-specific fixes
  static Future<void> _applyOnePlusFixes(EmergencyFixResult result) async {
    result.manualSteps.addAll([
      'OnePlus: Settings > Battery > Battery optimization > GroupSharing > Don\'t optimize',
      'OnePlus: Settings > Apps > Auto-start management > GroupSharing > Enable',
      'OnePlus: Settings > Apps > App management > GroupSharing > Battery > Unrestricted',
      'OnePlus: Settings > Battery > More battery settings > Sleep standby optimization > Disable',
      'OnePlus: Check Gaming Mode and Zen Mode settings',
    ]);
    
    try {
      await _channel.invokeMethod('openOnePlusSettings');
      result.fixes['OnePlus Settings Opened'] = true;
    } catch (e) {
      result.fixes['OnePlus Settings Opened'] = false;
      developer.log('[$_tag] OnePlus settings error: $e');
    }
  }
  
  /// Apply Xiaomi-specific fixes
  static Future<void> _applyXiaomiFixes(EmergencyFixResult result) async {
    result.manualSteps.addAll([
      'Xiaomi: Security app > Autostart > GroupSharing > Enable',
      'Xiaomi: Security app > Battery optimization > GroupSharing > No restrictions',
      'Xiaomi: Settings > Apps > Manage apps > GroupSharing > Battery saver > No restrictions',
      'Xiaomi: Developer options > MIUI optimization > Disable',
    ]);
    
    try {
      await _channel.invokeMethod('openXiaomiSettings');
      result.fixes['Xiaomi Settings Opened'] = true;
    } catch (e) {
      result.fixes['Xiaomi Settings Opened'] = false;
      developer.log('[$_tag] Xiaomi settings error: $e');
    }
  }
  
  /// Apply Samsung-specific fixes
  static Future<void> _applySamsungFixes(EmergencyFixResult result) async {
    result.manualSteps.addAll([
      'Samsung: Settings > Device care > Battery > More battery settings > Optimize settings > GroupSharing > Disable',
      'Samsung: Settings > Device care > Battery > App power management > Apps that won\'t be put to sleep > Add GroupSharing',
      'Samsung: Settings > Apps > GroupSharing > Battery > Allow background activity',
      'Samsung: Disable Adaptive Battery for GroupSharing',
    ]);
    
    try {
      await _channel.invokeMethod('openSamsungSettings');
      result.fixes['Samsung Settings Opened'] = true;
    } catch (e) {
      result.fixes['Samsung Settings Opened'] = false;
      developer.log('[$_tag] Samsung settings error: $e');
    }
  }
  
  /// Apply Huawei-specific fixes
  static Future<void> _applyHuaweiFixes(EmergencyFixResult result) async {
    result.manualSteps.addAll([
      'Huawei: Phone Manager > Protected apps > GroupSharing > Enable',
      'Huawei: Settings > Battery > App launch > GroupSharing > Manage manually > Enable all',
      'Huawei: Settings > Apps > GroupSharing > Battery > Power-intensive prompt > Disable',
    ]);
    
    try {
      await _channel.invokeMethod('openHuaweiSettings');
      result.fixes['Huawei Settings Opened'] = true;
    } catch (e) {
      result.fixes['Huawei Settings Opened'] = false;
      developer.log('[$_tag] Huawei settings error: $e');
    }
  }
  
  /// Apply Vivo-specific fixes
  static Future<void> _applyVivoFixes(EmergencyFixResult result) async {
    result.manualSteps.addAll([
      'Vivo: Settings > Battery > Background app refresh > GroupSharing > Allow',
      'Vivo: Settings > More settings > Applications > Autostart > GroupSharing > Enable',
      'Vivo: Settings > Battery > High background power consumption > GroupSharing > Allow',
    ]);
  }
  
  /// Test location services
  static Future<void> _testLocationServices(EmergencyFixResult result) async {
    try {
      developer.log('[$_tag] Testing location services...');
      
      // Check if location services are enabled
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        result.testResults['Location Services'] = 'Disabled - Enable in device settings';
        return;
      }
      
      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        result.testResults['Location Permission'] = 'Denied - Grant in app settings';
        return;
      }
      
      // Try to get current location
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        
        result.testResults['Location Test'] = 'Success - Got location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      } catch (e) {
        result.testResults['Location Test'] = 'Failed - $e';
      }
      
    } catch (e) {
      result.testResults['Location Test'] = 'Error - $e';
      developer.log('[$_tag] Location test error: $e');
    }
  }
  
  /// Open device-specific settings
  static Future<void> openDeviceSettings() async {
    try {
      await AppSettings.openAppSettings();
    } catch (e) {
      developer.log('[$_tag] Error opening settings: $e');
    }
  }
  
  /// Get troubleshooting guide for device
  static String getTroubleshootingGuide(String manufacturer) {
    switch (manufacturer.toLowerCase()) {
      case 'oneplus':
      case 'oppo':
        return _getOnePlusGuide();
      case 'xiaomi':
        return _getXiaomiGuide();
      case 'samsung':
        return _getSamsungGuide();
      case 'huawei':
        return _getHuaweiGuide();
      case 'vivo':
        return _getVivoGuide();
      default:
        return _getGenericGuide();
    }
  }
  
  static String _getOnePlusGuide() {
    return '''
🔧 OnePlus Background Location Fix:

1. Settings > Battery > Battery optimization
   - Find GroupSharing > Don't optimize

2. Settings > Apps > Auto-start management
   - Find GroupSharing > Enable

3. Settings > Apps > App management > GroupSharing
   - Battery > Unrestricted
   - Mobile data > Allow background data

4. Settings > Privacy > Permission manager > Location
   - GroupSharing > Allow all the time

5. Settings > Battery > More battery settings
   - Sleep standby optimization > Disable

6. Check Gaming Mode and Zen Mode settings
   - Add GroupSharing to exceptions if you use these

7. Restart your device after making changes
''';
  }
  
  static String _getXiaomiGuide() {
    return '''
🔧 Xiaomi/MIUI Background Location Fix:

1. Security app > Autostart
   - Find GroupSharing > Enable

2. Security app > Battery optimization
   - Find GroupSharing > No restrictions

3. Settings > Apps > Manage apps > GroupSharing
   - Battery saver > No restrictions
   - Other permissions > Display pop-up windows while running in background > Allow

4. Settings > Privacy > Permission manager > Location
   - GroupSharing > Allow all the time

5. Developer options (if enabled)
   - MIUI optimization > Disable

6. Restart your device after making changes
''';
  }
  
  static String _getSamsungGuide() {
    return '''
🔧 Samsung Background Location Fix:

1. Settings > Device care > Battery
   - More battery settings > Optimize settings > GroupSharing > Disable

2. Settings > Device care > Battery > App power management
   - Apps that won't be put to sleep > Add GroupSharing
   - Sleeping apps > Remove GroupSharing if present

3. Settings > Apps > GroupSharing
   - Battery > Allow background activity
   - Battery > Optimize battery usage > All apps > GroupSharing > Don't optimize

4. Settings > Privacy > Permission manager > Location
   - GroupSharing > Allow all the time

5. Disable Adaptive Battery for GroupSharing

6. Restart your device after making changes
''';
  }
  
  static String _getHuaweiGuide() {
    return '''
🔧 Huawei Background Location Fix:

1. Phone Manager > Protected apps
   - Find GroupSharing > Enable

2. Settings > Battery > App launch
   - GroupSharing > Manage manually
   - Enable Auto-launch, Secondary launch, Run in background

3. Settings > Apps > GroupSharing
   - Battery > Power-intensive prompt > Disable

4. Settings > Privacy > Permission manager > Location
   - GroupSharing > Allow all the time

5. Restart your device after making changes
''';
  }
  
  static String _getVivoGuide() {
    return '''
🔧 Vivo Background Location Fix:

1. Settings > Battery > Background app refresh
   - Find GroupSharing > Allow

2. Settings > More settings > Applications > Autostart
   - Find GroupSharing > Enable

3. Settings > Battery > High background power consumption
   - Find GroupSharing > Allow

4. Settings > Privacy > Permission manager > Location
   - GroupSharing > Allow all the time

5. Restart your device after making changes
''';
  }
  
  static String _getGenericGuide() {
    return '''
🔧 Generic Android Background Location Fix:

1. Settings > Apps > GroupSharing > Permissions > Location
   - Select "Allow all the time"

2. Settings > Battery > Battery optimization
   - Find GroupSharing > Don't optimize

3. Settings > Apps > GroupSharing > Battery
   - Allow background activity
   - Remove from any battery optimization

4. Check for manufacturer-specific battery/power management apps

5. Restart your device after making changes
''';
  }
}

/// Device information
class DeviceInfo {
  final String manufacturer;
  final String model;
  final String androidVersion;
  final int sdkInt;
  
  DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.sdkInt,
  });
}

/// Emergency fix result
class EmergencyFixResult {
  bool success = false;
  String message = '';
  DeviceInfo? deviceInfo;
  Map<String, bool> fixes = {};
  List<String> manualSteps = [];
  Map<String, String> testResults = {};
  
  /// Get summary of applied fixes
  String getSummary() {
    final appliedFixes = fixes.entries.where((e) => e.value).length;
    final totalFixes = fixes.length;
    
    return '''
Emergency Fix Results:
- Applied: $appliedFixes/$totalFixes automatic fixes
- Manual steps: ${manualSteps.length}
- Device: ${deviceInfo?.manufacturer ?? 'Unknown'} ${deviceInfo?.model ?? ''}
- Status: ${success ? 'Success' : 'Needs manual intervention'}

Next steps: ${manualSteps.isNotEmpty ? 'Complete manual steps below' : 'Test background location'}
''';
  }
}