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

  // Welcome Image
  final String welcomeBgImg;
  final String welcomeTitleText;
  final String welcomeDescText;

  // Select Category
  final String selectCategoryTitle;
  final String selectCategoryDesc;

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

  /// No news found for selected date
  final String noNewsForDate;

  /// Text size preview text
  final String textSizePreviewText;

  // Images
  final String? getStartedImg;
  final String? splashAnimatedGif;

  // App Common Images
  final String appNameLogo;
  final String languageImg;
  final String headlineImg;
  final String listenIcon;
  final String? appIcon; // Dynamic app icon from Firebase Realtime Database

  // Drawer Contents
  final List<dynamic> drawerMenu;
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

    // Welcome
    this.welcomeBgImg = '',
    this.welcomeTitleText = '',
    this.welcomeDescText = '',

    // Select Category
    this.selectCategoryTitle = '',
    this.selectCategoryDesc = '',
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
    // No news for date
    this.noNewsForDate = 'No news found for this date',
    // Text size preview text
    this.textSizePreviewText =
        'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.\n\nIt has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.\n\nLorem Ipsum is simply dummy text of the printing and typesetting industry.',

    // Images
    this.getStartedImg,
    this.splashAnimatedGif,

    // App Common Images
    this.appNameLogo = '',
    this.languageImg = '',
    this.headlineImg = '',
    this.listenIcon = '',
    this.appIcon, // Dynamic app icon from Firebase Realtime Database

    // Drawer Contents
    this.drawerMenu = const [],
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

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'splashWelcomeText': splashWelcomeText,
      'splashAppNameText': splashAppNameText,
      'splashSwipeText': splashSwipeText,
      'authTitleText': authTitleText,
      'authDescText': authDescText,
      'onboardingFeatures': onboardingFeatures,
      'welcomeBgImg': welcomeBgImg,
      'welcomeTitleText': welcomeTitleText,
      'welcomeDescText': welcomeDescText,
      'selectCategoryTitle': selectCategoryTitle,
      'selectCategoryDesc': selectCategoryDesc,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'backgroundColor': backgroundColor,
      'textPrimaryColor': textPrimaryColor,
      'textSecondaryColor': textSecondaryColor,
      'cardBackgroundColor': cardBackgroundColor,
      'darkBackgroundColor': darkBackgroundColor,
      'splashWelcomeFontSize': splashWelcomeFontSize,
      'splashAppNameFontSize': splashAppNameFontSize,
      'splashSwipeFontSize': splashSwipeFontSize,
      'displayLargeFontSize': displayLargeFontSize,
      'displayMediumFontSize': displayMediumFontSize,
      'displaySmallFontSize': displaySmallFontSize,
      'headlineMediumFontSize': headlineMediumFontSize,
      'titleLargeFontSize': titleLargeFontSize,
      'titleMediumFontSize': titleMediumFontSize,
      'bodyLargeFontSize': bodyLargeFontSize,
      'bodyMediumFontSize': bodyMediumFontSize,
      'bodySmallFontSize': bodySmallFontSize,
      'splashWelcomeFontWeight': splashWelcomeFontWeight,
      'splashAppNameFontWeight': splashAppNameFontWeight,
      'splashSwipeFontWeight': splashSwipeFontWeight,
      'defaultPadding': defaultPadding,
      'smallPadding': smallPadding,
      'largePadding': largePadding,
      'borderRadius': borderRadius,
      'cardElevation': cardElevation,
      'splashButtonHeight': splashButtonHeight,
      'splashButtonBorderRadius': splashButtonBorderRadius,
      'noInternetError': noInternetError,
      'serverError': serverError,
      'unknownError': unknownError,
      'noDataError': noDataError,
      'bookmarkAdded': bookmarkAdded,
      'bookmarkRemoved': bookmarkRemoved,
      'shortAnimationDuration': shortAnimationDuration,
      'mediumAnimationDuration': mediumAnimationDuration,
      'longAnimationDuration': longAnimationDuration,
      'splashWelcomeLetterSpacing': splashWelcomeLetterSpacing,
      'splashAppNameLetterSpacing': splashAppNameLetterSpacing,
      'newsApiKey': newsApiKey,
      'noResultsFound': noResultsFound,
      'noNewsForDate': noNewsForDate,
      'textSizePreviewText': textSizePreviewText,
      'getStartedImg': getStartedImg,
      'splashAnimatedGif': splashAnimatedGif,
      'appNameLogo': appNameLogo,
      'languageImg': languageImg,
      'headlineImg': headlineImg,
      'listenIcon': listenIcon,
      'appIcon': appIcon,
      'drawerMenu': drawerMenu,
    };
  }

  /// Create from JSON for local storage
  factory RemoteConfigModel.fromJson(Map<String, dynamic> json) {
    return RemoteConfigModel(
      appName: json['appName'] as String? ?? 'NewsOn',
      splashWelcomeText: json['splashWelcomeText'] as String? ?? 'WELCOME TO',
      splashAppNameText: json['splashAppNameText'] as String? ?? 'NEWSON',
      splashSwipeText:
          json['splashSwipeText'] as String? ?? 'Swipe To Get Started',
      authTitleText: json['authTitleText'] as String? ?? 'Sign In',
      authDescText:
          json['authDescText'] as String? ?? 'Sign in to your account',
      onboardingFeatures: json['onboardingFeatures'] as String? ?? '',
      welcomeBgImg: json['welcomeBgImg'] as String? ?? '',
      welcomeTitleText: json['welcomeTitleText'] as String? ?? '',
      welcomeDescText: json['welcomeDescText'] as String? ?? '',
      selectCategoryTitle: json['selectCategoryTitle'] as String? ?? '',
      selectCategoryDesc: json['selectCategoryDesc'] as String? ?? '',
      primaryColor: json['primaryColor'] as String? ?? '#C70000',
      secondaryColor: json['secondaryColor'] as String? ?? '#2C2C2C',
      backgroundColor: json['backgroundColor'] as String? ?? '#FFFFFF',
      textPrimaryColor: json['textPrimaryColor'] as String? ?? '#2C2C2C',
      textSecondaryColor: json['textSecondaryColor'] as String? ?? '#757575',
      cardBackgroundColor: json['cardBackgroundColor'] as String? ?? '#FFFFFF',
      darkBackgroundColor: json['darkBackgroundColor'] as String? ?? '#121212',
      splashWelcomeFontSize:
          (json['splashWelcomeFontSize'] as num?)?.toDouble() ?? 32.0,
      splashAppNameFontSize:
          (json['splashAppNameFontSize'] as num?)?.toDouble() ?? 36.0,
      splashSwipeFontSize:
          (json['splashSwipeFontSize'] as num?)?.toDouble() ?? 16.0,
      displayLargeFontSize:
          (json['displayLargeFontSize'] as num?)?.toDouble() ?? 32.0,
      displayMediumFontSize:
          (json['displayMediumFontSize'] as num?)?.toDouble() ?? 28.0,
      displaySmallFontSize:
          (json['displaySmallFontSize'] as num?)?.toDouble() ?? 24.0,
      headlineMediumFontSize:
          (json['headlineMediumFontSize'] as num?)?.toDouble() ?? 20.0,
      titleLargeFontSize:
          (json['titleLargeFontSize'] as num?)?.toDouble() ?? 18.0,
      titleMediumFontSize:
          (json['titleMediumFontSize'] as num?)?.toDouble() ?? 16.0,
      bodyLargeFontSize:
          (json['bodyLargeFontSize'] as num?)?.toDouble() ?? 16.0,
      bodyMediumFontSize:
          (json['bodyMediumFontSize'] as num?)?.toDouble() ?? 14.0,
      bodySmallFontSize:
          (json['bodySmallFontSize'] as num?)?.toDouble() ?? 12.0,
      splashWelcomeFontWeight: json['splashWelcomeFontWeight'] as int? ?? 700,
      splashAppNameFontWeight: json['splashAppNameFontWeight'] as int? ?? 800,
      splashSwipeFontWeight: json['splashSwipeFontWeight'] as int? ?? 500,
      defaultPadding: (json['defaultPadding'] as num?)?.toDouble() ?? 16.0,
      smallPadding: (json['smallPadding'] as num?)?.toDouble() ?? 8.0,
      largePadding: (json['largePadding'] as num?)?.toDouble() ?? 24.0,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 12.0,
      cardElevation: (json['cardElevation'] as num?)?.toDouble() ?? 2.0,
      splashButtonHeight:
          (json['splashButtonHeight'] as num?)?.toDouble() ?? 64.0,
      splashButtonBorderRadius:
          (json['splashButtonBorderRadius'] as num?)?.toDouble() ?? 40.0,
      noInternetError:
          json['noInternetError'] as String? ??
          'No internet connection. Please check your network.',
      serverError:
          json['serverError'] as String? ??
          'Server error. Please try again later.',
      unknownError:
          json['unknownError'] as String? ?? 'An unknown error occurred.',
      noDataError: json['noDataError'] as String? ?? 'No data available.',
      bookmarkAdded: json['bookmarkAdded'] as String? ?? 'Added to bookmarks',
      bookmarkRemoved:
          json['bookmarkRemoved'] as String? ?? 'Removed from bookmarks',
      shortAnimationDuration: json['shortAnimationDuration'] as int? ?? 200,
      mediumAnimationDuration: json['mediumAnimationDuration'] as int? ?? 300,
      longAnimationDuration: json['longAnimationDuration'] as int? ?? 500,
      splashWelcomeLetterSpacing:
          (json['splashWelcomeLetterSpacing'] as num?)?.toDouble() ?? 1.0,
      splashAppNameLetterSpacing:
          (json['splashAppNameLetterSpacing'] as num?)?.toDouble() ?? 1.2,
      newsApiKey: json['newsApiKey'] as String? ?? '',
      noResultsFound: json['noResultsFound'] as String?,
      noNewsForDate:
          json['noNewsForDate'] as String? ?? 'No news found for this date',
      textSizePreviewText:
          json['textSizePreviewText'] as String? ??
          'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.\n\nIt has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.\n\nLorem Ipsum is simply dummy text of the printing and typesetting industry.',
      getStartedImg: json['getStartedImg'] as String?,
      splashAnimatedGif: json['splashAnimatedGif'] as String?,
      appNameLogo: json['appNameLogo'] as String? ?? '',
      languageImg: json['languageImg'] as String? ?? '',
      headlineImg: json['headlineImg'] as String? ?? '',
      listenIcon: json['listenIcon'] as String? ?? '',
      appIcon: json['appIcon'] as String?,
      drawerMenu: json['drawerMenu'] as List<dynamic>? ?? const [],
    );
  }
}
