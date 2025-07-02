#!/bin/bash

echo "=== Universal Location Integration Deployment ==="
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

echo "✅ Flutter found"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Analyze code
echo "🔍 Analyzing code..."
flutter analyze

# Check for any critical issues
if [ $? -ne 0 ]; then
    echo "⚠️  Code analysis found issues, but continuing..."
fi

# Build APK for testing
echo "🔨 Building APK..."
flutter build apk --debug

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"

# Check if device is connected
echo "📱 Checking for connected devices..."
adb devices

# Install APK if device is connected
if adb devices | grep -q "device$"; then
    echo "📲 Installing APK on connected device..."
    flutter install
    
    if [ $? -eq 0 ]; then
        echo "✅ APK installed successfully"
        echo ""
        echo "🎉 Universal Location Integration deployed!"
        echo ""
        echo "Next steps:"
        echo "1. Open the app on your device"
        echo "2. Login with ANY user account (not just test users)"
        echo "3. Go to Friends & Family screen"
        echo "4. Enable location sharing"
        echo "5. Check notification panel for 'Location Sharing Active'"
        echo "6. Tap 'Update Now' button to test"
        echo "7. Close app and verify notification persists"
        echo ""
        echo "To run the test script:"
        echo "dart test_universal_location_integration.dart"
        echo ""
        echo "To check logs:"
        echo "adb logcat | grep UniversalLocationIntegration"
    else
        echo "❌ APK installation failed"
        exit 1
    fi
else
    echo "⚠️  No device connected"
    echo "APK built successfully at: build/app/outputs/flutter-apk/app-debug.apk"
    echo ""
    echo "To install manually:"
    echo "1. Connect your device"
    echo "2. Run: flutter install"
    echo "   or"
    echo "3. Run: adb install build/app/outputs/flutter-apk/app-debug.apk"
fi

echo ""
echo "=== Deployment Complete ==="