// Debug script to test Google Sign-In
// Run this with: dart run debug_signin.dart

import 'dart:io';

void main() {
  print('🔍 Google Sign-In Debug Information');
  print('=====================================');
  
  // Check if google-services.json exists
  final googleServicesFile = File('android/app/google-services.json');
  if (googleServicesFile.existsSync()) {
    print('✅ google-services.json found');
    
    // Read and parse the file
    final content = googleServicesFile.readAsStringSync();
    
    // Extract key information
    if (content.contains('"project_id": "group-sharing-9d119"')) {
      print('✅ Project ID matches: group-sharing-9d119');
    } else {
      print('❌ Project ID mismatch or not found');
    }
    
    if (content.contains('"package_name": "com.sundeep.groupsharing"')) {
      print('✅ Package name matches: com.sundeep.groupsharing');
    } else {
      print('❌ Package name mismatch or not found');
    }
    
    if (content.contains('9b909399776b71e517d0e8d6e82d7857e4f9df91')) {
      print('✅ Debug SHA-1 certificate found in config');
    } else {
      print('❌ Debug SHA-1 certificate NOT found in config');
      print('   Expected: 9b909399776b71e517d0e8d6e82d7857e4f9df91');
    }
    
  } else {
    print('❌ google-services.json NOT found');
  }
  
  print('');
  print('📋 Next Steps:');
  print('1. Follow the Firebase console checklist in firebase_setup_checklist.md');
  print('2. Ensure SHA-1 is added to Firebase console');
  print('3. Download updated google-services.json if needed');
  print('4. Run: flutter clean && flutter pub get');
  print('5. Build debug APK: flutter build apk --debug');
  print('6. Test Google Sign-In');
}