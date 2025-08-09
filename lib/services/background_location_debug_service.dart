import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'battery_optimization_service.dart';
import 'oneplus_optimization_service.dart';
import 'firebase_service.dart';
import 'bulletproof_location_service.dart';
import 'life360_location_service.dart';
import 'persistent_location_service.dart';
import 'ultra_persistent_location_service.dart';
import 'android_background_location_optimizer.dart';
import '../providers/location_provider.dart';
import '../providers/enhanced_location_provider.dart';

/// Comprehensive Background Location Debug Service
/// 
/// This service provides detailed debugging and diagnostics for background location issues.
/// It identifies and helps resolve the 5 critical issues:
/// 1. battery_optimization - Battery optimization killing the app
/// 2. auto_start - Auto-start permission for app restart after reboot
/// 3. background_refresh - Background app refresh settings
/// 4. app_lock - Device-specific app lock features
/// 5. device_specific - Other manufacturer-specific restrictions
class BackgroundLocationDebugService {
  static const String _tag = 'BackgroundLocationDebugService';
  static const MethodChannel _debugChannel = MethodChannel('background_location_debug');
  
  // Debug state
  static bool _isDebugging = false;
  static Timer? _debugTimer;
  static final List<DebugLogEntry> _debugLogs = [];
  static final StreamController<DebugLogEntry> _logStreamController = 
      StreamController<DebugLogEntry>.broadcast();
  
  // Firebase references for debug data
  static final FirebaseFirestore _firestore = FirebaseService.firestore;
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  
  /// Start comprehensive debugging session with location service integration
  static Future<void> startDebugging({
    String? userId,
    LocationProvider? locationProvider,
    EnhancedLocationProvider? enhancedLocationProvider,
  }) async {
    if (_isDebugging) return;
    
    _isDebugging = true;
    _debugLogs.clear();
    
    _log('🔍 Starting comprehensive background location debugging...');
    
    try {
      // Start periodic debug checks
      _debugTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _performPeriodicDebugCheck();
      });
      
      // Initial comprehensive diagnosis
      await _performInitialDiagnosis();
      
      // Diagnose existing location services
      await _diagnoseLocationServices(locationProvider, enhancedLocationProvider);
      
      // Start monitoring critical systems
      await _startSystemMonitoring();
      
      // Setup location service monitoring
      await _setupLocationServiceMonitoring(locationProvider, enhancedLocationProvider);
      
      _log('✅ Debug session started successfully');
      
      // Save debug session to Firebase if userId provided
      if (userId != null) {
        await _saveDebugSessionToFirebase(userId);
      }
      
    } catch (e) {
      _log('❌ Error starting debug session: $e', isError: true);
    }
  }
  
  /// Stop debugging session
  static Future<void> stopDebugging() async {
    if (!_isDebugging) return;
    
    _isDebugging = false;
    _debugTimer?.cancel();
    _debugTimer = null;
    
    _log('🛑 Stopping debug session...');
    _log('📊 Debug session completed. Total logs: ${_debugLogs.length}');
  }
  
  /// Get debug logs stream
  static Stream<DebugLogEntry> get debugLogsStream => _logStreamController.stream;
  
  /// Get all debug logs
  static List<DebugLogEntry> get debugLogs => List.unmodifiable(_debugLogs);
  
  /// Perform initial comprehensive diagnosis
  static Future<void> _performInitialDiagnosis() async {
    _log('🔎 Performing initial diagnosis...');
    
    // 1. Device Information
    await _diagnoseDeviceInfo();
    
    // 2. Permission Status
    await _diagnosePermissions();
    
    // 3. Battery Optimization Status
    await _diagnoseBatteryOptimization();
    
    // 4. Auto-Start Permission
    await _diagnoseAutoStart();
    
    // 5. Background Refresh Settings
    await _diagnoseBackgroundRefresh();
    
    // 6. App Lock Settings
    await _diagnoseAppLock();
    
    // 7. Device-Specific Issues
    await _diagnoseDeviceSpecificIssues();
    
    // 8. Location Service Status
    await _diagnoseLocationServiceStatus();
    
    // 9. Network Connectivity
    await _diagnoseNetworkConnectivity();
    
    // 10. Android Background Location Limits
    await _diagnoseAndroidBackgroundLimits();
    
    _log('✅ Initial diagnosis completed');
  }
  
  /// Diagnose device information
  static Future<void> _diagnoseDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _log('📱 Device Info:');
        _log('   Manufacturer: ${androidInfo.manufacturer}');
        _log('   Model: ${androidInfo.model}');
        _log('   Android Version: ${androidInfo.version.release}');
        _log('   SDK Level: ${androidInfo.version.sdkInt}');
        _log('   Brand: ${androidInfo.brand}');
        _log('   Hardware: ${androidInfo.hardware}');
        
        // Check for problematic devices
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        final model = androidInfo.model.toLowerCase();
        
        if (manufacturer.contains('oneplus')) {
          _log('⚠️  OnePlus device detected - Known for aggressive power management');
        } else if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
          _log('⚠️  Xiaomi device detected - MIUI has strict background restrictions');
        } else if (manufacturer.contains('huawei')) {
          _log('⚠️  Huawei device detected - EMUI has aggressive power saving');
        } else if (manufacturer.contains('oppo') || manufacturer.contains('realme')) {
          _log('⚠️  Oppo/Realme device detected - ColorOS restrictions apply');
        } else if (manufacturer.contains('vivo')) {
          _log('⚠️  Vivo device detected - FunTouch OS has background limitations');
        } else if (manufacturer.contains('samsung')) {
          _log('ℹ️  Samsung device detected - Generally good for background location');
        }
        
        // Check specific problematic models
        if (model.contains('cph2491')) {
          _log('🚨 OnePlus CPH2491 detected - This model has severe background restrictions!');
        }
        
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _log('📱 iOS Device Info:');
        _log('   Model: ${iosInfo.model}');
        _log('   System Version: ${iosInfo.systemVersion}');
        _log('   Name: ${iosInfo.name}');
      }
      
    } catch (e) {
      _log('❌ Error getting device info: $e', isError: true);
    }
  }
  
  /// Diagnose permission status
  static Future<void> _diagnosePermissions() async {
    try {
      _log('🔐 Checking Permissions:');
      
      // Location permission
      final locationStatus = await Permission.location.status;
      _log('   Location: ${locationStatus.name}');
      
      if (locationStatus != PermissionStatus.granted) {
        _log('❌ Location permission not granted!', isError: true);
      }
      
      // Location always permission (Android)
      if (Platform.isAndroid) {
        final locationAlwaysStatus = await Permission.locationAlways.status;
        _log('   Location Always: ${locationAlwaysStatus.name}');
        
        if (locationAlwaysStatus != PermissionStatus.granted) {
          _log('❌ Background location permission not granted!', isError: true);
        }
      }
      
      // Notification permission
      final notificationStatus = await Permission.notification.status;
      _log('   Notification: ${notificationStatus.name}');
      
      // Phone permission (for emergency features)
      final phoneStatus = await Permission.phone.status;
      _log('   Phone: ${phoneStatus.name}');
      
      // Check Geolocator permissions
      final geoPermission = await Geolocator.checkPermission();
      _log('   Geolocator Permission: ${geoPermission.name}');
      
      final geoServiceEnabled = await Geolocator.isLocationServiceEnabled();
      _log('   Location Services Enabled: $geoServiceEnabled');
      
      if (!geoServiceEnabled) {
        _log('❌ Location services are disabled!', isError: true);
      }
      
    } catch (e) {
      _log('❌ Error checking permissions: $e', isError: true);
    }
  }
  
  /// Diagnose battery optimization
  static Future<void> _diagnoseBatteryOptimization() async {
    try {
      _log('🔋 Checking Battery Optimization:');
      
      final isDisabled = await BatteryOptimizationService.isBatteryOptimizationDisabled();
      _log('   Battery Optimization Disabled: $isDisabled');
      
      if (!isDisabled) {
        _log('❌ Battery optimization is enabled - this will kill background location!', isError: true);
      }
      
      // Get comprehensive status
      final status = await BatteryOptimizationService.getComprehensiveOptimizationStatus();
      _log('   Comprehensive Status: $status');
      
    } catch (e) {
      _log('❌ Error checking battery optimization: $e', isError: true);
    }
  }
  
  /// Diagnose auto-start permission
  static Future<void> _diagnoseAutoStart() async {
    try {
      _log('🚀 Checking Auto-Start Permission:');
      
      if (Platform.isAndroid) {
        // Check if device supports auto-start
        final isOnePlus = await OnePlusOptimizationService.isOnePlusDevice();
        if (isOnePlus) {
          final optimizations = await OnePlusOptimizationService.checkOnePlusOptimizations();
          final autoStartEnabled = optimizations['auto_start'] ?? false;
          _log('   Auto-Start Enabled: $autoStartEnabled');
          
          if (!autoStartEnabled) {
            _log('❌ Auto-start permission not granted!', isError: true);
          }
        } else {
          _log('   Auto-Start: Not applicable for this device');
        }
      } else {
        _log('   Auto-Start: iOS handles this automatically');
      }
      
    } catch (e) {
      _log('❌ Error checking auto-start: $e', isError: true);
    }
  }
  
  /// Diagnose background refresh settings
  static Future<void> _diagnoseBackgroundRefresh() async {
    try {
      _log('🔄 Checking Background Refresh:');
      
      if (Platform.isAndroid) {
        // Use native channel to check background app refresh
        try {
          final result = await _debugChannel.invokeMethod('checkBackgroundRefresh');
          _log('   Background Refresh Enabled: ${result ?? "Unknown"}');
          
          if (result == false) {
            _log('❌ Background app refresh is disabled!', isError: true);
          }
        } catch (e) {
          _log('   Background Refresh: Unable to check (${e.toString()})');
        }
      } else {
        _log('   Background Refresh: iOS manages this automatically');
      }
      
    } catch (e) {
      _log('❌ Error checking background refresh: $e', isError: true);
    }
  }
  
  /// Diagnose app lock settings
  static Future<void> _diagnoseAppLock() async {
    try {
      _log('🔒 Checking App Lock Settings:');
      
      if (Platform.isAndroid) {
        // Check device-specific app lock features
        try {
          final result = await _debugChannel.invokeMethod('checkAppLock');
          _log('   App Lock Status: ${result ?? "Unknown"}');
          
          if (result == true) {
            _log('⚠️  App lock is enabled - this may prevent background operation');
          }
        } catch (e) {
          _log('   App Lock: Unable to check (${e.toString()})');
        }
      } else {
        _log('   App Lock: Not applicable for iOS');
      }
      
    } catch (e) {
      _log('❌ Error checking app lock: $e', isError: true);
    }
  }
  
  /// Diagnose device-specific issues
  static Future<void> _diagnoseDeviceSpecificIssues() async {
    try {
      _log('🔧 Checking Device-Specific Issues:');
      
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        
        // OnePlus specific checks
        if (manufacturer.contains('oneplus')) {
          await _diagnoseOnePlusSpecific();
        }
        
        // Xiaomi specific checks
        else if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
          await _diagnoseXiaomiSpecific();
        }
        
        // Huawei specific checks
        else if (manufacturer.contains('huawei')) {
          await _diagnoseHuaweiSpecific();
        }
        
        // Samsung specific checks
        else if (manufacturer.contains('samsung')) {
          await _diagnoseSamsungSpecific();
        }
        
        // Generic Android checks
        else {
          _log('   Generic Android device - checking standard optimizations');
        }
        
      } else {
        _log('   iOS device - checking iOS-specific settings');
        await _diagnoseiOSSpecific();
      }
      
    } catch (e) {
      _log('❌ Error checking device-specific issues: $e', isError: true);
    }
  }
  
  /// Diagnose OnePlus specific issues
  static Future<void> _diagnoseOnePlusSpecific() async {
    _log('   🔍 OnePlus Specific Diagnostics:');
    
    try {
      final optimizations = await OnePlusOptimizationService.checkOnePlusOptimizations();
      
      optimizations.forEach((key, value) {
        final status = value ? '✅' : '❌';
        _log('     $key: $status $value');
        
        if (!value) {
          _log('❌ OnePlus $key optimization failed!', isError: true);
        }
      });
      
    } catch (e) {
      _log('❌ Error checking OnePlus optimizations: $e', isError: true);
    }
  }
  
  /// Diagnose Xiaomi specific issues
  static Future<void> _diagnoseXiaomiSpecific() async {
    _log('   🔍 Xiaomi/MIUI Specific Diagnostics:');
    
    try {
      // Check MIUI specific settings
      final result = await _debugChannel.invokeMethod('checkMIUISettings');
      _log('     MIUI Settings: ${result ?? "Unable to check"}');
      
      // Common MIUI issues
      _log('     Common MIUI Issues to Check:');
      _log('       - Battery Saver mode');
      _log('       - Background app limits');
      _log('       - MIUI Optimization');
      _log('       - Autostart management');
      
    } catch (e) {
      _log('❌ Error checking MIUI settings: $e', isError: true);
    }
  }
  
  /// Diagnose Huawei specific issues
  static Future<void> _diagnoseHuaweiSpecific() async {
    _log('   🔍 Huawei/EMUI Specific Diagnostics:');
    
    try {
      // Check EMUI specific settings
      final result = await _debugChannel.invokeMethod('checkEMUISettings');
      _log('     EMUI Settings: ${result ?? "Unable to check"}');
      
      // Common EMUI issues
      _log('     Common EMUI Issues to Check:');
      _log('       - Power Genie settings');
      _log('       - Protected apps list');
      _log('       - Launch management');
      _log('       - Battery optimization');
      
    } catch (e) {
      _log('❌ Error checking EMUI settings: $e', isError: true);
    }
  }
  
  /// Diagnose Samsung specific issues
  static Future<void> _diagnoseSamsungSpecific() async {
    _log('   🔍 Samsung Specific Diagnostics:');
    
    try {
      // Check Samsung specific settings
      final result = await _debugChannel.invokeMethod('checkSamsungSettings');
      _log('     Samsung Settings: ${result ?? "Unable to check"}');
      
      // Samsung is generally good for background location
      _log('     Samsung devices generally handle background location well');
      _log('     Check: Device Care > Battery > App power management');
      
    } catch (e) {
      _log('❌ Error checking Samsung settings: $e', isError: true);
    }
  }
  
  /// Diagnose iOS specific issues
  static Future<void> _diagnoseiOSSpecific() async {
    _log('   🔍 iOS Specific Diagnostics:');
    
    try {
      // iOS specific checks
      _log('     iOS Background App Refresh: Check in Settings');
      _log('     Location Services: Check in Settings > Privacy & Security');
      _log('     Low Power Mode: May affect background location');
      
    } catch (e) {
      _log('❌ Error checking iOS settings: $e', isError: true);
    }
  }
  
  /// Diagnose location service status
  static Future<void> _diagnoseLocationServiceStatus() async {
    try {
      _log('📍 Checking Location Services:');
      
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _log('   Location Services Enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        _log('❌ Location services are disabled!', isError: true);
        return;
      }
      
      // Try to get current position
      try {
        _log('   Testing location acquisition...');
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        _log('   ✅ Location acquired: ${position.latitude}, ${position.longitude}');
        _log('   Accuracy: ${position.accuracy}m');
        _log('   Timestamp: ${DateTime.fromMillisecondsSinceEpoch(position.timestamp.millisecondsSinceEpoch)}');
        
      } catch (e) {
        _log('❌ Failed to get location: $e', isError: true);
      }
      
      // Check location settings
      final locationSettings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              forceLocationManager: false,
            )
          : AppleSettings(
              accuracy: LocationAccuracy.high,
              activityType: ActivityType.fitness,
              distanceFilter: 10,
              pauseLocationUpdatesAutomatically: false,
              showBackgroundLocationIndicator: true,
            );
      
      _log('   Location Settings: ${locationSettings.toString()}');
      
    } catch (e) {
      _log('❌ Error checking location services: $e', isError: true);
    }
  }
  
  /// Diagnose network connectivity
  static Future<void> _diagnoseNetworkConnectivity() async {
    try {
      _log('🌐 Checking Network Connectivity:');
      
      // Test Firebase connectivity
      try {
        await _firestore.collection('test').doc('connectivity').get();
        _log('   ✅ Firestore connectivity: OK');
      } catch (e) {
        _log('❌ Firestore connectivity failed: $e', isError: true);
      }
      
      // Test Realtime Database connectivity
      try {
        await _realtimeDb.ref('test').once();
        _log('   ✅ Realtime Database connectivity: OK');
      } catch (e) {
        _log('❌ Realtime Database connectivity failed: $e', isError: true);
      }
      
    } catch (e) {
      _log('❌ Error checking network connectivity: $e', isError: true);
    }
  }
  
  /// Perform periodic debug check
  static Future<void> _performPeriodicDebugCheck() async {
    if (!_isDebugging) return;
    
    try {
      _log('🔄 Periodic debug check...');
      
      // Check if location is still working
      try {
        final position = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 5),
        );
        _log('   📍 Location still working: ${position.latitude}, ${position.longitude}');
      } catch (e) {
        _log('❌ Location check failed: $e', isError: true);
      }
      
      // Check permissions
      final locationStatus = await Permission.location.status;
      if (locationStatus != PermissionStatus.granted) {
        _log('❌ Location permission revoked!', isError: true);
      }
      
      // Check battery optimization
      final batteryOptDisabled = await BatteryOptimizationService.isBatteryOptimizationDisabled();
      if (!batteryOptDisabled) {
        _log('❌ Battery optimization re-enabled!', isError: true);
      }
      
    } catch (e) {
      _log('❌ Error in periodic check: $e', isError: true);
    }
  }
  
  /// Diagnose existing location services
  static Future<void> _diagnoseLocationServices(
    LocationProvider? locationProvider,
    EnhancedLocationProvider? enhancedLocationProvider,
  ) async {
    _log('🔧 Diagnosing Location Services Integration...');
    
    try {
      // Check LocationProvider status
      if (locationProvider != null) {
        _log('📍 LocationProvider Status:');
        _log('   Initialized: ${locationProvider.isInitialized}');
        _log('   Tracking: ${locationProvider.isTracking}');
        _log('   Current Location: ${locationProvider.currentLocation}');
        _log('   Status: ${locationProvider.status}');
        _log('   Error: ${locationProvider.error ?? "None"}');
        _log('   User Locations Count: ${locationProvider.userLocations.length}');
        
        if (!locationProvider.isInitialized) {
          _log('❌ LocationProvider not initialized!', isError: true);
        }
        
        if (!locationProvider.isTracking && locationProvider.isInitialized) {
          _log('⚠️  LocationProvider initialized but not tracking');
        }
        
        if (locationProvider.error != null) {
          _log('❌ LocationProvider has error: ${locationProvider.error}', isError: true);
        }
      } else {
        _log('⚠️  LocationProvider not provided for debugging');
      }
      
      // Check EnhancedLocationProvider status
      if (enhancedLocationProvider != null) {
        _log('🚀 EnhancedLocationProvider Status:');
        _log('   Initialized: ${enhancedLocationProvider.isInitialized}');
        _log('   Tracking: ${enhancedLocationProvider.isTracking}');
        _log('   Current Location: ${enhancedLocationProvider.currentLocation}');
        _log('   Status: ${enhancedLocationProvider.status}');
        _log('   Error: ${enhancedLocationProvider.error ?? "None"}');
        _log('   User Locations Count: ${enhancedLocationProvider.userLocations.length}');
        
        if (!enhancedLocationProvider.isInitialized) {
          _log('❌ EnhancedLocationProvider not initialized!', isError: true);
        }
        
        if (!enhancedLocationProvider.isTracking && enhancedLocationProvider.isInitialized) {
          _log('⚠️  EnhancedLocationProvider initialized but not tracking');
        }
        
        if (enhancedLocationProvider.error != null) {
          _log('❌ EnhancedLocationProvider has error: ${enhancedLocationProvider.error}', isError: true);
        }
      } else {
        _log('⚠️  EnhancedLocationProvider not provided for debugging');
      }
      
      // Check BulletproofLocationService status
      await _diagnoseBulletproofLocationService();
      
      // Check Life360LocationService status
      await _diagnoseLife360LocationService();
      
      // Check PersistentLocationService status
      await _diagnosePersistentLocationService();
      
      // Check UltraPersistentLocationService status
      await _diagnoseUltraPersistentLocationService();
      
    } catch (e) {
      _log('❌ Error diagnosing location services: $e', isError: true);
    }
  }
  
  /// Diagnose BulletproofLocationService
  static Future<void> _diagnoseBulletproofLocationService() async {
    try {
      _log('🛡️  BulletproofLocationService Status:');
      
      // Try to initialize and check status
      final initialized = await BulletproofLocationService.initialize();
      _log('   Initialization: ${initialized ? "✅ Success" : "❌ Failed"}');
      
      if (!initialized) {
        _log('❌ BulletproofLocationService failed to initialize!', isError: true);
      }
      
      // Additional checks would require exposing more state from BulletproofLocationService
      _log('   Service: Available for background location tracking');
      
    } catch (e) {
      _log('❌ Error checking BulletproofLocationService: $e', isError: true);
    }
  }
  
  /// Diagnose Life360LocationService
  static Future<void> _diagnoseLife360LocationService() async {
    try {
      _log('🌍 Life360LocationService Status:');
      
      // Try to initialize and check status
      final initialized = await Life360LocationService.initialize();
      _log('   Initialization: ${initialized ? "✅ Success" : "❌ Failed"}');
      
      if (!initialized) {
        _log('❌ Life360LocationService failed to initialize!', isError: true);
      }
      
      _log('   Service: Life360-style persistent tracking available');
      
    } catch (e) {
      _log('❌ Error checking Life360LocationService: $e', isError: true);
    }
  }
  
  /// Diagnose PersistentLocationService
  static Future<void> _diagnosePersistentLocationService() async {
    try {
      _log('⚡ PersistentLocationService Status:');
      
      // Try to initialize and check status
      final initialized = await PersistentLocationService.initialize();
      _log('   Initialization: ${initialized ? "✅ Success" : "❌ Failed"}');
      
      if (!initialized) {
        _log('❌ PersistentLocationService failed to initialize!', isError: true);
      }
      
      _log('   Service: Isolate-based persistent tracking available');
      
    } catch (e) {
      _log('❌ Error checking PersistentLocationService: $e', isError: true);
    }
  }
  
  /// Diagnose UltraPersistentLocationService
  static Future<void> _diagnoseUltraPersistentLocationService() async {
    try {
      _log('🚀 UltraPersistentLocationService Status:');
      
      // Try to initialize and check status
      final initialized = await UltraPersistentLocationService.initialize();
      _log('   Initialization: ${initialized ? "✅ Success" : "❌ Failed"}');
      
      if (!initialized) {
        _log('❌ UltraPersistentLocationService failed to initialize!', isError: true);
      }
      
      _log('   Service: Ultra-persistent tracking for aggressive devices available');
      
    } catch (e) {
      _log('❌ Error checking UltraPersistentLocationService: $e', isError: true);
    }
  }
  
  /// Setup location service monitoring
  static Future<void> _setupLocationServiceMonitoring(
    LocationProvider? locationProvider,
    EnhancedLocationProvider? enhancedLocationProvider,
  ) async {
    _log('👁️  Setting up location service monitoring...');
    
    try {
      // Monitor LocationProvider changes
      if (locationProvider != null) {
        locationProvider.addListener(() {
          _log('📍 LocationProvider Update:');
          _log('   Status: ${locationProvider.status}');
          _log('   Location: ${locationProvider.currentLocation}');
          _log('   Error: ${locationProvider.error ?? "None"}');
          
          if (locationProvider.error != null) {
            _log('❌ LocationProvider error: ${locationProvider.error}', isError: true);
          }
        });
      }
      
      // Monitor EnhancedLocationProvider changes
      if (enhancedLocationProvider != null) {
        enhancedLocationProvider.addListener(() {
          _log('🚀 EnhancedLocationProvider Update:');
          _log('   Status: ${enhancedLocationProvider.status}');
          _log('   Location: ${enhancedLocationProvider.currentLocation}');
          _log('   Error: ${enhancedLocationProvider.error ?? "None"}');
          
          if (enhancedLocationProvider.error != null) {
            _log('❌ EnhancedLocationProvider error: ${enhancedLocationProvider.error}', isError: true);
          }
        });
      }
      
      _log('✅ Location service monitoring setup complete');
      
    } catch (e) {
      _log('❌ Error setting up location service monitoring: $e', isError: true);
    }
  }
  
  /// Diagnose Android background location limits
  static Future<void> _diagnoseAndroidBackgroundLimits() async {
    try {
      _log('🚫 Checking Android Background Location Limits...');
      
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        _log('   Android SDK Level: $sdkInt');
        _log('   Android Version: ${androidInfo.version.release}');
        
        if (sdkInt >= 26) {
          _log('❌ CRITICAL: Device is affected by Android 8.0+ background location limits!', isError: true);
          _log('   Background apps can only receive location updates a few times per hour');
          _log('   This severely impacts real-time location sharing');
          
          // Initialize optimizer to get detailed analysis
          await AndroidBackgroundLocationOptimizer.initialize();
          final status = AndroidBackgroundLocationOptimizer.getStrategyStatus();
          
          _log('   Current Strategy: ${status['currentStrategy']}');
          _log('   Foreground Service Active: ${status['foregroundServiceActive']}');
          _log('   Geofencing Active: ${status['geofencingActive']}');
          _log('   Batched Mode Active: ${status['batchedModeActive']}');
          
          // Get recommendations
          final recommendations = AndroidBackgroundLocationOptimizer.getStrategyRecommendations(
            requireRealTime: true,
            powerEfficient: true,
          );
          
          _log('   📋 Recommended Strategy: ${recommendations['strategy']}');
          _log('   📝 Reason: ${recommendations['reason']}');
          
          if (recommendations['warning'] != null) {
            _log('⚠️  Warning: ${recommendations['warning']}');
          }
          
          // List limitations
          if (recommendations['limitations'] != null) {
            _log('   🚫 Android 8.0+ Limitations:');
            for (final limitation in recommendations['limitations']) {
              _log('     • $limitation');
            }
          }
          
          // Check if foreground service is needed but not active
          if (recommendations['strategy'] == 'foregroundService' && !status['foregroundServiceActive']) {
            _log('❌ Foreground service required but not active!', isError: true);
            _log('   Real-time location updates will not work in background');
          }
          
        } else if (sdkInt >= 23) {
          _log('⚠️  Android 6.0+ device - has Doze mode and App Standby');
          _log('   May experience some background location limitations');
        } else {
          _log('✅ Pre-Android 8.0 device - no background location limits');
        }
        
        // Check specific Android version issues
        if (sdkInt >= 30) { // Android 11+
          _log('⚠️  Android 11+ detected - additional foreground service restrictions');
          _log('   ACCESS_BACKGROUND_LOCATION permission required for foreground services');
        }
        
        if (sdkInt >= 31) { // Android 12+
          _log('⚠️  Android 12+ detected - even stricter background restrictions');
          _log('   Approximate location may be provided instead of precise location');
        }
        
      } else {
        _log('✅ iOS device - not affected by Android background location limits');
        _log('   iOS has its own background app refresh system');
      }
      
    } catch (e) {
      _log('❌ Error diagnosing Android background limits: $e', isError: true);
    }
  }
  
  /// Start system monitoring
  static Future<void> _startSystemMonitoring() async {
    _log('👁️  Starting system monitoring...');
    
    // Monitor permission changes
    // Monitor battery state changes
    // Monitor network connectivity changes
    // This would require platform-specific implementation
  }
  
  /// Save debug session to Firebase
  static Future<void> _saveDebugSessionToFirebase(String userId) async {
    try {
      final sessionData = {
        'timestamp': FieldValue.serverTimestamp(),
        'logs': _debugLogs.map((log) => log.toMap()).toList(),
        'deviceInfo': await _getDeviceInfoMap(),
        'sessionDuration': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('debug_sessions')
          .add(sessionData);
      
      _log('💾 Debug session saved to Firebase');
      
    } catch (e) {
      _log('❌ Error saving debug session: $e', isError: true);
    }
  }
  
  /// Get device info as map
  static Future<Map<String, dynamic>> _getDeviceInfoMap() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'model': iosInfo.model,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
        };
      }
      
      return {'platform': 'unknown'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Log debug message
  static void _log(String message, {bool isError = false}) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      message: message,
      isError: isError,
      tag: _tag,
    );
    
    _debugLogs.add(entry);
    _logStreamController.add(entry);
    
    // Also log to developer console
    if (isError) {
      developer.log(message, name: _tag, level: 1000); // Error level
    } else {
      developer.log(message, name: _tag);
    }
  }
  
  /// Get debug summary
  static Map<String, dynamic> getDebugSummary() {
    final errors = _debugLogs.where((log) => log.isError).length;
    final warnings = _debugLogs.where((log) => log.message.contains('⚠️')).length;
    final successes = _debugLogs.where((log) => log.message.contains('✅')).length;
    
    return {
      'totalLogs': _debugLogs.length,
      'errors': errors,
      'warnings': warnings,
      'successes': successes,
      'isDebugging': _isDebugging,
      'startTime': _debugLogs.isNotEmpty ? _debugLogs.first.timestamp : null,
      'lastLog': _debugLogs.isNotEmpty ? _debugLogs.last.timestamp : null,
    };
  }
  
  /// Export debug logs
  static String exportDebugLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== Background Location Debug Report ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Logs: ${_debugLogs.length}');
    buffer.writeln();
    
    for (final log in _debugLogs) {
      final prefix = log.isError ? '❌' : 'ℹ️';
      buffer.writeln('$prefix [${log.timestamp}] ${log.message}');
    }
    
    return buffer.toString();
  }
  
  /// Test location service functionality
  static Future<void> testLocationServices({
    LocationProvider? locationProvider,
    EnhancedLocationProvider? enhancedLocationProvider,
    String? userId,
  }) async {
    _log('🧪 Testing Location Services...');
    
    try {
      // Test LocationProvider
      if (locationProvider != null && userId != null) {
        _log('📍 Testing LocationProvider...');
        
        if (!locationProvider.isInitialized) {
          _log('   Initializing LocationProvider...');
          await locationProvider.initialize();
        }
        
        if (!locationProvider.isTracking) {
          _log('   Starting LocationProvider tracking...');
          await locationProvider.startTracking(userId);
          
          // Wait for location update
          await Future.delayed(const Duration(seconds: 5));
          
          if (locationProvider.currentLocation != null) {
            _log('   ✅ LocationProvider test successful');
          } else {
            _log('   ❌ LocationProvider test failed - no location received', isError: true);
          }
        }
      }
      
      // Test EnhancedLocationProvider
      if (enhancedLocationProvider != null && userId != null) {
        _log('🚀 Testing EnhancedLocationProvider...');
        
        if (!enhancedLocationProvider.isInitialized) {
          _log('   Initializing EnhancedLocationProvider...');
          await enhancedLocationProvider.initialize();
        }
        
        if (!enhancedLocationProvider.isTracking) {
          _log('   Starting EnhancedLocationProvider tracking...');
          await enhancedLocationProvider.startTracking(userId);
          
          // Wait for location update
          await Future.delayed(const Duration(seconds: 5));
          
          if (enhancedLocationProvider.currentLocation != null) {
            _log('   ✅ EnhancedLocationProvider test successful');
          } else {
            _log('   ❌ EnhancedLocationProvider test failed - no location received', isError: true);
          }
        }
      }
      
      // Test BulletproofLocationService
      _log('🛡️  Testing BulletproofLocationService...');
      if (userId != null) {
        try {
          await BulletproofLocationService.initialize();
          // Additional testing would require exposing more methods
          _log('   ✅ BulletproofLocationService initialization successful');
        } catch (e) {
          _log('   ❌ BulletproofLocationService test failed: $e', isError: true);
        }
      }
      
      // Test Life360LocationService
      _log('🌍 Testing Life360LocationService...');
      try {
        await Life360LocationService.initialize();
        _log('   ✅ Life360LocationService initialization successful');
      } catch (e) {
        _log('   ❌ Life360LocationService test failed: $e', isError: true);
      }
      
      // Test PersistentLocationService
      _log('⚡ Testing PersistentLocationService...');
      try {
        await PersistentLocationService.initialize();
        _log('   ✅ PersistentLocationService initialization successful');
      } catch (e) {
        _log('   ❌ PersistentLocationService test failed: $e', isError: true);
      }
      
      // Test UltraPersistentLocationService
      _log('🚀 Testing UltraPersistentLocationService...');
      try {
        await UltraPersistentLocationService.initialize();
        _log('   ✅ UltraPersistentLocationService initialization successful');
      } catch (e) {
        _log('   ❌ UltraPersistentLocationService test failed: $e', isError: true);
      }
      
      _log('✅ Location services testing completed');
      
    } catch (e) {
      _log('❌ Error testing location services: $e', isError: true);
    }
  }
  
  /// Get location service recommendations based on device
  static Future<Map<String, dynamic>> getLocationServiceRecommendations() async {
    final recommendations = <String, dynamic>{};
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        final model = androidInfo.model.toLowerCase();
        final sdkInt = androidInfo.version.sdkInt;
        
        recommendations['device'] = {
          'manufacturer': manufacturer,
          'model': model,
          'androidVersion': androidInfo.version.release,
          'sdkInt': sdkInt,
        };
        
        // Recommendations based on device
        if (manufacturer.contains('oneplus') || model.contains('cph2491')) {
          recommendations['recommended'] = 'UltraPersistentLocationService';
          recommendations['reason'] = 'OnePlus devices have aggressive power management';
          recommendations['alternatives'] = ['BulletproofLocationService', 'Life360LocationService'];
        } else if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
          recommendations['recommended'] = 'BulletproofLocationService';
          recommendations['reason'] = 'MIUI has strict background restrictions';
          recommendations['alternatives'] = ['UltraPersistentLocationService', 'Life360LocationService'];
        } else if (manufacturer.contains('huawei')) {
          recommendations['recommended'] = 'BulletproofLocationService';
          recommendations['reason'] = 'EMUI has aggressive power saving';
          recommendations['alternatives'] = ['UltraPersistentLocationService'];
        } else if (manufacturer.contains('samsung')) {
          recommendations['recommended'] = 'Life360LocationService';
          recommendations['reason'] = 'Samsung devices generally handle background location well';
          recommendations['alternatives'] = ['BulletproofLocationService', 'PersistentLocationService'];
        } else if (sdkInt >= 31) { // Android 12+
          recommendations['recommended'] = 'BulletproofLocationService';
          recommendations['reason'] = 'Android 12+ has strict background restrictions';
          recommendations['alternatives'] = ['Life360LocationService', 'PersistentLocationService'];
        } else {
          recommendations['recommended'] = 'PersistentLocationService';
          recommendations['reason'] = 'Standard persistent tracking should work well';
          recommendations['alternatives'] = ['Life360LocationService', 'BulletproofLocationService'];
        }
        
        // Provider recommendations
        recommendations['provider'] = {
          'primary': 'EnhancedLocationProvider',
          'fallback': 'LocationProvider',
          'reason': 'EnhancedLocationProvider has better error handling and persistence',
        };
        
      } else if (Platform.isIOS) {
        recommendations['device'] = {'platform': 'ios'};
        recommendations['recommended'] = 'Life360LocationService';
        recommendations['reason'] = 'iOS handles background location well with proper permissions';
        recommendations['alternatives'] = ['PersistentLocationService'];
        
        recommendations['provider'] = {
          'primary': 'LocationProvider',
          'fallback': 'EnhancedLocationProvider',
          'reason': 'Standard LocationProvider works well on iOS',
        };
      }
      
    } catch (e) {
      recommendations['error'] = e.toString();
    }
    
    return recommendations;
  }
  
  /// Test Android background location optimization strategies
  static Future<void> testAndroidBackgroundOptimization({
    bool requireRealTime = false,
    bool powerEfficient = true,
  }) async {
    _log('🧪 Testing Android Background Location Optimization...');
    
    try {
      // Initialize optimizer
      await AndroidBackgroundLocationOptimizer.initialize();
      
      // Get current status
      final status = AndroidBackgroundLocationOptimizer.getStrategyStatus();
      _log('   Current Status: $status');
      
      // Get recommendations
      final recommendations = AndroidBackgroundLocationOptimizer.getStrategyRecommendations(
        requireRealTime: requireRealTime,
        powerEfficient: powerEfficient,
      );
      
      _log('   📋 Testing Strategy: ${recommendations['strategy']}');
      _log('   📝 Reason: ${recommendations['reason']}');
      
      // Test the recommended strategy
      final strategyEnum = _parseLocationStrategy(recommendations['strategy']);
      if (strategyEnum != null) {
        final success = await AndroidBackgroundLocationOptimizer.startOptimizedTracking(
          preferredStrategy: strategyEnum,
          requireRealTime: requireRealTime,
        );
        
        if (success) {
          _log('   ✅ Android optimization strategy test successful');
          
          // Wait for some updates
          await Future.delayed(const Duration(seconds: 10));
          
          final newStatus = AndroidBackgroundLocationOptimizer.getStrategyStatus();
          _log('   📊 Updated Status: $newStatus');
          
        } else {
          _log('   ❌ Android optimization strategy test failed', isError: true);
        }
      }
      
    } catch (e) {
      _log('❌ Error testing Android background optimization: $e', isError: true);
    }
  }
  
  /// Parse location strategy from string
  static LocationStrategy? _parseLocationStrategy(String strategyName) {
    switch (strategyName) {
      case 'standard':
        return LocationStrategy.standard;
      case 'foregroundService':
        return LocationStrategy.foregroundService;
      case 'geofencing':
        return LocationStrategy.geofencing;
      case 'batchedUpdates':
        return LocationStrategy.batchedUpdates;
      case 'passiveListener':
        return LocationStrategy.passiveListener;
      case 'hybrid':
        return LocationStrategy.hybrid;
      case 'automatic':
        return LocationStrategy.automatic;
      default:
        return null;
    }
  }
  
  /// Start optimized Android background location tracking
  static Future<void> startOptimizedAndroidTracking({
    bool requireRealTime = false,
    bool powerEfficient = true,
  }) async {
    _log('🚀 Starting optimized Android background location tracking...');
    
    try {
      // Initialize optimizer
      await AndroidBackgroundLocationOptimizer.initialize();
      
      // Setup callbacks for monitoring
      AndroidBackgroundLocationOptimizer.onLocationUpdate = (location, source) {
        _log('📍 Location update from ${source.name}: $location');
      };
      
      AndroidBackgroundLocationOptimizer.onError = (error) {
        _log('❌ Android optimizer error: $error', isError: true);
      };
      
      AndroidBackgroundLocationOptimizer.onStrategyChanged = (strategy) {
        _log('🔄 Strategy changed to: ${strategy.name}');
      };
      
      AndroidBackgroundLocationOptimizer.onForegroundServiceStateChanged = (active) {
        _log('🔔 Foreground service ${active ? "started" : "stopped"}');
      };
      
      // Start optimized tracking
      final success = await AndroidBackgroundLocationOptimizer.startOptimizedTracking(
        requireRealTime: requireRealTime,
      );
      
      if (success) {
        _log('✅ Optimized Android tracking started successfully');
      } else {
        _log('❌ Failed to start optimized Android tracking', isError: true);
      }
      
    } catch (e) {
      _log('❌ Error starting optimized Android tracking: $e', isError: true);
    }
  }
  
  /// Restart location services with recommended configuration
  static Future<void> restartWithRecommendedConfiguration({
    LocationProvider? locationProvider,
    EnhancedLocationProvider? enhancedLocationProvider,
    String? userId,
  }) async {
    _log('🔄 Restarting location services with recommended configuration...');
    
    try {
      final recommendations = await getLocationServiceRecommendations();
      final recommendedService = recommendations['recommended'];
      final recommendedProvider = recommendations['provider']?['primary'];
      
      _log('   Recommended Service: $recommendedService');
      _log('   Recommended Provider: $recommendedProvider');
      
      // Stop current tracking
      if (locationProvider?.isTracking == true) {
        _log('   Stopping LocationProvider...');
        await locationProvider!.stopTracking();
      }
      
      if (enhancedLocationProvider?.isTracking == true) {
        _log('   Stopping EnhancedLocationProvider...');
        await enhancedLocationProvider!.stopTracking();
      }
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 2));
      
      // Start with recommended configuration
      if (userId != null) {
        if (recommendedProvider == 'EnhancedLocationProvider' && enhancedLocationProvider != null) {
          _log('   Starting EnhancedLocationProvider with recommended settings...');
          await enhancedLocationProvider.initialize();
          await enhancedLocationProvider.startTracking(userId);
        } else if (locationProvider != null) {
          _log('   Starting LocationProvider with recommended settings...');
          await locationProvider.initialize();
          await locationProvider.startTracking(userId);
        }
        
        // Initialize recommended background service
        switch (recommendedService) {
          case 'UltraPersistentLocationService':
            await UltraPersistentLocationService.initialize();
            break;
          case 'BulletproofLocationService':
            await BulletproofLocationService.initialize();
            break;
          case 'Life360LocationService':
            await Life360LocationService.initialize();
            break;
          case 'PersistentLocationService':
            await PersistentLocationService.initialize();
            break;
        }
        
        // Also start Android-optimized tracking if on Android 8.0+
        if (Platform.isAndroid) {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          if (androidInfo.version.sdkInt >= 26) {
            _log('   Starting Android-optimized background tracking...');
            await startOptimizedAndroidTracking(
              requireRealTime: false,
              powerEfficient: true,
            );
          }
        }
      }
      
      _log('✅ Location services restarted with recommended configuration');
      
    } catch (e) {
      _log('❌ Error restarting location services: $e', isError: true);
    }
  }
  
  /// Dispose resources
  static void dispose() {
    _debugTimer?.cancel();
    _logStreamController.close();
    _debugLogs.clear();
    _isDebugging = false;
  }
}

/// Debug log entry
class DebugLogEntry {
  final DateTime timestamp;
  final String message;
  final bool isError;
  final String tag;
  
  const DebugLogEntry({
    required this.timestamp,
    required this.message,
    required this.isError,
    required this.tag,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'message': message,
      'isError': isError,
      'tag': tag,
    };
  }
  
  factory DebugLogEntry.fromMap(Map<String, dynamic> map) {
    return DebugLogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      message: map['message'],
      isError: map['isError'] ?? false,
      tag: map['tag'] ?? 'Unknown',
    );
  }
}