import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom Font Manager Service
/// Manages all custom font configurations and provides easy access to font styles
class FontManager {
  // Font family name
  static const String _fontFamily = 'Crassula';

  // Font weights mapping
  static const FontWeight _thin = FontWeight.w100;
  static const FontWeight _light = FontWeight.w300;
  static const FontWeight _regular = FontWeight.w400;
  static const FontWeight _medium = FontWeight.w500;
  static const FontWeight _bold = FontWeight.w700;
  static const FontWeight _black = FontWeight.w900;

  /// Custom font styles for different text types
  static TextStyle get thin => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _thin,
      );

  static TextStyle get light => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _light,
      );

  static TextStyle get regular => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _regular,
      );

  static TextStyle get medium => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
      );

  static TextStyle get bold => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _bold,
      );

  static TextStyle get black => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _black,
      );

  /// Custom font styles with specific sizes and colors
  static TextStyle get headline1 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _bold,
        fontSize: 32,
        height: 1.2,
      );

  static TextStyle get headline2 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _bold,
        fontSize: 28,
        height: 1.2,
      );

  static TextStyle get headline3 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _bold,
        fontSize: 24,
        height: 1.2,
      );

  static TextStyle get headline4 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 20,
        height: 1.2,
      );

  static TextStyle get headline5 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 18,
        height: 1.2,
      );

  static TextStyle get headline6 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 16,
        height: 1.2,
      );

  static TextStyle get subtitle1 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 16,
        height: 1.4,
      );

  static TextStyle get subtitle2 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _regular,
        fontSize: 14,
        height: 1.4,
      );

  static TextStyle get bodyText1 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _regular,
        fontSize: 16,
        height: 1.5,
      );

  static TextStyle get bodyText2 => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _regular,
        fontSize: 14,
        height: 1.5,
      );

  static TextStyle get button => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 14,
        height: 1.2,
      );

  static TextStyle get caption => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _regular,
        fontSize: 12,
        height: 1.4,
      );

  static TextStyle get overline => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 10,
        height: 1.4,
      );

  /// News-specific font styles
  static TextStyle get newsTitle => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _bold,
        fontSize: 20,
        height: 1.3,
      );

  static TextStyle get newsSubtitle => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 16,
        height: 1.4,
      );

  static TextStyle get newsCategory => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _medium,
        fontSize: 12,
        height: 1.2,
      );

  static TextStyle get newsTimestamp => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _regular,
        fontSize: 11,
        height: 1.2,
      );

  static TextStyle get newsContent => GoogleFonts.openSans(
        // fontFamily: _fontFamily,
        fontWeight: _regular,
        fontSize: 16,
        height: 1.6,
      );

  /// Apply custom font to existing TextStyle
  static TextStyle applyCustomFont(TextStyle originalStyle,
      {FontWeight? weight}) {
    return originalStyle.copyWith(
      fontFamily: _fontFamily,
      fontWeight: weight ?? originalStyle.fontWeight ?? _regular,
    );
  }

  /// Get custom font with specific parameters
  static TextStyle customFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    TextDecoration? decoration,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.openSans(
      // fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight ?? _regular,
      color: color,
      decoration: decoration,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Check if custom font is loaded
  static bool isFontLoaded() {
    // This can be used to verify font loading
    return true; // Placeholder for font loading verification
  }
}

/// Extension methods for easy font usage
extension FontManagerExtensions on TextStyle {
  /// Apply Crassula font to this TextStyle
  TextStyle get crassula => FontManager.applyCustomFont(this);

  /// Apply Crassula font with specific weight
  TextStyle crassulaWithWeight(FontWeight weight) =>
      FontManager.applyCustomFont(this, weight: weight);
}
