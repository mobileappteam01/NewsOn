import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import '../data/services/dynamic_localization_service.dart';

/// Provider for managing app language (UI) and news language (content) separately.
/// - App language: drives MaterialApp locale and all app UI/localization.
/// - News language: drives only the language of news content (API fetch).
class LanguageProvider extends ChangeNotifier {
  /// App UI language (used by MaterialApp, menus, labels, etc.)
  Locale _locale = const Locale('ta'); // Default to Tamil

  /// News content language (used only for news API requests)
  String _newsLanguageCode = 'ta';

  // Base supported languages (fallback if dynamic loading fails)
  final Map<String, Locale> _baseSupportedLanguages = {
    'English': const Locale('en'),
    'Tamil': const Locale('ta'),
  };

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

  Locale get locale => _locale;
  String get selectedLanguage => _getLanguageNameFromLocale(_locale);

  /// Get language name from locale
  String _getLanguageNameFromLocale(Locale locale) {
    for (final entry in supportedLanguages.entries) {
      if (entry.value.languageCode == locale.languageCode) {
        return entry.key;
      }
    }
    return 'Tamil'; // Default fallback
  }

  /// Load saved app and news language preferences
  Future<void> _loadLanguage() async {
    try {
      final savedAppCode = StorageService.getLanguage();
      if (savedAppCode.isNotEmpty) {
        final locale = supportedLanguages.values.firstWhere(
          (loc) => loc.languageCode == savedAppCode,
          orElse: () => const Locale('ta'),
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
    if (isSupported) {
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
    } else {
      debugPrint('⚠️ Unsupported language: $languageName');
    }
  }

  /// Set news language only (affects news API fetch). Does not change app UI language.
  Future<void> setNewsLanguage(String languageName) async {
    if (supportedLanguages.containsKey(languageName)) {
      final code = supportedLanguages[languageName]!.languageCode;
      await setNewsLanguageByCode(code);
    } else {
      debugPrint('⚠️ Unsupported news language: $languageName');
    }
  }

  /// Set news language by code (e.g. 'en', 'ta').
  Future<void> setNewsLanguageByCode(String code) async {
    final isSupported = supportedLanguages.values
        .any((loc) => loc.languageCode == code);
    if (isSupported) {
      _newsLanguageCode = code;
      await StorageService.saveNewsLanguage(code);
      notifyListeners();
      debugPrint('✅ News language changed to: $code');
    } else {
      debugPrint('⚠️ Unsupported news language code: $code');
    }
  }

  /// Display name for current news language (e.g. "English", "Tamil")
  String get newsLanguageName => _getLanguageNameFromCode(_newsLanguageCode);

  String _getLanguageNameFromCode(String code) {
    for (final entry in supportedLanguages.entries) {
      if (entry.value.languageCode == code) return entry.key;
    }
    return 'Tamil';
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
    return 'ta'; // Default to Tamil
  }
}
