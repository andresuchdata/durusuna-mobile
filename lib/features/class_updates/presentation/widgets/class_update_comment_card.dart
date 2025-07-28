import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update_comment.dart';
import '../../../../shared/widgets/reactions_widget.dart';

class ClassUpdateCommentCard extends StatelessWidget {
  final ClassUpdateComment comment;
  final String? currentUserId;
  final Function(ClassUpdateComment)? onReply;
  final Function(ClassUpdateComment)? onEdit;
  final Function(ClassUpdateComment)? onDelete;
  final Function(ClassUpdateComment, String)? onReactionTap;
  final Function(ClassUpdateComment)? onAddReaction;
  final bool showReplies;
  final int level; // For nesting depth

  const ClassUpdateCommentCard({
    super.key,
    required this.comment,
    this.currentUserId,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onReactionTap,
    this.onAddReaction,
    this.showReplies = true,
    this.level = 0,
  });

  bool get _isMyComment => comment.authorId == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: level * 16.0, // Indent replies
        bottom: 8,
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author info and timestamp
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage:
                        comment.author?.avatarUrl?.isNotEmpty == true
                            ? NetworkImage(comment.author!.avatarUrl!)
                            : null,
                    child: comment.author?.avatarUrl?.isEmpty != false
                        ? Text(
                            _getInitials(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.author?.displayName ?? 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          timeago.format(comment.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isMyComment)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            if (onEdit != null) onEdit!(comment);
                            break;
                          case 'delete':
                            if (onDelete != null) onDelete!(comment);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete,
                                  size: 18, color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Reply indicator (if this is a reply)
              if (comment.isReply && comment.replyTo != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${comment.replyTo!.author?.displayName ?? "Unknown"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.replyTo!.displayContent,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],

              // Comment content
              Text(
                comment.displayContent,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 8),

              // Reactions
              if (comment.hasReactions || onAddReaction != null)
                ReactionsWidget(
                  reactions: comment.reactions ?? {},
                  currentUserId: currentUserId,
                  onReactionTap: (emoji) {
                    if (onReactionTap != null) {
                      onReactionTap!(comment, emoji);
                    }
                  },
                  onAddReaction: onAddReaction != null
                      ? () => onAddReaction!(comment)
                      : null,
                ),

              // Action buttons
              Row(
                children: [
                  if (onReply != null)
                    TextButton.icon(
                      onPressed: () => onReply!(comment),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Reply'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  if (onAddReaction != null)
                    TextButton.icon(
                      onPressed: () => onAddReaction!(comment),
                      icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
                      label: const Text('React'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  if (comment.hasReplies && showReplies)
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Implement show/hide replies
                      },
                      icon: const Icon(Icons.comment, size: 16),
                      label: Text('${comment.repliesCount} replies'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  const Spacer(),
                  if (comment.isEdited)
                    const Text(
                      'edited',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),

              // Nested replies
              if (showReplies && comment.replies?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                ...comment.replies!.map((reply) => ClassUpdateCommentCard(
                      comment: reply,
                      currentUserId: currentUserId,
                      onReply: onReply,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onReactionTap: onReactionTap,
                      onAddReaction: onAddReaction,
                      showReplies:
                          false, // Don't show nested replies for performance
                      level: level + 1,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (comment.author == null) return 'U';
    final firstName = comment.author!.firstName.trim();
    final lastName = comment.author!.lastName.trim();
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';

    if (firstInitial.isNotEmpty && lastInitial.isNotEmpty) {
      return '$firstInitial$lastInitial';
    } else if (firstInitial.isNotEmpty) {
      return firstInitial;
    } else if (lastInitial.isNotEmpty) {
      return lastInitial;
    }
    return 'U';
  }
}
