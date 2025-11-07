import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
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

          minimumFetchInterval: const Duration(
            minutes: 1,
          ), // Fetch new values every hour
        ),
      );

      // Set default values
      await _remoteConfig.setDefaults(_getDefaultValues());
      print('✅ Default values set');

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

  /// Get default values for Remote Config
  Map<String, dynamic> _getDefaultValues() {
    return {
      // App Texts
      'app_name': 'NewsOn',
      'splash_welcome_text': 'WELCOME TO',
      'splash_app_name_text': 'NEWSON',
      'splash_swipe_text': 'Swipe To Get Started',
      'auth_title_text': 'Sign In',
      'auth_desc_text': 'Sign in to your account',

      // OnBoarding
      'onboarding_features':
          '[{"title":"Welcome aboard, news enthusiast!","image":"https://example.com/1.png"},{"title":"Read news with only one app, Headnews!","image":"https://example.com/2.png"},{"title":"Get ready to explore the world of news!","image":"https://example.com/3.png"}]',

      // Colors (hex strings)
      'primary_color': '#C70000',
      'secondary_color': '#2C2C2C',
      'background_color': '#FFFFFF',
      'text_primary_color': '#2C2C2C',
      'text_secondary_color': '#757575',
      'card_background_color': '#FFFFFF',
      'dark_background_color': '#121212',

      // Text Sizes
      'splash_welcome_font_size': 32.0,
      'splash_app_name_font_size': 36.0,
      'splash_swipe_font_size': 16.0,
      'display_large_font_size': 32.0,
      'display_medium_font_size': 28.0,
      'display_small_font_size': 24.0,
      'headline_medium_font_size': 20.0,
      'title_large_font_size': 18.0,
      'title_medium_font_size': 16.0,
      'body_large_font_size': 16.0,
      'body_medium_font_size': 14.0,
      'body_small_font_size': 12.0,

      // Font Weights (100-900)
      'splash_welcome_font_weight': 700,
      'splash_app_name_font_weight': 800,
      'splash_swipe_font_weight': 500,

      // UI Dimensions
      'default_padding': 16.0,
      'small_padding': 8.0,
      'large_padding': 24.0,
      'border_radius': 12.0,
      'card_elevation': 2.0,
      'splash_button_height': 64.0,
      'splash_button_border_radius': 40.0,

      // Messages
      'no_internet_error': 'No internet connection. Please check your network.',
      'server_error': 'Server error. Please try again later.',
      'unknown_error': 'An unknown error occurred.',
      'no_data_error': 'No data available.',
      'bookmark_added': 'Added to bookmarks',
      'bookmark_removed': 'Removed from bookmarks',

      // Animation Durations (milliseconds)
      'short_animation_duration': 200,
      'medium_animation_duration': 300,
      'long_animation_duration': 500,

      // Letter Spacing
      'splash_welcome_letter_spacing': 1.0,
      'splash_app_name_letter_spacing': 1.2,
    };
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

      // onBoarding
      onboardingFeatures: _remoteConfig.getString('onboarding_features'),

      // Welcome
      welcomeBgImg: _remoteConfig.getString('welcome_bg_img'),
      welcomeTitleText: _remoteConfig.getString('welcome_title_text'),
      welcomeDescText: _remoteConfig.getString('welcome_desc_text'),

      // Select Category
      selectCategoryTitle: _remoteConfig.getString('categroy_selection_title'),
      selectCategoryDesc: _remoteConfig.getString('categroy_selection_desc'),
      // Colors
      primaryColor: _remoteConfig.getString('primary_color'),
      secondaryColor: _remoteConfig.getString('secondary_color'),
      backgroundColor: _remoteConfig.getString('background_color'),
      textPrimaryColor: _remoteConfig.getString('text_primary_color'),
      textSecondaryColor: _remoteConfig.getString('text_secondary_color'),
      cardBackgroundColor: _remoteConfig.getString('card_background_color'),
      darkBackgroundColor: _remoteConfig.getString('dark_background_color'),

      // Text Sizes
      splashWelcomeFontSize: _remoteConfig.getDouble(
        'splash_welcome_font_size',
      ),
      splashAppNameFontSize: _remoteConfig.getDouble(
        'splash_app_name_font_size',
      ),
      splashSwipeFontSize: _remoteConfig.getDouble('splash_swipe_font_size'),
      displayLargeFontSize: _remoteConfig.getDouble('display_large_font_size'),
      displayMediumFontSize: _remoteConfig.getDouble(
        'display_medium_font_size',
      ),
      displaySmallFontSize: _remoteConfig.getDouble('display_small_font_size'),
      headlineMediumFontSize: _remoteConfig.getDouble(
        'headline_medium_font_size',
      ),
      titleLargeFontSize: _remoteConfig.getDouble('title_large_font_size'),
      titleMediumFontSize: _remoteConfig.getDouble('title_medium_font_size'),
      bodyLargeFontSize: _remoteConfig.getDouble('body_large_font_size'),
      bodyMediumFontSize: _remoteConfig.getDouble('body_medium_font_size'),
      bodySmallFontSize: _remoteConfig.getDouble('body_small_font_size'),

      // Font Weights
      splashWelcomeFontWeight: _remoteConfig.getInt(
        'splash_welcome_font_weight',
      ),
      splashAppNameFontWeight: _remoteConfig.getInt(
        'splash_app_name_font_weight',
      ),
      splashSwipeFontWeight: _remoteConfig.getInt('splash_swipe_font_weight'),

      // UI Dimensions
      defaultPadding: _remoteConfig.getDouble('default_padding'),
      smallPadding: _remoteConfig.getDouble('small_padding'),
      largePadding: _remoteConfig.getDouble('large_padding'),
      borderRadius: _remoteConfig.getDouble('border_radius'),
      cardElevation: _remoteConfig.getDouble('card_elevation'),
      splashButtonHeight: _remoteConfig.getDouble('splash_button_height'),
      splashButtonBorderRadius: _remoteConfig.getDouble(
        'splash_button_border_radius',
      ),

      // Messages
      noInternetError: _remoteConfig.getString('no_internet_error'),
      serverError: _remoteConfig.getString('server_error'),
      unknownError: _remoteConfig.getString('unknown_error'),
      noDataError: _remoteConfig.getString('no_data_error'),
      bookmarkAdded: _remoteConfig.getString('bookmark_added'),
      bookmarkRemoved: _remoteConfig.getString('bookmark_removed'),

      // Animation Durations
      shortAnimationDuration: _remoteConfig.getInt('short_animation_duration'),
      mediumAnimationDuration: _remoteConfig.getInt(
        'medium_animation_duration',
      ),
      longAnimationDuration: _remoteConfig.getInt('long_animation_duration'),

      // Letter Spacing
      splashWelcomeLetterSpacing: _remoteConfig.getDouble(
        'splash_welcome_letter_spacing',
      ),
      splashAppNameLetterSpacing: _remoteConfig.getDouble(
        'splash_app_name_letter_spacing',
      ),

      // No Results Found
      noResultsFound: _remoteConfig.getString('no_results_found'),
      splashAnimatedGif: _remoteConfig.getString('splash_animated_gif'),

      // App Common Images
      appNameLogo: _remoteConfig.getString('app_name_logo'),
      languageImg: _remoteConfig.getString('language_img'),
      headlineImg: _remoteConfig.getString('headline_img'),
      listenIcon: _remoteConfig.getString('listen_img'),
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
