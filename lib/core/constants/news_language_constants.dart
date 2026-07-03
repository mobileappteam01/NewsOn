import 'package:flutter/material.dart';

import '../../data/models/language_model.dart';

/// Languages available for news content (API `language` param).
/// App UI may use a smaller ARB-backed set; news can include all Indian languages here.
abstract final class NewsLanguageConstants {
  static final List<LanguageModel> languages = [
    LanguageModel(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flagEmoji: '🇺🇸',
    ),
    LanguageModel(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      isDefault: true,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिंदी',
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'ml',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      flagEmoji: '🇮🇳',
    ),
  ];

  static Map<String, Locale> get localeMap => {
        for (final lang in languages) lang.name: Locale(lang.code),
      };

  static List<Map<String, dynamic>> toRemoteConfigJson() =>
      languages
          .map(
            (lang) => {
              'code': lang.code,
              'name': lang.name,
              'nativeName': lang.nativeName,
              'isDefault': lang.isDefault,
              'isActive': true,
              if (lang.flagEmoji != null) 'flagEmoji': lang.flagEmoji,
            },
          )
          .toList();

  static LanguageModel? findByName(String name) {
    for (final lang in languages) {
      if (lang.name == name) return lang;
    }
    return null;
  }

  static LanguageModel? findByCode(String code) {
    for (final lang in languages) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  static String nativeNameFor(String languageName) =>
      findByName(languageName)?.nativeName ?? languageName;

  static String languageNameForCode(String code) =>
      findByCode(code)?.name ?? 'Tamil';
}
