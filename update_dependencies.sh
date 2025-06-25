#!/bin/bash

echo "🧹 Cleaning Flutter project..."
flutter clean

echo "📦 Getting updated dependencies with specific versions..."
flutter pub get

echo "🔧 Running pub deps to check for conflicts..."
flutter pub deps

echo "📋 Checking specific Firebase Auth version..."
flutter pub deps | grep firebase_auth

echo "✅ Dependencies updated successfully!"
echo ""
echo "📱 Updated versions:"
echo "  - firebase_core: ^2.24.2"
echo "  - firebase_auth: ^4.15.3"
echo "  - google_sign_in: ^6.1.6"
echo "  - firebase_auth_platform_interface: ^7.0.9 (override)"
echo ""
echo "📱 To rebuild your debug APK, run:"
echo "flutter build apk --debug"