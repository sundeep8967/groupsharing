#!/bin/bash

# Deploy Firebase Security Rules
# This script deploys Firestore and Realtime Database security rules

echo "🔐 Deploying Firebase Security Rules"
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

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    print_error "Firebase CLI is not installed"
    print_status "Install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    print_error "Not logged in to Firebase"
    print_status "Login with: firebase login"
    exit 1
fi

print_success "Firebase CLI is ready"

# Function to deploy Firestore rules
deploy_firestore_rules() {
    print_status "Deploying Firestore security rules..."
    
    if [ ! -f "firestore.rules" ]; then
        print_error "firestore.rules file not found"
        return 1
    fi
    
    # Show current rules
    print_status "Current Firestore rules:"
    head -20 firestore.rules
    echo "..."
    
    # Deploy rules
    firebase deploy --only firestore:rules
    
    if [ $? -eq 0 ]; then
        print_success "Firestore rules deployed successfully"
    else
        print_error "Failed to deploy Firestore rules"
        return 1
    fi
}

# Function to deploy Realtime Database rules
deploy_database_rules() {
    print_status "Deploying Realtime Database security rules..."
    
    if [ ! -f "database.rules.json" ]; then
        print_error "database.rules.json file not found"
        return 1
    fi
    
    # Show current rules
    print_status "Current Realtime Database rules:"
    head -20 database.rules.json
    echo "..."
    
    # Deploy rules
    firebase deploy --only database
    
    if [ $? -eq 0 ]; then
        print_success "Realtime Database rules deployed successfully"
    else
        print_error "Failed to deploy Realtime Database rules"
        return 1
    fi
}

# Function to deploy Storage rules
deploy_storage_rules() {
    if [ -f "storage.rules" ]; then
        print_status "Deploying Storage security rules..."
        
        # Show current rules
        print_status "Current Storage rules:"
        head -20 storage.rules
        echo "..."
        
        # Deploy rules
        firebase deploy --only storage
        
        if [ $? -eq 0 ]; then
            print_success "Storage rules deployed successfully"
        else
            print_error "Failed to deploy Storage rules"
            return 1
        fi
    else
        print_warning "storage.rules file not found, skipping Storage rules deployment"
    fi
}

# Function to validate rules before deployment
validate_rules() {
    print_status "Validating security rules..."
    
    # Check Firestore rules syntax
    if [ -f "firestore.rules" ]; then
        print_status "Validating Firestore rules syntax..."
        # Note: Firebase CLI doesn't have a built-in validator, but we can check basic syntax
        if grep -q "rules_version" firestore.rules && grep -q "service cloud.firestore" firestore.rules; then
            print_success "Firestore rules syntax looks valid"
        else
            print_warning "Firestore rules may have syntax issues"
        fi
    fi
    
    # Check Realtime Database rules syntax
    if [ -f "database.rules.json" ]; then
        print_status "Validating Realtime Database rules syntax..."
        if python3 -m json.tool database.rules.json > /dev/null 2>&1; then
            print_success "Realtime Database rules JSON is valid"
        else
            print_error "Realtime Database rules JSON is invalid"
            return 1
        fi
    fi
}

# Function to backup current rules
backup_rules() {
    print_status "Creating backup of current rules..."
    
    local backup_dir="rules_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Firestore rules
    if [ -f "firestore.rules" ]; then
        cp firestore.rules "$backup_dir/"
        print_status "Firestore rules backed up to $backup_dir/"
    fi
    
    # Backup Realtime Database rules
    if [ -f "database.rules.json" ]; then
        cp database.rules.json "$backup_dir/"
        print_status "Database rules backed up to $backup_dir/"
    fi
    
    # Backup Storage rules
    if [ -f "storage.rules" ]; then
        cp storage.rules "$backup_dir/"
        print_status "Storage rules backed up to $backup_dir/"
    fi
    
    print_success "Rules backed up to $backup_dir/"
}

# Function to show rules summary
show_rules_summary() {
    print_status "Security Rules Summary:"
    echo ""
    
    if [ -f "firestore.rules" ]; then
        echo "📄 Firestore Rules:"
        echo "  • File: firestore.rules"
        echo "  • Size: $(wc -l < firestore.rules) lines"
        echo "  • Last modified: $(stat -c %y firestore.rules 2>/dev/null || stat -f %Sm firestore.rules 2>/dev/null)"
        echo ""
    fi
    
    if [ -f "database.rules.json" ]; then
        echo "📄 Realtime Database Rules:"
        echo "  • File: database.rules.json"
        echo "  • Size: $(wc -l < database.rules.json) lines"
        echo "  • Last modified: $(stat -c %y database.rules.json 2>/dev/null || stat -f %Sm database.rules.json 2>/dev/null)"
        echo ""
    fi
    
    if [ -f "storage.rules" ]; then
        echo "📄 Storage Rules:"
        echo "  • File: storage.rules"
        echo "  • Size: $(wc -l < storage.rules) lines"
        echo "  • Last modified: $(stat -c %y storage.rules 2>/dev/null || stat -f %Sm storage.rules 2>/dev/null)"
        echo ""
    fi
}

# Main deployment function
main() {
    local skip_backup=${1:-"false"}
    local validate_only=${2:-"false"}
    
    # Show rules summary
    show_rules_summary
    
    # Validate rules
    validate_rules
    if [ $? -ne 0 ]; then
        print_error "Rules validation failed"
        exit 1
    fi
    
    # If validate only, exit here
    if [ "$validate_only" = "true" ]; then
        print_success "Rules validation completed successfully"
        exit 0
    fi
    
    # Create backup unless skipped
    if [ "$skip_backup" != "true" ]; then
        backup_rules
    fi
    
    # Deploy rules
    print_status "Starting rules deployment..."
    
    # Deploy Firestore rules
    deploy_firestore_rules
    if [ $? -ne 0 ]; then
        print_error "Firestore rules deployment failed"
        exit 1
    fi
    
    # Deploy Realtime Database rules
    deploy_database_rules
    if [ $? -ne 0 ]; then
        print_error "Realtime Database rules deployment failed"
        exit 1
    fi
    
    # Deploy Storage rules
    deploy_storage_rules
    
    print_success "🎉 All security rules deployed successfully!"
    echo ""
    echo "📋 Deployed Rules:"
    echo "  • Firestore security rules"
    echo "  • Realtime Database security rules"
    if [ -f "storage.rules" ]; then
        echo "  • Storage security rules"
    fi
    echo ""
    echo "🔗 Monitor rules in Firebase Console:"
    echo "  • Firestore: https://console.firebase.google.com/project/group-sharing-9d119/firestore/rules"
    echo "  • Database: https://console.firebase.google.com/project/group-sharing-9d119/database/rules"
    echo "  • Storage: https://console.firebase.google.com/project/group-sharing-9d119/storage/rules"
    echo ""
    echo "⚠️  Important: Test your app to ensure rules work correctly!"
}

# Script usage
usage() {
    echo "Usage: $0 [skip_backup] [validate_only]"
    echo ""
    echo "Parameters:"
    echo "  skip_backup: 'true' to skip creating backup (default: false)"
    echo "  validate_only: 'true' to only validate rules without deploying (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Deploy with backup"
    echo "  $0 true               # Deploy without backup"
    echo "  $0 false true         # Validate only"
}

# Handle script arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
    exit 0
fi

# Run main function
main "$@"