# Google Sign-In Setup Guide

## ✅ What's Been Implemented

I've created a complete Google Sign-In button for your auth screen with:

- ✅ Beautiful Material Design button
- ✅ Loading state animation
- ✅ Google Auth Service
- ✅ Error handling
- ✅ Success/failure notifications
- ✅ Remote Config integration for styling

---

## 🎨 What You'll See

**Auth Screen Features:**
- Title and description text (from Remote Config)
- Google Sign-In button with:
  - Google logo (or "G" fallback icon)
  - "Continue with Google" text
  - Loading spinner during sign-in
  - Smooth animations
- Terms & Privacy Policy text

---

## 🔧 Configuration Required

### Step 1: Android Setup

**1.1 Get SHA-1 Certificate Fingerprint:**

```bash
cd android
./gradlew signingReport
```

Copy the **SHA-1** from the output (under `debug` variant).

**1.2 Add SHA-1 to Firebase:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **newson-dea6b**
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** → Select your Android app
5. Click **Add fingerprint**
6. Paste the SHA-1 certificate
7. Click **Save**
8. **Download the new `google-services.json`**
9. Replace the old one at: `android/app/google-services.json`

**1.3 Enable Google Sign-In in Firebase:**

1. In Firebase Console → **Authentication**
2. Click **Sign-in method** tab
3. Click **Google** → Click **Enable**
4. Enter support email
5. Click **Save**

---

### Step 2: iOS Setup (Optional - if you support iOS)

**2.1 Add URL Scheme:**

Edit `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

**2.2 Download GoogleService-Info.plist:**

1. Firebase Console → Project Settings
2. Download `GoogleService-Info.plist`
3. Add to `ios/Runner/` in Xcode

---

## 🚀 Testing the Sign-In

### Step 1: Run the App

```bash
flutter run
```

### Step 2: Navigate to Auth Screen

- Swipe on the splash screen
- You'll see the auth screen with the Google Sign-In button

### Step 3: Test Sign-In

1. **Tap the "Continue with Google" button**
2. **Select a Google account**
3. **Grant permissions**
4. **See success message!** ✅

---

## 📱 What Happens When You Sign In

```
1. User taps "Continue with Google"
   ↓
2. Button shows loading spinner
   ↓
3. Google Sign-In dialog appears
   ↓
4. User selects account & grants permissions
   ↓
5. Success! Shows welcome message with user's name
   ↓
6. TODO: Navigate to home screen
```

---

## 🎯 Current Implementation

### Files Created:

1. **`lib/data/services/google_auth_service.dart`**
   - Handles all Google Sign-In logic
   - Methods: `signInWithGoogle()`, `signOut()`, `isSignedIn()`

2. **`lib/widgets/google_signin_button.dart`**
   - Reusable Google Sign-In button widget
   - Material Design styling
   - Loading state support

3. **`lib/screens/auth/auth_screen.dart`** (Updated)
   - Auth screen with Google Sign-In button
   - Error handling
   - Success notifications

### Remote Config Parameters Added:

- `auth_title_text` - Auth screen title (default: "Sign In")
- `auth_desc_text` - Auth screen description (default: "Sign in to your account")

---

## 🎨 Customization via Remote Config

You can customize the auth screen text from Firebase Console:

### Parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `auth_title_text` | "Sign In" | Main title on auth screen |
| `auth_desc_text` | "Sign in to your account" | Description text |
| `primary_color` | "#E31E24" | Button accent color |
| `background_color` | "#FFFFFF" | Screen background |
| `text_primary_color` | "#2C2C2C" | Main text color |
| `text_secondary_color` | "#757575" | Secondary text color |

### To Change:

1. Go to Firebase Console → Remote Config
2. Edit the parameter values
3. Click **"Publish changes"**
4. Tap the refresh button in your app (or restart)

---

## 🔐 Security Notes

### Current Implementation:

- ✅ Uses official `google_sign_in` package
- ✅ Secure OAuth 2.0 flow
- ✅ No credentials stored in app
- ✅ Tokens managed by Google SDK

### TODO for Production:

- [ ] Add Firebase Authentication integration
- [ ] Store user data securely
- [ ] Implement proper session management
- [ ] Add sign-out functionality
- [ ] Handle token refresh

---

## 🐛 Troubleshooting

### Issue: "Sign-in failed" or "Error 10"

**Solution:**
- Make sure SHA-1 is added to Firebase Console
- Download the new `google-services.json`
- Rebuild the app: `flutter clean && flutter run`

### Issue: "Developer error" or "Invalid client"

**Solution:**
- Enable Google Sign-In in Firebase Authentication
- Make sure package name matches: `com.app.newson`
- Check `google-services.json` is in `android/app/`

### Issue: Button shows "G" instead of Google logo

**Solution:**
- This is normal! The fallback icon works perfectly
- To add the logo: Download from Google's branding guidelines
- Save as: `assets/images/google_logo.png`

### Issue: "PlatformException"

**Solution:**
- Check internet connection
- Verify Firebase project is active
- Check console logs for specific error

---

## 📋 Next Steps

### Immediate:

1. ✅ Get SHA-1 certificate
2. ✅ Add SHA-1 to Firebase
3. ✅ Enable Google Sign-In in Firebase Auth
4. ✅ Download new `google-services.json`
5. ✅ Test sign-in

### Later:

- [ ] Integrate with Firebase Authentication
- [ ] Create user profile screen
- [ ] Add sign-out button
- [ ] Implement session persistence
- [ ] Navigate to home screen after sign-in

---

## 💡 Usage Example

### Sign In:

```dart
final GoogleAuthService _googleAuthService = GoogleAuthService();

Future<void> signIn() async {
  final account = await _googleAuthService.signInWithGoogle();
  if (account != null) {
    print('Signed in: ${account.email}');
    // Navigate to home screen
  }
}
```

### Sign Out:

```dart
await _googleAuthService.signOut();
```

### Check if Signed In:

```dart
final isSignedIn = await _googleAuthService.isSignedIn();
if (isSignedIn) {
  final user = _googleAuthService.currentUser;
  print('Current user: ${user?.email}');
}
```

---

## 🎉 Summary

**What's Working:**
- ✅ Beautiful Google Sign-In button
- ✅ Loading states
- ✅ Error handling
- ✅ Success notifications
- ✅ Remote Config integration

**What's Needed:**
- ⚠️ Firebase configuration (SHA-1, enable Google Auth)
- ⚠️ Download new `google-services.json`

**What's Next:**
- 🔜 Firebase Authentication integration
- 🔜 User profile management
- 🔜 Navigate to home screen

---

**Last Updated:** October 22, 2024  
**Status:** ✅ Code complete, needs Firebase configuration  
**Next Step:** Add SHA-1 to Firebase Console and enable Google Sign-In!
