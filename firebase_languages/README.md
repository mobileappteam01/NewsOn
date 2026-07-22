# Dynamic Localization - Firebase Setup Guide

This guide explains how to set up Firebase for dynamic localization in the NewsOn app.

## Overview

The dynamic localization system allows you to:
- Add new languages without app updates
- Update translations remotely
- Manage language availability from Firebase Console

## Firebase Setup

### 1. Firebase Remote Config

Add the following parameters in Firebase Console → Remote Config:

#### `supported_languages` (JSON)
```json
[
  {"code": "en", "name": "English", "nativeName": "English", "isDefault": false, "isActive": true, "flagEmoji": "🇺🇸"},
  {"code": "ta", "name": "Tamil", "nativeName": "தமிழ்", "isDefault": true, "isActive": true, "flagEmoji": "🇮🇳"},
  {"code": "hi", "name": "Hindi", "nativeName": "हिंदी", "isDefault": false, "isActive": true, "flagEmoji": "🇮🇳"},
  {"code": "ml", "name": "Malayalam", "nativeName": "മലയാളം", "isDefault": false, "isActive": true, "flagEmoji": "🇮🇳"},
  {"code": "te", "name": "Telugu", "nativeName": "తెలుగు", "isDefault": false, "isActive": true, "flagEmoji": "🇮🇳"},
  {"code": "kn", "name": "Kannada", "nativeName": "ಕನ್ನಡ", "isDefault": false, "isActive": true, "flagEmoji": "🇮🇳"}
]
```

**News language** (home feed globe icon) always includes English, Tamil, Hindi, Malayalam, Telugu, and Kannada from app code, even if Firebase is offline. Firebase `supported_languages` controls the **app UI language** list and optional dynamic translations.

#### `language_version` (String)
```
1.0.0
```

**Note:** Increment `language_version` whenever you update translations to force the app to re-download them.

### 2. Firebase Storage

Upload translation JSON files to Firebase Storage:

```
gs://your-bucket/Languages/
  ├── en.json
  ├── ta.json
  ├── hi.json
  ├── ml.json
  ├── te.json
  ├── kn.json
  └── (add more languages here)
```

#### Storage Rules (firebase.storage.rules)
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow read access to language files for all users
    match /languages/{languageFile} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }
  }
}
```

## Adding a New Language

### Step 1: Create Translation File

Create a new JSON file (e.g., `ml.json` for Malayalam):

```json
{
  "appName": "NewsOn",
  "welcomeTo": "സ്വാഗതം",
  "signIn": "സൈൻ ഇൻ",
  ...
}
```

### Step 2: Upload to Firebase Storage

Upload the file to `gs://your-bucket/languages/ml.json`

### Step 3: Update Remote Config

Update `supported_languages` in Firebase Remote Config:

```json
[
  {"code": "en", "name": "English", "nativeName": "English", "isDefault": false, "flagEmoji": "🇺🇸"},
  {"code": "ta", "name": "Tamil", "nativeName": "தமிழ்", "isDefault": true, "flagEmoji": "🇮🇳"},
  {"code": "ml", "name": "Malayalam", "nativeName": "മലയാളം", "isDefault": false, "flagEmoji": "🇮🇳"}
]
```

### Step 4: Increment Version

Update `language_version` to force app to refresh:
```
1.0.1
```

### Step 5: Publish Changes

Click "Publish changes" in Firebase Remote Config.

**That's it!** The new language will be available in the app without any app update.

## Translation File Format

Each translation file should be a JSON object with key-value pairs:

```json
{
  "key": "translated text",
  "keyWithParam": "Hello {name}!",
  ...
}
```

### Parameters

Use `{paramName}` syntax for dynamic values:
```json
{
  "signInFailed": "Sign-in failed: {error}",
  "welcomeUser": "Welcome, {name}!"
}
```

## Files in This Directory

Upload these JSON files to Firebase Storage under `Languages/` (or `languages/`):

- `en.json`, `ta.json`, `hi.json` — also shipped in `assets/languages/`
- `ml.json`, `te.json`, `kn.json` — required for Malayalam / Telugu / Kannada UI
- `README.md` — this guide

The app loads `assets/languages/{code}.json` as a bundled base layer so bottom-nav
and other UI strings still update offline even if Storage is unreachable or a
partial cache exists on the device.

## How It Works

1. **App Startup**: The app fetches `supported_languages` from Remote Config
2. **Language Selection**: User selects a language from the available list
3. **Download**: App downloads the translation file from Firebase Storage
4. **Cache**: Translations are cached locally for offline use
5. **Display**: App uses cached translations for UI text

## Offline Support

- Languages list is cached locally
- Translation files are cached after first download
- App works offline with cached data
- New translations are downloaded when online

## Troubleshooting

### Translations not updating?
1. Increment `language_version` in Remote Config
2. Publish Remote Config changes
3. Force close and reopen the app

### New language not showing?
1. Check `supported_languages` JSON is valid
2. Ensure language file is uploaded to correct path
3. Check Firebase Storage rules allow read access

### App crashes on language change?
1. Verify JSON file is valid (use a JSON validator)
2. Check all required keys are present
3. Check Firebase Storage file permissions
