# NewsOn - News App with Audio Playback

A modern Flutter news application that allows users to read and listen to news articles using Text-to-Speech technology.

## Features

- 📰 **Browse News**: View latest news from multiple categories
- 🎧 **Audio Playback**: Listen to news articles with Text-to-Speech
- 🔖 **Bookmarks**: Save articles to read later
- 🔍 **Search**: Find specific news articles
- 🌓 **Dark Mode**: Toggle between light and dark themes
- 📱 **Clean UI**: Modern, intuitive interface based on Material Design

## Architecture

This project follows a clean, maintainable architecture:

```
lib/
├── core/
│   ├── constants/      # App-wide constants
│   ├── theme/          # Theme configuration
│   ├── utils/          # Utility functions
│   └── widgets/        # Reusable widgets
├── data/
│   ├── models/         # Data models
│   ├── repositories/   # Repository layer
│   └── services/       # API and local services
├── providers/          # State management (Provider)
└── screens/            # UI screens
```

## Setup Instructions

### Prerequisites

- Flutter SDK (3.7.2 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Newsdata.IO API Key

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd NewsOn
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive adapters**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Configure API Key**
   - Open `lib/core/constants/api_constants.dart`
   - Replace `YOUR_API_KEY_HERE` with your Newsdata.IO API key
   - Get your free API key at: https://newsdata.io/

5. **Run the app**
   ```bash
   flutter run
   ```

## API Configuration

This app uses **Newsdata.IO** API for fetching news articles.

### Getting an API Key

1. Visit [Newsdata.IO](https://newsdata.io/)
2. Sign up for a free account
3. Copy your API key from the dashboard
4. Paste it in `lib/core/constants/api_constants.dart`

### API Features Used

- Latest news endpoint
- Category filtering
- Search functionality
- Multi-language support

## State Management

The app uses **Provider** for state management with the following providers:

- `NewsProvider`: Manages news articles and API calls
- `BookmarkProvider`: Handles bookmark operations
- `TtsProvider`: Controls Text-to-Speech functionality
- `ThemeProvider`: Manages app theme (light/dark mode)

## Key Dependencies

- `provider`: State management
- `http` & `dio`: API requests
- `hive` & `hive_flutter`: Local storage
- `flutter_tts`: Text-to-Speech
- `cached_network_image`: Image caching
- `shimmer`: Loading animations
- `share_plus`: Share functionality
- `url_launcher`: Open external links

## Project Structure Details

### Core Layer
- **Constants**: API endpoints, app configurations
- **Theme**: Light and dark theme definitions
- **Utils**: Helper functions for connectivity, date formatting
- **Widgets**: Reusable UI components (NewsCard, CategoryCard, etc.)

### Data Layer
- **Models**: NewsArticle, NewsResponse
- **Services**: NewsApiService, TtsService, StorageService
- **Repositories**: NewsRepository (abstraction layer)

### Presentation Layer
- **Providers**: State management classes
- **Screens**: UI screens organized by feature

## Features in Detail

### 1. Category Selection
- Select preferred news categories on first launch
- Beautiful grid layout with category images

### 2. News Feed
- Breaking news carousel
- Category-filtered news list
- Pull-to-refresh
- Infinite scroll pagination

### 3. Text-to-Speech
- Play/pause audio for any article
- Persistent audio control bar
- Adjustable speech rate and pitch

### 4. Bookmarks
- Save articles for offline reading
- Search within bookmarks
- Clear all bookmarks option

### 5. Search
- Search news by keywords
- Recent searches history
- Real-time search results

## Customization

### Changing Theme Colors

Edit `lib/core/theme/app_theme.dart`:
```dart
static const Color primaryRed = Color(0xFFE31E24); // Change this
```

### Adding More Categories

Edit `lib/core/constants/api_constants.dart`:
```dart
static const List<String> categories = [
  'top',
  'business',
  // Add more categories
];
```

### Adjusting TTS Settings

Edit `lib/core/constants/app_constants.dart`:
```dart
static const double defaultTtsRate = 0.5;  // Speech rate
static const double defaultTtsPitch = 1.0; // Pitch
```

## Troubleshooting

### Build Runner Issues
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### API Errors
- Verify your API key is correct
- Check your internet connection
- Ensure you haven't exceeded API rate limits

### TTS Not Working
- Check device volume settings
- Ensure TTS engine is installed on device
- Test on a physical device (TTS may not work on some emulators)

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Contact

For questions or support, please open an issue on GitHub.

---

**Note**: This app requires an active internet connection to fetch news articles. Bookmarked articles are stored locally for offline access.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
