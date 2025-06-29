#!/bin/bash

# Flutter Run Script with ADB Fix
# This script resolves the "device not found" issue during app installation

echo "🚀 Starting Flutter app with ADB fix..."

# Check if device is connected
echo "📱 Checking device connection..."
adb devices

# Kill and restart ADB server to ensure clean connection
echo "🔄 Restarting ADB server..."
adb kill-server
adb start-server

# Wait a moment for ADB to stabilize
sleep 2

# Check devices again
echo "📱 Verifying device connection..."
adb devices

# Run Flutter with the fix
echo "🏃 Running Flutter app (bypassing uninstall issue)..."
flutter run --no-uninstall-first

echo "✅ Script completed!"