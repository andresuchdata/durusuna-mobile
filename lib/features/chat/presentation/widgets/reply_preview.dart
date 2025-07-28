import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/message.dart';

class ReplyPreview extends StatelessWidget {
  final Message replyToMessage;
  final VoidCallback onCancel;

  const ReplyPreview({
    super.key,
    required this.replyToMessage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor.withOpacity(0.3),
            width: 1,
          ),
          left: BorderSide(
            color: AppTheme.primaryColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${replyToMessage.isFromMe ? 'yourself' : replyToMessage.sender?.displayName ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  replyToMessage.displayContent,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: onCancel,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }
}
