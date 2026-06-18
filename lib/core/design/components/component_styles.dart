import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// Reusable component styling utilities
/// Provides pre-configured styles for common components
class ComponentStyles {
  ComponentStyles._(); // Private constructor to prevent instantiation

  // ============ CARD STYLES ============
  /// Default elevated card decoration
  static BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: AppColors.neutral0,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    boxShadow: AppShadows.light,
  );

  /// Compact card decoration
  static BoxDecoration compactCardDecoration = BoxDecoration(
    color: AppColors.neutral0,
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    boxShadow: AppShadows.subtle,
  );

  /// Outlined card decoration
  static BoxDecoration outlinedCardDecoration = BoxDecoration(
    color: AppColors.neutral0,
    border: Border.all(color: AppColors.borderLight),
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
  );

  /// Dark card decoration
  static BoxDecoration darkCardDecoration = BoxDecoration(
    color: AppColors.surfaceDarkContainer,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    boxShadow: AppShadows.mediumDark,
  );

  // ============ BUTTON STYLES ============
  /// Primary button padding
  static const EdgeInsets primaryButtonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.md,
  );

  /// Secondary button padding
  static const EdgeInsets secondaryButtonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Compact button padding
  static const EdgeInsets compactButtonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  /// Icon button padding
  static const EdgeInsets iconButtonPadding = EdgeInsets.all(AppSpacing.md);

  // ============ INPUT FIELD STYLES ============
  /// Default input field padding
  static const EdgeInsets inputFieldPadding = EdgeInsets.all(AppSpacing.lg);

  /// Compact input field padding
  static const EdgeInsets compactInputPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  /// Default input field border
  static InputBorder defaultInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    borderSide: const BorderSide(color: AppColors.borderLight),
  );

  // ============ LIST TILE STYLES ============
  /// Default list tile padding
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Compact list tile padding
  static const EdgeInsets compactListTilePadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  // ============ DIVIDER STYLES ============
  /// Standard horizontal divider
  static const Divider standardDivider = Divider(
    height: AppSpacing.lg,
    thickness: AppSpacing.dividerThickness,
    color: AppColors.dividerLight,
  );

  /// Compact divider
  static const Divider compactDivider = Divider(
    height: AppSpacing.md,
    thickness: AppSpacing.dividerThickness,
    color: AppColors.dividerLight,
  );

  // ============ BORDER STYLES ============
  /// Subtle border
  static const Border subtleBorder = Border(
    top: BorderSide(color: AppColors.borderLight, width: 1),
    bottom: BorderSide(color: AppColors.borderLight, width: 1),
  );

  /// Emphasized border
  static const Border emphasizedBorder = Border(
    top: BorderSide(color: AppColors.borderLight, width: 2),
    bottom: BorderSide(color: AppColors.borderLight, width: 2),
  );

  // ============ CONTAINER STYLES ============
  /// Primary container decoration
  static BoxDecoration primaryContainerDecoration = BoxDecoration(
    color: AppColors.primary10,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    border: Border.all(color: AppColors.primary30),
  );

  /// Secondary container decoration
  static BoxDecoration secondaryContainerDecoration = BoxDecoration(
    color: AppColors.secondary20,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    border: Border.all(color: AppColors.secondary30),
  );

  /// Error container decoration
  static BoxDecoration errorContainerDecoration = BoxDecoration(
    color: AppColors.errorContainer,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    border: Border.all(color: AppColors.error),
  );

  /// Success container decoration
  static BoxDecoration successContainerDecoration = BoxDecoration(
    color: AppColors.successContainer,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    border: Border.all(color: AppColors.success),
  );

  // ============ BADGE STYLES ============
  /// Small badge padding
  static const EdgeInsets badgePaddingSmall = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.xs,
  );

  /// Medium badge padding
  static const EdgeInsets badgePaddingMedium = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  /// Large badge padding
  static const EdgeInsets badgePaddingLarge = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );
}
