import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/widgets/attachment_list.dart';
import '../../../../shared/widgets/attachment_viewer_page.dart';

class ClassUpdateCard extends StatelessWidget {
  final ClassUpdate update;
  final Function(String emoji) onReaction;
  final VoidCallback onComment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ClassUpdateCard({
    super.key,
    required this.update,
    required this.onReaction,
    required this.onComment,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Author avatar
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    update.author != null
                        ? '${update.author!.firstName[0]}${update.author!.lastName[0]}'
                        : 'T',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Author info and timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            update.author?.displayName ?? 'Teacher',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getUpdateTypeColor(update.updateType),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              update.updateTypeIcon,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (update.isPinned) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.push_pin,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeago.format(update.createdAt),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // More options
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete,
                                  size: 20, color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
              ],
            ),
          ),

          // Title
          if (update.title != null && update.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                update.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              update.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),

          // Attachments
          if (update.hasAttachments)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAttachments(context),
            ),

          // Reactions
          if (update.hasReactions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildReactions(),
            ),

          const Divider(height: 1),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showReactionPicker(context),
                    icon: const Icon(Icons.thumb_up_outlined, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        update.totalReactions > 0
                            ? '${update.totalReactions}'
                            : 'React',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onComment,
                    icon: const Icon(Icons.comment_outlined, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        update.hasComments
                            ? '${update.commentsCount}'
                            : 'Comment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      // TODO: Implement share functionality
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Share',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AttachmentList(
        attachments: update.attachments ?? [],
        mode: AttachmentListMode.vertical,
        maxItems: 3, // Show max 3 attachments, then "X more"
        onMoreTap: () {
          _showAllAttachments(context);
        },
      ),
    );
  }

  void _showAllAttachments(BuildContext context) {
    if (update.attachments == null || update.attachments!.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AttachmentViewerPage(
          attachments: update.attachments!,
          title: update.displayTitle,
        ),
      ),
    );
  }

  Widget _buildReactions() {
    return Wrap(
      spacing: 8,
      children: update.reactions!.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.key, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '${entry.value.count}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a reaction',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '😊', '😮', '😢', '😡'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onReaction(emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.backgroundColor,
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getUpdateTypeColor(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return AppTheme.primaryColor.withOpacity(0.1);
      case UpdateType.homework:
        return AppTheme.warningColor.withOpacity(0.1);
      case UpdateType.reminder:
        return AppTheme.infoColor.withOpacity(0.1);
      case UpdateType.event:
        return AppTheme.successColor.withOpacity(0.1);
    }
  }
}
