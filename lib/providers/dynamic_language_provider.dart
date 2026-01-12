import 'package:flutter/material.dart';

import '../data/models/language_model.dart';
import '../data/services/dynamic_localization_service.dart';
import '../data/services/storage_service.dart';

/// Provider for managing dynamic language selection
/// 
/// This provider works with DynamicLocalizationService to:
/// 1. Provide list of supported languages from Firebase
/// 2. Handle language switching
/// 3. Notify UI of language changes
/// 4. Maintain backward compatibility with existing LanguageProvider
class DynamicLanguageProvider extends ChangeNotifier {
  final DynamicLocalizationService _localizationService = DynamicLocalizationService();
  
  bool _isLoading = true;
  bool _isInitialized = false;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  
  /// Get all supported languages (including inactive)
  List<LanguageModel> get supportedLanguages => _localizationService.supportedLanguages;
  
  /// Get only active languages for display in language selector
  List<LanguageModel> get activeLanguages => _localizationService.activeLanguages;
  
  String get currentLanguageCode => _localizationService.currentLanguageCode;
  LanguageModel? get currentLanguage => _localizationService.currentLanguage;
  
  /// Get current locale for MaterialApp
  Locale get locale => Locale(_localizationService.currentLanguageCode);
  
  /// Get selected language name for display
  String get selectedLanguage {
    final lang = _localizationService.currentLanguage;
    return lang?.name ?? 'Tamil';
  }

  /// Get list of supported locales for MaterialApp
  List<Locale> get supportedLocales {
    if (_localizationService.supportedLanguages.isEmpty) {
      return [const Locale('en'), const Locale('ta')];
    }
    return _localizationService.supportedLanguages
        .map((l) => Locale(l.code))
        .toList();
  }

  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🌐 DynamicLanguageProvider already initialized');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🌐 Initializing DynamicLanguageProvider...');
      
      // Initialize the localization service
      await _localizationService.initialize();
      
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ DynamicLanguageProvider initialized');
      debugPrint('🌐 Current language: ${_localizationService.currentLanguageCode}');
      debugPrint('🌐 Supported languages: ${supportedLanguages.map((l) => l.code).toList()}');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isInitialized = true; // Mark as initialized even on error to prevent loops
      notifyListeners();
      debugPrint('❌ Error initializing DynamicLanguageProvider: $e');
    }
  }

  /// Set language by locale
  Future<void> setLocale(Locale locale) async {
    await setLanguageByCode(locale.languageCode);
  }

  /// Set language by language code (e.g., 'en', 'ta', 'ml')
  Future<void> setLanguageByCode(String languageCode) async {
    if (languageCode == _localizationService.currentLanguageCode) {
      debugPrint('🌐 Language already set to $languageCode');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _localizationService.setLanguage(languageCode);
      
      // Also save to StorageService for backward compatibility
      await StorageService.saveLanguage(languageCode);
      
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ Language changed to $languageCode');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error setting language: $e');
    }
  }

  /// Set language by language name (e.g., 'English', 'Tamil')
  Future<void> setLanguage(String languageName) async {
    final language = supportedLanguages.firstWhere(
      (l) => l.name == languageName,
      orElse: () => supportedLanguages.isNotEmpty 
          ? supportedLanguages.first 
          : LanguageModel(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    );
    await setLanguageByCode(language.code);
  }

  /// Get translation for a key
  String translate(String key, {Map<String, String>? params}) {
    return _localizationService.translate(key, params: params);
  }

  /// Get translation with fallback to English
  String tr(String key, {Map<String, String>? params}) {
    return _localizationService.translateWithFallback(key, params: params);
  }

  /// Refresh translations from Firebase
  Future<void> refreshTranslations() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _localizationService.refreshTranslations();

      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ Translations refreshed');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error refreshing translations: $e');
    }
  }

  /// Get API language code for news API
  String getApiLanguageCode() {
    return _localizationService.currentLanguageCode;
  }

  /// Get locale from language name
  Locale? getLocaleFromName(String languageName) {
    final language = supportedLanguages.firstWhere(
      (l) => l.name == languageName,
      orElse: () => LanguageModel(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    );
    return Locale(language.code);
  }

  /// Get list of active language names for display in language selector
  List<String> get languageNames {
    if (activeLanguages.isEmpty) {
      return ['English', 'Tamil'];
    }
    return activeLanguages.map((l) => l.name).toList();
  }

  /// Get map of active language names to locales (for language selector)
  Map<String, Locale> get supportedLanguagesMap {
    final map = <String, Locale>{};
    for (final lang in activeLanguages) {
      map[lang.name] = Locale(lang.code);
    }
    if (map.isEmpty) {
      map['English'] = const Locale('en');
      map['Tamil'] = const Locale('ta');
    }
    return map;
  }

  /// Preload all translations for offline use
  Future<void> preloadAllTranslations() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _localizationService.preloadAllTranslations();

      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ All translations preloaded');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error preloading translations: $e');
    }
  }
}
