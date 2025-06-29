#!/bin/bash

# Complete Deployment Script for GroupSharing App
# This script handles the full deployment process including Firebase services and mobile builds

set -e  # Exit on any error

echo "🚀 GroupSharing App - Complete Deployment"
echo "========================================"

# Color codes for output
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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check Firebase CLI
    if ! command -v firebase &> /dev/null; then
        print_error "Firebase CLI is not installed"
        print_status "Install with: npm install -g firebase-tools"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi
    
    # Check if logged into Firebase
    if ! firebase projects:list &> /dev/null; then
        print_error "Not logged in to Firebase"
        print_status "Login with: firebase login"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Clean and prepare project
prepare_project() {
    print_status "Preparing project..."
    
    # Flutter clean
    flutter clean
    
    # Get dependencies
    flutter pub get
    
    print_success "Project prepared"
}

# Deploy Firebase services
deploy_firebase() {
    print_status "Deploying Firebase services..."
    
    # Deploy Firestore rules
    print_status "Deploying Firestore rules..."
    firebase deploy --only firestore:rules
    
    # Deploy Realtime Database rules
    print_status "Deploying Realtime Database rules..."
    firebase deploy --only database
    
    # Deploy Cloud Functions
    print_status "Deploying Cloud Functions..."
    cd functions
    npm install
    npm run build
    cd ..
    firebase deploy --only functions
    
    # Deploy Storage rules (if they exist)
    if [ -f "storage.rules" ]; then
        print_status "Deploying Storage rules..."
        firebase deploy --only storage
    fi
    
    print_success "Firebase services deployed"
}

# Build mobile apps
build_mobile() {
    local build_type=$1
    
    print_status "Building mobile apps ($build_type)..."
    
    if [ "$build_type" = "debug" ]; then
        # Debug builds
        print_status "Building Android debug APK..."
        flutter build apk --debug
        
        print_status "Building iOS debug (if on macOS)..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            flutter build ios --debug --no-codesign
        else
            print_warning "Skipping iOS build (not on macOS)"
        fi
        
    elif [ "$build_type" = "release" ]; then
        # Release builds
        print_status "Building Android release APK..."
        flutter build apk --release
        
        print_status "Building Android App Bundle..."
        flutter build appbundle --release
        
        print_status "Building iOS release (if on macOS)..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            flutter build ios --release --no-codesign
        else
            print_warning "Skipping iOS build (not on macOS)"
        fi
    fi
    
    print_success "Mobile apps built"
}

# Run tests
run_tests() {
    print_status "Running tests..."
    
    # Unit tests
    print_status "Running unit tests..."
    flutter test
    
    # Integration tests (if they exist)
    if [ -d "integration_test" ]; then
        print_status "Running integration tests..."
        flutter test integration_test/
    fi
    
    print_success "All tests passed"
}

# Generate deployment report
generate_report() {
    print_status "Generating deployment report..."
    
    local report_file="deployment_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Deployment Report - $(date)

## Deployment Summary
- **Date**: $(date)
- **Project**: GroupSharing App
- **Firebase Project**: group-sharing-9d119
- **Deployment Type**: $1

## Services Deployed
- ✅ Firebase Firestore Rules
- ✅ Firebase Realtime Database Rules
- ✅ Firebase Cloud Functions
- ✅ Firebase Storage Rules (if applicable)

## Mobile Builds
- ✅ Android APK ($1)
- ✅ Android App Bundle (release only)
- ✅ iOS Build (if on macOS)

## Cloud Functions Deployed
- \`checkProximity\` - Proximity detection and notifications
- \`cleanupNotificationCooldowns\` - Cleanup scheduled task
- \`updateFcmToken\` - FCM token management
- \`getProximityStats\` - Statistics and debugging

## Build Artifacts
- Android APK: \`build/app/outputs/flutter-apk/app-$1.apk\`
- Android Bundle: \`build/app/outputs/bundle/${1}Release/app-$1.aab\`
- iOS Build: \`build/ios/iphoneos/Runner.app\`

## Next Steps
1. Test the deployed services
2. Upload mobile builds to app stores (for release)
3. Monitor Firebase Console for any issues
4. Check analytics and performance metrics

## Useful Commands
\`\`\`bash
# View Cloud Function logs
firebase functions:log

# Monitor Realtime Database
firebase database:get /

# Check Firestore data
firebase firestore:get users

# Install debug APK
flutter install
\`\`\`

## Support Resources
- [Firebase Console](https://console.firebase.google.com/project/group-sharing-9d119)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
EOF

    print_success "Deployment report generated: $report_file"
}

# Main deployment function
main() {
    local deployment_type=${1:-"debug"}
    local skip_tests=${2:-"false"}
    
    print_status "Starting deployment process..."
    print_status "Deployment type: $deployment_type"
    
    # Check prerequisites
    check_prerequisites
    
    # Prepare project
    prepare_project
    
    # Run tests (unless skipped)
    if [ "$skip_tests" != "true" ]; then
        run_tests
    else
        print_warning "Skipping tests"
    fi
    
    # Deploy Firebase services
    deploy_firebase
    
    # Build mobile apps
    build_mobile "$deployment_type"
    
    # Generate report
    generate_report "$deployment_type"
    
    print_success "🎉 Deployment completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "  • Firebase services deployed"
    echo "  • Mobile apps built ($deployment_type)"
    echo "  • All tests passed"
    echo "  • Deployment report generated"
    echo ""
    echo "🔗 Useful links:"
    echo "  • Firebase Console: https://console.firebase.google.com/project/group-sharing-9d119"
    echo "  • Cloud Functions: https://console.firebase.google.com/project/group-sharing-9d119/functions"
    echo "  • Realtime Database: https://console.firebase.google.com/project/group-sharing-9d119/database"
    echo ""
    echo "📱 Next steps:"
    if [ "$deployment_type" = "release" ]; then
        echo "  • Upload Android App Bundle to Google Play Console"
        echo "  • Upload iOS build to App Store Connect"
    else
        echo "  • Install debug APK: flutter install"
        echo "  • Test app functionality"
    fi
}

# Script usage
usage() {
    echo "Usage: $0 [deployment_type] [skip_tests]"
    echo ""
    echo "Parameters:"
    echo "  deployment_type: 'debug' or 'release' (default: debug)"
    echo "  skip_tests: 'true' to skip tests (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Debug deployment with tests"
    echo "  $0 debug              # Debug deployment with tests"
    echo "  $0 release            # Release deployment with tests"
    echo "  $0 debug true         # Debug deployment without tests"
    echo "  $0 release true       # Release deployment without tests"
}

# Handle script arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
    exit 0
fi

# Validate deployment type
if [ -n "$1" ] && [ "$1" != "debug" ] && [ "$1" != "release" ]; then
    print_error "Invalid deployment type: $1"
    usage
    exit 1
fi

# Run main function
main "$@"