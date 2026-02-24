import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// Get language preference (app UI language)
  static String getLanguage() {
    if (_settingsBox == null) return 'ta';
    return _settingsBox!.get(AppConstants.languageKey, defaultValue: 'ta');
  }

  /// Save news language preference (language of news content only)
  static Future<void> saveNewsLanguage(String languageCode) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(AppConstants.newsLanguageKey, languageCode);
  }

  /// Get news language preference (language of news content only)
  static String getNewsLanguage() {
    if (_settingsBox == null) return '';
    return _settingsBox!.get(AppConstants.newsLanguageKey, defaultValue: '');
  }

  /// Save background music enabled preference (play BG music while news plays)
  static Future<void> saveBackgroundMusicEnabled(bool enabled) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(AppConstants.backgroundMusicEnabledKey, enabled);
  }

  /// Get background music enabled preference (default true for backward compatibility)
  static bool getBackgroundMusicEnabled() {
    if (_settingsBox == null) return true;
    final v = _settingsBox!.get(
      AppConstants.backgroundMusicEnabledKey,
      defaultValue: true,
    );
    if (v is bool) return v;
    if (v is int) return v != 0;
    return true;
  }

  /// Save background music volume (0.0 to 1.0)
  static Future<void> saveBackgroundMusicVolume(double volume) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(
      AppConstants.backgroundMusicVolumeKey,
      volume.clamp(0.0, 1.0),
    );
  }

  /// Get background music volume (default from AppConstants)
  static double getBackgroundMusicVolume() {
    if (_settingsBox == null) return AppConstants.defaultBackgroundMusicVolume;
    final v = _settingsBox!.get(
      AppConstants.backgroundMusicVolumeKey,
      defaultValue: AppConstants.defaultBackgroundMusicVolume,
    );
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return AppConstants.defaultBackgroundMusicVolume;
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

  /// Save news reading mode preference
  static Future<void> saveNewsReadingMode(String mode) async {
    if (_settingsBox == null) await initialize();
    await _settingsBox!.put(AppConstants.newsReadingModeKey, mode);
    debugPrint('💾 StorageService.saveNewsReadingMode() saved: "$mode"');
  }

  /// Get news reading mode preference
  static String getNewsReadingMode() {
    if (_settingsBox == null) {
      debugPrint('⚠️ StorageService: Settings box is null, returning default reading mode: ${AppConstants.defaultReadingMode}');
      return AppConstants.defaultReadingMode;
    }
    final mode = _settingsBox!.get(
      AppConstants.newsReadingModeKey,
      defaultValue: AppConstants.defaultReadingMode,
    ) as String;
    debugPrint('📖 StorageService.getNewsReadingMode() returning: "$mode"');
    return mode;
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

  // ==================== News Articles Cache ====================

  /// Save breaking news to cache
  static Future<void> saveBreakingNewsCache(List<NewsArticle> articles) async {
    if (_settingsBox == null) await initialize();
    try {
      final jsonList = articles.map((a) => a.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _settingsBox!.put(AppConstants.breakingNewsCacheKey, jsonString);
      debugPrint('💾 Breaking news cached (${articles.length} articles)');
    } catch (e) {
      debugPrint('❌ Error saving breaking news cache: $e');
    }
  }

  /// Get cached breaking news
  static List<NewsArticle> getBreakingNewsCache() {
    if (_settingsBox == null) return [];
    try {
      final jsonString =
          _settingsBox!.get(AppConstants.breakingNewsCacheKey) as String?;
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error loading breaking news cache: $e');
    }
    return [];
  }

  /// Save today's news to cache
  static Future<void> saveTodayNewsCache(List<NewsArticle> articles) async {
    if (_settingsBox == null) await initialize();
    try {
      final jsonList = articles.map((a) => a.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _settingsBox!.put(AppConstants.todayNewsCacheKey, jsonString);
      debugPrint('💾 Today news cached (${articles.length} articles)');
    } catch (e) {
      debugPrint('❌ Error saving today news cache: $e');
    }
  }

  /// Get cached today's news
  static List<NewsArticle> getTodayNewsCache() {
    if (_settingsBox == null) return [];
    try {
      final jsonString =
          _settingsBox!.get(AppConstants.todayNewsCacheKey) as String?;
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error loading today news cache: $e');
    }
    return [];
  }

  /// Save articles to cache (for search/category results)
  static Future<void> saveArticlesCache(List<NewsArticle> articles) async {
    if (_settingsBox == null) await initialize();
    try {
      final jsonList = articles.map((a) => a.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _settingsBox!.put(AppConstants.articlesCacheKey, jsonString);
      debugPrint('💾 Articles cached (${articles.length} articles)');
    } catch (e) {
      debugPrint('❌ Error saving articles cache: $e');
    }
  }

  /// Get cached articles
  static List<NewsArticle> getArticlesCache() {
    if (_settingsBox == null) return [];
    try {
      final jsonString =
          _settingsBox!.get(AppConstants.articlesCacheKey) as String?;
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error loading articles cache: $e');
    }
    return [];
  }

  // ==================== Realtime Database Cache ====================

  /// Save Realtime Database data to cache
  static Future<void> saveRealtimeDbCache(String key, dynamic data) async {
    if (_settingsBox == null) await initialize();
    try {
      final jsonString = jsonEncode(data);
      await _settingsBox!.put('${AppConstants.realtimeDbCacheKey}_$key', jsonString);
      debugPrint('💾 Realtime DB data cached for key: $key');
    } catch (e) {
      debugPrint('❌ Error saving Realtime DB cache: $e');
    }
  }

  /// Get cached Realtime Database data
  static dynamic getRealtimeDbCache(String key) {
    if (_settingsBox == null) return null;
    try {
      final jsonString =
          _settingsBox!.get('${AppConstants.realtimeDbCacheKey}_$key') as String?;
      if (jsonString != null) {
        return jsonDecode(jsonString);
      }
    } catch (e) {
      debugPrint('❌ Error loading Realtime DB cache: $e');
    }
    return null;
  }

  // ==================== Bookmark List Cache ====================

  /// Save bookmark list to cache
  static Future<void> saveBookmarkListCache(List<NewsArticle> bookmarks) async {
    if (_settingsBox == null) await initialize();
    try {
      final jsonList = bookmarks.map((a) => a.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _settingsBox!.put(AppConstants.bookmarkListCacheKey, jsonString);
      debugPrint('💾 Bookmark list cached (${bookmarks.length} bookmarks)');
    } catch (e) {
      debugPrint('❌ Error saving bookmark list cache: $e');
    }
  }

  /// Get cached bookmark list
  static List<NewsArticle> getBookmarkListCache() {
    if (_settingsBox == null) return [];
    try {
      final jsonString =
          _settingsBox!.get(AppConstants.bookmarkListCacheKey) as String?;
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error loading bookmark list cache: $e');
    }
    return [];
  }

  // ==================== Cleanup ====================

  /// Close all boxes
  static Future<void> dispose() async {
    await _bookmarksBox?.close();
    await _settingsBox?.close();
  }
}
