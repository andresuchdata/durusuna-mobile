import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/avatar_widget.dart';

class ContactTile extends StatelessWidget {
  final User user;
  final VoidCallback onTap;
  final bool showOnlineStatus;

  const ContactTile({
    super.key,
    required this.user,
    required this.onTap,
    this.showOnlineStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar with online status
                Avatar.user(
                  firstName: user.firstName,
                  lastName: user.lastName,
                  avatarUrl: user.avatarUrl,
                  radius: AvatarSize.medium,
                  showOnlineIndicator: showOnlineStatus,
                  isOnline: _isUserOnline(),
                ),

                const SizedBox(width: 16),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getUserTypeColor(user.userType)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getUserTypeLabel(user.userType),
                              style: TextStyle(
                                color: _getUserTypeColor(user.userType),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (user.role == UserRole.admin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (user.email != null && user.email!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.email!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Action icon
                Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isUserOnline() {
    // TODO: Implement real-time online status based on lastActiveAt
    // For now, consider user online if they were active in the last 5 minutes
    if (user.lastActiveAt == null) return false;
    final now = DateTime.now();
    final difference = now.difference(user.lastActiveAt!);
    return difference.inMinutes < 5;
  }

  String _getUserTypeLabel(UserType userType) {
    switch (userType) {
      case UserType.student:
        return 'Student';
      case UserType.teacher:
        return 'Teacher';
      case UserType.parent:
        return 'Parent';
    }
  }

  Color _getUserTypeColor(UserType userType) {
    switch (userType) {
      case UserType.student:
        return AppTheme.infoColor;
      case UserType.teacher:
        return AppTheme.successColor;
      case UserType.parent:
        return AppTheme.warningColor;
    }
  }
}
