import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../shared/widgets/avatar_widget.dart';

class ChatTopUserPanel extends StatelessWidget implements PreferredSizeWidget {
  final String displayName;
  final String avatarUrl;
  final String initials;
  final bool isDirect;
  final bool isOnline;
  final bool isTyping;
  final String? lastSeenLabel;
  final VoidCallback onAvatarTap;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;
  final VoidCallback onClearChat;
  final VoidCallback onBlockUser;

  const ChatTopUserPanel({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.initials,
    required this.isDirect,
    required this.isOnline,
    required this.isTyping,
    required this.onAvatarTap,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onClearChat,
    required this.onBlockUser,
    this.lastSeenLabel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      titleSpacing: 0,
      title: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              children: [
                AvatarWidget(
                  avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                  displayName: displayName,
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor,
                  textColor: Colors.white,
                  fontSize: 16,
                ),
                if (isDirect && isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    isTyping
                        ? 'typing...'
                        : isOnline
                            ? 'Online'
                            : (lastSeenLabel ?? 'Last seen recently'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isTyping
                          ? AppTheme.primaryColor
                          : isOnline
                              ? AppTheme.successColor
                              : AppTheme.textSecondary,
                      fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: onVoiceCall,
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: onVideoCall,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'clear':
                onClearChat();
                break;
              case 'block':
                onBlockUser();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: 20),
                  SizedBox(width: 8),
                  Text('Clear Chat'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, size: 20, color: AppTheme.errorColor),
                  SizedBox(width: 8),
                  Text('Block User',
                      style: TextStyle(color: AppTheme.errorColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
