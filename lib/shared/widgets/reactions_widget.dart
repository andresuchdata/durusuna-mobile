import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

class ReactionsWidget extends StatelessWidget {
  final Map<String, dynamic> reactions;
  final String? currentUserId;
  final Function(String emoji) onReactionTap;
  final Function()? onAddReaction;
  final bool isMyMessage;

  const ReactionsWidget({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
    this.onAddReaction,
    this.isMyMessage = false,
  });

  // Helper method to get reaction count and check if current user reacted
  Map<String, dynamic> _getReactionInfo(String emoji, dynamic reactionData) {
    if (reactionData is int) {
      // Simple count format
      return {
        'count': reactionData,
        'hasReacted': false, // Can't determine individual users
      };
    } else if (reactionData is Map<String, dynamic>) {
      // Detailed format with user IDs
      final users = reactionData['users'] as List<dynamic>? ?? [];
      final hasReacted = currentUserId != null &&
          users.any((user) => user['id'] == currentUserId);
      return {
        'count': users.length,
        'hasReacted': hasReacted,
      };
    } else if (reactionData is List) {
      // List of user IDs
      final hasReacted =
          currentUserId != null && reactionData.contains(currentUserId);
      return {
        'count': reactionData.length,
        'hasReacted': hasReacted,
      };
    }

    return {'count': 0, 'hasReacted': false};
  }

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final reactionWidgets = <Widget>[];

    // Build reaction chips
    reactions.forEach((emoji, reactionData) {
      final info = _getReactionInfo(emoji, reactionData);
      final count = info['count'] as int;
      final hasReacted = info['hasReacted'] as bool;

      if (count > 0) {
        reactionWidgets.add(
          GestureDetector(
            onTap: () => onReactionTap(emoji),
            child: Container(
              margin: const EdgeInsets.only(right: 4, bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasReacted
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasReacted ? AppTheme.primaryColor : Colors.grey[300]!,
                  width: hasReacted ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasReacted
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    });

    // Add reaction button
    if (onAddReaction != null) {
      reactionWidgets.add(
        GestureDetector(
          onTap: onAddReaction,
          child: Container(
            margin: const EdgeInsets.only(right: 4, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.add,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    if (reactionWidgets.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        children: reactionWidgets,
      ),
    );
  }
}

class ReactionPicker extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback onClose;

  const ReactionPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  static const List<String> quickReactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '😡',
    '👏',
    '🔥',
    '✨',
    '🎉',
    '💯',
    '👌',
    '🙏',
    '😍',
    '🤔',
    '💪'
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'React with',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick reactions grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickReactions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    onEmojiSelected(emoji);
                    onClose();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
