#!/bin/bash

# Build Mobile Apps Script
# This script builds Android and iOS versions of the GroupSharing app

echo "📱 Building GroupSharing Mobile Apps"
echo "===================================="

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_success "Flutter is available"

# Function to check Flutter doctor
check_flutter_doctor() {
    print_status "Checking Flutter environment..."
    flutter doctor
    echo ""
}

# Function to clean and prepare project
prepare_project() {
    print_status "Preparing project..."
    
    # Clean previous builds
    flutter clean
    
    # Get dependencies
    flutter pub get
    
    # Run code generation if needed
    if [ -f "build_runner.yaml" ] || grep -q "build_runner" pubspec.yaml; then
        print_status "Running code generation..."
        flutter packages pub run build_runner build --delete-conflicting-outputs
    fi
    
    print_success "Project prepared"
}

# Function to analyze code
analyze_code() {
    print_status "Analyzing code..."
    flutter analyze
    
    if [ $? -eq 0 ]; then
        print_success "Code analysis passed"
    else
        print_warning "Code analysis found issues (continuing anyway)"
    fi
}

# Function to build Android APK
build_android_apk() {
    local build_mode=$1
    
    print_status "Building Android APK ($build_mode)..."
    
    if [ "$build_mode" = "debug" ]; then
        flutter build apk --debug
    elif [ "$build_mode" = "profile" ]; then
        flutter build apk --profile
    elif [ "$build_mode" = "release" ]; then
        flutter build apk --release
    else
        print_error "Invalid build mode: $build_mode"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        local apk_path="build/app/outputs/flutter-apk/app-$build_mode.apk"
        local apk_size=$(du -h "$apk_path" | cut -f1)
        print_success "Android APK built successfully"
        print_status "APK location: $apk_path"
        print_status "APK size: $apk_size"
    else
        print_error "Failed to build Android APK"
        return 1
    fi
}

# Function to build Android App Bundle
build_android_bundle() {
    local build_mode=$1
    
    print_status "Building Android App Bundle ($build_mode)..."
    
    if [ "$build_mode" = "profile" ]; then
        flutter build appbundle --profile
    elif [ "$build_mode" = "release" ]; then
        flutter build appbundle --release
    else
        print_warning "App Bundle only supports profile and release modes"
        return 0
    fi
    
    if [ $? -eq 0 ]; then
        local bundle_path="build/app/outputs/bundle/${build_mode}Release/app-$build_mode.aab"
        local bundle_size=$(du -h "$bundle_path" | cut -f1)
        print_success "Android App Bundle built successfully"
        print_status "Bundle location: $bundle_path"
        print_status "Bundle size: $bundle_size"
    else
        print_error "Failed to build Android App Bundle"
        return 1
    fi
}

# Function to build iOS app
build_ios() {
    local build_mode=$1
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS builds are only supported on macOS"
        return 0
    fi
    
    print_status "Building iOS app ($build_mode)..."
    
    if [ "$build_mode" = "debug" ]; then
        flutter build ios --debug --no-codesign
    elif [ "$build_mode" = "profile" ]; then
        flutter build ios --profile --no-codesign
    elif [ "$build_mode" = "release" ]; then
        flutter build ios --release --no-codesign
    else
        print_error "Invalid build mode: $build_mode"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        print_success "iOS app built successfully"
        print_status "iOS build location: build/ios/iphoneos/Runner.app"
    else
        print_error "Failed to build iOS app"
        return 1
    fi
}

# Function to build iOS IPA (for App Store)
build_ios_ipa() {
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS IPA builds are only supported on macOS"
        return 0
    fi
    
    print_status "Building iOS IPA for App Store..."
    
    flutter build ipa
    
    if [ $? -eq 0 ]; then
        local ipa_path="build/ios/ipa/GroupSharing.ipa"
        if [ -f "$ipa_path" ]; then
            local ipa_size=$(du -h "$ipa_path" | cut -f1)
            print_success "iOS IPA built successfully"
            print_status "IPA location: $ipa_path"
            print_status "IPA size: $ipa_size"
        else
            print_success "iOS IPA built (check build/ios/ipa/ directory)"
        fi
    else
        print_error "Failed to build iOS IPA"
        return 1
    fi
}

# Function to generate build report
generate_build_report() {
    local build_mode=$1
    local report_file="build_report_${build_mode}_$(date +%Y%m%d_%H%M%S).md"
    
    print_status "Generating build report..."
    
    cat > "$report_file" << EOF
# Build Report - $build_mode

**Date**: $(date)  
**Build Mode**: $build_mode  
**Flutter Version**: $(flutter --version | head -1)  
**Dart Version**: $(dart --version)  

## Build Artifacts

### Android
EOF

    # Add Android APK info
    local apk_path="build/app/outputs/flutter-apk/app-$build_mode.apk"
    if [ -f "$apk_path" ]; then
        local apk_size=$(du -h "$apk_path" | cut -f1)
        echo "- **APK**: \`$apk_path\` ($apk_size)" >> "$report_file"
    fi
    
    # Add Android Bundle info (for profile/release)
    if [ "$build_mode" = "profile" ] || [ "$build_mode" = "release" ]; then
        local bundle_path="build/app/outputs/bundle/${build_mode}Release/app-$build_mode.aab"
        if [ -f "$bundle_path" ]; then
            local bundle_size=$(du -h "$bundle_path" | cut -f1)
            echo "- **App Bundle**: \`$bundle_path\` ($bundle_size)" >> "$report_file"
        fi
    fi
    
    # Add iOS info
    cat >> "$report_file" << EOF

### iOS
EOF
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local ios_path="build/ios/iphoneos/Runner.app"
        if [ -d "$ios_path" ]; then
            local ios_size=$(du -sh "$ios_path" | cut -f1)
            echo "- **iOS App**: \`$ios_path\` ($ios_size)" >> "$report_file"
        fi
        
        # Add IPA info for release builds
        if [ "$build_mode" = "release" ]; then
            local ipa_path="build/ios/ipa"
            if [ -d "$ipa_path" ]; then
                echo "- **IPA**: Check \`$ipa_path\` directory" >> "$report_file"
            fi
        fi
    else
        echo "- iOS builds not available (not on macOS)" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Installation Commands

### Android
\`\`\`bash
# Install APK on connected device
flutter install

# Or manually install
adb install $apk_path
\`\`\`

### iOS (macOS only)
\`\`\`bash
# Open in Xcode
open ios/Runner.xcworkspace

# Or install via Xcode to connected device
\`\`\`

## Next Steps

### For Debug Builds
1. Install on test devices
2. Test all functionality
3. Check performance

### For Release Builds
1. **Android**: Upload App Bundle to Google Play Console
2. **iOS**: Upload IPA to App Store Connect
3. Fill in store listings and metadata
4. Submit for review

## Store Upload Commands

### Google Play Console
1. Go to [Google Play Console](https://play.google.com/console)
2. Upload \`$bundle_path\` (if available)
3. Fill in release notes and metadata

### App Store Connect
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Upload IPA using Xcode or Transporter
3. Fill in app metadata and submit for review

---
*Generated on $(date)*
EOF

    print_success "Build report generated: $report_file"
}

# Function to show build summary
show_build_summary() {
    local build_mode=$1
    
    echo ""
    print_success "🎉 Build completed successfully!"
    echo ""
    echo "📋 Build Summary:"
    echo "  • Build mode: $build_mode"
    echo "  • Flutter version: $(flutter --version | head -1 | cut -d' ' -f2)"
    echo ""
    
    echo "📱 Android Artifacts:"
    local apk_path="build/app/outputs/flutter-apk/app-$build_mode.apk"
    if [ -f "$apk_path" ]; then
        local apk_size=$(du -h "$apk_path" | cut -f1)
        echo "  • APK: $apk_path ($apk_size)"
    fi
    
    if [ "$build_mode" = "profile" ] || [ "$build_mode" = "release" ]; then
        local bundle_path="build/app/outputs/bundle/${build_mode}Release/app-$build_mode.aab"
        if [ -f "$bundle_path" ]; then
            local bundle_size=$(du -h "$bundle_path" | cut -f1)
            echo "  • App Bundle: $bundle_path ($bundle_size)"
        fi
    fi
    
    echo ""
    echo "🍎 iOS Artifacts:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local ios_path="build/ios/iphoneos/Runner.app"
        if [ -d "$ios_path" ]; then
            local ios_size=$(du -sh "$ios_path" | cut -f1)
            echo "  • iOS App: $ios_path ($ios_size)"
        fi
        
        if [ "$build_mode" = "release" ]; then
            echo "  • IPA: Check build/ios/ipa/ directory"
        fi
    else
        echo "  • Not available (not on macOS)"
    fi
    
    echo ""
    echo "🚀 Next Steps:"
    if [ "$build_mode" = "debug" ]; then
        echo "  • Install on device: flutter install"
        echo "  • Test app functionality"
    elif [ "$build_mode" = "release" ]; then
        echo "  • Upload to app stores"
        echo "  • Test on production environment"
    fi
}

# Main build function
main() {
    local build_mode=${1:-"debug"}
    local skip_analysis=${2:-"false"}
    local build_ios_ipa_flag=${3:-"false"}
    
    print_status "Starting build process..."
    print_status "Build mode: $build_mode"
    
    # Validate build mode
    if [ "$build_mode" != "debug" ] && [ "$build_mode" != "profile" ] && [ "$build_mode" != "release" ]; then
        print_error "Invalid build mode: $build_mode"
        print_status "Valid modes: debug, profile, release"
        exit 1
    fi
    
    # Check Flutter environment
    check_flutter_doctor
    
    # Prepare project
    prepare_project
    
    # Analyze code (unless skipped)
    if [ "$skip_analysis" != "true" ]; then
        analyze_code
    else
        print_warning "Skipping code analysis"
    fi
    
    # Build Android APK
    build_android_apk "$build_mode"
    if [ $? -ne 0 ]; then
        print_error "Android APK build failed"
        exit 1
    fi
    
    # Build Android App Bundle (for profile/release)
    if [ "$build_mode" = "profile" ] || [ "$build_mode" = "release" ]; then
        build_android_bundle "$build_mode"
    fi
    
    # Build iOS
    build_ios "$build_mode"
    
    # Build iOS IPA (for release and if requested)
    if [ "$build_mode" = "release" ] && [ "$build_ios_ipa_flag" = "true" ]; then
        build_ios_ipa
    fi
    
    # Generate build report
    generate_build_report "$build_mode"
    
    # Show build summary
    show_build_summary "$build_mode"
}

# Script usage
usage() {
    echo "Usage: $0 [build_mode] [skip_analysis] [build_ios_ipa]"
    echo ""
    echo "Parameters:"
    echo "  build_mode: 'debug', 'profile', or 'release' (default: debug)"
    echo "  skip_analysis: 'true' to skip code analysis (default: false)"
    echo "  build_ios_ipa: 'true' to build iOS IPA for release (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                          # Debug build with analysis"
    echo "  $0 debug                    # Debug build with analysis"
    echo "  $0 release                  # Release build with analysis"
    echo "  $0 release false true       # Release build with IPA"
    echo "  $0 debug true               # Debug build without analysis"
}

# Handle script arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
    exit 0
fi

# Run main function
main "$@"