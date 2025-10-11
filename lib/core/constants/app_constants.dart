/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'NewsOn';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String bookmarksBoxName = 'bookmarks';
  static const String settingsBoxName = 'settings';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String countryKey = 'country';
  
  // Pagination
  static const int newsPerPage = 10;
  static const int maxCachedPages = 5;
  
  // TTS Settings
  static const double defaultTtsRate = 0.5;
  static const double defaultTtsPitch = 1.0;
  static const double defaultTtsVolume = 1.0;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Error Messages
  static const String noInternetError = 'No internet connection. Please check your network.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unknownError = 'An unknown error occurred.';
  static const String noDataError = 'No data available.';
  
  // Success Messages
  static const String bookmarkAdded = 'Added to bookmarks';
  static const String bookmarkRemoved = 'Removed from bookmarks';
  
  // Category Images (placeholder URLs - replace with actual assets)
  static const Map<String, String> categoryImages = {
    'top': 'assets/images/categories/top.jpg',
    'business': 'assets/images/categories/business.jpg',
    'entertainment': 'assets/images/categories/entertainment.jpg',
    'environment': 'assets/images/categories/environment.jpg',
    'food': 'assets/images/categories/food.jpg',
    'health': 'assets/images/categories/health.jpg',
    'politics': 'assets/images/categories/politics.jpg',
    'science': 'assets/images/categories/science.jpg',
    'sports': 'assets/images/categories/sports.jpg',
    'technology': 'assets/images/categories/technology.jpg',
    'tourism': 'assets/images/categories/tourism.jpg',
    'world': 'assets/images/categories/world.jpg',
  };
}
