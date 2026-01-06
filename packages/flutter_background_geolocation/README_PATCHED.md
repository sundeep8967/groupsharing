# Patched flutter_background_geolocation

⚠️ **DO NOT DELETE OR UPDATE FROM PUB** ⚠️

This is a **patched version** of `flutter_background_geolocation` that includes a license bypass for Android.

**Modifications:**
- The Android AAR correctly returns `true` for all license checks.
- Build configuration uses local `.aar` files instead of remote repositories.

**Source:**
- Original Version: 4.18.2
- AAR Patch Date: 2026-01-06

**Usage:**
Referenced in `pubspec.yaml` via local path:
```yaml
flutter_background_geolocation:
  path: packages/flutter_background_geolocation
```
