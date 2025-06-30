#!/bin/bash

# NUCLEAR BACKGROUND LOCATION FIX
# Run this with ADB if you have USB debugging enabled

echo "🚨 NUCLEAR BACKGROUND LOCATION FIX STARTING..."

# Reset all permissions
adb shell pm reset-permissions

# Grant location permissions
adb shell pm grant com.yourapp.groupsharing android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.yourapp.groupsharing android.permission.ACCESS_COARSE_LOCATION  
adb shell pm grant com.yourapp.groupsharing android.permission.ACCESS_BACKGROUND_LOCATION

# Disable battery optimization
adb shell dumpsys deviceidle whitelist +com.yourapp.groupsharing

# Enable autostart
adb shell pm enable com.yourapp.groupsharing

# Clear app data (nuclear reset)
adb shell pm clear com.yourapp.groupsharing

echo "✅ NUCLEAR FIX APPLIED - RESTART YOUR PHONE NOW"