import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/local_message.dart';

class LocalMessageBubble extends StatelessWidget {
  final LocalMessage message;
  final bool isMe;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const LocalMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isSelectionMode) ...[
          Container(
            margin: const EdgeInsets.only(left: 8, right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ],

        // Message bubble
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isMe
                            ? AppTheme.primaryColor.withValues(alpha: 0.8)
                            : Colors.grey[300])
                        : (isMe ? AppTheme.primaryColor : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(16),
                    border: message.readStatus == 'failed'
                        ? Border.all(color: AppTheme.errorColor, width: 1)
                        : isSelected
                            ? Border.all(color: AppTheme.primaryColor, width: 2)
                            : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.content ?? '',
                        style: TextStyle(
                          color: isMe ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // time
                            Text(
                              '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildStatusIcon(message.readStatus),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(String? status) {
    switch (status) {
      case 'sending':
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.7),
            ),
          ),
        );
      case 'sent':
        return Icon(
          Icons.check,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case 'delivered':
        return Icon(
          Icons.done_all,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case 'read':
        return Icon(
          Icons.done_all,
          size: 12,
          color: Colors.lightBlue[300],
        );
      case 'failed':
        return const Icon(
          Icons.error_outline,
          size: 12,
          color: AppTheme.errorColor,
        );
      default:
        return Icon(
          Icons.schedule,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        );
    }
  }
}
