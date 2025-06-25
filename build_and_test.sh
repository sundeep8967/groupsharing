#!/bin/bash

echo "🚀 Building and Testing Google Sign-In Debug APK"
echo "================================================"

# Step 1: Clean project
echo "🧹 Cleaning project..."
flutter clean

# Step 2: Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Step 3: Check for dependency conflicts
echo "🔍 Checking dependencies..."
flutter pub deps

# Step 4: Build debug APK
echo "🔨 Building debug APK..."
flutter build apk --debug

# Step 5: Check if APK was built successfully
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo "✅ Debug APK built successfully!"
    echo "📍 Location: build/app/outputs/flutter-apk/app-debug.apk"
    
    # Get APK size
    APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-debug.apk | cut -f1)
    echo "📏 APK Size: $APK_SIZE"
    
    echo ""
    echo "🧪 Testing Instructions:"
    echo "1. Install the APK on your device"
    echo "2. Open the app and try Google Sign-In"
    echo "3. Check the logs using: adb logcat | grep -E '\\[AUTH\\]|Flutter'"
    echo "4. Look for the detailed authentication flow logs"
    echo ""
    echo "🔧 If sign-in still fails:"
    echo "1. Check Firebase Console (see firebase_setup_checklist.md)"
    echo "2. Ensure SHA-1 certificate is added: 9B:90:93:99:77:6B:71:E5:17:D0:E8:D6:E8:2D:78:57:E4:F9:DF:91"
    echo "3. Wait 5-10 minutes after adding SHA-1 for changes to propagate"
    
else
    echo "❌ Failed to build debug APK"
    echo "Check the build output above for errors"
    exit 1
fi