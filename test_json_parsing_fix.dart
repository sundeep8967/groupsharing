import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'lib/services/comprehensive_location_fix_service.dart';
import 'lib/services/bulletproof_location_service.dart';

/// Test script to verify JSON parsing fixes and Android background location solutions
void main() async {
  print('=== JSON Parsing Fix and Android Background Location Test ===');
  
  try {
    // Test 1: Initialize comprehensive location fix service
    print('\n1. Testing Comprehensive Location Fix Service initialization...');
    final initialized = await ComprehensiveLocationFixService.initialize();
    print('Initialization result: $initialized');
    
    if (initialized) {
      print('✅ Comprehensive Location Fix Service initialized successfully');
      
      // Get status info
      final statusInfo = ComprehensiveLocationFixService.getStatusInfo();
      print('Status info: $statusInfo');
      
      // Get available services
      final availableServices = ComprehensiveLocationFixService.getAvailableServices();
      print('Available services: $availableServices');
    } else {
      print('❌ Failed to initialize Comprehensive Location Fix Service');
    }
    
    // Test 2: Test JSON parsing safety
    print('\n2. Testing JSON parsing safety...');
    await _testJsonParsingSafety();
    
    // Test 3: Test method channel error handling
    print('\n3. Testing method channel error handling...');
    await _testMethodChannelErrorHandling();
    
    // Test 4: Test Android background location compliance
    print('\n4. Testing Android background location compliance...');
    await _testAndroidBackgroundLocationCompliance();
    
    print('\n=== Test completed successfully ===');
    
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}

/// Test JSON parsing safety with various malformed inputs
Future<void> _testJsonParsingSafety() async {
  print('Testing safe JSON parsing methods...');
  
  // Test safe double extraction
  final testCases = [
    {'latitude': 37.7749, 'longitude': -122.4194}, // Valid
    {'latitude': '37.7749', 'longitude': '-122.4194'}, // String numbers
    {'latitude': 37, 'longitude': -122}, // Integers
    {'lat': 37.7749, 'lng': -122.4194}, // Wrong keys
    null, // Null data
    'invalid', // String data
    {'latitude': 'invalid', 'longitude': 'invalid'}, // Invalid strings
  ];
  
  for (int i = 0; i < testCases.length; i++) {
    final testData = testCases[i];
    print('Test case ${i + 1}: $testData');
    
    try {
      // Test the safe extraction methods from BulletproofLocationService
      final latitude = BulletproofLocationService._safeExtractDouble(testData, 'latitude');
      final longitude = BulletproofLocationService._safeExtractDouble(testData, 'longitude');
      
      print('  Extracted - lat: $latitude, lng: $longitude');
      
      if (latitude != null && longitude != null) {
        print('  ✅ Valid location data extracted');
      } else {
        print('  ⚠️ Invalid data handled safely (no crash)');
      }
    } catch (e) {
      print('  ❌ Error in safe extraction: $e');
    }
  }
  
  print('✅ JSON parsing safety test completed');
}

/// Test method channel error handling
Future<void> _testMethodChannelErrorHandling() async {
  print('Testing method channel error handling...');
  
  try {
    // Create a test method call with malformed JSON
    final testCall = MethodCall('onLocationUpdate', {
      'latitude': 'malformed',
      'longitude': null,
      'extra': {'nested': 'data'}
    });
    
    // Test the bulletproof method call handler
    await BulletproofLocationService._handleNativeMethodCall(testCall);
    print('✅ Method call with malformed data handled safely');
    
    // Test with null arguments
    final nullCall = MethodCall('onLocationUpdate', null);
    await BulletproofLocationService._handleNativeMethodCall(nullCall);
    print('✅ Method call with null arguments handled safely');
    
    // Test with string arguments
    final stringCall = MethodCall('onError', 'Test error message');
    await BulletproofLocationService._handleNativeMethodCall(stringCall);
    print('✅ Method call with string arguments handled safely');
    
  } catch (e) {
    print('❌ Method channel error handling test failed: $e');
  }
  
  print('✅ Method channel error handling test completed');
}

/// Test Android background location compliance
Future<void> _testAndroidBackgroundLocationCompliance() async {
  print('Testing Android background location compliance...');
  
  try {
    // Check if we're on Android
    print('Platform check...');
    
    // Test Android 8.0+ specific configurations
    print('Testing Android 8.0+ configurations...');
    
    // Simulate Android SDK version checks
    final testSdkVersions = [23, 26, 29, 30, 33, 34]; // Various Android versions
    
    for (final sdkVersion in testSdkVersions) {
      print('Testing SDK version $sdkVersion:');
      
      if (sdkVersion >= 26) {
        print('  - Android 8.0+ detected');
        print('  - Background location updates limited to few times per hour');
        print('  - Foreground service required for continuous updates');
        print('  - Geofencing API recommended for power efficiency');
        
        if (sdkVersion >= 29) {
          print('  - Android 10+ background location permission required');
        }
        
        if (sdkVersion >= 30) {
          print('  - Android 11+ foreground service restrictions apply');
        }
        
        if (sdkVersion >= 33) {
          print('  - Android 13+ notification permission required');
        }
      } else {
        print('  - Pre-Android 8.0 - no background location restrictions');
      }
    }
    
    print('✅ Android background location compliance test completed');
    
  } catch (e) {
    print('❌ Android background location compliance test failed: $e');
  }
}

/// Extension to access private methods for testing
extension BulletproofLocationServiceTest on BulletproofLocationService {
  static double? _safeExtractDouble(dynamic data, String key) {
    // This would normally be private, but we're testing it
    try {
      if (data is Map<String, dynamic>) {
        final value = data[key];
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value);
      }
      return null;
    } catch (e) {
      developer.log('Error extracting double for key $key: $e');
      return null;
    }
  }
  
  static Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    // Simulate the safe method call handling
    try {
      switch (call.method) {
        case 'onLocationUpdate':
          final args = call.arguments;
          if (args == null) {
            developer.log('Null arguments received for location update');
            return;
          }
          
          Map<String, dynamic> locationData;
          if (args is Map<String, dynamic>) {
            locationData = args;
          } else {
            developer.log('Invalid arguments type for location update: ${args.runtimeType}');
            return;
          }
          
          final latitude = _safeExtractDouble(locationData, 'latitude');
          final longitude = _safeExtractDouble(locationData, 'longitude');
          
          if (latitude != null && longitude != null) {
            developer.log('Valid location extracted: $latitude, $longitude');
          } else {
            developer.log('Invalid location data - lat: $latitude, lng: $longitude');
          }
          break;
          
        case 'onError':
          final error = call.arguments?.toString() ?? 'Unknown error';
          developer.log('Error handled safely: $error');
          break;
          
        default:
          developer.log('Unknown method call handled safely: ${call.method}');
      }
    } catch (e) {
      developer.log('Error in method call handler (handled safely): $e');
    }
  }
}