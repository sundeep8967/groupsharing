import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Responsive dialog widget that adapts to screen size using pure ratios
class ResponsiveDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final bool barrierDismissible;

  const ResponsiveDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.barrierDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenSize = MediaQuery.of(context).size;
    
    // Pure ratio-based calculations
    final maxHeight = screenHeight * 0.65; // 65% of screen height
    final maxWidth = screenWidth * 0.85;   // 85% of screen width
    final basePadding = screenSize.shortestSide * 0.04; // 4% of shortest side
    final borderRadius = screenSize.shortestSide * 0.025; // 2.5% of shortest side
    
    return AlertDialog(
      title: title,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: maxWidth,
        ),
        child: SingleChildScrollView(
          child: content,
        ),
      ),
      actions: actions,
      titlePadding: EdgeInsets.all(basePadding),
      contentPadding: EdgeInsets.fromLTRB(
        basePadding,
        basePadding * 0.5,
        basePadding,
        basePadding,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        basePadding,
        0,
        basePadding,
        basePadding,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Responsive dialog title with icon using pure ratios
class ResponsiveDialogTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const ResponsiveDialogTitle({
    super.key,
    required this.icon,
    required this.text,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Pure ratio-based calculations
    final iconSize = screenSize.shortestSide * 0.055; // 5.5% of shortest side
    final spacing = screenSize.shortestSide * 0.02;   // 2% of shortest side
    final fontSize = screenSize.shortestSide * 0.045; // 4.5% of shortest side
    
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        SizedBox(width: spacing),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Responsive dialog content text using pure ratios
class ResponsiveDialogContent extends StatelessWidget {
  final String text;

  const ResponsiveDialogContent({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Pure ratio-based calculations
    final fontSize = screenSize.shortestSide * 0.035; // 3.5% of shortest side
    final lineHeight = 1.35; // Consistent line height ratio
    
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
      ),
    );
  }
}

/// Responsive dialog button using pure ratios
class ResponsiveDialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  const ResponsiveDialogButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Pure ratio-based calculations
    final horizontalPadding = screenSize.shortestSide * 0.045; // 4.5% of shortest side
    final verticalPadding = screenSize.shortestSide * 0.025;   // 2.5% of shortest side
    final fontSize = screenSize.shortestSide * 0.032;         // 3.2% of shortest side
    
    if (isPrimary) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
          ),
        ),
      );
    } else {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
          ),
        ),
      );
    }
  }
}

/// Comprehensive permission manager for persistent background location tracking
/// This ensures all necessary permissions are granted before the app can be used
class PermissionManager {
  static const String _permissionsGrantedKey = 'all_permissions_granted';
  static const String _permissionsDeniedKey = 'permissions_permanently_denied';
  
  // Method channels for native permission handling
  static const MethodChannel _batteryChannel = MethodChannel('com.sundeep.groupsharing/battery_optimization');
  static const MethodChannel _locationChannel = MethodChannel('persistent_location_service');
  
  /// Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool(_permissionsGrantedKey) ?? false;
      
      if (cached) {
        // Double-check critical permissions
        final locationStatus = await Geolocator.checkPermission();
        final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
        
        if (locationStatus == LocationPermission.always && locationServiceEnabled) {
          return true;
        }
      }
      
      // Perform full permission check
      return await _checkAllPermissions();
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }
  
  /// Request all required permissions with user-friendly explanations
  static Future<bool> requestAllPermissions(BuildContext context) async {
    try {
      // Check if permissions were permanently denied
      final prefs = await SharedPreferences.getInstance();
      final permanentlyDenied = prefs.getBool(_permissionsDeniedKey) ?? false;
      
      if (permanentlyDenied) {
        await _showPermanentlyDeniedDialog(context);
        return false;
      }
      
      // Step 1: Location Services
      if (!await _ensureLocationServicesEnabled(context)) {
        return false;
      }
      
      // Step 2: Basic Location Permission
      if (!await _requestBasicLocationPermission(context)) {
        return false;
      }
      
      // Step 3: Background Location Permission (Android)
      if (Platform.isAndroid) {
        if (!await _requestBackgroundLocationPermission(context)) {
          return false;
        }
      }
      
      // Step 4: Always Location Permission (iOS)
      if (Platform.isIOS) {
        if (!await _requestAlwaysLocationPermission(context)) {
          return false;
        }
      }
      
      // Step 5: Notification Permission
      if (!await _requestNotificationPermission(context)) {
        return false;
      }
      
      // Step 6: Battery Optimization (Android)
      if (Platform.isAndroid) {
        await _requestBatteryOptimizationExemption(context);
      }
      
      // Step 7: Auto-start Permission (Android)
      if (Platform.isAndroid) {
        await _requestAutoStartPermission(context);
      }
      
      // Final verification
      final allGranted = await _checkAllPermissions();
      
      // Cache the result
      await prefs.setBool(_permissionsGrantedKey, allGranted);
      
      if (allGranted) {
        await _showPermissionsGrantedDialog(context);
      }
      
      return allGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Check all required permissions
  static Future<bool> _checkAllPermissions() async {
    try {
      // Location service enabled
      final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) return false;
      
      // Location permission
      final locationPermission = await Geolocator.checkPermission();
      if (Platform.isAndroid) {
        if (locationPermission != LocationPermission.always) return false;
      } else {
        if (locationPermission != LocationPermission.always && 
            locationPermission != LocationPermission.whileInUse) return false;
      }
      
      // Notification permission
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) return false;
      
      return true;
    } catch (e) {
      debugPrint('Error checking all permissions: $e');
      return false;
    }
  }
  
  /// Ensure location services are enabled
  static Future<bool> _ensureLocationServicesEnabled(BuildContext context) async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    
    if (!isEnabled) {
      final shouldEnable = await _showLocationServicesDialog(context);
      if (shouldEnable) {
        await Geolocator.openLocationSettings();
        
        // Wait for user to enable and return
        await Future.delayed(const Duration(seconds: 2));
        return await Geolocator.isLocationServiceEnabled();
      }
      return false;
    }
    
    return true;
  }
  
  /// Request basic location permission
  static Future<bool> _requestBasicLocationPermission(BuildContext context) async {
    final permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Show explanation dialog first
      await _showLocationPermissionExplanationDialog(context);
      
      final newPermission = await Geolocator.requestPermission();
      return newPermission != LocationPermission.denied && 
             newPermission != LocationPermission.deniedForever;
    }
    
    if (permission == LocationPermission.deniedForever) {
      await _showLocationPermissionDeniedDialog(context);
      return false;
    }
    
    return permission != LocationPermission.denied;
  }
  
  /// Request background location permission (Android)
  static Future<bool> _requestBackgroundLocationPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    final currentPermission = await Geolocator.checkPermission();
    
    if (currentPermission != LocationPermission.always) {
      // Show explanation for background location
      await _showBackgroundLocationExplanationDialog(context);
      
      try {
        final result = await _locationChannel.invokeMethod('requestBackgroundLocationPermission');
        return result == true;
      } catch (e) {
        debugPrint('Error requesting background location permission: $e');
        
        // Fallback: Guide user to settings
        await _showBackgroundLocationSettingsDialog(context);
        return false;
      }
    }
    
    return true;
  }
  
  /// Request always location permission (iOS)
  static Future<bool> _requestAlwaysLocationPermission(BuildContext context) async {
    if (!Platform.isIOS) return true;
    
    final permission = await Geolocator.checkPermission();
    
    if (permission != LocationPermission.always) {
      // Show explanation for always location
      await _showAlwaysLocationExplanationDialog(context);
      
      // Request always permission
      final newPermission = await Geolocator.requestPermission();
      
      if (newPermission != LocationPermission.always) {
        await _showAlwaysLocationSettingsDialog(context);
        return false;
      }
    }
    
    return true;
  }
  
  /// Request notification permission
  static Future<bool> _requestNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.status;
    
    if (status.isDenied) {
      // Show explanation dialog
      await _showNotificationPermissionExplanationDialog(context);
      
      final newStatus = await Permission.notification.request();
      return newStatus.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      await _showNotificationPermissionDeniedDialog(context);
      return false;
    }
    
    return status.isGranted;
  }
  
  /// Request battery optimization exemption (Android)
  static Future<void> _requestBatteryOptimizationExemption(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    try {
      final isOptimized = !(await _batteryChannel.invokeMethod('isBatteryOptimizationDisabled') ?? false);
      
      if (isOptimized) {
        await _showBatteryOptimizationExplanationDialog(context);
        await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
      }
    } catch (e) {
      debugPrint('Error handling battery optimization: $e');
    }
  }
  
  /// Request auto-start permission (Android)
  static Future<void> _requestAutoStartPermission(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    await _showAutoStartExplanationDialog(context);
  }
  
  /// Show location services dialog
  static Future<bool> _showLocationServicesDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.location_off,
            text: 'Location Services Required',
            iconColor: Colors.red,
          ),
          content: const ResponsiveDialogContent(
            text: 'This app requires location services to be enabled to share your location with family and friends.\n\n'
                'Please enable location services in your device settings.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Exit App',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ResponsiveDialogButton(
              text: 'Enable Location',
              onPressed: () => Navigator.of(context).pop(true),
              isPrimary: true,
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  /// Show location permission explanation dialog
  static Future<void> _showLocationPermissionExplanationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.location_on,
            text: 'Location Permission',
            iconColor: Colors.blue,
          ),
          content: const ResponsiveDialogContent(
            text: 'We need access to your location to:\n\n'
                '• Share your location with family and friends\n'
                '• Show your position on the map\n'
                '• Send proximity notifications\n'
                '• Provide location-based features\n\n'
                'Your location data is only shared with people you choose.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Continue',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show background location explanation dialog
  static Future<void> _showBackgroundLocationExplanationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.location_history,
            text: 'Background Location',
            iconColor: Colors.orange,
          ),
          content: const ResponsiveDialogContent(
            text: 'For the best experience, please allow location access "All the time".\n\n'
                'This enables:\n'
                '• Continuous location sharing with family\n'
                '• Real-time location updates\n'
                '• Location sharing even when app is closed\n'
                '• Emergency location features\n\n'
                'We only use your location for family safety and never share it with third parties.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Continue',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show always location explanation dialog (iOS)
  static Future<void> _showAlwaysLocationExplanationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.location_history,
            text: 'Always Allow Location',
            iconColor: Colors.orange,
          ),
          content: const ResponsiveDialogContent(
            text: 'Please select "Always Allow" for location access.\n\n'
                'This enables:\n'
                '• Continuous family location sharing\n'
                '• Background location updates\n'
                '• Emergency location features\n'
                '• Real-time proximity alerts\n\n'
                'Your privacy is protected - location is only shared with your chosen family members.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Continue',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show notification permission explanation dialog
  static Future<void> _showNotificationPermissionExplanationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.notifications,
            text: 'Notification Permission',
            iconColor: Colors.green,
          ),
          content: const ResponsiveDialogContent(
            text: 'We need notification permission to:\n\n'
                '• Alert you when family members are nearby\n'
                '• Notify about location sharing status\n'
                '• Send important family safety alerts\n'
                '• Keep you informed about app status\n\n'
                'You can customize notification settings later.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Continue',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show battery optimization explanation dialog
  static Future<void> _showBatteryOptimizationExplanationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.battery_saver,
            text: 'Battery Optimization',
            iconColor: Colors.amber,
          ),
          content: const ResponsiveDialogContent(
            text: 'To ensure reliable location sharing, please disable battery optimization for this app.\n\n'
                'This prevents Android from stopping location updates when the app is in the background.\n\n'
                'Don\'t worry - our app is designed to be battery efficient while maintaining accurate location sharing.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Continue',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show auto-start explanation dialog
  static Future<void> _showAutoStartExplanationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.power_settings_new,
            text: 'Auto-Start Permission',
            iconColor: Colors.purple,
          ),
          content: const ResponsiveDialogContent(
            text: 'Some Android devices require auto-start permission for background location.\n\n'
                'If you experience issues with location sharing:\n'
                '1. Go to device Settings\n'
                '2. Find "Auto-start" or "Background apps"\n'
                '3. Enable auto-start for GroupSharing\n\n'
                'This ensures location sharing continues working reliably.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Got It',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show permissions granted dialog
  static Future<void> _showPermissionsGrantedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.check_circle,
            text: 'All Set!',
            iconColor: Colors.green,
          ),
          content: const ResponsiveDialogContent(
            text: 'Perfect! All permissions have been granted.\n\n'
                'Your app is now ready for:\n'
                '• Reliable background location sharing\n'
                '• Real-time family tracking\n'
                '• Proximity notifications\n'
                '• Emergency location features\n\n'
                'You can start sharing your location with family and friends!',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Start Using App',
              onPressed: () => Navigator.of(context).pop(),
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show location permission denied dialog
  static Future<void> _showLocationPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.error,
            text: 'Permission Required',
            iconColor: Colors.red,
          ),
          content: const ResponsiveDialogContent(
            text: 'Location permission is required for this app to work.\n\n'
                'Please go to Settings > Apps > GroupSharing > Permissions and enable Location access.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Exit App',
              onPressed: () => SystemNavigator.pop(),
            ),
            ResponsiveDialogButton(
              text: 'Open Settings',
              onPressed: () async {
                await Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show background location settings dialog
  static Future<void> _showBackgroundLocationSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.settings,
            text: 'Background Location Setup',
            iconColor: Colors.orange,
          ),
          content: const ResponsiveDialogContent(
            text: 'Please enable background location access:\n\n'
                '1. Go to Settings > Apps > GroupSharing\n'
                '2. Tap Permissions > Location\n'
                '3. Select "Allow all the time"\n\n'
                'This ensures location sharing works even when the app is closed.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Exit App',
              onPressed: () => SystemNavigator.pop(),
            ),
            ResponsiveDialogButton(
              text: 'Open Settings',
              onPressed: () async {
                await Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }
  
  /// Show always location settings dialog (iOS)
  static Future<void> _showAlwaysLocationSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.orange),
              SizedBox(width: 8),
              Text('Location Settings'),
            ],
          ),
          content: const Text(
            'Please enable "Always" location access:\n\n'
            '1. Go to Settings > Privacy & Security > Location Services\n'
            '2. Find GroupSharing\n'
            '3. Select "Always"\n\n'
            'This enables background location sharing with your family.',
          ),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Exit App'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show notification permission denied dialog
  static Future<void> _showNotificationPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_off, color: Colors.red),
              SizedBox(width: 8),
              Text('Notifications Required'),
            ],
          ),
          content: const Text(
            'Notification permission is required for proximity alerts and important updates.\n\n'
            'Please enable notifications in Settings > Apps > GroupSharing > Notifications.',
          ),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Exit App'),
            ),
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show permanently denied dialog
  static Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('Permissions Required'),
            ],
          ),
          content: const Text(
            'This app requires location and notification permissions to function.\n\n'
            'Please enable all required permissions in your device settings to use the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Exit App'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
                // Clear the permanently denied flag to allow retry
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(_permissionsDeniedKey);
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
  
  /// Mark permissions as permanently denied
  static Future<void> markPermissionsPermanentlyDenied() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsDeniedKey, true);
  }
  
  /// Clear all permission cache
  static Future<void> clearPermissionCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionsGrantedKey);
    await prefs.remove(_permissionsDeniedKey);
  }
}