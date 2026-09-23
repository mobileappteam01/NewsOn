import 'package:flutter/material.dart';
import '../core/constants/news_language_constants.dart';
import '../data/services/storage_service.dart';
import '../data/services/dynamic_localization_service.dart';

/// Provider for managing app language (UI) and news language (content) separately.
/// - App language: drives MaterialApp locale and all app UI/localization.
/// - News language: drives only the language of news content (API fetch).
class LanguageProvider extends ChangeNotifier {
  /// App UI language (used by MaterialApp, menus, labels, etc.)
  Locale _locale =
      const Locale('en'); // Default to English when no preference saved

  /// News content language (used only for news API requests)
  String _newsLanguageCode = 'en';

  // Base supported languages (fallback if dynamic loading fails)
  final Map<String, Locale> _baseSupportedLanguages = {
    'English': const Locale('en'),
    'Tamil': const Locale('ta'),
  };

  /// Languages for news API requests (includes Indian regional languages).
  Map<String, Locale> get newsLanguages {
    final Map<String, Locale> languages =
        Map<String, Locale>.from(NewsLanguageConstants.localeMap);

    final dynamicService = DynamicLocalizationService();
    for (final lang in dynamicService.activeLanguages) {
      languages[lang.name] = Locale(lang.code);
    }

    return languages;
  }

  List<String> get newsLanguageNames => newsLanguages.keys.toList();

  String nativeNameForNewsLanguage(String languageName) {
    final fromConstants = NewsLanguageConstants.findByName(languageName);
    if (fromConstants != null) return fromConstants.nativeName;

    final dynamicService = DynamicLocalizationService();
    final dynamicLang = dynamicService.getLanguageByCode(
      newsLanguages[languageName]?.languageCode ?? '',
    );
    if (dynamicLang != null && dynamicLang.nativeName.isNotEmpty) {
      return dynamicLang.nativeName;
    }

    return languageName;
  }

  /// Get supported languages - combines base + dynamic active languages
  Map<String, Locale> get supportedLanguages {
    final dynamicService = DynamicLocalizationService();
    final Map<String, Locale> languages = Map.from(_baseSupportedLanguages);

    // Add only active dynamic languages from Firebase (isActive=true)
    for (final lang in dynamicService.activeLanguages) {
      languages[lang.name] = Locale(lang.code);
    }

    return languages;
  }

  /// Get language names for display (only active languages)
  List<String> get languageNames {
    return supportedLanguages.keys.toList();
  }

  LanguageProvider() {
    _loadLanguage();
  }

  /// Test-only constructor — skips StorageService I/O.
  @visibleForTesting
  LanguageProvider.forTest({String newsLanguageCode = 'en'})
      : _newsLanguageCode = newsLanguageCode;

  Locale get locale => _locale;
  String get selectedLanguage => _getLanguageNameFromLocale(_locale);

  /// Get language name from locale
  String _getLanguageNameFromLocale(Locale locale) {
    for (final entry in supportedLanguages.entries) {
      if (entry.value.languageCode == locale.languageCode) {
        return entry.key;
      }
    }
    return 'English'; // Default fallback when code is unrecognized
  }

  /// Load saved app and news language preferences
  Future<void> _loadLanguage() async {
    try {
      final savedAppCode = StorageService.getLanguage();
      if (savedAppCode.isNotEmpty) {
        final locale = supportedLanguages.values.firstWhere(
          (loc) => loc.languageCode == savedAppCode,
          orElse: () => const Locale('en'),
        );
        _locale = locale;
      }
      final savedNewsCode = StorageService.getNewsLanguage();
      if (savedNewsCode.isNotEmpty) {
        _newsLanguageCode = savedNewsCode;
      } else {
        // Migration: first run after split – use app language as news language
        _newsLanguageCode = _locale.languageCode;
        await StorageService.saveNewsLanguage(_newsLanguageCode);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading language: $e');
    }
  }

  /// Set app language (UI only). Does not change news language.
  Future<void> setLocale(Locale locale) async {
    final isSupported = supportedLanguages.values.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
    // Also accept known UI language codes so Malayalam etc. work even if
    // Remote Config language list has not loaded yet.
    const knownUiCodes = {'en', 'ta', 'hi', 'ml', 'te', 'kn', 'es', 'fr'};
    if (isSupported || knownUiCodes.contains(locale.languageCode)) {
      _locale = locale;
      await StorageService.saveLanguage(locale.languageCode);
      notifyListeners();
      debugPrint('✅ App language changed to: ${locale.languageCode}');
    } else {
      debugPrint('⚠️ Unsupported locale: ${locale.languageCode}');
    }
  }

  /// Set app language by name (e.g. "English", "Tamil"). Does not change news language.
  Future<void> setLanguage(String languageName) async {
    if (supportedLanguages.containsKey(languageName)) {
      final locale = supportedLanguages[languageName]!;
      await setLocale(locale);
      return;
    }

    // Fallback: resolve from dynamic service / news constants by name
    final dynamicService = DynamicLocalizationService();
    final match = dynamicService.supportedLanguages
        .where((l) => l.name == languageName)
        .toList();
    if (match.isNotEmpty) {
      await setLocale(Locale(match.first.code));
      return;
    }

    final fromNews = NewsLanguageConstants.findByName(languageName);
    if (fromNews != null) {
      await setLocale(Locale(fromNews.code));
      return;
    }

    debugPrint('⚠️ Unsupported language: $languageName');
  }

  /// Set news language only (affects news API fetch). Does not change app UI language.
  Future<void> setNewsLanguage(String languageName) async {
    if (newsLanguages.containsKey(languageName)) {
      final code = newsLanguages[languageName]!.languageCode;
      await setNewsLanguageByCode(code);
    } else {
      debugPrint('⚠️ Unsupported news language: $languageName');
    }
  }

  /// Set news language by code (e.g. 'en', 'ta', 'hi').
  Future<void> setNewsLanguageByCode(String code) async {
    final isSupported =
        newsLanguages.values.any((loc) => loc.languageCode == code);
    if (isSupported) {
      _newsLanguageCode = code;
      try {
        await StorageService.saveNewsLanguage(code);
      } catch (_) {
        // Tests / offline — still update in-memory.
      }
      notifyListeners();
      debugPrint('✅ News language changed to: $code');
    } else {
      debugPrint('⚠️ Unsupported news language code: $code');
    }
  }

  /// Test helper — update news language without StorageService.
  @visibleForTesting
  void setNewsLanguageCodeForTest(String code) {
    _newsLanguageCode = code;
    notifyListeners();
  }

  /// Display name for current news language (e.g. "English", "Tamil")
  String get newsLanguageName => _getLanguageNameFromCode(_newsLanguageCode);

  String _getLanguageNameFromCode(String code) {
    for (final entry in newsLanguages.entries) {
      if (entry.value.languageCode == code) return entry.key;
    }
    return NewsLanguageConstants.languageNameForCode(code);
  }

  /// Get locale from language name
  Locale? getLocaleFromName(String languageName) {
    return supportedLanguages[languageName];
  }

  /// Get list of supported locales
  List<Locale> get supportedLocales => supportedLanguages.values.toList();

  /// API language code for news content (used by NewsProvider for API requests)
  String getApiLanguageCode() {
    return _newsLanguageCode;
  }

  /// Current news language code (e.g. 'en', 'ta')
  String get newsLanguageCode => _newsLanguageCode;

  /// Get API language code from locale code
  /// This ensures we always return a valid API language code
  static String getApiLanguageCodeFromLocale(String localeCode) {
    // For dynamic languages, the locale code IS the API language code
    // NewsData API supports: en, ta, hi, ml, etc.
    if (localeCode.isNotEmpty) {
      return localeCode;
    }
    return 'en'; // Default to English when empty
  }
}
