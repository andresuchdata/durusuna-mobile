import 'package:flutter/material.dart';

/// Modern typography system for Durusuna Mobile
/// Follows Material Design 3 typography scale
class AppTypography {
  AppTypography._(); // Private constructor to prevent instantiation

  // ============ FONT FAMILY ============
  static const String fontFamily = 'Inter';
  static const String fontFamilyMono = 'Courier';

  // ============ FONT WEIGHTS ============
  static const FontWeight thin = FontWeight.w100;
  static const FontWeight extralight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;

  // ============ LETTER SPACING ============
  static const double letterSpacingTight = -0.05;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.02;
  static const double letterSpacingXWide = 0.05;

  // ============ LINE HEIGHT MULTIPLIERS ============
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;
  static const double lineHeightLoose = 2.0;

  // ============ DISPLAY TEXT STYLES (Large Headlines) ============
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: bold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightTight,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: bold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightTight,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: bold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightTight,
  );

  // ============ HEADLINE TEXT STYLES ============
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: bold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightNormal,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: bold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightNormal,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: semibold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightNormal,
  );

  // ============ TITLE TEXT STYLES ============
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: semibold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightNormal,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: semibold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingTight,
    height: lineHeightNormal,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: semibold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingNormal,
    height: lineHeightNormal,
  );

  // ============ BODY TEXT STYLES ============
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: normal,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingNormal,
    height: lineHeightRelaxed,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: normal,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingNormal,
    height: lineHeightRelaxed,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: normal,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingWide,
    height: lineHeightRelaxed,
  );

  // ============ LABEL TEXT STYLES ============
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: medium,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingWide,
    height: lineHeightNormal,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: medium,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingWide,
    height: lineHeightNormal,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: semibold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingXWide,
    height: lineHeightNormal,
  );

  // ============ CAPTION TEXT STYLES ============
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: normal,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingWide,
    height: lineHeightNormal,
  );

  static const TextStyle captionSmall = TextStyle(
    fontSize: 9,
    fontWeight: normal,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingWide,
    height: lineHeightNormal,
  );

  // ============ OVERLINE TEXT STYLES ============
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: semibold,
    fontFamily: fontFamily,
    letterSpacing: letterSpacingXWide,
    height: lineHeightNormal,
    decoration: TextDecoration.none,
  );

  // ============ HELPER: GET TEXT THEME ============
  static TextTheme getLightTextTheme() => const TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );

  static TextTheme getDarkTextTheme() => const TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
