import 'package:flutter/material.dart';

/// Model for Remote Config data
class RemoteConfigModel {
  // App Texts
  final String appName;
  final String splashWelcomeText;
  final String splashAppNameText;
  final String splashSwipeText;
  final String authTitleText;
  final String authDescText;
  // OnBoarding
  final String onboardingFeatures;

  // Colors (stored as hex strings)
  final String primaryColor;
  final String secondaryColor;
  final String backgroundColor;
  final String textPrimaryColor;
  final String textSecondaryColor;
  final String cardBackgroundColor;
  final String darkBackgroundColor;

  // Text Sizes
  final double splashWelcomeFontSize;
  final double splashAppNameFontSize;
  final double splashSwipeFontSize;
  final double displayLargeFontSize;
  final double displayMediumFontSize;
  final double displaySmallFontSize;
  final double headlineMediumFontSize;
  final double titleLargeFontSize;
  final double titleMediumFontSize;
  final double bodyLargeFontSize;
  final double bodyMediumFontSize;
  final double bodySmallFontSize;

  // Font Weights (stored as int: 100-900)
  final int splashWelcomeFontWeight;
  final int splashAppNameFontWeight;
  final int splashSwipeFontWeight;

  // UI Dimensions
  final double defaultPadding;
  final double smallPadding;
  final double largePadding;
  final double borderRadius;
  final double cardElevation;
  final double splashButtonHeight;
  final double splashButtonBorderRadius;

  // Messages
  final String noInternetError;
  final String serverError;
  final String unknownError;
  final String noDataError;
  final String bookmarkAdded;
  final String bookmarkRemoved;

  // Animation Durations (in milliseconds)
  final int shortAnimationDuration;
  final int mediumAnimationDuration;
  final int longAnimationDuration;

  // Letter Spacing
  final double splashWelcomeLetterSpacing;
  final double splashAppNameLetterSpacing;

  // API Keys
  final String newsApiKey;

  ///No Results Found
  final String? noResultsFound;

  // Images
  final String? getStartedImg;
  final String? splashAnimatedGif;
  RemoteConfigModel({
    // App Texts
    this.appName = 'NewsOn',
    this.splashWelcomeText = 'WELCOME TO',
    this.splashAppNameText = 'NEWSON',
    this.splashSwipeText = 'Swipe To Get Started',
    this.authTitleText = 'Sign In',
    this.authDescText = 'Sign in to your account',
    // OnBoarding
    this.onboardingFeatures = '',
    // Colors
    this.primaryColor = '#C70000',
    this.secondaryColor = '#2C2C2C',
    this.backgroundColor = '#FFFFFF',
    this.textPrimaryColor = '#2C2C2C',
    this.textSecondaryColor = '#757575',
    this.cardBackgroundColor = '#FFFFFF',
    this.darkBackgroundColor = '#121212',

    // Text Sizes
    this.splashWelcomeFontSize = 32.0,
    this.splashAppNameFontSize = 36.0,
    this.splashSwipeFontSize = 16.0,
    this.displayLargeFontSize = 32.0,
    this.displayMediumFontSize = 28.0,
    this.displaySmallFontSize = 24.0,
    this.headlineMediumFontSize = 20.0,
    this.titleLargeFontSize = 18.0,
    this.titleMediumFontSize = 16.0,
    this.bodyLargeFontSize = 16.0,
    this.bodyMediumFontSize = 14.0,
    this.bodySmallFontSize = 12.0,

    // Font Weights
    this.splashWelcomeFontWeight = 700,
    this.splashAppNameFontWeight = 800,
    this.splashSwipeFontWeight = 500,

    // UI Dimensions
    this.defaultPadding = 16.0,
    this.smallPadding = 8.0,
    this.largePadding = 24.0,
    this.borderRadius = 12.0,
    this.cardElevation = 2.0,
    this.splashButtonHeight = 64.0,
    this.splashButtonBorderRadius = 40.0,

    // Messages
    this.noInternetError = 'No internet connection. Please check your network.',
    this.serverError = 'Server error. Please try again later.',
    this.unknownError = 'An unknown error occurred.',
    this.noDataError = 'No data available.',
    this.bookmarkAdded = 'Added to bookmarks',
    this.bookmarkRemoved = 'Removed from bookmarks',

    // Animation Durations
    this.shortAnimationDuration = 200,
    this.mediumAnimationDuration = 300,
    this.longAnimationDuration = 500,

    // Letter Spacing
    this.splashWelcomeLetterSpacing = 1.0,
    this.splashAppNameLetterSpacing = 1.2,

    // API Keys
    this.newsApiKey = '',
    //No Results Found
    this.noResultsFound,

    // Images
    this.getStartedImg,
    this.splashAnimatedGif,
  });

  // Helper method to convert hex string to Color
  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // Helper method to convert font weight int to FontWeight
  FontWeight intToFontWeight(int weight) {
    switch (weight) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
      default:
        return FontWeight.normal;
    }
  }

  // Getters for Color objects
  Color get primaryColorValue => hexToColor(primaryColor);
  Color get secondaryColorValue => hexToColor(secondaryColor);
  Color get backgroundColorValue => hexToColor(backgroundColor);
  Color get textPrimaryColorValue => hexToColor(textPrimaryColor);
  Color get textSecondaryColorValue => hexToColor(textSecondaryColor);
  Color get cardBackgroundColorValue => hexToColor(cardBackgroundColor);
  Color get darkBackgroundColorValue => hexToColor(darkBackgroundColor);

  // Getters for FontWeight objects
  FontWeight get splashWelcomeFontWeightValue =>
      intToFontWeight(splashWelcomeFontWeight);
  FontWeight get splashAppNameFontWeightValue =>
      intToFontWeight(splashAppNameFontWeight);
  FontWeight get splashSwipeFontWeightValue =>
      intToFontWeight(splashSwipeFontWeight);

  // Getters for Duration objects
  Duration get shortAnimationDurationValue =>
      Duration(milliseconds: shortAnimationDuration);
  Duration get mediumAnimationDurationValue =>
      Duration(milliseconds: mediumAnimationDuration);
  Duration get longAnimationDurationValue =>
      Duration(milliseconds: longAnimationDuration);
}
