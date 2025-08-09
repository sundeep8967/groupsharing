Reverse geocoding implemented
- Replace placeholder reverse geocoding with `geocoding` package in `lib/providers/location_provider.dart`.
- Throttle reverse geocoding (>=60s or >50m movement) to avoid rate limits.
- Trigger address update after getting current position and on location updates.

Follow-ups
- Map initial center: fetch one-time location even when provider is already initialized and tracking is off. Adjust `_buildMapScreen()` in `lib/screens/main/main_screen.dart` to call `getCurrentLocationForMap()` when `currentLocation == null` (guard with local fetched flag).
- Consolidate map widgets: keep `SmoothModernMap`; remove `CustomMap` (migrated family dashboard) and deprecate/remove `ModernMap`.
- Align map tile userAgentPackageName: use `com.sundeep.groupsharing` consistently.
- Providers cleanup: confirm only `LocationProvider` is wired; mark `EnhancedLocationProvider` and `MinimalLocationProvider` as legacy or remove.
- Native services unification: ensure only one native service abstraction is used (`NativeBackgroundLocationService` vs `NativeLocationService`).
- Use `geocoding` to populate address in any other UI that still shows placeholders.
