import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../models/remote_config_model.dart';

/// Service to manage Firebase Remote Config
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  
  /// Initialize Remote Config with default values and fetch settings
  Future<void> initialize() async {
    try {
      print('🔥 Initializing Firebase Remote Config...');
      
      // Set config settings
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1), // Fetch new values every hour
        ),
      );

      // Set default values from JSON file
      final defaults = await _getDefaultValuesFromAsset();
      await _remoteConfig.setDefaults(defaults);
      print('✅ Default values set from JSON');

      // Fetch and activate
      final activated = await _remoteConfig.fetchAndActivate();
      print('✅ Remote Config fetch and activate: $activated');
      
      // Log the app name to verify
      final appName = _remoteConfig.getString('app_name');
      print('📱 App Name from Remote Config: $appName');
      
    } catch (e) {
      print('❌ Error initializing Remote Config: $e');
    }
  }

  /// Load default values from asset JSON file
  Future<Map<String, dynamic>> _getDefaultValuesFromAsset() async {
    try {
      final jsonString = await rootBundle.loadString('assets/remote_config_defaults.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return jsonMap;
    } catch (e) {
      print('❌ Error loading default values from asset: $e');
      return {};
    }
  }

  /// Get current config as RemoteConfigModel
  RemoteConfigModel getConfig() {
    return RemoteConfigModel(
      // App Texts
      appName: _remoteConfig.getString('app_name'),
      splashWelcomeText: _remoteConfig.getString('splash_welcome_text'),
      splashAppNameText: _remoteConfig.getString('splash_app_name_text'),
      splashSwipeText: _remoteConfig.getString('splash_swipe_text'),
      authTitleText: _remoteConfig.getString('auth_title_text'),
      authDescText: _remoteConfig.getString('auth_desc_text'),
      
      // Colors
      primaryColor: _remoteConfig.getString('primary_color'),
      secondaryColor: _remoteConfig.getString('secondary_color'),
      backgroundColor: _remoteConfig.getString('background_color'),
      textPrimaryColor: _remoteConfig.getString('text_primary_color'),
      textSecondaryColor: _remoteConfig.getString('text_secondary_color'),
      cardBackgroundColor: _remoteConfig.getString('card_background_color'),
      darkBackgroundColor: _remoteConfig.getString('dark_background_color'),
      
      // Text Sizes
      splashWelcomeFontSize: _remoteConfig.getDouble('splash_welcome_font_size'),
      splashAppNameFontSize: _remoteConfig.getDouble('splash_app_name_font_size'),
      splashSwipeFontSize: _remoteConfig.getDouble('splash_swipe_font_size'),
      displayLargeFontSize: _remoteConfig.getDouble('display_large_font_size'),
      displayMediumFontSize: _remoteConfig.getDouble('display_medium_font_size'),
      displaySmallFontSize: _remoteConfig.getDouble('display_small_font_size'),
      headlineMediumFontSize: _remoteConfig.getDouble('headline_medium_font_size'),
      titleLargeFontSize: _remoteConfig.getDouble('title_large_font_size'),
      titleMediumFontSize: _remoteConfig.getDouble('title_medium_font_size'),
      bodyLargeFontSize: _remoteConfig.getDouble('body_large_font_size'),
      bodyMediumFontSize: _remoteConfig.getDouble('body_medium_font_size'),
      bodySmallFontSize: _remoteConfig.getDouble('body_small_font_size'),
      
      // Font Weights
      splashWelcomeFontWeight: _remoteConfig.getInt('splash_welcome_font_weight'),
      splashAppNameFontWeight: _remoteConfig.getInt('splash_app_name_font_weight'),
      splashSwipeFontWeight: _remoteConfig.getInt('splash_swipe_font_weight'),
      
      // UI Dimensions
      defaultPadding: _remoteConfig.getDouble('default_padding'),
      smallPadding: _remoteConfig.getDouble('small_padding'),
      largePadding: _remoteConfig.getDouble('large_padding'),
      borderRadius: _remoteConfig.getDouble('border_radius'),
      cardElevation: _remoteConfig.getDouble('card_elevation'),
      splashButtonHeight: _remoteConfig.getDouble('splash_button_height'),
      splashButtonBorderRadius: _remoteConfig.getDouble('splash_button_border_radius'),
      
      // Messages
      noInternetError: _remoteConfig.getString('no_internet_error'),
      serverError: _remoteConfig.getString('server_error'),
      unknownError: _remoteConfig.getString('unknown_error'),
      noDataError: _remoteConfig.getString('no_data_error'),
      bookmarkAdded: _remoteConfig.getString('bookmark_added'),
      bookmarkRemoved: _remoteConfig.getString('bookmark_removed'),
      
      // Animation Durations
      shortAnimationDuration: _remoteConfig.getInt('short_animation_duration'),
      mediumAnimationDuration: _remoteConfig.getInt('medium_animation_duration'),
      longAnimationDuration: _remoteConfig.getInt('long_animation_duration'),
      
      // Letter Spacing
      splashWelcomeLetterSpacing: _remoteConfig.getDouble('splash_welcome_letter_spacing'),
      splashAppNameLetterSpacing: _remoteConfig.getDouble('splash_app_name_letter_spacing'),

      // API Keys
      newsApiKey: _remoteConfig.getString('news_api_key'),
    );
  }

  /// Fetch latest config values
  Future<bool> fetchConfig() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      if (updated) {
        print('🔄 Remote Config updated with new values');
      } else {
        print('ℹ️ Remote Config already up to date');
      }
      return updated;
    } catch (e) {
      print('❌ Error fetching Remote Config: $e');
      return false;
    }
  }
  
  /// Force fetch config (ignores minimum fetch interval)
  Future<bool> forceFetchConfig() async {
    try {
      // Temporarily set fetch interval to 0 to force immediate fetch
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero, // Force fetch immediately
        ),
      );
      
      final updated = await _remoteConfig.fetchAndActivate();
      
      // Reset to normal fetch interval
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      
      if (updated) {
        print('🔄 Remote Config force updated with new values');
      }
      return updated;
    } catch (e) {
      print('❌ Error force fetching Remote Config: $e');
      return false;
    }
  }
}
