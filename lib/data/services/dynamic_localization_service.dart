import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_model.dart';

/// Service for managing dynamic localization from Firebase
/// 
/// This service:
/// 1. Fetches available languages from Firebase Remote Config
/// 2. Downloads translation files from Firebase Storage
/// 3. Caches translations locally for offline use
/// 4. Provides translations dynamically without app updates
class DynamicLocalizationService {
  static final DynamicLocalizationService _instance = DynamicLocalizationService._internal();
  factory DynamicLocalizationService() => _instance;
  DynamicLocalizationService._internal();

  // Firebase instances
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Cache keys
  static const String _languagesKey = 'dynamic_languages';
  static const String _languageVersionKey = 'language_version';
  static const String _translationsCachePrefix = 'translations_';

  // In-memory cache
  List<LanguageModel> _supportedLanguages = [];
  Map<String, Map<String, String>> _translationsCache = {};
  String _currentLanguageCode = 'ta'; // Default to Tamil
  String _languageVersion = '1.0.0';
  bool _isInitialized = false;

  // Getters
  List<LanguageModel> get supportedLanguages => _supportedLanguages;
  
  /// Get only active languages (isActive = true) for display in language selector
  List<LanguageModel> get activeLanguages => 
      _supportedLanguages.where((lang) => lang.isActive).toList();
  
  String get currentLanguageCode => _currentLanguageCode;
  bool get isInitialized => _isInitialized;
  String get languageVersion => _languageVersion;

  /// Initialize the service - call this at app startup
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🌐 DynamicLocalizationService already initialized');
      return;
    }

    try {
      debugPrint('🌐 Initializing DynamicLocalizationService...');

      // Step 1: Load cached data first (for offline support)
      await _loadCachedData();

      // Step 2: Fetch latest languages from Remote Config
      await _fetchLanguagesFromRemoteConfig();

      // Step 3: Load translations for current language
      await loadTranslations(_currentLanguageCode);

      _isInitialized = true;
      debugPrint('✅ DynamicLocalizationService initialized successfully');
      debugPrint('🌐 Supported languages: ${_supportedLanguages.map((l) => l.code).toList()}');
      debugPrint('🌐 Current language: $_currentLanguageCode');
    } catch (e) {
      debugPrint('❌ Error initializing DynamicLocalizationService: $e');
      // Use defaults if initialization fails
      _useDefaultLanguages();
      _isInitialized = true;
    }
  }

  /// Load cached data from SharedPreferences
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached languages
      final languagesJson = prefs.getString(_languagesKey);
      if (languagesJson != null && languagesJson.isNotEmpty) {
        final List<dynamic> languagesList = jsonDecode(languagesJson);
        _supportedLanguages = languagesList
            .map((json) => LanguageModel.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint('📦 Loaded ${_supportedLanguages.length} cached languages');
      }

      // Load cached language version
      _languageVersion = prefs.getString(_languageVersionKey) ?? '1.0.0';

      // Load saved current language
      _currentLanguageCode = prefs.getString('selected_language_code') ?? 'ta';

      // Load cached translations for current language
      final translationsJson = prefs.getString('$_translationsCachePrefix$_currentLanguageCode');
      if (translationsJson != null && translationsJson.isNotEmpty) {
        final Map<String, dynamic> translations = jsonDecode(translationsJson);
        _translationsCache[_currentLanguageCode] = translations.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        debugPrint('📦 Loaded cached translations for $_currentLanguageCode');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading cached data: $e');
    }
  }

  /// Fetch languages from Firebase Remote Config
  Future<void> _fetchLanguagesFromRemoteConfig() async {
    try {
      // Get languages JSON from Remote Config
      final languagesJson = _remoteConfig.getString('supported_languages');
      final newVersion = _remoteConfig.getString('language_version');

      if (languagesJson.isNotEmpty) {
        final List<dynamic> languagesList = jsonDecode(languagesJson);
        _supportedLanguages = languagesList
            .map((json) => LanguageModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Check if version changed - need to refresh translations
        final versionChanged = newVersion.isNotEmpty && newVersion != _languageVersion;
        if (versionChanged) {
          debugPrint('🔄 Language version changed: $_languageVersion → $newVersion');
          _languageVersion = newVersion;
          // Clear translations cache to force refresh
          _translationsCache.clear();
        }

        // Save to cache
        await _saveLanguagesToCache();

        debugPrint('✅ Fetched ${_supportedLanguages.length} languages from Remote Config');
      } else {
        debugPrint('⚠️ No languages found in Remote Config, using cached/defaults');
        if (_supportedLanguages.isEmpty) {
          _useDefaultLanguages();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching languages from Remote Config: $e');
      if (_supportedLanguages.isEmpty) {
        _useDefaultLanguages();
      }
    }
  }

  /// Use default languages when Firebase is unavailable
  void _useDefaultLanguages() {
    _supportedLanguages = [
      LanguageModel(
        code: 'en',
        name: 'English',
        nativeName: 'English',
        isDefault: false,
        flagEmoji: '🇺🇸',
      ),
      LanguageModel(
        code: 'ta',
        name: 'Tamil',
        nativeName: 'தமிழ்',
        isDefault: true,
        flagEmoji: '🇮🇳',
      ),
    ];
    debugPrint('📦 Using default languages: ${_supportedLanguages.map((l) => l.code).toList()}');
  }

  /// Save languages to SharedPreferences cache
  Future<void> _saveLanguagesToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languagesJson = jsonEncode(_supportedLanguages.map((l) => l.toJson()).toList());
      await prefs.setString(_languagesKey, languagesJson);
      await prefs.setString(_languageVersionKey, _languageVersion);
      debugPrint('💾 Languages saved to cache');
    } catch (e) {
      debugPrint('⚠️ Error saving languages to cache: $e');
    }
  }

  /// Load translations for a specific language
  /// Downloads from Firebase Storage if not cached
  Future<Map<String, String>> loadTranslations(String languageCode) async {
    // Check in-memory cache first
    if (_translationsCache.containsKey(languageCode)) {
      debugPrint('📦 Using in-memory cached translations for $languageCode');
      return _translationsCache[languageCode]!;
    }

    // Check local file cache
    final cachedTranslations = await _loadTranslationsFromLocalCache(languageCode);
    if (cachedTranslations != null && cachedTranslations.isNotEmpty) {
      _translationsCache[languageCode] = cachedTranslations;
      debugPrint('📦 Loaded translations from local cache for $languageCode');
      return cachedTranslations;
    }

    // Download from Firebase Storage
    try {
      final translations = await _downloadTranslationsFromFirebase(languageCode);
      if (translations.isNotEmpty) {
        _translationsCache[languageCode] = translations;
        await _saveTranslationsToLocalCache(languageCode, translations);
        debugPrint('✅ Downloaded and cached translations for $languageCode');
        return translations;
      }
    } catch (e) {
      debugPrint('⚠️ Error downloading translations for $languageCode: $e');
    }

    // Fallback to bundled translations
    final bundledTranslations = await _loadBundledTranslations(languageCode);
    if (bundledTranslations.isNotEmpty) {
      _translationsCache[languageCode] = bundledTranslations;
      debugPrint('📦 Using bundled translations for $languageCode');
      return bundledTranslations;
    }

    // Return empty map as last resort
    debugPrint('⚠️ No translations found for $languageCode');
    return {};
  }

  /// Download translations from Firebase Storage
  Future<Map<String, String>> _downloadTranslationsFromFirebase(String languageCode) async {
    try {
      // Path in Firebase Storage: languages/en.json, languages/ta.json, etc.
      final ref = _storage.ref('Languages/$languageCode.json');
      
      // Download to local file
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/translations_$languageCode.json');
      
      await ref.writeToFile(localFile);
      
      // Read and parse the file
      final jsonString = await localFile.readAsString();
      final Map<String, dynamic> json = jsonDecode(jsonString);
      
      // Convert to Map<String, String>
      final translations = json.map((key, value) => MapEntry(key, value.toString()));
      
      debugPrint('✅ Downloaded translations for $languageCode from Firebase Storage');
      return translations;
    } catch (e) {
      debugPrint('⚠️ Error downloading translations from Firebase Storage: $e');
      return {};
    }
  }

  /// Load translations from local file cache
  Future<Map<String, String>?> _loadTranslationsFromLocalCache(String languageCode) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/translations_$languageCode.json');
      
      if (await localFile.exists()) {
        final jsonString = await localFile.readAsString();
        final Map<String, dynamic> json = jsonDecode(jsonString);
        return json.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      debugPrint('⚠️ Error loading translations from local cache: $e');
    }
    return null;
  }

  /// Save translations to local file cache
  Future<void> _saveTranslationsToLocalCache(String languageCode, Map<String, String> translations) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/translations_$languageCode.json');
      
      final jsonString = jsonEncode(translations);
      await localFile.writeAsString(jsonString);
      
      // Also save to SharedPreferences for quick access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_translationsCachePrefix$languageCode', jsonString);
      
      debugPrint('💾 Translations saved to local cache for $languageCode');
    } catch (e) {
      debugPrint('⚠️ Error saving translations to local cache: $e');
    }
  }

  /// Load bundled translations from assets (fallback)
  Future<Map<String, String>> _loadBundledTranslations(String languageCode) async {
    // This will use the existing ARB-based translations as fallback
    // The actual implementation depends on how you want to handle this
    // For now, return empty - the app will use the existing localization system
    return {};
  }

  /// Set current language
  Future<void> setLanguage(String languageCode) async {
    if (languageCode == _currentLanguageCode) {
      debugPrint('🌐 Language already set to $languageCode');
      return;
    }

    // Check if language is supported
    final isSupported = _supportedLanguages.any((l) => l.code == languageCode);
    if (!isSupported) {
      debugPrint('⚠️ Language $languageCode is not supported');
      return;
    }

    _currentLanguageCode = languageCode;

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language_code', languageCode);

    // Load translations for new language
    await loadTranslations(languageCode);

    debugPrint('✅ Language changed to $languageCode');
  }

  /// Get translation for a key
  String translate(String key, {Map<String, String>? params}) {
    final translations = _translationsCache[_currentLanguageCode] ?? {};
    String value = translations[key] ?? key;

    // Replace parameters if provided
    if (params != null) {
      params.forEach((paramKey, paramValue) {
        value = value.replaceAll('{$paramKey}', paramValue);
      });
    }

    return value;
  }

  /// Get translation with fallback to English
  String translateWithFallback(String key, {Map<String, String>? params}) {
    // Try current language first
    final currentTranslations = _translationsCache[_currentLanguageCode] ?? {};
    if (currentTranslations.containsKey(key)) {
      String value = currentTranslations[key]!;
      if (params != null) {
        params.forEach((paramKey, paramValue) {
          value = value.replaceAll('{$paramKey}', paramValue);
        });
      }
      return value;
    }

    // Fallback to English
    final englishTranslations = _translationsCache['en'] ?? {};
    if (englishTranslations.containsKey(key)) {
      String value = englishTranslations[key]!;
      if (params != null) {
        params.forEach((paramKey, paramValue) {
          value = value.replaceAll('{$paramKey}', paramValue);
        });
      }
      return value;
    }

    // Return key if no translation found
    return key;
  }

  /// Refresh translations from Firebase
  Future<void> refreshTranslations() async {
    try {
      debugPrint('🔄 Refreshing translations...');

      // Fetch latest languages
      await _fetchLanguagesFromRemoteConfig();

      // Clear in-memory cache
      _translationsCache.clear();

      // Reload translations for current language
      await loadTranslations(_currentLanguageCode);

      debugPrint('✅ Translations refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing translations: $e');
    }
  }

  /// Get default language
  LanguageModel? getDefaultLanguage() {
    return _supportedLanguages.firstWhere(
      (l) => l.isDefault,
      orElse: () => _supportedLanguages.isNotEmpty 
          ? _supportedLanguages.first 
          : LanguageModel(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', isDefault: true),
    );
  }

  /// Get language by code
  LanguageModel? getLanguageByCode(String code) {
    try {
      return _supportedLanguages.firstWhere((l) => l.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Check if a language is supported
  bool isLanguageSupported(String code) {
    return _supportedLanguages.any((l) => l.code == code);
  }

  /// Get current language model
  LanguageModel? get currentLanguage => getLanguageByCode(_currentLanguageCode);

  /// Preload translations for all supported languages (for offline use)
  Future<void> preloadAllTranslations() async {
    debugPrint('🔄 Preloading translations for all languages...');
    for (final language in _supportedLanguages) {
      await loadTranslations(language.code);
    }
    debugPrint('✅ All translations preloaded');
  }
}
