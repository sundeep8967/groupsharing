#!/bin/bash

# Dart Files Cleanup Script
# This script removes unused Dart files in phases for safety

set -e  # Exit on any error

echo "🧹 DART FILES CLEANUP SCRIPT"
echo "=============================="
echo ""

# Function to confirm action
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled"
        exit 1
    fi
}

# Function to backup files
backup_files() {
    echo "📦 Creating backup..."
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_dir="backup_$timestamp"
    mkdir -p "$backup_dir"
    cp -r lib "$backup_dir/"
    echo "✅ Backup created in $backup_dir"
}

# Function to test build
test_build() {
    echo "🔨 Testing build..."
    if flutter build apk --debug > /dev/null 2>&1; then
        echo "✅ Build successful"
        return 0
    else
        echo "❌ Build failed"
        return 1
    fi
}

# Phase 1: High Priority (Safe to remove immediately)
phase1_cleanup() {
    echo ""
    echo "🔴 PHASE 1: High Priority Cleanup"
    echo "================================="
    echo "Removing alternative providers and debug screens..."
    
    # Alternative providers
    files_to_remove=(
        "lib/providers/enhanced_location_provider.dart"
        "lib/providers/location_provider_debug.dart"
        "lib/providers/minimal_location_provider.dart"
        "lib/providers/ultra_geofencing_provider.dart"
        
        # Debug screens (except native_location_test_screen.dart which is used)
        "lib/screens/debug/api_key_debug_screen.dart"
        "lib/screens/debug/background_location_fix_screen.dart"
        "lib/screens/debug/comprehensive_debug_screen.dart"
        
        # Alternative map widgets (except smooth_modern_map.dart which is used)
        "lib/widgets/custom_map.dart"
        "lib/widgets/modern_map.dart"
        "lib/widgets/optimized_map.dart"
        "lib/widgets/uber_map.dart"
        "lib/widgets/ultra_smooth_map.dart"
    )
    
    removed_count=0
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            echo "🗑️  Removing $file"
            rm "$file"
            ((removed_count++))
        else
            echo "⚠️  File not found: $file"
        fi
    done
    
    echo "✅ Phase 1 complete: Removed $removed_count files"
}

# Phase 2: Medium Priority (Remove after verification)
phase2_cleanup() {
    echo ""
    echo "🟡 PHASE 2: Medium Priority Cleanup"
    echo "==================================="
    echo "Removing unused models and redundant services..."
    
    # Unused models
    files_to_remove=(
        "lib/models/advanced_geofence.dart"
        "lib/models/chat_message_model.dart"
        "lib/models/emergency_contact.dart"
        "lib/models/friend_relationship.dart"
        "lib/models/friendship_model.dart"
        "lib/models/geofence_model.dart"
        "lib/models/location_model.dart"
        "lib/models/saved_place.dart"
        "lib/models/user_marker.dart"
        "lib/models/user_model.dart"
        
        # Redundant services
        "lib/services/deep_link_service.dart"
        "lib/services/advanced_location_engine.dart"
        "lib/services/android_8_background_location_solution.dart"
        "lib/services/android_background_location_fix.dart"
        "lib/services/android_background_location_optimizer.dart"
        "lib/services/api_key_validator.dart"
        "lib/services/background_location_debug_service.dart"
        "lib/services/battery_optimization_engine.dart"
        "lib/services/battery_optimization_service.dart"
        "lib/services/emergency_location_fix_service.dart"
        "lib/services/enhanced_native_service.dart"
        "lib/services/firebase_service.dart"
        "lib/services/friend_service.dart"
        "lib/services/geofence_repository.dart"
        "lib/services/geofence_service_helper.dart"
        "lib/services/location_fusion_engine.dart"
        "lib/services/location_sync_service.dart"
        "lib/services/motion_detection_engine.dart"
        "lib/services/native_location_service.dart"
        "lib/services/network_aware_engine.dart"
        "lib/services/oneplus_optimization_service.dart"
        "lib/services/permission_manager.dart"
        "lib/services/presence_service.dart"
        "lib/services/ultra_geofencing_service.dart"
        "lib/services/ultra_persistent_location_service.dart"
    )
    
    removed_count=0
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            echo "🗑️  Removing $file"
            rm "$file"
            ((removed_count++))
        else
            echo "⚠️  File not found: $file"
        fi
    done
    
    echo "✅ Phase 2 complete: Removed $removed_count files"
}

# Phase 3: Low Priority (Remove if confirmed unused)
phase3_cleanup() {
    echo ""
    echo "🟢 PHASE 3: Low Priority Cleanup"
    echo "================================"
    echo "Removing unused screens and utilities..."
    
    files_to_remove=(
        # Unused screens
        "lib/screens/chat/chat_screen.dart"
        "lib/screens/friends/add_friends_screen.dart"
        "lib/screens/friends/friends_screen.dart"
        "lib/screens/location_sharing_screen.dart"
        "lib/screens/main/life360_main_screen.dart"
        "lib/screens/oneplus_permission_screen.dart"
        "lib/screens/oneplus_troubleshooting_screen.dart"
        "lib/screens/permission_screen.dart"
        "lib/screens/profile/location_history_screen.dart"
        "lib/screens/profile/location_permissions_screen.dart"
        "lib/screens/settings/battery_optimization_screen.dart"
        
        # Unused utils and config
        "lib/utils/battery_optimization_handler.dart"
        "lib/utils/error_handler.dart"
        "lib/config/app_config.dart"
        "lib/config/environment.dart"
        "lib/constants/map_constants.dart"
    )
    
    removed_count=0
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            echo "🗑️  Removing $file"
            rm "$file"
            ((removed_count++))
        else
            echo "⚠️  File not found: $file"
        fi
    done
    
    echo "✅ Phase 3 complete: Removed $removed_count files"
}

# Main execution
main() {
    echo "This script will remove unused Dart files to clean up the codebase."
    echo ""
    echo "📊 Current status:"
    echo "  Total Dart files: $(find lib -name "*.dart" | wc -l)"
    echo "  Estimated unused files: ~62"
    echo ""
    
    confirm "Do you want to create a backup before proceeding?"
    backup_files
    
    echo ""
    confirm "Proceed with Phase 1 cleanup (alternative providers, debug screens, unused widgets)?"
    phase1_cleanup
    
    echo ""
    echo "🔨 Testing build after Phase 1..."
    if ! test_build; then
        echo "❌ Build failed after Phase 1. Please check the errors and restore from backup if needed."
        exit 1
    fi
    
    echo ""
    confirm "Proceed with Phase 2 cleanup (unused models, redundant services)?"
    phase2_cleanup
    
    echo ""
    echo "🔨 Testing build after Phase 2..."
    if ! test_build; then
        echo "❌ Build failed after Phase 2. Please check the errors and restore from backup if needed."
        exit 1
    fi
    
    echo ""
    confirm "Proceed with Phase 3 cleanup (unused screens, utilities)?"
    phase3_cleanup
    
    echo ""
    echo "🔨 Final build test..."
    if test_build; then
        echo ""
        echo "🎉 CLEANUP COMPLETE!"
        echo "==================="
        echo "✅ All phases completed successfully"
        echo "📊 Final status:"
        echo "  Remaining Dart files: $(find lib -name "*.dart" | wc -l)"
        echo "  Backup available in: backup_*"
        echo ""
        echo "💡 Next steps:"
        echo "  1. Test the app thoroughly"
        echo "  2. Run 'flutter clean && flutter pub get'"
        echo "  3. Test on physical devices"
        echo "  4. If everything works, you can delete the backup"
    else
        echo "❌ Final build test failed. Please restore from backup and investigate."
        exit 1
    fi
}

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "lib" ]; then
    echo "❌ Error: This script must be run from the Flutter project root directory"
    echo "   Make sure you're in the directory containing pubspec.yaml and lib/"
    exit 1
fi

# Run main function
main