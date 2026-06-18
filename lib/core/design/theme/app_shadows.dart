import 'package:flutter/material.dart';

/// Shadow and elevation system for Durusuna Mobile
/// Provides consistent shadow styles for depth hierarchy
class AppShadows {
  AppShadows._(); // Private constructor to prevent instantiation

  // ============ ELEVATION LEVELS ============
  static const double elevation0 = 0.0; // No shadow
  static const double elevation1 = 1.0; // Subtle
  static const double elevation2 = 2.0; // Light
  static const double elevation3 = 3.0; // Light-medium
  static const double elevation4 = 4.0; // Medium
  static const double elevation6 = 6.0; // Medium-high
  static const double elevation8 = 8.0; // High
  static const double elevation12 = 12.0; // Higher
  static const double elevation16 = 16.0; // Very high
  static const double elevation24 = 24.0; // Maximum

  // ============ SHADOW DEFINITIONS ============
  /// Subtle shadow for slightly elevated elements
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.05),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Light shadow for cards and containers
  static const List<BoxShadow> light = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.08),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Medium shadow for elevated components
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.1),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  /// Medium-high shadow for floating action buttons
  static const List<BoxShadow> mediumHigh = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.12),
      offset: Offset(0, 6),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// High shadow for modals and overlays
  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.15),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Very high shadow for popups
  static const List<BoxShadow> veryHigh = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.2),
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  /// Maximum shadow for dialogs
  static const List<BoxShadow> maximum = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.25),
      offset: Offset(0, 16),
      blurRadius: 32,
      spreadRadius: 0,
    ),
  ];

  // ============ DARK MODE SHADOWS ============
  /// Dark mode subtle shadow
  static const List<BoxShadow> subtleDark = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Dark mode light shadow
  static const List<BoxShadow> lightDark = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.4),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Dark mode medium shadow
  static const List<BoxShadow> mediumDark = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.5),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  // ============ HELPER METHODS ============
  /// Get shadow by elevation level
  static List<BoxShadow> getShadowByElevation(double elevation) {
    if (elevation <= 0) return [];
    if (elevation <= 1) return subtle;
    if (elevation <= 2) return light;
    if (elevation <= 4) return medium;
    if (elevation <= 6) return mediumHigh;
    if (elevation <= 8) return high;
    if (elevation <= 12) return veryHigh;
    return maximum;
  }

  /// Get adaptive shadow based on brightness
  static List<BoxShadow> getAdaptiveShadow({
    required List<BoxShadow> lightShadow,
    required List<BoxShadow> darkShadow,
    required Brightness brightness,
  }) =>
      brightness == Brightness.light ? lightShadow : darkShadow;

  // ============ CUSTOM SHADOW CREATOR ============
  /// Create custom shadow with parameters
  static List<BoxShadow> custom({
    Color color = const Color.fromRGBO(0, 0, 0, 0.1),
    Offset offset = const Offset(0, 4),
    double blurRadius = 8,
    double spreadRadius = 0,
  }) =>
      [
        BoxShadow(
          color: color,
          offset: offset,
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
        ),
      ];
}
