import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/url_utils.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.initials,
    this.radius = 20,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onTap,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final rewrittenUrl =
        hasAvatar ? UrlUtils.rewriteAttachmentUrl(avatarUrl!) : null;

    Widget avatarContent = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      backgroundImage: hasAvatar ? NetworkImage(rewrittenUrl!) : null,
      child: !hasAvatar
          ? Text(
              initials,
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.4,
              ),
            )
          : null,
    );

    if (onTap != null) {
      avatarContent = GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }

    if (showOnlineIndicator) {
      return Stack(
        children: [
          avatarContent,
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: radius * 0.4,
                height: radius * 0.4,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      );
    }

    return avatarContent;
  }
}
