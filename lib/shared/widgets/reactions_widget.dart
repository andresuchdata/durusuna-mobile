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
      final count = reactionData['count'] as int? ?? users.length;
      final hasReacted = currentUserId != null && users.contains(currentUserId);
      return {
        'count': count,
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

    // Prepare a compact list of at most two emoji types, with "+N" overflow
    final entries = reactions.entries
        .map((e) {
          final info = _getReactionInfo(e.key, e.value);
          return {
            'emoji': e.key,
            'count': info['count'] as int,
            'hasReacted': info['hasReacted'] as bool,
          };
        })
        .where((m) => (m['count'] as int) > 0)
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    // Sort by count desc; keep user's reacted emoji first if counts tie
    entries.sort((a, b) {
      final ca = a['count'] as int;
      final cb = b['count'] as int;
      if (cb != ca) return cb.compareTo(ca);
      final ra = (a['hasReacted'] as bool) ? 1 : 0;
      final rb = (b['hasReacted'] as bool) ? 1 : 0;
      return rb.compareTo(ra);
    });

    final displayed = entries.take(2).toList();
    final overflowCount = entries.length > 2 ? (entries.length - 2) : 0;

    Widget buildCircleBadge({required Widget child, bool highlighted = false}) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: highlighted
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey[300]!,
            width: 0.02,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
        child: Center(child: child),
      );
    }

    final reactionWidgets = <Widget>[
      for (final m in displayed)
        GestureDetector(
          onTap: () => onReactionTap(m['emoji'] as String),
          child: buildCircleBadge(
            child: Text(
              m['emoji'] as String,
              style: const TextStyle(fontSize: 10),
            ),
            highlighted: (m['hasReacted'] as bool),
          ),
        ),
      if (overflowCount > 0)
        buildCircleBadge(
          child: Text(
            '+$overflowCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
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
