import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';

/// Provider for managing app language selection
class LanguageProvider extends ChangeNotifier {
  String _selectedLanguage = 'English';
  
  // Supported languages
  final List<String> supportedLanguages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Arabic',
    'Portuguese',
    'Russian',
  ];

  LanguageProvider() {
    _loadLanguage();
  }

  String get selectedLanguage => _selectedLanguage;

  Future<void> _loadLanguage() async {
    final savedLanguage = StorageService.getLanguage();
    if (savedLanguage.isNotEmpty && supportedLanguages.contains(savedLanguage)) {
      _selectedLanguage = savedLanguage;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String language) async {
    if (supportedLanguages.contains(language)) {
      _selectedLanguage = language;
      await StorageService.saveLanguage(language);
      notifyListeners();
    }
  }
}
