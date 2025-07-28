import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

class ChatActionBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final bool canReply; // Only allow reply for single message
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const ChatActionBar({
    super.key,
    required this.selectedCount,
    required this.canReply,
    required this.onReply,
    required this.onForward,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: onCancel,
      ),
      title: Text(
        '$selectedCount selected',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        // Reply button (only for single message)
        if (canReply)
          IconButton(
            icon: const Icon(Icons.reply, color: Colors.white),
            onPressed: onReply,
            tooltip: 'Reply',
          ),

        // Forward button (for up to 5 messages)
        if (selectedCount <= 5)
          IconButton(
            icon: const Icon(Icons.forward, color: Colors.white),
            onPressed: onForward,
            tooltip: 'Forward',
          ),

        // Delete button
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}

class ForwardingHeader extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const ForwardingHeader({
    super.key,
    required this.selectedCount,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.successColor,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: onCancel,
      ),
      title: Text(
        'Forward $selectedCount message${selectedCount > 1 ? 's' : ''}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.send, color: Colors.white),
          onPressed: onConfirm,
          tooltip: 'Send',
        ),
      ],
    );
  }
}
