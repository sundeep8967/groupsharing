# 🔑 GroupSharing App - API Setup Guide

This guide will help you set up all the necessary API keys for your GroupSharing app to work properly.

## 🚀 Quick Setup

1. **Copy the environment file:**
   ```bash
   cp .env.example .env
   ```
   
   Or use the setup script:
   ```bash
   ./setup_env.sh
   ```

2. **Edit the `.env` file** and replace `your_*_here` values with actual API keys

3. **Run the app** - it will work with the default Firebase configuration!

## 📋 API Keys Status

Your app comes pre-configured with these working API keys:

### ✅ **Already Configured (Working)**
- **Firebase Android API Key**: `AIzaSyBa697BquKrxRC-_nFJzDJ225a19qSwEP8`
- **Firebase iOS API Key**: `AIzaSyB8asDhYd__rxirDbYnjEsIXmSHhvuTut8`
- **Firebase Project ID**: `group-sharing-9d119`

### 🔧 **Optional (For Enhanced Features)**
- Google Maps API Key
- Mapbox Access Token
- Twilio (SMS alerts)
- SendGrid (Email notifications)
- OpenWeather (Weather-based optimizations)

## 🔥 Firebase Setup (Already Done!)

Your Firebase project is already configured:
- **Project**: `group-sharing-9d119`
- **Console**: https://console.firebase.google.com/project/group-sharing-9d119
- **Authentication**: Enabled
- **Realtime Database**: Enabled
- **Cloud Firestore**: Enabled

## 🗺️ Map Services Setup

### Google Maps API (Optional)
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new project or select existing
3. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Geocoding API
   - Directions API
4. Create an API key
5. Add to `.env`: `GOOGLE_MAPS_API_KEY=your_key_here`

### Mapbox (Optional)
1. Go to [Mapbox Account](https://account.mapbox.com/access-tokens/)
2. Create a new access token
3. Add to `.env`: `MAPBOX_ACCESS_TOKEN=pk.your_token_here`

## 📱 Push Notifications Setup

### FCM Server Key (Optional)
1. Go to [Firebase Console](https://console.firebase.google.com/project/group-sharing-9d119/settings/cloudmessaging)
2. Copy the Server Key
3. Add to `.env`: `FCM_SERVER_KEY=your_key_here`

### APNs (iOS Push Notifications)
1. Go to [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list)
2. Create an APNs key
3. Add to `.env`:
   ```
   APNS_KEY_ID=your_key_id
   APNS_TEAM_ID=your_team_id
   ```

## 🚨 Emergency Services Setup

### Twilio (SMS Alerts)
1. Go to [Twilio Console](https://console.twilio.com/)
2. Get your Account SID and Auth Token
3. Buy a phone number
4. Add to `.env`:
   ```
   TWILIO_ACCOUNT_SID=ACxxxxx
   TWILIO_AUTH_TOKEN=your_token
   TWILIO_PHONE_NUMBER=+1234567890
   ```

### SendGrid (Email Notifications)
1. Go to [SendGrid](https://app.sendgrid.com/settings/api_keys)
2. Create an API key
3. Add to `.env`: `SENDGRID_API_KEY=SG.your_key`

## 🌤️ Weather Integration (Optional)

### OpenWeather API
1. Go to [OpenWeatherMap](https://openweathermap.org/api)
2. Sign up and get an API key
3. Add to `.env`: `OPENWEATHER_API_KEY=your_key`

## 🔒 Security Configuration

### JWT Secret
Generate a secure random string (32+ characters):
```bash
openssl rand -base64 32
```
Add to `.env`: `JWT_SECRET=your_secure_secret`

### Encryption Key
Generate a 32-character encryption key:
```bash
openssl rand -hex 16
```
Add to `.env`: `ENCRYPTION_KEY=your_32_char_key`

## 🛠️ Development vs Production

### Development (Current Setup)
- Uses default Firebase project
- Debug mode enabled
- Detailed logging
- All features enabled

### Production Setup
1. Create a new Firebase project for production
2. Update all API keys in `.env`
3. Set `ENVIRONMENT=production`
4. Set `DEBUG_MODE=false`
5. Configure proper security rules

## 🔍 Debugging API Keys

Use the built-in API key validator:

```dart
import 'package:your_app/services/api_key_validator.dart';

// Validate all keys
final report = ApiKeyValidator.validateAllKeys();
print('App ready: ${report.isReadyToRun}');

// Get setup instructions
final instructions = ApiKeyValidator.getSetupInstructions(report);
instructions.forEach(print);
```

Or use the debug screen in your app:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const ApiKeyDebugScreen(),
  ),
);
```

## 📊 API Key Status Check

Run this command to check your API key configuration:
```bash
flutter run --dart-define-from-file=.env
```

## 🚨 Security Best Practices

1. **Never commit `.env` to version control**
2. **Use different API keys for different environments**
3. **Enable API key restrictions in Google Cloud Console**
4. **Monitor API usage and set up billing alerts**
5. **Rotate API keys regularly**
6. **Use least privilege access**

## 🔗 Useful Links

- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Mapbox Account](https://account.mapbox.com/)
- [Twilio Console](https://console.twilio.com/)
- [SendGrid Dashboard](https://app.sendgrid.com/)
- [Apple Developer](https://developer.apple.com/)
- [OpenWeatherMap](https://openweathermap.org/)

## 🆘 Troubleshooting

### Common Issues

1. **Firebase connection failed**
   - Check if `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are present
   - Verify Firebase project ID matches

2. **Maps not loading**
   - Check if Google Maps API key is valid
   - Verify API restrictions in Google Cloud Console
   - Ensure Maps SDK is enabled

3. **Push notifications not working**
   - Verify FCM server key
   - Check if notifications are enabled in device settings
   - Ensure APNs certificates are valid (iOS)

4. **Location tracking issues**
   - Check location permissions
   - Verify background location permission (Android 10+)
   - Ensure battery optimization is disabled

### Getting Help

1. Check the API key debug screen in your app
2. Review the validation report logs
3. Verify all required APIs are enabled
4. Check Firebase project configuration

## 🎉 You're All Set!

Your GroupSharing app is now configured with Google Maps-level location technology and all the necessary APIs for a production-ready family location sharing app!

The app will work immediately with the default configuration, and you can add optional API keys for enhanced features as needed.