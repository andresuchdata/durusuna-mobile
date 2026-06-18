/// Spacing and sizing system for Durusuna Mobile
/// Provides consistent spacing scale based on 8dp grid
class AppSpacing {
  AppSpacing._(); // Private constructor to prevent instantiation

  // ============ BASE SPACING UNIT ============
  /// Base spacing unit - 8dp
  static const double base = 8.0;

  // ============ SPACING SCALE (Multiples of 8dp) ============
  static const double xs = 2.0; // Extra small - micro spacing
  static const double sm = 4.0; // Small - 0.5x base
  static const double md = 8.0; // Medium - 1x base (base unit)
  static const double lg = 12.0; // Large - 1.5x base
  static const double xl = 16.0; // Extra large - 2x base
  static const double xxl = 24.0; // Double extra large - 3x base
  static const double xxxl = 32.0; // Triple extra large - 4x base
  static const double huge = 40.0; // Huge - 5x base
  static const double massive = 48.0; // Massive - 6x base

  // ============ COMMON GAPS & MARGINS ============
  static const double gap2xs = xs; // 2px
  static const double gap2sm = sm; // 4px
  static const double gap2md = md; // 8px
  static const double gap2lg = lg; // 12px
  static const double gap2xl = xl; // 16px
  static const double gap2xxl = xxl; // 24px
  static const double gap2xxxl = xxxl; // 32px

  // ============ PADDING PRESETS ============
  /// Tight padding - minimal spacing
  static const double paddingTight = xs;

  /// Compact padding - reduced spacing
  static const double paddingCompact = sm;

  /// Default padding - standard spacing
  static const double paddingDefault = md;

  /// Comfortable padding - relaxed spacing
  static const double paddingComfortable = lg;

  /// Generous padding - ample spacing
  static const double paddingGenerous = xl;

  /// Extra generous padding
  static const double paddingExtra = xxl;

  // ============ MARGIN PRESETS ============
  static const double marginXs = xs;
  static const double marginSm = sm;
  static const double marginMd = md;
  static const double marginLg = lg;
  static const double marginXl = xl;
  static const double marginXxl = xxl;
  static const double marginXxxl = xxxl;

  // ============ PAGE/SECTION SPACING ============
  /// Page horizontal padding
  static const double pageHorizontal = xl;

  /// Page vertical padding
  static const double pageVertical = xl;

  /// Section spacing
  static const double sectionSpacing = xxl;

  /// Component spacing
  static const double componentSpacing = lg;

  // ============ BORDER RADIUS SCALE ============
  static const double radiusXs = 2.0;
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusXxl = 24.0;
  static const double radiusCircle = 50.0; // For circular elements

  // ============ ICON SIZING ============
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 40.0;
  static const double iconXxl = 48.0;
  static const double iconHuge = 64.0;

  // ============ BUTTON SIZING ============
  static const double buttonHeightSm = 32.0;
  static const double buttonHeightMd = 40.0;
  static const double buttonHeightLg = 48.0;
  static const double buttonHeightXl = 56.0;

  static const double buttonPaddingHorizontal = xl;
  static const double buttonPaddingVertical = md;

  // ============ INPUT FIELD SIZING ============
  static const double inputHeightSm = 36.0;
  static const double inputHeightMd = 44.0;
  static const double inputHeightLg = 52.0;

  static const double inputPaddingHorizontal = lg;
  static const double inputPaddingVertical = md;

  // ============ CARD & CONTAINER SIZING ============
  static const double cardPaddingCompact = md;
  static const double cardPaddingDefault = lg;
  static const double cardPaddingComfortable = xl;
  static const double cardPaddingGenerous = xxl;

  // ============ LIST/TILE SIZING ============
  static const double listTilePadding = lg;
  static const double listTileHeight = 56.0;
  static const double listTileHeightCompact = 48.0;
  static const double listTileHeightExpanded = 72.0;

  // ============ DIVIDER SPACING ============
  static const double dividerThickness = 1.0;
  static const double dividerThicknessEmphasized = 2.0;
  static const double dividerVerticalMargin = lg;
  static const double dividerHorizontalMargin = md;

  // ============ HELPER CALCULATIONS ============
  /// Multiply spacing unit
  static double multiply(double value, double factor) => value * factor;

  /// Add spacing values
  static double add(double value1, double value2) => value1 + value2;

  /// Subtract spacing values
  static double subtract(double value1, double value2) => value1 - value2;
}
