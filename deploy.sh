#!/bin/bash

# Quick Deployment Script for GroupSharing App
# This is the main entry point for all deployment operations

echo "🚀 GroupSharing App - Deployment Hub"
echo "===================================="

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}$1${NC}"
}

print_option() {
    echo -e "${BLUE}$1${NC} $2"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show deployment options
show_menu() {
    echo ""
    print_header "📋 Available Deployment Options:"
    echo ""
    print_option "1." "Complete Deployment (Firebase + Mobile Apps)"
    print_option "2." "Firebase Services Only (Rules + Functions)"
    print_option "3." "Cloud Functions Only"
    print_option "4." "Security Rules Only"
    print_option "5." "Mobile Apps Only (Debug)"
    print_option "6." "Mobile Apps Only (Release)"
    print_option "7." "Show Deployment Guide"
    print_option "8." "Show Deployment Checklist"
    print_option "9." "Validate Environment"
    print_option "0." "Exit"
    echo ""
}

# Function to validate environment
validate_environment() {
    print_header "🔍 Validating Environment..."
    echo ""
    
    local errors=0
    
    # Check Flutter
    if command -v flutter &> /dev/null; then
        echo "✅ Flutter: $(flutter --version | head -1)"
    else
        echo "❌ Flutter: Not installed"
        errors=$((errors + 1))
    fi
    
    # Check Firebase CLI
    if command -v firebase &> /dev/null; then
        echo "✅ Firebase CLI: $(firebase --version)"
    else
        echo "❌ Firebase CLI: Not installed"
        errors=$((errors + 1))
    fi
    
    # Check Node.js
    if command -v node &> /dev/null; then
        echo "✅ Node.js: $(node --version)"
    else
        echo "❌ Node.js: Not installed"
        errors=$((errors + 1))
    fi
    
    # Check Firebase login
    if firebase projects:list &> /dev/null; then
        echo "✅ Firebase: Logged in"
    else
        echo "❌ Firebase: Not logged in"
        errors=$((errors + 1))
    fi
    
    # Check project files
    if [ -f "pubspec.yaml" ]; then
        echo "✅ Flutter project: Found"
    else
        echo "❌ Flutter project: pubspec.yaml not found"
        errors=$((errors + 1))
    fi
    
    if [ -f "firebase.json" ]; then
        echo "✅ Firebase config: Found"
    else
        echo "❌ Firebase config: firebase.json not found"
        errors=$((errors + 1))
    fi
    
    echo ""
    if [ $errors -eq 0 ]; then
        print_success "Environment validation passed!"
    else
        print_error "Environment validation failed with $errors errors"
        echo ""
        echo "📖 Setup instructions:"
        echo "  • Install Flutter: https://flutter.dev/docs/get-started/install"
        echo "  • Install Firebase CLI: npm install -g firebase-tools"
        echo "  • Install Node.js: https://nodejs.org/"
        echo "  • Login to Firebase: firebase login"
    fi
    
    return $errors
}

# Function to execute deployment option
execute_option() {
    local option=$1
    
    case $option in
        1)
            print_header "🚀 Starting Complete Deployment..."
            if [ -f "./deploy_complete.sh" ]; then
                ./deploy_complete.sh
            else
                print_error "deploy_complete.sh not found"
            fi
            ;;
        2)
            print_header "☁️ Deploying Firebase Services..."
            echo "Deploying Security Rules..."
            if [ -f "./deploy_firebase_rules.sh" ]; then
                ./deploy_firebase_rules.sh
            fi
            echo ""
            echo "Deploying Cloud Functions..."
            if [ -f "./deploy_cloud_functions.sh" ]; then
                ./deploy_cloud_functions.sh
            fi
            ;;
        3)
            print_header "⚡ Deploying Cloud Functions..."
            if [ -f "./deploy_cloud_functions.sh" ]; then
                ./deploy_cloud_functions.sh
            else
                print_error "deploy_cloud_functions.sh not found"
            fi
            ;;
        4)
            print_header "🔐 Deploying Security Rules..."
            if [ -f "./deploy_firebase_rules.sh" ]; then
                ./deploy_firebase_rules.sh
            else
                print_error "deploy_firebase_rules.sh not found"
            fi
            ;;
        5)
            print_header "📱 Building Mobile Apps (Debug)..."
            if [ -f "./build_mobile_apps.sh" ]; then
                ./build_mobile_apps.sh debug
            else
                print_error "build_mobile_apps.sh not found"
            fi
            ;;
        6)
            print_header "📱 Building Mobile Apps (Release)..."
            if [ -f "./build_mobile_apps.sh" ]; then
                ./build_mobile_apps.sh release false true
            else
                print_error "build_mobile_apps.sh not found"
            fi
            ;;
        7)
            print_header "📖 Opening Deployment Guide..."
            if [ -f "DEPLOYMENT_GUIDE.md" ]; then
                if command -v code &> /dev/null; then
                    code DEPLOYMENT_GUIDE.md
                elif command -v cat &> /dev/null; then
                    cat DEPLOYMENT_GUIDE.md
                else
                    echo "Please open DEPLOYMENT_GUIDE.md in your preferred editor"
                fi
            else
                print_error "DEPLOYMENT_GUIDE.md not found"
            fi
            ;;
        8)
            print_header "📋 Opening Deployment Checklist..."
            if [ -f "DEPLOYMENT_CHECKLIST.md" ]; then
                if command -v code &> /dev/null; then
                    code DEPLOYMENT_CHECKLIST.md
                elif command -v cat &> /dev/null; then
                    cat DEPLOYMENT_CHECKLIST.md
                else
                    echo "Please open DEPLOYMENT_CHECKLIST.md in your preferred editor"
                fi
            else
                print_error "DEPLOYMENT_CHECKLIST.md not found"
            fi
            ;;
        9)
            validate_environment
            ;;
        0)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option: $option"
            ;;
    esac
}

# Main interactive function
interactive_mode() {
    while true; do
        show_menu
        read -p "Select an option (0-9): " choice
        echo ""
        
        execute_option "$choice"
        
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Main function
main() {
    # If arguments provided, execute directly
    if [ $# -gt 0 ]; then
        execute_option "$1"
    else
        # Interactive mode
        clear
        interactive_mode
    fi
}

# Script usage
usage() {
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  1    Complete Deployment"
    echo "  2    Firebase Services Only"
    echo "  3    Cloud Functions Only"
    echo "  4    Security Rules Only"
    echo "  5    Mobile Apps (Debug)"
    echo "  6    Mobile Apps (Release)"
    echo "  7    Show Deployment Guide"
    echo "  8    Show Deployment Checklist"
    echo "  9    Validate Environment"
    echo ""
    echo "Examples:"
    echo "  $0        # Interactive mode"
    echo "  $0 1      # Complete deployment"
    echo "  $0 9      # Validate environment"
}

# Handle help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
    exit 0
fi

# Run main function
main "$@"