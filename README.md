# Group Sharing App

A real-time location sharing application built with Flutter that allows users to share their live location with friends and family, create groups, and track multiple users on an interactive map.

## Features

- 🔄 Real-time location sharing
- 👥 Create and manage groups
- 🗺️ Interactive map with user markers
- 🔒 Privacy controls for location sharing
- 📱 Responsive design for mobile devices
- 🔔 Location update notifications
- 👤 User authentication (Email/Google Sign-In)

## Screenshots

<!-- Add screenshots here once available -->

## Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / Xcode (for emulator/simulator)
- Firebase account (for backend services)
- Google Maps API key (for map functionality)

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/groupsharing.git
cd groupsharing
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android/iOS app to your Firebase project
3. Download the configuration files:
   - Android: `google-services.json` (place in `android/app/`)
   - iOS: `GoogleService-Info.plist` (place in `ios/Runner/`)

### 4. Add Google Maps API Key

1. Get an API key from the [Google Cloud Console](https://console.cloud.google.com/)
2. For Android, add the API key to `android/app/src/main/AndroidManifest.xml`
3. For iOS, add the API key to `ios/Runner/AppDelegate.swift`

### 5. Run the app

```bash
# For Android
flutter run -d <device_id>

# For iOS
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                  # Data models
├── providers/               # State management
├── screens/                 # App screens
│   ├── auth/                # Authentication screens
│   ├── home/                # Main app screens
│   └── onboarding/          # Onboarding flow
├── services/                # Business logic
├── utils/                   # Utilities and helpers
└── widgets/                 # Reusable widgets
    └── app_map_widget.dart  # Map component
```

## Dependencies

- `firebase_core`: Firebase Core
- `firebase_auth`: Firebase Authentication
- `cloud_firestore`: Cloud Firestore
- `geolocator`: Location services
- `flutter_map`: Interactive maps
- `provider`: State management
- `shared_preferences`: Local storage
- `smooth_page_indicator`: Onboarding indicators

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter Team for the amazing framework
- Firebase for the backend services
- OpenStreetMap for map data
