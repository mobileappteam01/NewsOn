// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../data/models/remote_config_model.dart';

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
      displayLarge: TextStyle(
        fontSize: config.displayLargeFontSize,
        fontWeight: FontWeight.bold,
        color: config.textPrimaryColorValue,
      ),
      displayMedium: TextStyle(
        fontSize: config.displayMediumFontSize,
        fontWeight: FontWeight.bold,
        color: config.textPrimaryColorValue,
      ),
      displaySmall: TextStyle(
        fontSize: config.displaySmallFontSize,
        fontWeight: FontWeight.bold,
        color: config.textPrimaryColorValue,
      ),
      headlineMedium: TextStyle(
        fontSize: config.headlineMediumFontSize,
        fontWeight: FontWeight.w600,
        color: config.textPrimaryColorValue,
      ),
      titleLarge: TextStyle(
        fontSize: config.titleLargeFontSize,
        fontWeight: FontWeight.w600,
        color: config.textPrimaryColorValue,
      ),
      titleMedium: TextStyle(
        fontSize: config.titleMediumFontSize,
        fontWeight: FontWeight.w500,
        color: config.textPrimaryColorValue,
      ),
      bodyLarge: TextStyle(
        fontSize: config.bodyLargeFontSize,
        color: config.textPrimaryColorValue,
      ),
      bodyMedium: TextStyle(
        fontSize: config.bodyMediumFontSize,
        color: config.textSecondaryColorValue,
      ),
      bodySmall: TextStyle(
        fontSize: config.bodySmallFontSize,
        color: config.textSecondaryColorValue,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF5F5F5),
      selectedColor: config.primaryColorValue,
      labelStyle: TextStyle(color: config.textPrimaryColorValue),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      ), // 👈 ensures your grey tone stays secondary
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
      displayLarge: TextStyle(
        fontSize: config.displayLargeFontSize,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: config.displayMediumFontSize,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: config.displaySmallFontSize,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: config.headlineMediumFontSize,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: config.titleLargeFontSize,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: config.titleMediumFontSize,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: config.bodyLargeFontSize,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: config.bodyMediumFontSize,
        color: textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: config.bodySmallFontSize,
        color: textSecondary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cardBackground,
      selectedColor: config.primaryColorValue,
      labelStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
