import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_theme.dart';
import '../models/user.dart';
import 'avatar_widget.dart';

class ProfileCard extends StatelessWidget {
  final User user;
  final bool isOnline;
  final DateTime? lastSeen;
  final VoidCallback? onStartChat;
  final VoidCallback? onCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onBlock;

  const ProfileCard({
    super.key,
    required this.user,
    this.isOnline = false,
    this.lastSeen,
    this.onStartChat,
    this.onCall,
    this.onVideoCall,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Profile Avatar with online indicator
          Avatar.user(
            firstName: user.firstName,
            lastName: user.lastName,
            avatarUrl: user.avatarUrl,
            radius: AvatarSize.extraLarge,
            showOnlineIndicator: true,
            isOnline: isOnline,
          ),

          const SizedBox(height: 16),

          // User name
          Text(
            user.displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          // User type and role
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getUserTypeDisplay(),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Online status
          Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 14,
              color: isOnline ? AppTheme.successColor : AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // User details
          if (user.email.isNotEmpty) ...[
            _buildDetailRow(Icons.email, 'Email', user.email),
            const SizedBox(height: 12),
          ],

          if (user.phone?.isNotEmpty == true) ...[
            _buildDetailRow(Icons.phone, 'Phone', user.phone!),
            const SizedBox(height: 12),
          ],

          if (user.school?.name.isNotEmpty == true) ...[
            _buildDetailRow(Icons.school, 'School', user.school!.name),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 8),

          // Action buttons
          Row(
            children: [
              if (onStartChat != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStartChat,
                    icon: const Icon(Icons.chat_bubble, size: 18),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              if (onStartChat != null &&
                  (onCall != null || onVideoCall != null))
                const SizedBox(width: 12),
              if (onCall != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              if (onCall != null && onVideoCall != null)
                const SizedBox(width: 12),
              if (onVideoCall != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onVideoCall,
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text('Video'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Additional actions
          if (onBlock != null)
            TextButton.icon(
              onPressed: onBlock,
              icon:
                  const Icon(Icons.block, size: 18, color: AppTheme.errorColor),
              label: const Text(
                'Block User',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getUserTypeDisplay() {
    switch (user.userType) {
      case UserType.teacher:
        return 'Teacher';
      case UserType.student:
        return 'Student';
      case UserType.parent:
        return 'Parent';
    }
  }

  String _getStatusText() {
    if (isOnline) {
      return 'Online';
    } else if (lastSeen != null) {
      return 'Last seen ${timeago.format(lastSeen!)}';
    } else {
      return 'Offline';
    }
  }

  /// Show profile card as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required User user,
    bool isOnline = false,
    DateTime? lastSeen,
    VoidCallback? onStartChat,
    VoidCallback? onCall,
    VoidCallback? onVideoCall,
    VoidCallback? onBlock,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileCard(
        user: user,
        isOnline: isOnline,
        lastSeen: lastSeen,
        onStartChat: onStartChat,
        onCall: onCall,
        onVideoCall: onVideoCall,
        onBlock: onBlock,
      ),
    );
  }
}
