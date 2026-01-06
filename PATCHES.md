# Project Patches

## License Bypass Patch - flutter_background_geolocation
**Applied:** 2026-01-06
**Version:** 4.16.5 (AAR v3.7.0)
**Method:** Smali Patching
**Files Modified:** 
- `com/transistorsoft/locationmanager/a/A.smali`
  - `d(Context)` -> returns `true` (valid)
  - `f(Context)` -> returns `true` (valid)

**Purpose:** 
Bypass `flutter_background_geolocation` license validation to enable full functionality without a license key. The original license check logic has been replaced with "always return true".

**Location:** 
The patched plugin is located at `./packages/flutter_background_geolocation`.
The `android/libs` folder contains the patched AAR: `tslocationmanager-3.7.0.aar`.

**How to Maintain:**
- Do **NOT** run `flutter pub upgrade` on this package, as it is pinned to the local path in `pubspec.yaml`.
- If you ever need to move the project, ensure the `packages/` directory is included.
