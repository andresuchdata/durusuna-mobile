import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../../shared/models/user.dart';
import 'robust_image_widget.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String? displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final BoxFit fit;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    this.displayName,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fit = BoxFit.cover,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasDisplayName = displayName != null && displayName!.isNotEmpty;

    // Generate initials from display name
    final initials = _generateInitials(displayName ?? '');

    // Default colors
    final defaultBgColor =
        backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final defaultTextColor = textColor ?? AppTheme.primaryColor;
    final defaultFontSize = fontSize ?? (radius * 0.4);

    Widget avatarContent;

    if (hasAvatar) {
      // Use RobustImageWidget for better image loading
      avatarContent = RobustImageWidget(
        imageUrl: avatarUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: fit,
        borderRadius: BorderRadius.circular(radius),
        placeholder: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: defaultBgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: defaultTextColor,
                fontSize: defaultFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        errorWidget: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: defaultBgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: defaultTextColor,
                fontSize: defaultFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    } else {
      // Fallback to initials
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: defaultBgColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              color: defaultTextColor,
              fontSize: defaultFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Add border if requested
    if (showBorder) {
      avatarContent = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? AppTheme.primaryColor,
            width: borderWidth,
          ),
        ),
        child: ClipOval(child: avatarContent),
      );
    }

    // Add tap functionality if provided
    if (onTap != null) {
      avatarContent = GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  String _generateInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }

    return '?';
  }
}

// Convenience constructor for User objects
class UserAvatarWidget extends StatelessWidget {
  final User user;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final BoxFit fit;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatarWidget({
    super.key,
    required this.user,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fit = BoxFit.cover,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarWidget(
      avatarUrl: user.avatarUrl,
      displayName: user.displayName,
      radius: radius,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
      fit: fit,
      onTap: onTap,
      showBorder: showBorder,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }
}
