// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../data/models/remote_config_model.dart';
import '../services/font_manager.dart';

/// Application theme configuration
class AppTheme {
  // Primary Colors (fallback values)
  static const Color primaryRed = Color(0xFFC70000);
  static const Color darkBackground = Color(0xFF121212);
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);

  // Light Theme with dynamic config
  static ThemeData getLightTheme(RemoteConfigModel config) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: config.primaryColorValue,
        scaffoldBackgroundColor: config.backgroundColorValue,
        colorScheme: ColorScheme.light(
          primary: config.primaryColorValue,
          secondary: config.secondaryColorValue,
          tertiary: Color(0xff757575),
          surface: config.cardBackgroundColorValue,
          background: config.backgroundColorValue,
          error: const Color(0xFFC70000),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: config.backgroundColorValue,
          foregroundColor: config.textPrimaryColorValue,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: config.textPrimaryColorValue,
            fontSize: config.headlineMediumFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: config.cardBackgroundColorValue,
          elevation: config.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(config.borderRadius),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: config.backgroundColorValue,
          selectedItemColor: config.primaryColorValue,
          unselectedItemColor: config.textSecondaryColorValue,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        textTheme: TextTheme(
          displayLarge: FontManager.headline1.copyWith(
            color: config.textPrimaryColorValue,
            fontSize: config.displayLargeFontSize,
          ),
          displayMedium: FontManager.headline2.copyWith(
            color: config.textPrimaryColorValue,
            fontSize: config.displayMediumFontSize,
          ),
          displaySmall: FontManager.headline3.copyWith(
            color: config.textPrimaryColorValue,
            fontSize: config.displaySmallFontSize,
          ),
          headlineMedium: FontManager.headline4.copyWith(
            color: config.textPrimaryColorValue,
            fontSize: config.headlineMediumFontSize,
          ),
          titleLarge: FontManager.headline5.copyWith(
            color: config.textPrimaryColorValue,
            fontSize: config.titleLargeFontSize,
          ),
          titleMedium: FontManager.headline6.copyWith(
            color: config.textPrimaryColorValue,
            fontSize: config.titleMediumFontSize,
          ),
          bodyLarge: FontManager.bodyText1.copyWith(
            color: config.textPrimaryColorValue,
            fontSize: config.bodyLargeFontSize,
          ),
          bodyMedium: FontManager.bodyText2.copyWith(
            color: config.textSecondaryColorValue,
            fontSize: config.bodyMediumFontSize,
          ),
          bodySmall: FontManager.caption.copyWith(
            color: config.textSecondaryColorValue,
            fontSize: config.bodySmallFontSize,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF5F5F5),
          selectedColor: config.primaryColorValue,
          labelStyle: TextStyle(color: config.textPrimaryColorValue),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );

  // Light Theme (static fallback)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryRed,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryRed,
      secondary: Color(0xFF2C2C2C),
      surface: Colors.white,
      error: primaryRed,
    ),
  );

  // Dark Theme with dynamic config
  static ThemeData getDarkTheme(RemoteConfigModel config) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primaryRed,
        scaffoldBackgroundColor: config.darkBackgroundColorValue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: config.primaryColorValue,
          brightness: Brightness.dark,
          secondary: Color.fromARGB(
            242,
            255,
            255,
            255,
          ), // ensures your grey tone stays secondary
          tertiary: Color.fromARGB(255, 255, 255, 255),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: config.darkBackgroundColorValue,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: config.headlineMediumFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: cardBackground,
          elevation: config.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(config.borderRadius),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: cardBackground,
          selectedItemColor: config.primaryColorValue,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        textTheme: TextTheme(
          displayLarge: FontManager.headline1.copyWith(
            color: textPrimary,
            fontSize: config.displayLargeFontSize,
          ),
          displayMedium: FontManager.headline2.copyWith(
            color: textPrimary,
            fontSize: config.displayMediumFontSize,
          ),
          displaySmall: FontManager.headline3.copyWith(
            color: textPrimary,
            fontSize: config.displaySmallFontSize,
          ),
          headlineMedium: FontManager.headline4.copyWith(
            color: textPrimary,
            fontSize: config.headlineMediumFontSize,
          ),
          titleLarge: FontManager.headline5.copyWith(
            color: textPrimary,
            fontSize: config.titleLargeFontSize,
          ),
          titleMedium: FontManager.headline6.copyWith(
            color: textPrimary,
            fontSize: config.titleMediumFontSize,
          ),
          bodyLarge: FontManager.bodyText1.copyWith(
            color: textPrimary,
            fontSize: config.bodyLargeFontSize,
          ),
          bodyMedium: FontManager.bodyText2.copyWith(
            color: textSecondary,
            fontSize: config.bodyMediumFontSize,
          ),
          bodySmall: FontManager.caption.copyWith(
            color: textSecondary,
            fontSize: config.bodySmallFontSize,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: cardBackground,
          selectedColor: config.primaryColorValue,
          labelStyle: const TextStyle(color: textPrimary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );

  // Dark Theme (static fallback)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryRed,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryRed,
      secondary: Color(0xFFE0E0E0),
      surface: cardBackground,
      error: primaryRed,
    ),
  );
}
