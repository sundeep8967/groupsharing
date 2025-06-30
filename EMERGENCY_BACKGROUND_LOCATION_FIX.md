# 🚨 EMERGENCY BACKGROUND LOCATION FIX

## STEP 1: NUCLEAR PERMISSION RESET
```bash
# If you have ADB access, run these:
adb shell pm reset-permissions
adb shell pm grant com.yourapp.groupsharing android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.yourapp.groupsharing android.permission.ACCESS_BACKGROUND_LOCATION
adb shell pm grant com.yourapp.groupsharing android.permission.ACCESS_COARSE_LOCATION
```

## STEP 2: MANUAL PERMISSION BLITZ
1. **Settings > Apps > GroupSharing > Permissions**
2. **Location** → "Allow all the time" (NOT "While using app")
3. **Physical Activity** → Allow (if available)
4. **Nearby Devices** → Allow (if available)

## STEP 3: BATTERY OPTIMIZATION MURDER
1. **Settings > Battery > Battery Optimization**
2. **Find GroupSharing** → "Don't optimize"
3. **Settings > Battery > App Battery Usage**
4. **GroupSharing** → "Unrestricted"

## STEP 4: AUTOSTART ENFORCEMENT
1. **Settings > Apps > Auto-start management**
2. **Find GroupSharing** → Enable ALL toggles
3. **Settings > Apps > App management > GroupSharing**
4. **Battery** → "No restrictions"

## STEP 5: NOTIFICATION CHANNEL FIX
1. **Settings > Notifications > App notifications**
2. **GroupSharing** → Enable ALL notification types
3. **Allow notification dot** → ON
4. **Show on lock screen** → ON

## STEP 6: DEVELOPER OPTIONS HACK
1. **Settings > About phone** → Tap "Build number" 7 times
2. **Settings > Developer options**
3. **Don't keep activities** → OFF
4. **Background process limit** → "Standard limit"
5. **Mobile data always active** → ON

## STEP 7: LOCATION SERVICES DEEP CHECK
1. **Settings > Location**
2. **Use location** → ON
3. **App location permissions** → GroupSharing → "Allow all the time"
4. **Location services** → Google Location Accuracy → ON
5. **Wi-Fi and Bluetooth scanning** → Both ON