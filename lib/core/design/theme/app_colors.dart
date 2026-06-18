import 'package:flutter/material.dart';

/// Modern semantic color system for Durusuna Mobile
/// Built on Material Design 3 color tokens
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ============ PRIMARY COLOR PALETTE ============
  /// Deep professional blue - primary brand color
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primary90 = Color(0xFF3F5FC9);
  static const Color primary80 = Color(0xFF5B70D9);
  static const Color primary70 = Color(0xFF7682E8);
  static const Color primary60 = Color(0xFF8F95F7);
  static const Color primary50 = Color(0xFFA6AEFF);
  static const Color primary40 = Color(0xFFBCC2FF);
  static const Color primary30 = Color(0xFFD8DBFF);
  static const Color primary20 = Color(0xFFF0F1FF);
  static const Color primary10 = Color(0xFFFBFAFF);

  // ============ SECONDARY COLOR PALETTE ============
  /// Vibrant green - success and positive actions
  static const Color secondary = Color(0xFF059669);
  static const Color secondary90 = Color(0xFF38B376);
  static const Color secondary80 = Color(0xFF54C487);
  static const Color secondary70 = Color(0xFF6ED499);
  static const Color secondary60 = Color(0xFF87E3AA);
  static const Color secondary50 = Color(0xFFA0F1BC);
  static const Color secondary40 = Color(0xFFB9FFCE);
  static const Color secondary30 = Color(0xFFD3FFDD);
  static const Color secondary20 = Color(0xFFEBFFF3);
  static const Color secondary10 = Color(0xFFF7FFFC);

  // ============ TERTIARY COLOR PALETTE ============
  /// Accent blue - interactive elements
  static const Color tertiary = Color(0xFF3B82F6);
  static const Color tertiary90 = Color(0xFF5FA3FF);
  static const Color tertiary80 = Color(0xFF7BBFFF);
  static const Color tertiary70 = Color(0xFF95D4FF);
  static const Color tertiary60 = Color(0xFFADE5FF);
  static const Color tertiary50 = Color(0xFFC7F0FF);
  static const Color tertiary40 = Color(0xFFE1F8FF);
  static const Color tertiary30 = Color(0xFFF0FAFF);
  static const Color tertiary20 = Color(0xFFFCFDFF);
  static const Color tertiary10 = Color(0xFFFFFBFE);

  // ============ NEUTRAL COLOR PALETTE ============
  static const Color neutral100 = Color(0xFF000000);
  static const Color neutral90 = Color(0xFF1F2937);
  static const Color neutral80 = Color(0xFF374151);
  static const Color neutral70 = Color(0xFF4B5563);
  static const Color neutral60 = Color(0xFF6B7280);
  static const Color neutral50 = Color(0xFF9CA3AF);
  static const Color neutral40 = Color(0xFFD1D5DB);
  static const Color neutral30 = Color(0xFFE5E7EB);
  static const Color neutral20 = Color(0xFFF3F4F6);
  static const Color neutral10 = Color(0xFFF9FAFB);
  static const Color neutral0 = Color(0xFFFFFFFF);

  // ============ SEMANTIC COLORS ============
  /// Success state - positive actions and confirmations
  static const Color success = Color(0xFF10B981);
  static const Color successContainer = Color(0xFFD3FFDD);
  static const Color onSuccess = Color(0xFFFFFFFF);

  /// Warning state - caution and attention
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFFF3CD);
  static const Color onWarning = Color(0xFF1F2937);

  /// Error state - errors and destructive actions
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFFEBEE);
  static const Color onError = Color(0xFFFFFFFF);

  /// Info state - informational messages
  static const Color info = Color(0xFF0284C7);
  static const Color infoContainer = Color(0xFFE0F2FE);
  static const Color onInfo = Color(0xFFFFFFFF);

  // ============ SURFACE COLORS ============
  /// Light theme surfaces
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color surfaceBright = Color(0xFFFBFCFD);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF8FAFC);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerHigh = Color(0xFFEBF0F5);
  static const Color surfaceContainerHighest = Color(0xFFE5E7EB);

  /// Dark theme surfaces
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceDarkDim = Color(0xFF0F172A);
  static const Color surfaceDarkBright = Color(0xFF1B2D42);
  static const Color surfaceDarkContainerLowest = Color(0xFF000000);
  static const Color surfaceDarkContainerLow = Color(0xFF1B2D42);
  static const Color surfaceDarkContainer = Color(0xFF1E293B);
  static const Color surfaceDarkContainerHigh = Color(0xFF334155);
  static const Color surfaceDarkContainerHighest = Color(0xFF475569);

  // ============ BACKGROUND COLORS ============
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);

  // ============ TEXT COLORS ============
  /// Light theme text
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textDisabledLight = Color(0xFFD1D5DB);

  /// Dark theme text
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);

  // ============ BORDER & DIVIDER COLORS ============
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF475569);
  static const Color dividerLight = Color(0xFFF3F4F6);
  static const Color dividerDark = Color(0xFF334155);

  // ============ CHAT BUBBLE COLORS ============
  /// Messages from user (sent)
  static const Color chatBubbleUser = Color(0xFFDCF8C6);
  static const Color chatBubbleUserDark = Color(0xFF056162);

  /// Messages from others (received)
  static const Color chatBubbleOther = Color(0xFFFFFFFF);
  static const Color chatBubbleOtherDark = Color(0xFF1F2C34);

  /// Chat background
  static const Color chatBackgroundLight = Color(0xFFECE5DD);
  static const Color chatBackgroundDark = Color(0xFF0B141A);

  // ============ HELPER METHODS ============
  /// Get color scheme based on brightness
  static ColorScheme getLightColorScheme() => const ColorScheme.light(
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    surface: neutral0,
    background: backgroundLight,
    error: error,
    onPrimary: neutral0,
    onSecondary: neutral0,
    onTertiary: neutral0,
    onSurface: textPrimaryLight,
    onBackground: textPrimaryLight,
    onError: neutral0,
  );

  static ColorScheme getDarkColorScheme() => const ColorScheme.dark(
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    surface: surfaceDarkContainer,
    background: backgroundDark,
    error: error,
    onPrimary: neutral0,
    onSecondary: neutral0,
    onTertiary: neutral0,
    onSurface: textPrimaryDark,
    onBackground: textPrimaryDark,
    onError: neutral0,
  );

  /// Get adaptive color based on brightness
  static Color getAdaptiveColor({
    required Color lightColor,
    required Color darkColor,
    required Brightness brightness,
  }) =>
      brightness == Brightness.light ? lightColor : darkColor;

  /// Get opacity variant of color
  static Color withOpacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}
