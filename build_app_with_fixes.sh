#!/bin/bash

# Build App with Background Location Fixes
# This script builds the app with all the implemented fixes

echo "🚀 Building GroupSharing App with Background Location Fixes"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the Flutter project root."
    exit 1
fi

print_status "Starting build process..."

# Step 1: Clean previous builds
print_status "Step 1: Cleaning previous builds..."
flutter clean
if [ $? -eq 0 ]; then
    print_success "Clean completed"
else
    print_error "Clean failed"
    exit 1
fi

# Step 2: Get dependencies
print_status "Step 2: Getting dependencies..."
flutter pub get
if [ $? -eq 0 ]; then
    print_success "Dependencies downloaded"
else
    print_error "Failed to get dependencies"
    exit 1
fi

# Step 3: Check for any analysis issues
print_status "Step 3: Running Flutter analyze..."
flutter analyze --no-fatal-infos
if [ $? -eq 0 ]; then
    print_success "Analysis passed"
else
    print_warning "Analysis found issues, but continuing build..."
fi

# Step 4: Build APK (Debug)
print_status "Step 4: Building debug APK..."
flutter build apk --debug
if [ $? -eq 0 ]; then
    print_success "Debug APK built successfully"
    DEBUG_APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
    print_status "Debug APK location: $DEBUG_APK_PATH"
else
    print_error "Debug APK build failed"
    exit 1
fi

# Step 5: Build APK (Release)
print_status "Step 5: Building release APK..."
flutter build apk --release
if [ $? -eq 0 ]; then
    print_success "Release APK built successfully"
    RELEASE_APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    print_status "Release APK location: $RELEASE_APK_PATH"
else
    print_error "Release APK build failed"
    exit 1
fi

# Step 6: Check APK sizes
print_status "Step 6: Checking APK sizes..."
if [ -f "$DEBUG_APK_PATH" ]; then
    DEBUG_SIZE=$(du -h "$DEBUG_APK_PATH" | cut -f1)
    print_status "Debug APK size: $DEBUG_SIZE"
fi

if [ -f "$RELEASE_APK_PATH" ]; then
    RELEASE_SIZE=$(du -h "$RELEASE_APK_PATH" | cut -f1)
    print_status "Release APK size: $RELEASE_SIZE"
fi

# Step 7: Check if device is connected
print_status "Step 7: Checking for connected devices..."
DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
if [ $DEVICES -gt 0 ]; then
    print_success "$DEVICES device(s) connected"
    
    # Ask if user wants to install
    echo ""
    read -p "Do you want to install the debug APK on connected device? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installing debug APK..."
        adb install -r "$DEBUG_APK_PATH"
        if [ $? -eq 0 ]; then
            print_success "APK installed successfully"
        else
            print_error "APK installation failed"
        fi
    fi
else
    print_warning "No devices connected. Connect a device to install the APK."
fi

# Step 8: Summary
echo ""
echo "🎉 BUILD SUMMARY"
echo "================"
print_success "Build completed successfully!"
echo ""
echo "📱 APK Files:"
echo "  Debug APK:   $DEBUG_APK_PATH ($DEBUG_SIZE)"
echo "  Release APK: $RELEASE_APK_PATH ($RELEASE_SIZE)"
echo ""
echo "🔧 Fixes Included:"
echo "  ✅ Native background service logic fix"
echo "  ✅ Enhanced Firebase authentication"
echo "  ✅ Improved error handling and logging"
echo "  ✅ Readable timestamps in Firebase"
echo "  ✅ Manual location update functionality"
echo "  ✅ Better notification handling"
echo ""
echo "📋 Next Steps:"
echo "  1. Deploy Firebase Database Rules (see instructions below)"
echo "  2. Install APK on test devices"
echo "  3. Test with multiple user accounts"
echo "  4. Verify 'Update Now' button works for all users"
echo ""
echo "🔥 Firebase Rules Deployment:"
echo "  1. Go to: https://console.firebase.google.com/"
echo "  2. Select your project: group-sharing-9d119"
echo "  3. Navigate to: Realtime Database → Rules"
echo "  4. Copy rules from: database.rules.json"
echo "  5. Click 'Publish'"
echo ""
echo "🧪 Testing Instructions:"
echo "  1. Login with different user accounts"
echo "  2. Enable location sharing for each user"
echo "  3. Close app completely (swipe from recent apps)"
echo "  4. Check notification panel for 'Location Sharing Active'"
echo "  5. Tap 'Update Now' button in notification"
echo "  6. Verify Firebase updates with current timestamp"
echo ""
print_success "Build process completed! 🚀"