Group Sharing App
A real-time location sharing application built with Flutter that allows users to share their live location with friends and family, create groups, track multiple users on an interactive map, and manage friend connections.

## Features

- **Real-time Location Sharing**: Share your live location with friends and family.
- **Friend Management**: Add and manage friends to share your location with.
- **Friend Requests**: Send and receive friend requests with a simple tap.
- **Shareable Profile Links**: Generate and share a link to your profile for easy friend requests.
- **Interactive Map**: View your friends' locations on an interactive map.
- **User Profiles**: View and manage your profile information with Google profile integration.
- **Google Sign-In**: Secure authentication using Google accounts.

✨ Features
Authentication & Profile
👤 Google Sign-In: Seamless integration for user authentication.

🖼️ Profile Management: Display user's Google profile picture and information.

🔐 Secure Flow: Ensures a secure authentication process.

📤 Sign Out: Functionality to securely log out users.

Friends Management
👥 Friends List: View connected friends with real-time status updates.

🔍 Search & Add: Easily find and add new friends by username or name.

📨 Friend Requests: Send, accept, and decline incoming requests.

📱 Request Management: View and manage both sent and received friend requests.

👤 Friend Profiles: Access friend profiles and connection status.

Location Sharing
🔄 Real-time Location: Share live location updates with selected contacts or groups.

🗺️ Interactive Map: Track multiple users on an interactive map.

👥 Group Tracking: Create groups for shared location tracking.

🔒 Privacy Controls: Granular privacy settings for location sharing.

🔔 Notifications: Receive alerts for location updates.

📱 Responsive Design: Optimized for various mobile devices and orientations.

📸 Screenshots
🛠️ Prerequisites
Before you begin, ensure you have the following installed:

Flutter SDK (latest stable version recommended)

Android Studio / Xcode (for running on emulators/simulators or physical devices)

A Firebase account (for backend services like Authentication and Firestore)

A Google Cloud Project with billing enabled (required for Google Maps APIs)

🚀 Getting Started
Follow these steps to get your development environment set up and run the app:

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/groupsharing.git
   cd groupsharing
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Firebase:
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add an Android app with package name `com.sundeep.groupsharing`
   - Download and add `google-services.json` to `android/app/`
   - Enable Google Sign-In in the Firebase Console
   - Set up Firestore database with the following structure:
     ```
     users/
       {userId}/
         id: string
         name: string
         email: string
         photoUrl: string
         friends: array
         sentRequests: array
         receivedRequests: array
     ```

4. Configure Deep Linking:
   - **Android**: The deep link configuration is already set up in `AndroidManifest.xml`
   - **iOS**: Update the URL scheme in Xcode:
     1. Open the project in Xcode
     2. Select the Runner target
     3. Go to Info > URL Types
     4. Add a new URL Type with Identifier `com.sundeep.groupsharing` and URL Schemes `groupsharing`

5. Add Google Maps API key:
   - Get an API key from [Google Cloud Console](https://console.cloud.google.com/)
   - Add the API key to `android/app/src/main/AndroidManifest.xml`

6. Run the app:
   ```bash
   flutter run
   ```

Add Firebase dependencies to your android/build.gradle and ios/Podfile if not already done by the Firebase setup wizard.

4. Configure Google Maps API Key
The app utilizes Google Maps for location tracking.

Get an API key from the Google Cloud Console.

Enable the following APIs in your Google Cloud Project:

Maps SDK for Android

Maps SDK for iOS

Places API

Geocoding API

Add the API key to your project:

Android: Open android/app/src/main/AndroidManifest.xml and add the following inside the <application> tag:

<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY" />

Replace YOUR_API_KEY with your actual Google Maps API Key.

iOS: Open ios/Runner/AppDelegate.swift and add the following inside didFinishLaunchingWithOptions:

import GoogleMaps // Add this import at the top
GMSServices.provideAPIKey("YOUR_API_KEY")

Replace YOUR_API_KEY with your actual Google Maps API Key.

5. Run the app
Once all prerequisites and configurations are complete, you can run the application:

# Install dependencies (if you haven't already)
flutter pub get

# For Android emulator/device
flutter run

# Or for iOS simulator/device
flutter run

🧠 Features Implementation Details
This section provides a brief overview of how core features are handled:

Authentication Flow
Leverages Google Sign-In with firebase_auth for secure user authentication.

Maintains persistent login state using shared_preferences.

Includes robust error handling for common authentication failures.

Friends Management
Uses Cloud Firestore for storing user data and friend connections.

Implements search functionality for users by various criteria.

Manages friend requests (sent/received) with real-time updates via Firestore listeners.

Profile
Displays user details fetched from Google Profile after successful sign-in.

Provides a clear sign-out option.

📂 Project Structure
lib/
├── main.dart                 # App entry point, global theme, and initial route setup
├── models/                   # Data structures (e.g., user, friend request, location)
│   └── user_model.dart       # User data structure, possibly including friend and group info
├── providers/                # State management using `provider` (or similar solution)
│   ├── auth_provider.dart    # Manages authentication state and user session
│   └── location_provider.dart# Handles real-time location updates and map data
├── screens/                  # Top-level screens/pages of the application
│   ├── auth/                 # Authentication-related screens
│   │   ├── login_screen.dart   # User login with Google Sign-In
│   │   └── signup_screen.dart  # User registration (if applicable beyond Google sign-up)
│   ├── friends/              # Screens related to friend management
│   │   ├── add_friends_screen.dart   # Screen to search and add new friends
│   │   ├── friend_requests_screen.dart # Screen to manage pending friend requests
│   │   └── friends_list_screen.dart    # Renamed from friends_family_screen for clarity; displays friends
│   ├── main/                 # Core app navigation and primary content
│   │   └── main_screen.dart  # Main screen orchestrating bottom navigation bar
│   └── profile/              # User profile management
│       └── profile_screen.dart # Displays user profile and settings
├── services/                 # Abstraction layer for business logic and API calls
│   ├── auth_service.dart     # Handles all authentication-related operations
│   └── friend_service.dart   # Manages friend connections, requests, and user searches
│   └── location_service.dart # Manages GPS, geocoding, and location updates
├── utils/                    # Utility functions, constants, and helper classes
│   ├── constants.dart        # Defines app-wide constants (e.g., API keys, route names)
│   └── theme.dart            # Centralized theme data and styling configurations
└── widgets/                  # Reusable UI components used across different screens
    ├── app_map_widget.dart   # Encapsulates Google Maps functionality
    ├── friend_request_item.dart # Widget for displaying a single friend request
    └── custom_bottom_nav_bar.dart # Reusable custom bottom navigation bar

📦 Dependencies
This project relies on the following key dependencies:

Core
flutter: The powerful UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.

provider: A simple, scalable state management solution for Flutter.

shared_preferences: A Flutter plugin for reading and writing simple key-value pairs.

Firebase
firebase_core: Required for any Firebase Flutter app.

firebase_auth: Firebase Authentication plugin.

cloud_firestore: Firebase Cloud Firestore plugin for NoSQL database.

firebase_storage: Firebase Cloud Storage for storing user avatars and other files.

UI & UX
google_maps_flutter: Google Maps plugin for embedding maps in Flutter apps.

cached_network_image: A Flutter library for displaying images from the internet and caching them.

intl: Provides internationalization and localization facilities, useful for date/time formatting.

google_fonts: (Optional, but recommended) Helps to easily use fonts from fonts.google.com.

Location
geolocator: A Flutter plugin that provides easy access to platform-specific location services.

geocoding: A Flutter plugin that provides geocoding and reverse geocoding services.

Utilities
uuid: Generates universally unique IDs.

http: A composable, multi-platform, Future-based API for HTTP requests.

smooth_page_indicator: A widget that shows dots representing pages in a PageView.

🤝 Contributing
Contributions are highly welcome! If you have suggestions, bug reports, or want to contribute code, please follow these steps:

Fork the repository.

Create a new branch (git checkout -b feature/YourFeatureName).

Make your changes.

Commit your changes (git commit -m 'Add new feature').

Push to the branch (git push origin feature/YourFeatureName).

Create a Pull Request.

📄 License
This project is licensed under the MIT License - see the LICENSE file for more details.

🙏 Acknowledgments
The amazing Flutter Team for providing such a powerful and flexible UI framework.

Firebase for offering comprehensive backend services.

OpenStreetMap for open-source map data.