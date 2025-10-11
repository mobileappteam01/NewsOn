# NewsOn - Quick Setup Guide

## 🚀 Getting Started

### Step 1: Get Your API Key

1. Visit [Newsdata.IO](https://newsdata.io/)
2. Click "Get API Key" or "Sign Up"
3. Create a free account
4. Copy your API key from the dashboard

### Step 2: Configure the API Key

Open `lib/core/constants/api_constants.dart` and replace the placeholder:

```dart
static const String apiKey = 'YOUR_API_KEY_HERE'; // Replace with your actual key
```

### Step 3: Run the App

```bash
flutter run
```

## 📱 First Time Usage

1. **Category Selection**: On first launch, select your preferred news categories
2. **Browse News**: View breaking news and category-specific articles
3. **Listen to News**: Tap the play button on any article to listen
4. **Bookmark**: Tap the bookmark icon to save articles for later
5. **Search**: Use the search tab to find specific news

## 🎨 UI Screens Overview

### 1. Category Selection Screen
- Grid of news categories with images
- Multi-select functionality
- Continue button to proceed to main app

### 2. Home Screen (News Feed)
- **Breaking News**: Horizontal scrolling carousel with large cards
- **Today's News**: Category-filtered news list
- **Category Chips**: Quick filter by selected categories
- **Pull to Refresh**: Swipe down to refresh news
- **Infinite Scroll**: Automatically loads more as you scroll

### 3. Categories Tab
- Horizontal scrolling category grid
- Tap any category to view its news
- Dynamic news list based on selection

### 4. Bookmarks Tab
- All saved articles in one place
- Search within bookmarks
- Clear all option
- Sorted by most recent

### 5. Search Tab
- Search bar for keywords
- Recent searches history
- Real-time search results

### 6. News Detail Screen
- Full article view with large image
- Author information and metadata
- **Listen to Article** button (TTS)
- Bookmark and share options
- "Read Full Article" button to open in browser

## 🎧 Audio Features

### Text-to-Speech Controls
- **Play Button**: Start reading the article
- **Pause Button**: Pause the audio
- **Stop Button**: Stop and close the audio player
- **Persistent Control Bar**: Shows at bottom when audio is playing

### TTS Settings (Customizable)
Located in `lib/core/constants/app_constants.dart`:
- Speech Rate: 0.5 (default)
- Pitch: 1.0 (default)
- Volume: 1.0 (default)

## 🌓 Theme Toggle

- Tap the sun/moon icon in the app bar
- Switches between light and dark mode
- Preference is saved locally

## 🔖 Bookmark Management

- **Add Bookmark**: Tap bookmark icon on any article
- **Remove Bookmark**: Tap filled bookmark icon
- **View All**: Go to Bookmarks tab
- **Search**: Use search bar in Bookmarks tab
- **Clear All**: Tap delete icon in app bar

## 📊 Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   ├── api_constants.dart      # API configuration
│   │   └── app_constants.dart      # App-wide constants
│   ├── theme/
│   │   └── app_theme.dart          # Theme definitions
│   ├── utils/
│   │   ├── connectivity_helper.dart
│   │   └── date_formatter.dart
│   └── widgets/
│       ├── news_card.dart          # Reusable news card
│       ├── category_card.dart      # Category selection card
│       ├── breaking_news_card.dart # Breaking news card
│       └── loading_shimmer.dart    # Loading animation
├── data/
│   ├── models/
│   │   ├── news_article.dart       # Article model
│   │   └── news_response.dart      # API response model
│   ├── repositories/
│   │   └── news_repository.dart    # Data abstraction layer
│   └── services/
│       ├── news_api_service.dart   # API calls
│       ├── tts_service.dart        # Text-to-Speech
│       └── storage_service.dart    # Local storage (Hive)
├── providers/
│   ├── news_provider.dart          # News state management
│   ├── bookmark_provider.dart      # Bookmark state
│   ├── tts_provider.dart           # TTS state
│   └── theme_provider.dart         # Theme state
├── screens/
│   ├── category_selection/         # Initial category screen
│   ├── home/                       # Main home with tabs
│   ├── categories/                 # Categories tab
│   ├── bookmarks/                  # Bookmarks tab
│   ├── search/                     # Search tab
│   └── news_detail/                # Article detail screen
└── main.dart                       # App entry point
```

## 🛠️ Customization Tips

### Change Primary Color
Edit `lib/core/theme/app_theme.dart`:
```dart
static const Color primaryRed = Color(0xFFE31E24);
```

### Add More Categories
Edit `lib/core/constants/api_constants.dart`:
```dart
static const List<String> categories = [
  'top',
  'business',
  'entertainment',
  // Add your categories here
];
```

### Adjust News Per Page
Edit `lib/core/constants/app_constants.dart`:
```dart
static const int newsPerPage = 10; // Change this value
```

## 🐛 Common Issues

### Issue: "Invalid API Key"
**Solution**: Verify your API key in `api_constants.dart` is correct

### Issue: "No internet connection"
**Solution**: Check your device's internet connection

### Issue: TTS not working
**Solution**: 
- Test on a physical device (emulators may have issues)
- Check device volume settings
- Ensure TTS engine is installed

### Issue: Images not loading
**Solution**: 
- Check internet connection
- Some articles may not have images
- Clear app cache and restart

## 📝 Development Notes

### State Management
- Uses **Provider** pattern
- All providers are initialized in `main.dart`
- Providers are accessible throughout the app

### Local Storage
- Uses **Hive** for fast, lightweight storage
- Bookmarks are stored locally
- Settings (theme, preferences) are persisted

### API Integration
- **Newsdata.IO** API
- Supports pagination with `nextPage` token
- Category filtering
- Search functionality

## 🎯 Next Steps

1. **Add Category Images**: Place images in `assets/images/categories/`
2. **Customize Theme**: Modify colors in `app_theme.dart`
3. **Add Analytics**: Integrate Firebase Analytics
4. **Add Push Notifications**: For breaking news alerts
5. **Offline Mode**: Cache articles for offline reading

## 📞 Support

If you encounter any issues:
1. Check the README.md for detailed documentation
2. Review the troubleshooting section
3. Open an issue on GitHub

---

**Happy Coding! 🎉**
