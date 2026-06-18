import 'package:flutter/material.dart';

/// Responsive design helper for Durusuna Mobile
/// Provides breakpoints and utilities for responsive layouts
class ResponsiveHelper {
  ResponsiveHelper._(); // Private constructor to prevent instantiation

  // ============ BREAKPOINTS (in logical pixels) ============
  /// Mobile breakpoint - small phones
  static const double breakpointMobileSmall = 320;

  /// Mobile breakpoint - medium phones
  static const double breakpointMobileMedium = 375;

  /// Mobile breakpoint - large phones
  static const double breakpointMobileLarge = 414;

  /// Tablet breakpoint - small tablets
  static const double breakpointTabletSmall = 600;

  /// Tablet breakpoint - medium tablets
  static const double breakpointTabletMedium = 768;

  /// Tablet breakpoint - large tablets
  static const double breakpointTabletLarge = 1024;

  /// Desktop breakpoint - small desktop
  static const double breakpointDesktopSmall = 1200;

  /// Desktop breakpoint - large desktop
  static const double breakpointDesktopLarge = 1920;

  // ============ DEVICE TYPE DETECTION ============
  /// Check if device is small phone (< 375dp)
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointMobileMedium;

  /// Check if device is phone (< 600dp)
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointTabletSmall;

  /// Check if device is tablet (600dp - 1024dp)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointTabletSmall && width < breakpointTabletLarge;
  }

  /// Check if device is desktop (>= 1024dp)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointTabletLarge;

  /// Check if device is landscape
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Check if device is portrait
  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  // ============ SIZE GETTERS ============
  /// Get screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Get device pixel ratio
  static double devicePixelRatio(BuildContext context) =>
      MediaQuery.of(context).devicePixelRatio;

  /// Get safe area padding
  static EdgeInsets safeAreaPadding(BuildContext context) =>
      MediaQuery.of(context).padding;

  /// Get safe area view insets
  static EdgeInsets viewInsets(BuildContext context) =>
      MediaQuery.of(context).viewInsets;

  // ============ PERCENTAGE-BASED SIZING ============
  /// Get width percentage
  static double percentWidth(BuildContext context, double percent) =>
      screenWidth(context) * (percent / 100);

  /// Get height percentage
  static double percentHeight(BuildContext context, double percent) =>
      screenHeight(context) * (percent / 100);

  // ============ RESPONSIVE PADDING ============
  /// Get responsive padding based on device type
  static EdgeInsets responsivePadding(BuildContext context) {
    if (isPhone(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  /// Get responsive margin based on device type
  static double responsiveMargin(BuildContext context) {
    if (isPhone(context)) return 12;
    if (isTablet(context)) return 16;
    return 20;
  }

  // ============ RESPONSIVE FONT SIZING ============
  /// Get responsive font size
  static double responsiveFontSize(
    BuildContext context, {
    required double mobileSize,
    double tabletSize = 0,
    double desktopSize = 0,
  }) {
    tabletSize = tabletSize == 0 ? mobileSize + 2 : tabletSize;
    desktopSize = desktopSize == 0 ? mobileSize + 4 : desktopSize;

    if (isPhone(context)) return mobileSize;
    if (isTablet(context)) return tabletSize;
    return desktopSize;
  }

  // ============ GRID COLUMN COUNT ============
  /// Get number of columns for grid layout
  static int getGridColumns(BuildContext context) {
    if (isSmallPhone(context)) return 2;
    if (isPhone(context)) return 2;
    if (isTablet(context)) return 3;
    return 4;
  }

  // ============ RESPONSIVE BUILDER ============
  /// Simple responsive widget builder
  static Widget responsiveBuilder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? mobile;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }
}
