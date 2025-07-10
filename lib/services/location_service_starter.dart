import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Location Service Starter
/// Provides the exact startLocationService method pattern you requested
class LocationServiceStarter {
  static const MethodChannel _platform = MethodChannel('background_location');
  
  /// Start location service with the exact pattern you requested
  /// 
  /// This method:
  /// 1. Sets location_sharing_enabled to true in SharedPreferences
  /// 2. Calls the native startLocationService method
  /// 3. Automatically checks and requests battery optimization disable
  /// 
  /// Usage:
  /// ```dart
  /// await LocationServiceStarter.startLocationService(userId: 'user123');
  /// ```
  static Future<void> startLocationService({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_enabled', true);
    
    // Start the service
    try {
      await _platform.invokeMethod('startLocationService', {
        'userId': userId,
      });
      print('✅ Location service started successfully for user: $userId');
      print('✅ Battery optimization check included automatically');
    } catch (e) {
      print('❌ Error starting location service: $e');
      rethrow;
    }
  }
  
  /// Stop location service
  static Future<void> stopLocationService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_enabled', false);
    
    try {
      await _platform.invokeMethod('stop');
      print('✅ Location service stopped successfully');
    } catch (e) {
      print('❌ Error stopping location service: $e');
      rethrow;
    }
  }
  
  /// Check if location sharing is enabled
  static Future<bool> isLocationSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_sharing_enabled') ?? false;
  }
  
  /// Trigger manual location update
  static Future<void> updateLocationNow() async {
    try {
      await _platform.invokeMethod('updateNow');
      print('✅ Manual location update triggered');
    } catch (e) {
      print('❌ Error triggering location update: $e');
      rethrow;
    }
  }
}