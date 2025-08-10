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

  // Future: These can be configurable via user settings
  final Color? customSentBubbleColor;
  final Color? customReceivedBubbleColor;

  const LocalMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.customSentBubbleColor,
    this.customReceivedBubbleColor,
  });

  /// Get the bubble color based on theme and customization
  Color _getBubbleColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMe) {
      // Use custom color if provided, otherwise use theme color
      return customSentBubbleColor ??
          (isDark ? AppTheme.messageBubbleMeDark : AppTheme.messageBubbleMe);
    } else {
      // Use custom color if provided, otherwise use theme color
      return customReceivedBubbleColor ??
          (isDark
              ? AppTheme.messageBubbleOtherDark
              : AppTheme.messageBubbleOther);
    }
  }

  /// Get the text color based on bubble background
  Color _getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMe) {
      // For sent messages: white text on dark bubbles, black text on light bubbles
      return isDark ? Colors.white : Colors.black;
    } else {
      // For received messages: always use primary text color
      return isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    }
  }

  /// Get the timestamp and status icon color
  Color _getMetaTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMe) {
      // For sent messages: semi-transparent version of text color
      return isDark
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.black.withValues(alpha: 0.7);
    } else {
      // For received messages: tertiary text color
      return isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary;
    }
  }

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
                            ? _getBubbleColor(context).withValues(alpha: 0.8)
                            : Colors.grey[300])
                        : _getBubbleColor(context),
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
                        : [
                            // Subtle shadow for all message bubbles
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.content ?? '',
                        style: TextStyle(
                          color: _getTextColor(context),
                          fontSize: 15,
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
                                color: _getMetaTextColor(context),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildStatusIcon(message.readStatus, context),
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

  Widget _buildStatusIcon(String? status, BuildContext context) {
    // Get the appropriate color for status icons
    final metaColor = _getMetaTextColor(context);

    switch (status) {
      case 'sending':
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(metaColor),
          ),
        );
      case 'sent':
        return Icon(
          Icons.check,
          size: 12,
          color: metaColor,
        );
      case 'delivered':
        return Icon(
          Icons.done_all,
          size: 12,
          color: metaColor,
        );
      case 'read':
        return Icon(
          Icons.done_all,
          size: 12,
          color: Colors.lightBlue[300], // Keep blue for read status
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
          color: metaColor,
        );
    }
  }
}
