# ⚠️ BEFORE YOU RUN - Important Setup Steps

## 🔴 CRITICAL: API Key Configuration

**The app will NOT work without a valid API key!**

### Step 1: Get Your API Key

1. Visit: https://newsdata.io/
2. Click "Get API Key" or "Sign Up"
3. Create a free account (takes 2 minutes)
4. Copy your API key from the dashboard

### Step 2: Add API Key to Project

Open this file:
```
lib/core/constants/api_constants.dart
```

Replace this line:
```dart
static const String apiKey = 'YOUR_API_KEY_HERE';
```

With your actual key:
```dart
static const String apiKey = 'pub_123456789abcdef'; // Your actual key
```

**⚠️ Without this step, you'll see "Invalid API Key" errors!**

---

## ✅ Pre-Flight Checklist

### 1. Dependencies Installed?
```bash
flutter pub get
```
✅ Should complete without errors

### 2. Hive Adapters Generated?
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
✅ Should generate `news_article.g.dart`

### 3. API Key Added?
✅ Check `lib/core/constants/api_constants.dart`

### 4. Device/Emulator Ready?
```bash
flutter devices
```
✅ Should show at least one device

---

## 🚀 Run the App

```bash
flutter run
```

---

## 🎯 First Time Usage Flow

1. **Category Selection Screen**
   - Select at least one category
   - Tap "Continue" button

2. **Home Screen**
   - Wait for news to load (2-3 seconds)
   - Scroll through breaking news
   - Tap any article to read

3. **Test Audio**
   - Tap the play button on any article
   - Listen to the article being read

4. **Test Bookmarks**
   - Tap bookmark icon on any article
   - Go to Bookmarks tab
   - See your saved article

5. **Test Search**
   - Go to Search tab
   - Type a keyword (e.g., "technology")
   - Press Enter

---

## 🐛 Common Issues & Solutions

### Issue 1: "Invalid API Key" Error
**Solution**: 
- Verify API key in `api_constants.dart`
- Check for extra spaces or quotes
- Ensure you copied the entire key

### Issue 2: "No Internet Connection" Error
**Solution**:
- Check your internet connection
- Try on a different network
- Check if newsdata.io is accessible

### Issue 3: App Crashes on Startup
**Solution**:
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Issue 4: No News Loading
**Solution**:
- Check API key is correct
- Check internet connection
- Check console for error messages
- Verify you haven't exceeded rate limit (200/day)

### Issue 5: TTS Not Working
**Solution**:
- Test on a physical device (not emulator)
- Check device volume
- Ensure TTS engine is installed on device
- Try restarting the app

### Issue 6: Images Not Loading
**Solution**:
- Check internet connection
- Some articles may not have images
- Wait a few seconds for images to load

---

## 📱 Platform-Specific Notes

### Android
- Minimum SDK: 21 (Android 5.0)
- Internet permission: Already added
- Should work out of the box

### iOS
- Minimum iOS: 12.0
- May need to run `pod install` in ios folder
- TTS should work natively

### Web
- TTS may have limited support
- Some features may not work
- Best experienced on mobile

---

## 🎨 Optional: Add Category Images

The app works without images, but you can add them:

1. Create images for each category
2. Place them in: `assets/images/categories/`
3. Name them: `top.jpg`, `business.jpg`, etc.
4. Recommended size: 400x300px

Categories:
- top.jpg
- business.jpg
- entertainment.jpg
- environment.jpg
- food.jpg
- health.jpg
- politics.jpg
- science.jpg
- sports.jpg
- technology.jpg
- tourism.jpg
- world.jpg

---

## 🔍 Verify Installation

Run these commands to verify everything is set up:

```bash
# Check Flutter installation
flutter doctor

# Check dependencies
flutter pub get

# Check for errors
flutter analyze

# Run tests (optional)
flutter test
```

---

## 📊 Expected Behavior

### On First Launch:
1. Category selection screen appears
2. Select categories and tap Continue
3. Home screen loads with breaking news
4. News articles appear in ~2-3 seconds

### Normal Usage:
- Smooth scrolling
- Images load progressively
- TTS works when tapped
- Bookmarks save instantly
- Search returns results in ~1-2 seconds

---

## 🎯 Quick Test Checklist

After running the app, test these:

- [ ] Category selection works
- [ ] Breaking news loads
- [ ] Can scroll through news
- [ ] Can tap and read article
- [ ] Play button works (TTS)
- [ ] Bookmark button works
- [ ] Can navigate between tabs
- [ ] Search works
- [ ] Dark mode toggle works
- [ ] Pull-to-refresh works

---

## 📞 Still Having Issues?

1. **Check the logs**:
   ```bash
   flutter run --verbose
   ```

2. **Clear everything and start fresh**:
   ```bash
   flutter clean
   rm -rf .dart_tool
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   flutter run
   ```

3. **Check documentation**:
   - README.md
   - SETUP_GUIDE.md
   - API_REFERENCE.md

4. **Verify API status**:
   - Visit https://newsdata.io/
   - Check if API is operational
   - Verify your account status

---

## 🎉 Ready to Go!

Once you've completed the checklist above, you're ready to run:

```bash
flutter run
```

**Enjoy your NewsOn app! 📰🎧**

---

## 💡 Pro Tips

1. **Free API Limits**: 200 requests/day
   - Don't refresh too frequently
   - Cache is your friend

2. **Best Experience**: 
   - Use on physical device for TTS
   - Enable dark mode for better reading
   - Bookmark articles for later

3. **Performance**:
   - Images are cached automatically
   - Bookmarks work offline
   - Pull-to-refresh for latest news

---

**Last Updated**: October 2025  
**Status**: Ready for Launch 🚀
