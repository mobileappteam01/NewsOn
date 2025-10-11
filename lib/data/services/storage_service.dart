import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/news_article.dart';

/// Local storage service using Hive for bookmarks and settings
class StorageService {
  static Box<NewsArticle>? _bookmarksBox;
  static Box? _settingsBox;

  /// Initialize Hive and open boxes
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NewsArticleAdapter());
    }

    // Open boxes
    _bookmarksBox = await Hive.openBox<NewsArticle>(AppConstants.bookmarksBoxName);
    _settingsBox = await Hive.openBox(AppConstants.settingsBoxName);
  }

  // ==================== Bookmarks ====================

  /// Add article to bookmarks
  static Future<void> addBookmark(NewsArticle article) async {
    if (_bookmarksBox == null) await initialize();
    
    final bookmarkedArticle = article.copyWith(
      isBookmarked: true,
      bookmarkedAt: DateTime.now(),
    );
    
    await _bookmarksBox!.put(article.articleId ?? article.title, bookmarkedArticle);
  }

  /// Remove article from bookmarks
  static Future<void> removeBookmark(String key) async {
    if (_bookmarksBox == null) await initialize();
    await _bookmarksBox!.delete(key);
  }

  /// Check if article is bookmarked
  static bool isBookmarked(String key) {
    if (_bookmarksBox == null) return false;
    return _bookmarksBox!.containsKey(key);
  }

  /// Get all bookmarked articles
  static List<NewsArticle> getAllBookmarks() {
    if (_bookmarksBox == null) return [];
    return _bookmarksBox!.values.toList();
  }

  /// Get bookmarked article by key
  static NewsArticle? getBookmark(String key) {
    if (_bookmarksBox == null) return null;
    return _bookmarksBox!.get(key);
  }

  /// Clear all bookmarks
  static Future<void> clearAllBookmarks() async {
    if (_bookmarksBox == null) await initialize();
    await _bookmarksBox!.clear();
  }

  /// Get bookmarks count
  static int getBookmarksCount() {
    if (_bookmarksBox == null) return 0;
    return _bookmarksBox!.length;
  }

  // ==================== Settings ====================

  /// Save theme mode
  static Future<void> saveThemeMode(String themeMode) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(AppConstants.themeKey, themeMode);
  }

  /// Get theme mode
  static String getThemeMode() {
    if (_settingsBox == null) return 'system';
    return _settingsBox!.get(AppConstants.themeKey, defaultValue: 'system');
  }

  /// Save language preference
  static Future<void> saveLanguage(String language) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(AppConstants.languageKey, language);
  }

  /// Get language preference
  static String getLanguage() {
    if (_settingsBox == null) return 'en';
    return _settingsBox!.get(AppConstants.languageKey, defaultValue: 'en');
  }

  /// Save country preference
  static Future<void> saveCountry(String country) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(AppConstants.countryKey, country);
  }

  /// Get country preference
  static String getCountry() {
    if (_settingsBox == null) return 'us';
    return _settingsBox!.get(AppConstants.countryKey, defaultValue: 'us');
  }

  /// Save generic setting
  static Future<void> saveSetting(String key, dynamic value) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(key, value);
  }

  /// Get generic setting
  static dynamic getSetting(String key, {dynamic defaultValue}) {
    if (_settingsBox == null) return defaultValue;
    return _settingsBox!.get(key, defaultValue: defaultValue);
  }

  /// Clear all settings
  static Future<void> clearAllSettings() async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.clear();
  }

  // ==================== Cleanup ====================

  /// Close all boxes
  static Future<void> dispose() async {
    await _bookmarksBox?.close();
    await _settingsBox?.close();
  }
}
