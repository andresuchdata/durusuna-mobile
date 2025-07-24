import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import 'robust_image_widget.dart';

class Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String? initials;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showOnlineIndicator;
  final bool isOnline;
  final Color? onlineIndicatorColor;
  final IconData? fallbackIcon;
  final VoidCallback? onTap;
  final Widget? badge;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const Avatar({
    super.key,
    this.avatarUrl,
    this.initials,
    this.radius = 24,
    this.backgroundColor,
    this.textColor,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onlineIndicatorColor,
    this.fallbackIcon,
    this.onTap,
    this.badge,
    this.border,
    this.boxShadow,
  });

  /// Create avatar for user with initials fallback
  factory Avatar.user({
    required String firstName,
    required String lastName,
    String? avatarUrl,
    double radius = 24,
    bool showOnlineIndicator = false,
    bool isOnline = false,
    VoidCallback? onTap,
    Widget? badge,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    final initials = '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}'
        '${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}';

    return Avatar(
      avatarUrl: avatarUrl,
      initials: initials.isNotEmpty ? initials : '?',
      radius: radius,
      showOnlineIndicator: showOnlineIndicator,
      isOnline: isOnline,
      onTap: onTap,
      badge: badge,
      border: border,
      boxShadow: boxShadow,
    );
  }

  /// Create avatar for group/class with icon fallback
  factory Avatar.group({
    String? avatarUrl,
    double radius = 24,
    IconData fallbackIcon = Icons.group,
    VoidCallback? onTap,
    Widget? badge,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    return Avatar(
      avatarUrl: avatarUrl,
      radius: radius,
      fallbackIcon: fallbackIcon,
      onTap: onTap,
      badge: badge,
      border: border,
      boxShadow: boxShadow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final widget = _buildAvatarContent();

    // Wrap with GestureDetector if onTap is provided
    final avatarWidget = onTap != null
        ? GestureDetector(
            onTap: onTap,
            child: widget,
          )
        : widget;

    // Add badge if provided
    if (badge != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            top: -4,
            right: -4,
            child: badge!,
          ),
        ],
      );
    }

    return avatarWidget;
  }

  Widget _buildAvatarContent() {
    return Stack(
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border,
            boxShadow: boxShadow,
            color: backgroundColor ?? AppTheme.primaryColor,
          ),
          child: ClipOval(
            child: _buildAvatarImage(),
          ),
        ),
        if (showOnlineIndicator)
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildOnlineIndicator(),
          ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    // If we have an avatar URL, try to display it
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return RobustImageWidget(
        imageUrl: avatarUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: _buildFallback(),
        errorWidget: _buildFallback(),
      );
    }

    // Otherwise, show fallback
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: backgroundColor ?? AppTheme.primaryColor,
      child: Center(
        child: _buildFallbackContent(),
      ),
    );
  }

  Widget _buildFallbackContent() {
    // Show icon if provided
    if (fallbackIcon != null) {
      return Icon(
        fallbackIcon,
        size: radius * 0.8,
        color: textColor ?? Colors.white,
      );
    }

    // Show initials if provided
    if (initials != null && initials!.isNotEmpty) {
      return Text(
        initials!,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: _getInitialsFontSize(),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // Default fallback
    return Icon(
      Icons.person,
      size: radius * 0.8,
      color: textColor ?? Colors.white,
    );
  }

  double _getInitialsFontSize() {
    // Dynamic font size based on radius
    if (radius <= 16) return radius * 0.6;
    if (radius <= 24) return radius * 0.7;
    if (radius <= 32) return radius * 0.65;
    if (radius <= 50) return radius * 0.6;
    return radius * 0.5;
  }

  Widget _buildOnlineIndicator() {
    final indicatorSize = radius * 0.3;
    final indicatorBorderWidth = radius * 0.08;

    return Container(
      width: indicatorSize,
      height: indicatorSize,
      decoration: BoxDecoration(
        color: isOnline
            ? (onlineIndicatorColor ?? AppTheme.successColor)
            : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: indicatorBorderWidth,
        ),
      ),
    );
  }
}

/// Specific avatar sizes for consistency
class AvatarSize {
  static const double small = 16;
  static const double medium = 24;
  static const double large = 32;
  static const double extraLarge = 50;
  static const double huge = 64;
}
