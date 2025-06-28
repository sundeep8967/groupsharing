# Firebase Console Configuration Checklist

## Your Current Configuration Details:
- **Project ID**: `group-sharing-9d119`
- **Package Name**: `com.sundeep.groupsharing`
- **Debug SHA-1**: `9B:90:93:99:77:6B:71:E5:17:D0:E8:D6:E8:2D:78:57:E4:F9:DF:91`

## Steps to Verify Firebase Console Settings:

### 1. Access Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `group-sharing-9d119`

### 2. Check Android App Configuration
1. In the Firebase console, click on the **Settings gear icon** → **Project settings**
2. Scroll down to **Your apps** section
3. Find your Android app with package name: `com.sundeep.groupsharing`

### 3. Verify SHA Certificate Fingerprints
1. Click on your Android app in the **Your apps** section
2. Look for **SHA certificate fingerprints** section
3. **CRITICAL**: Ensure this SHA-1 is added:
   ```
   9B:90:93:99:77:6B:71:E5:17:D0:E8:D6:E8:2D:78:57:E4:F9:DF:91
   ```

### 4. Add SHA-1 if Missing
If the SHA-1 is not present:
1. Click **Add fingerprint**
2. Paste: `9B:90:93:99:77:6B:71:E5:17:D0:E8:D6:E8:2D:78:57:E4:F9:DF:91`
3. Click **Save**

### 5. Enable Google Sign-In
1. Go to **Authentication** → **Sign-in method**
2. Click on **Google** provider
3. Ensure it's **Enabled**
4. Verify the **Project support email** is set
5. Click **Save**

### 6. Download Updated google-services.json
After adding the SHA-1:
1. Go back to **Project settings** → **Your apps**
2. Click on your Android app
3. Click **Download google-services.json**
4. Replace the existing file in your project

### 7. OAuth 2.0 Client IDs (Advanced Check)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `group-sharing-9d119`
3. Go to **APIs & Services** → **Credentials**
4. Check that OAuth 2.0 client IDs exist for:
   - Android (with your package name and SHA-1)
   - Web client (for Firebase)

## Expected OAuth Client IDs from your config:
- Android: `343766046263-fjdsvjhfdadktl39rlv3jdp0u1l2oo9v.apps.googleusercontent.com`
- Web: `343766046263-lbl5n43cq11h9vnp1hs7ktdgmf34uoo9.apps.googleusercontent.com`

## After Making Changes:
1. Clean and rebuild your project:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

2. Test Google Sign-In on the new debug APK

## Common Issues and Solutions:

### Issue: "Sign-in failed" or "Network error"
- **Solution**: Ensure SHA-1 is correctly added to Firebase console

### Issue: "Developer error" or "Invalid client"
- **Solution**: Check package name matches exactly: `com.sundeep.groupsharing`

### Issue: "Sign-in cancelled"
- **Solution**: This is normal if user cancels, not an error

### Issue: Still not working after SHA-1 addition
- **Solution**: Wait 5-10 minutes for changes to propagate, then try again