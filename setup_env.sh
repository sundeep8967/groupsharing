#!/bin/bash

# GroupSharing App - Environment Setup Script
# This script helps you set up your .env file with proper API keys

echo "🚀 GroupSharing App - Environment Setup"
echo "========================================"
echo ""

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Setup cancelled."
        exit 1
    fi
fi

# Copy .env.example to .env
echo "📋 Copying .env.example to .env..."
cp .env.example .env

echo "✅ .env file created successfully!"
echo ""
echo "🔧 Next Steps:"
echo "1. Edit the .env file and replace 'your_*_here' values with actual API keys"
echo "2. Get your API keys from:"
echo "   - Firebase: https://console.firebase.google.com/"
echo "   - (Maps) Using OpenStreetMap tiles via flutter_map - no API key required"
echo "   - Twilio: https://console.twilio.com/"
echo ""
echo "🔒 Security Reminder:"
echo "- Never commit .env to version control"
echo "- Keep your API keys secure"
echo "- Use different keys for development/staging/production"
echo ""
echo "📱 Your Firebase configuration is already set up with:"
echo "   - Project ID: group-sharing-9d119"
echo "   - Android API Key: AIzaSyBa697BquKrxRC-_nFJzDJ225a19qSwEP8"
echo "   - iOS API Key: AIzaSyB8asDhYd__rxirDbYnjEsIXmSHhvuTut8"
echo ""
echo "🎉 Setup complete! You can now run your app."