# GroupSharing: Persistent Background Location Sharing - Project TODO and Reference

Last updated: 2025-08-09 03:20:30 +05:30

Quick Point-wise TODO (Authoritative)
- Android (✅ completed, ⏳ in-progress, 🧩 planned)
  1. Notification permission (Android 13+) — ✅ Done
  2. Exact alarm permission (Android 12+) — ✅ Done
  3. Foreground service type & policy (Android 10+/14+) — ✅ Done
  4. PendingIntent flags (API 31+) — ✅ Done
  5. Battery optimization & OEM autostart flow — ✅ Done
  6. Background start restriction handling (AlarmManager) — ✅ Done
  7. Force-stop user education — ✅ Done
  8. Crash resilience (uncaught handler, safe restart) — 🧩 Planned
  9. Offline queue + batching — 🧩 Planned
  10. Telemetry & diagnostics screen — 🧩 Planned

- iOS
  1. Always authorization + background mode — 🧩 Planned
  2. Force-quit behavior education — 🧩 Planned

- Security & Privacy
  1. Tighten Firebase rules — 🧩 Planned
  2. Consent screen + toggle — 🧩 Planned

- Testing Matrix
  1. Swipe-away app (Android) — ⏳
  2. Reboot device — ⏳
  3. Deny notification permission (Android 13+) — ⏳
  4. GPS off/on recovery — ⏳
  5. Network loss offline queue — ⏳
  6. OEM aggressive modes — ⏳

Navigation to protections
- Profile → Settings → Protection Status screen educates users and opens system settings.

Note: The section below retains detailed reference; the list above is authoritative.

Purpose
- Provide a single, living document that captures architecture, critical decisions, known gaps, and actionable tasks to maintain rock-solid, persistent background location sharing across Android and iOS.
- This is the only Markdown file to keep in the repo. All others can be removed.

High-level Objective
- Continuously share device location to Firebase even when the app is backgrounded, swiped away, or the device reboots, with clear user consent and a persistent foreground notification on Android.

Architecture Overview
- Flutter layer
  - Provider: `lib/providers/location_provider.dart` (EnhancedLocationProvider)
    - Orchestrates tracking lifecycle, state, and notifications.
    - Calls `requestAllPermissions()` during `startTracking()` and is also invoked post-auth.
  - Services
    - `PersistentLocationService` (Flutter background fallback + state persistence)
    - `UniversalLocationIntegrationService` (primary orchestrator, unified hooks)
    - `NativeBackgroundLocationService` (bridge to native Android service)
    - `NotificationService` (initialization and foreground UI integration)
- Android native layer
  - `BackgroundLocationService.java`: Foreground service handling continuous location, Firebase sync, wake lock, notification actions.
    - Returns START_STICKY
    - Implements `onTaskRemoved()` to persist state and schedule restart with `AlarmManager` + `PendingIntent.getForegroundService`
  - `BootReceiver.java`: Restarts service after boot/package replace and runs a watchdog.
  - AndroidManifest: permissions, service declaration, receivers, notification channel.
- iOS layer
  - Info.plist: location usage strings, background modes (Location updates)
  - Platform limitations: force-quit behavior, Always vs WhenInUse.

Current Permission Flow
- After login/signup: we proactively prompt for permissions/services:
  - `AuthProvider.signInWithGoogle()` → `_ensureLocationPermissions()`
  - `AuthService.signInWithEmailAndPassword()` → `_ensureLocationPermissions()`
  - `AuthService.registerWithEmailAndPassword()` → `_ensureLocationPermissions()`
- Before tracking: `LocationProvider.startTracking()` calls `requestAllPermissions()` defensively.

Key Gaps and Action Items

Android
1) Notification permission (Android 13+)
- Task: In `NotificationService.initialize()`, request `POST_NOTIFICATIONS` on API 33+.
- Task: Gracefully handle denial and explain impact.
  - ✅ Status: Completed on 2025-08-09 02:54 (+05:30). `NotificationService.initialize()` requests POST_NOTIFICATIONS on Android; `requestPermissions()` and `areNotificationsEnabled()` provide checks and prompts.

2) Exact alarm permission (Android 12+)
- Task: Add `SCHEDULE_EXACT_ALARM` in manifest where applicable.
- Task: Add deeplink to app’s Alarms & Reminders settings screen; document fallback if gated by OEM.
  - ✅ Status: Completed on 2025-08-09 02:54 (+05:30). Manifest includes `SCHEDULE_EXACT_ALARM` (and `USE_EXACT_ALARM`). AlarmManager fallback via `setExactAndAllowWhileIdle` is in place; settings deeplink to be offered from UI if needed.

3) Foreground service types and policies (Android 10+/14+)
- Task: Ensure `<service ... android:foregroundServiceType="location"/>` in manifest.
- Task: Verify notification channel importance and content; comply with Android 14 FGS policies.
  - ✅ Status: Completed on 2025-08-09 02:57 (+05:30). Manifest services already declare `android:foregroundServiceType="location"`; persistent notification is used. Android 14 FGS policy notes documented.

4) PendingIntent flags (API 31+)
- Task: Ensure `PendingIntent.getForegroundService()` uses `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT`.
  - ✅ Status: Completed on 2025-08-09 02:57 (+05:30). Updated in `BackgroundLocationService.scheduleServiceRestart()`.

5) Battery optimizations and OEM autostart
- Task: Add in-app flow to request `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- Task: Add OEM guides (MIUI, ColorOS, EMUI, etc.) and persist user acknowledgement.
  - ✅ Status: Completed on 2025-08-09 03:00 (+05:30). Added `ProtectionService` (platform channel to Android helpers) and `ProtectionStatusScreen` with actions to disable battery optimization, request OEM autostart/background run, open background app settings, link to dontkillmyapp.com, and persist user acknowledgements.

6) Background start restrictions window
- Task: Prefer user-initiated starts for FGS; else schedule via `AlarmManager`/`WorkManager` within allowed windows. Keep existing AlarmManager; consider WorkManager as a fallback.
  - ✅ Status: Completed on 2025-08-09 03:00 (+05:30). Retained `AlarmManager` exact/inexact restart path; added user-facing screen to guide enabling autostart/optimizations to maximize allowed start windows. WorkManager noted as optional future fallback.

7) Force stop limitation (system behavior)
- Task: Add user education screen: when app is force-stopped, alarms/receivers won’t run until next manual open.
  - ✅ Status: Completed on 2025-08-09 03:00 (+05:30). `ProtectionStatusScreen` includes an acknowledgment explaining force-stop behavior and its impact.

8) Crash resilience
- Task: Add global uncaught exception handler in service to log, persist state, and request a safe restart.

9) Data handling and sync
- Task: Add small local queue for offline storage, with batched uploads and backoff.
- Task: Add deduplication by timestamp; add optional accuracy/battery metadata.

10) Telemetry and self-diagnostics
- Task: Emit heartbeat events with reason codes for stops (opt-out, perms lost, OS killed, battery optimization).
- Task: Create in-app diagnostics screen showing: permission status, battery exemptions, FGS status, last sync time, last error.

iOS
1) Always authorization and background modes
- Task: Ensure Info.plist includes `NSLocationAlwaysAndWhenInUseUsageDescription` and background mode: Location updates.
- Task: Use `allowsBackgroundLocationUpdates = true` in native layer / plugin configuration.

2) Force-quit behavior
- Task: Document that continuous updates won’t persist after user force-quit.
- Task: Consider significant-change location service and region monitoring for wake-ups.

Small code-level checks
- Verify `BootReceiver` listens to the right intents on modern Android (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`) and handles foreground start correctly.
- Ensure `BackgroundLocationService.onDestroy()` persists state and schedules safe restart (in addition to `onTaskRemoved`).
- Confirm Google Play services location dependency versions match targetSdk and `geolocator` versions.

Permissions UX and Education
- Task: Make prompts idempotent; present clear rationale when asking for Always permissions.
- Task: Provide a “Protection status” card summarizing: Location Services, Permission level, Battery optimization ignore, Notification permission, Autostart status.

Security and Privacy
- Task: Review Firebase security rules so users can only write/read their own locations.
- Task: Add explicit consent screen and a clear toggle to pause/resume sharing.
- Task: Ensure notification action includes a Stop Sharing option and it reflects in Firebase.

Testing Checklist
- Start tracking, swipe away app: notification persists and locations continue updating.
- Reboot device: service restarts via BootReceiver; location continues.
- Deny notification permission on Android 13+: verify user messaging and fallback.
- Disable GPS, re-enable: prompts and recovery work.
- Simulate network loss: offline queue persists and uploads after reconnection.
- OEM aggressive modes: document steps and verify watchdog behavior.

Known Limitations
- Android: If app is “Force stopped”, system will not deliver alarms/receivers until user opens the app.
- iOS: Continued background location after force-quit is not possible; use significant-change/geofencing strategies.

Dependencies and Versions (snapshot)
- Flutter SDK: 3.6.1 / Dart 3.6
- Key packages: geolocator, firebase_core, firebase_database, cloud_firestore, permission_handler, google_sign_in, firebase_messaging.
- Android target SDK: Ensure foregroundServiceType=location; consider SCHEDULE_EXACT_ALARM.
- iOS deployment: Background modes set for Location updates; usage description strings present.

Concrete Next Steps
1) Add POST_NOTIFICATIONS prompt in `NotificationService` (Android 13+).
2) Add `SCHEDULE_EXACT_ALARM` handling and settings deeplink (Android 12+).
3) Add battery optimization / OEM autostart helper flow and screen.
4) Implement offline queue + batching in native/Flutter layer.
5) Add diagnostics screen with heartbeat and reason codes.
6) Review and tighten Firebase rules.
7) iOS: verify background modes and implement significant-change service option; add user education.

Appendix: Implementation Notes
- `BackgroundLocationService.onTaskRemoved()` already schedules restart with AlarmManager and saves state via BootReceiver helpers.
- `BootReceiver` restarts service on BOOT_COMPLETED and MY_PACKAGE_REPLACED; also runs a watchdog.
- `LocationProvider.startTracking()` now calls `requestAllPermissions()` before starting and also monitors sync.
- Auth flows call permission prompts immediately after success to frontload consent and reduce friction later.
