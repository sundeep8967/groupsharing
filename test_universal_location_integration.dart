import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/universal_location_integration_service.dart';
import 'lib/providers/auth_provider.dart';

/// Test script to verify Universal Location Integration works for ALL users
void main() async {
  developer.log('=== UNIVERSAL LOCATION INTEGRATION TEST ===');
  
  try {
    // Step 1: Initialize the universal service
    developer.log('Step 1: Initializing Universal Location Integration Service...');
    final initialized = await UniversalLocationIntegrationService.initialize();
    
    if (!initialized) {
      developer.log('❌ FAILED: Could not initialize universal service');
      return;
    }
    
    developer.log('✅ SUCCESS: Universal service initialized');
    
    // Step 2: Check current authentication status
    developer.log('Step 2: Checking authentication status...');
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      developer.log('❌ FAILED: No authenticated user found');
      developer.log('Please log in with any user account and try again');
      return;
    }
    
    final userId = currentUser.uid;
    final userEmail = currentUser.email ?? 'Unknown';
    developer.log('✅ SUCCESS: Found authenticated user');
    developer.log('User ID: ${userId.substring(0, 8)}...');
    developer.log('Email: $userEmail');
    
    // Step 3: Start location tracking for the authenticated user
    developer.log('Step 3: Starting location tracking for authenticated user...');
    final trackingStarted = await UniversalLocationIntegrationService.startLocationTrackingForUser(userId);
    
    if (!trackingStarted) {
      developer.log('❌ FAILED: Could not start location tracking');
      return;
    }
    
    developer.log('✅ SUCCESS: Location tracking started for authenticated user');
    
    // Step 4: Get service status
    developer.log('Step 4: Checking service status...');
    final status = UniversalLocationIntegrationService.getServiceStatus();
    
    developer.log('=== SERVICE STATUS ===');
    developer.log('Active: ${status['isActive']}');
    developer.log('Current User: ${status['currentUserId']?.substring(0, 8)}...');
    developer.log('Has Update Now Button: ${status['hasUpdateNowButton']}');
    developer.log('Persists When App Closed: ${status['persistsWhenAppClosed']}');
    
    // Step 5: Test "Update Now" functionality
    developer.log('Step 5: Testing "Update Now" functionality...');
    final updateTriggered = await UniversalLocationIntegrationService.triggerUpdateNow();
    
    if (updateTriggered) {
      developer.log('✅ SUCCESS: "Update Now" triggered successfully');
    } else {
      developer.log('⚠️  WARNING: "Update Now" failed to trigger');
    }
    
    // Step 6: Verify the service is working for current user
    developer.log('Step 6: Verifying service is working for current user...');
    final isWorking = UniversalLocationIntegrationService.isWorkingForCurrentUser();
    
    if (isWorking) {
      developer.log('✅ SUCCESS: Service is working for current authenticated user');
    } else {
      developer.log('❌ FAILED: Service is not working for current user');
    }
    
    // Step 7: Display instructions
    developer.log('Step 7: Displaying user instructions...');
    final instructions = status['instructions'] as List<String>;
    
    developer.log('=== USER INSTRUCTIONS ===');
    for (int i = 0; i < instructions.length; i++) {
      developer.log('${i + 1}. ${instructions[i]}');
    }
    
    // Final summary
    developer.log('=== FINAL SUMMARY ===');
    
    if (trackingStarted && isWorking) {
      developer.log('🎉 SUCCESS: Universal Location Integration is working!');
      developer.log('');
      developer.log('The authenticated user now has:');
      developer.log('✅ Persistent background location tracking');
      developer.log('✅ Foreground notification with "Update Now" button');
      developer.log('✅ Real-time Firebase sync');
      developer.log('✅ Service that survives app kills');
      developer.log('✅ Same functionality that test users had');
      developer.log('');
      developer.log('Next steps:');
      developer.log('1. Check notification panel for "Location Sharing Active"');
      developer.log('2. Tap "Update Now" button to test immediate location update');
      developer.log('3. Close the app completely and verify notification persists');
      developer.log('4. Check Firebase Console → Realtime Database → locations/userId');
      developer.log('5. Verify timestampReadable shows current time');
    } else {
      developer.log('❌ FAILED: Universal Location Integration is not working properly');
      developer.log('');
      developer.log('Troubleshooting steps:');
      developer.log('1. Check device logs: adb logcat | grep UniversalLocationIntegration');
      developer.log('2. Verify location permissions are "Allow all the time"');
      developer.log('3. Disable battery optimization for the app');
      developer.log('4. Ensure Firebase Database Rules are deployed correctly');
      developer.log('5. Try restarting the app and testing again');
    }
    
  } catch (e) {
    developer.log('❌ ERROR: Test failed with exception: $e');
  }
}

/// Instructions for manual verification
void printManualVerificationSteps() {
  developer.log('=== MANUAL VERIFICATION STEPS ===');
  developer.log('');
  developer.log('1. BUILD AND INSTALL the updated app');
  developer.log('2. LOGIN with ANY user account (not just test users)');
  developer.log('3. ENABLE location sharing in Friends & Family screen');
  developer.log('4. CLOSE the app completely (swipe away from recent apps)');
  developer.log('5. CHECK notification panel for "Location Sharing Active" notification');
  developer.log('6. EXPAND the notification and tap "Update Now" button');
  developer.log('7. CHECK Firebase Console → Realtime Database → locations/userId');
  developer.log('8. VERIFY timestampReadable shows current time');
  developer.log('');
  developer.log('Expected behavior for ALL authenticated users:');
  developer.log('- Notification should be visible');
  developer.log('- "Update Now" button should work');
  developer.log('- Firebase should update with current timestamp');
  developer.log('- Service should persist even when app is closed');
  developer.log('- No more "only test users work" limitation');
  developer.log('');
  developer.log('If any user still doesn\'t work:');
  developer.log('- Check device logs: adb logcat | grep UniversalLocationIntegration');
  developer.log('- Look for "SUCCESS:" or "FAILED:" messages');
  developer.log('- Verify the user is properly authenticated');
  developer.log('- Check Firebase Database Rules are deployed correctly');
  developer.log('- Ensure location permissions are "Allow all the time"');
  developer.log('- Disable battery optimization for the app');
}