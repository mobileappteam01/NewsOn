import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import '../data/services/dynamic_localization_service.dart';

/// Provider for managing app language selection
/// Works with Flutter's Locale system for proper localization
/// Now supports dynamic languages from Firebase via DynamicLocalizationService
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('ta'); // Default to Tamil

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

  /// Load saved language preference
  Future<void> _loadLanguage() async {
    try {
      final savedLanguageCode = StorageService.getLanguage();
      if (savedLanguageCode.isNotEmpty) {
        // Find locale from language code
        final locale = supportedLanguages.values.firstWhere(
          (loc) => loc.languageCode == savedLanguageCode,
          orElse: () => const Locale('ta'),
        );
        _locale = locale;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading language: $e');
      // Keep default locale
    }
  }

  /// Set language by locale
  Future<void> setLocale(Locale locale) async {
    // Check if locale is supported by comparing language codes
    final isSupported = supportedLanguages.values.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );

    if (isSupported) {
      _locale = locale;
      await StorageService.saveLanguage(locale.languageCode);
      notifyListeners();
      debugPrint('✅ Language changed to: ${locale.languageCode}');
      debugPrint('✅ Locale set to: $_locale');
    } else {
      debugPrint('⚠️ Unsupported locale: ${locale.languageCode}');
    }
  }

  /// Set language by language name (e.g., "English", "Hindi")
  Future<void> setLanguage(String languageName) async {
    if (supportedLanguages.containsKey(languageName)) {
      final locale = supportedLanguages[languageName]!;
      await setLocale(locale);
    } else {
      debugPrint('⚠️ Unsupported language: $languageName');
    }
  }

  /// Get locale from language name
  Locale? getLocaleFromName(String languageName) {
    return supportedLanguages[languageName];
  }

  /// Get list of supported locales
  List<Locale> get supportedLocales => supportedLanguages.values.toList();

  /// Get API language code for NewsData API
  /// Maps locale codes to API language codes (e.g., 'en', 'ta', 'hi')
  String getApiLanguageCode() {
    return _locale.languageCode; // Returns 'en', 'ta', or 'hi'
  }

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
