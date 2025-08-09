# GroupSharing Developer Guide

Last updated: 2025-08-09 05:20:00 +05:30

This guide orients developers quickly so you can ship changes fast. It maps the codebase, outlines core flows, and lists high-impact gaps. For live project status and the authoritative checklist, see `todo.md`.

---

## 1) Quick Start

- Flutter: 3.6.x / Dart 3.6
- Platforms: Android primary; iOS support planned for background persistence nuances
- Run:
  - Android: `flutter run -d <device>` (ensure Google Play services enabled if using emulator)
  - iOS: open `ios/Runner.xcworkspace` and run from Xcode or `flutter run -d <device>`
- Firebase:
  - Android `google-services.json` and iOS `GoogleService-Info.plist` must be present

---

## 2) App Architecture (High Level)

- UI: Flutter screens in `lib/screens/**`
- State: Providers in `lib/providers/**`
- Services: Location, permissions, background integration in `lib/services/**`
- Native Android: Services/Receivers in `android/app/src/main/java/com/sundeep/groupsharing/**`
- Native iOS: Managers/Helpers in `ios/Runner/**`
- Data: Firebase Auth, Firestore, Realtime Database

---

## 3) Core Flows Overview

### 3.1 Permission and Setup Flow
- Pre-login/onboarding and before tracking start: `LocationProvider.requestAllPermissions()` (and `ComprehensivePermissionService`) ensure:
  - Location (WhenInUse/Always), background location (Android)
  - Notifications (Android 13+)
  - Battery optimization exemption (Android), OEM autostart guidance
- UI Entrypoints:
  - `Profile → Location Permissions` (`lib/screens/profile/location_permissions_screen.dart`)
  - `Profile → Protection Status` (`lib/screens/protection_status_screen.dart`)

### 3.2 Background Location Sharing
- Flutter Orchestrators:
  - `UniversalLocationIntegrationService` — unified hooks
  - `PersistentLocationService` — state persistence / fallback
  - `NativeBackgroundLocationService` — bridge to native Android service
- Android Native:
  - `BackgroundLocationService.java` — Foreground service; continuous updates; Firebase sync
  - `BootReceiver.java` — Auto-restart after boot/package replace; watchdog
  - Restart logic via `AlarmManager` and `PendingIntent.getForegroundService()` with immutable + update flags
- iOS Native (planned nuance):
  - Managers in `ios/Runner/*LocationManager*.swift` with background modes

### 3.3 Battery Optimization and OEM Settings (Android)
- Dart: `BatteryOptimizationService` (platform channel)
- Screens: `BatteryOptimizationScreen`, `ProtectionStatusScreen`
- Actions: open app settings for “Don’t optimize”, vendor-specific guidance, dontkillmyapp.com link

---

## 4) File Map (Most Relevant)

- `lib/main.dart` — Routes; global setup
- Providers:
  - `lib/providers/location_provider.dart` — Core tracking lifecycle
  - `lib/providers/enhanced_location_provider.dart` — Advanced logic (if present in flow)
- Services:
  - `lib/services/native_background_location_service.dart`
  - `lib/services/persistent_location_service.dart`
  - `lib/services/universal_location_integration_service.dart`
  - `lib/services/notification_service.dart`
  - `lib/services/battery_optimization_service.dart`
  - `lib/services/comprehensive_permission_service.dart`
- UI:
  - `lib/screens/profile/profile_screen.dart` — Profile & Settings
  - `lib/screens/profile/location_permissions_screen.dart` — Permission checklist with fix actions
  - `lib/screens/protection_status_screen.dart` — Battery optimization, autostart guidance
  - `lib/screens/settings/battery_optimization_screen.dart` — Deep links to settings
  - Debug: `lib/screens/debug/native_location_test_screen.dart`, `background_location_fix_screen.dart`
- Android Native:
  - `android/app/src/main/AndroidManifest.xml`
  - `java/com/sundeep/groupsharing/BackgroundLocationService.java`
  - `java/com/sundeep/groupsharing/BootReceiver.java`
  - `java/com/sundeep/groupsharing/BatteryOptimizationHelper.java`
  - `java/com/sundeep/groupsharing/PersistentForegroundNotificationService.java`
- iOS Native:
  - `ios/Runner/BackgroundLocationManager.swift`
  - `ios/Runner/BulletproofLocationManager.swift`
  - `ios/Runner/BulletproofNotificationHelper.swift`
  - `ios/Runner/BulletproofPermissionHelper.swift`

---

## 5) What’s Done vs Pending (Condensed)

For the full authoritative list see `todo.md`. Summary:
- Done:
  - POST_NOTIFICATIONS prompt (Android 13+)
  - SCHEDULE_EXACT_ALARM handling + restart intents
  - Foreground service type=location; Android 14 FGS notes
  - PendingIntent flags: FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT
  - Battery optimization flows and Protection Status screen
  - Education on force-stop/background start windows
  - Settings cleanup (removed Saved Places; Share with Friends toggle)
  - “Open App Settings” fixed to open battery optimization/app settings
  - Moved Native Location Test into Profile > below Protection Status
- Pending (High-Impact):
  1) Crash resilience: global uncaught handler in native service; persist state + safe restart
  2) Offline queue + batching: store locations locally when offline; batch upload with dedupe/backoff
  3) Telemetry/diagnostics: heartbeat, reason codes, in-app diagnostics
  4) iOS: Always authorization flow, background updates; significant-change/geofencing wake-ups
  5) Firebase security rules tightening; explicit consent UI + toggle

---

## 6) How to Change Key Areas Quickly

- Permission UI updates: edit `lib/screens/profile/location_permissions_screen.dart` and wire actions into `ComprehensivePermissionService` and `LocationProvider` methods.
- Battery optimization button actions: `lib/screens/settings/battery_optimization_screen.dart` and `BatteryOptimizationService`.
- Background service behavior (Android): modify `BackgroundLocationService.java` and ensure restart paths (`onTaskRemoved`, `onDestroy`, `BootReceiver`). Check PendingIntent flags and notification channel.
- Start/Stop tracking logic: `LocationProvider.startTracking/stopTracking`, ensure `requestAllPermissions()` precedes start.
- Foreground notification behavior: `notification_service.dart` and Android `PersistentForegroundNotificationService`.

---

## 7) Testing Matrix (Actionable)

- Swipe-away app: location updates keep flowing; notification persists
- Reboot device: service restarts; uploads resume
- Android 13+: deny notifications and validate graceful degradation messaging
- Toggle GPS off/on: prompts show; recovery works
- Offline mode: data queued locally; uploads later; no data loss
- OEM modes (MIUI/ColorOS/EMUI/OneUI): confirm autostart/background run settings applied

---

## 8) Known Pitfalls and Fix Patterns

- Force stop kills all receivers/alarms until manual app open — educate user; avoid relying solely on background starts
- Foreground Service start restrictions (Android 12+) — prefer user-initiated actions; else AlarmManager with exact window
- Exact Alarm permission may be OEM-gated — provide settings deeplink and fallback
- iOS force-quit — background updates stop; use significant-change/geofencing to re-wake

---

## 9) Suggested Next Implementation Steps

1) Add crash resilience in Android service:
   - Global default uncaught handler; persist last state; schedule safe restart; add logs/telemetry
2) Implement offline queue + batching in Flutter service layer
3) Add diagnostics screen showing current permission states, FGS running status, last upload timestamp, last error
4) iOS: verify Info.plist strings and background modes; add significant-change service option
5) Review and tighten Firebase rules; add explicit consent toggle and UX

---

## 10) Glossary

- FGS: Foreground Service (Android)
- SCL: Significant-Change Location (iOS)
- OEM: Original Equipment Manufacturer (e.g., Xiaomi, Oppo)

---

## 11) Pointers for New Contributors

- Start with `todo.md` to understand current status
- Use `Profile → Protection Status` to learn device-specific steps
- For quick debugging, use `Profile → Test Native Location Service`
- Keep platform constraints in mind; never assume background starts will always work across OEMs

---

For any large changes, update `todo.md` and this `DEV_GUIDE.md` to keep the context fresh for the next developer.
