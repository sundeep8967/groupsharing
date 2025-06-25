// Final verification script for Google Sign-In setup
// Run this with: dart run final_verification.dart

import 'dart:io';

void main() {
  print('🔍 Final Google Sign-In Setup Verification');
  print('==========================================');
  
  // Check APK exists
  final apkFile = File('build/app/outputs/flutter-apk/app-debug.apk');
  if (apkFile.existsSync()) {
    final apkSize = (apkFile.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
    print('✅ Debug APK built successfully');
    print('   📍 Location: build/app/outputs/flutter-apk/app-debug.apk');
    print('   📏 Size: ${apkSize}MB');
  } else {
    print('❌ Debug APK not found');
    print('   Run: flutter build apk --debug');
  }
  
  // Check google-services.json
  final googleServicesFile = File('android/app/google-services.json');
  if (googleServicesFile.existsSync()) {
    print('✅ google-services.json found');
    
    final content = googleServicesFile.readAsStringSync();
    if (content.contains('9b909399776b71e517d0e8d6e82d7857e4f9df91')) {
      print('✅ Debug SHA-1 certificate found in config');
    } else {
      print('❌ Debug SHA-1 certificate NOT found in config');
    }
  } else {
    print('❌ google-services.json NOT found');
  }
  
  // Check pubspec.yaml dependencies
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final content = pubspecFile.readAsStringSync();
    
    print('✅ Dependency versions in pubspec.yaml:');
    
    // Extract versions
    final firebaseCoreMatch = RegExp(r'firebase_core:\s*\^?([0-9.]+)').firstMatch(content);
    final firebaseAuthMatch = RegExp(r'firebase_auth:\s*\^?([0-9.]+)').firstMatch(content);
    final googleSignInMatch = RegExp(r'google_sign_in:\s*\^?([0-9.]+)').firstMatch(content);
    
    if (firebaseCoreMatch != null) {
      print('   📦 firebase_core: ^${firebaseCoreMatch.group(1)}');
    }
    if (firebaseAuthMatch != null) {
      print('   📦 firebase_auth: ^${firebaseAuthMatch.group(1)}');
    }
    if (googleSignInMatch != null) {
      print('   📦 google_sign_in: ^${googleSignInMatch.group(1)}');
    }
    
    if (content.contains('dependency_overrides:')) {
      print('✅ Dependency overrides found');
      if (content.contains('firebase_auth_platform_interface:')) {
        print('   🔧 firebase_auth_platform_interface override active');
      }
    }
  }
  
  print('');
  print('🚀 Next Steps:');
  print('1. Install APK: adb install build/app/outputs/flutter-apk/app-debug.apk');
  print('2. Verify Firebase Console SHA-1 certificate');
  print('3. Test Google Sign-In');
  print('4. Monitor logs: adb logcat | grep -E "\\[AUTH\\]|Flutter"');
  print('');
  print('🔑 Critical Firebase Console Check:');
  print('   - Project: group-sharing-9d119');
  print('   - Package: com.sundeep.groupsharing');
  print('   - SHA-1: 9B:90:93:99:77:6B:71:E5:17:D0:E8:D6:E8:2D:78:57:E4:F9:DF:91');
  print('   - Google Sign-In: Enabled');
}