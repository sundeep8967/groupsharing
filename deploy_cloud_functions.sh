#!/bin/bash

# Deploy Cloud Functions for Proximity Notifications
# This script deploys the Firebase Cloud Functions for server-side proximity detection

echo "🚀 Deploying Firebase Cloud Functions for Proximity Notifications"
echo "================================================================"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed"
    echo "💡 Install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase"
    echo "💡 Login with: firebase login"
    exit 1
fi

echo "✅ Firebase CLI is ready"

# Navigate to functions directory
cd functions

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in functions directory"
    exit 1
fi

echo "📦 Installing dependencies..."
npm install

echo "🔨 Building TypeScript..."
npm run build

# Navigate back to root
cd ..

echo "☁️ Deploying Cloud Functions..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Cloud Functions deployed successfully!"
    echo ""
    echo "📋 Deployed Functions:"
    echo "• checkProximity - Triggers on location updates"
    echo "• cleanupNotificationCooldowns - Runs every hour"
    echo "• updateFcmToken - Updates user FCM tokens"
    echo "• getProximityStats - Returns proximity statistics"
    echo ""
    echo "💰 Cost: FREE (within Firebase free tier limits)"
    echo "📊 Expected usage: ~43,200 calls/month for 100 active users"
    echo "🎯 Free tier limit: 2,000,000 calls/month"
    echo ""
    echo "🔔 Proximity notifications are now active!"
    echo "Users will receive notifications when friends are within 500m"
else
    echo "❌ Deployment failed"
    exit 1
fi