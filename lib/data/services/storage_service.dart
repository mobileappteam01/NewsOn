import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/news_article.dart';
import '../models/remote_config_model.dart';
import '../models/api_config_model.dart';

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
    _bookmarksBox = await Hive.openBox<NewsArticle>(
      AppConstants.bookmarksBoxName,
    );
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

    await _bookmarksBox!.put(
      article.articleId ?? article.title,
      bookmarkedArticle,
    );
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

  // ==================== Remote Config Cache ====================

  /// Save Remote Config Model to local cache
  static Future<void> saveRemoteConfigCache(RemoteConfigModel config) async {
    if (_settingsBox == null) await initialize();
    try {
      final jsonString = jsonEncode(config.toJson());
      await _settingsBox!.put(AppConstants.remoteConfigCacheKey, jsonString);
      print('💾 Remote Config cached locally');
    } catch (e) {
      print('❌ Error saving Remote Config cache: $e');
    }
  }

  /// Get cached Remote Config Model
  static RemoteConfigModel? getRemoteConfigCache() {
    if (_settingsBox == null) return null;
    try {
      final jsonString =
          _settingsBox!.get(AppConstants.remoteConfigCacheKey) as String?;
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return RemoteConfigModel.fromJson(json);
      }
    } catch (e) {
      print('❌ Error loading Remote Config cache: $e');
    }
    return null;
  }

  /// Clear Remote Config cache
  static Future<void> clearRemoteConfigCache() async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.delete(AppConstants.remoteConfigCacheKey);
  }

  // ==================== API Config Cache ====================

  /// Save API Config Model to local cache
  static Future<void> saveApiConfigCache(ApiConfigModel config) async {
    if (_settingsBox == null) await initialize();
    try {
      final jsonString = jsonEncode(config.toJson());
      await _settingsBox!.put(AppConstants.apiConfigCacheKey, jsonString);
      print('💾 API Config cached locally');
    } catch (e) {
      print('❌ Error saving API Config cache: $e');
    }
  }

  /// Get cached API Config Model
  static ApiConfigModel? getApiConfigCache() {
    if (_settingsBox == null) return null;
    try {
      final jsonString =
          _settingsBox!.get(AppConstants.apiConfigCacheKey) as String?;
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return ApiConfigModel.fromJson(json);
      }
    } catch (e) {
      print('❌ Error loading API Config cache: $e');
    }
    return null;
  }

  /// Clear API Config cache
  static Future<void> clearApiConfigCache() async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.delete(AppConstants.apiConfigCacheKey);
  }

  // ==================== Cleanup ====================

  /// Close all boxes
  static Future<void> dispose() async {
    await _bookmarksBox?.close();
    await _settingsBox?.close();
  }
}
