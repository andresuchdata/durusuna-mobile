import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isSelected;
  final bool isSelectionMode;
  final String conversationType; // 'direct' or 'group'
  final Function(Message)? onReply;
  final Function(Message)? onEdit;
  final Function(Message)? onDelete;
  final Function(Message)? onForward;
  final Function(Message)? onLongPress;
  final Function(Message)? onTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.conversationType,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onForward,
    this.onLongPress,
    this.onTap,
  });

  bool get _shouldShowAvatar => conversationType == 'group' && !isMe;

  String get _senderInitials {
    if (message.sender == null) return 'U';
    final firstName = message.sender!.firstName.trim();
    final lastName = message.sender!.lastName.trim();
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

  @override
  Widget build(BuildContext context) {
    // Use smaller horizontal padding for both direct and group chats
    const horizontalPadding = 8.0;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        if (onLongPress != null) {
          onLongPress!(message);
        } else {
          _showMessageOptions(context);
        }
      },
      onTap: isSelectionMode && onTap != null ? () => onTap!(message) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors
              .transparent, // Always transparent, selection handled by bubble border
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: 8),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Selection indicator for selection mode (positioned first for consistent left margin)
              if (isSelectionMode) ...[
                Container(
                  margin: const EdgeInsets.only(
                    left: 4, // Fixed 4 units from screen border
                    right: 8, // Right margin from bubble
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.transparent,
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

              // Left side spacing for messages from others (only when not in selection mode)
              if (!isMe && !isSelectionMode)
                SizedBox(
                    width: _shouldShowAvatar
                        ? 4
                        : (conversationType == 'direct' ? 4 : 20)),

              // Avatar for other participants in group chats only
              if (_shouldShowAvatar) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: message.sender?.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(message.sender!.avatarUrl!)
                      : null,
                  child: message.sender?.avatarUrl?.isEmpty != false
                      ? Text(
                          _senderInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],

              // Message content container
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Sender name for group chats (other participants only)
                      if (_shouldShowAvatar) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.sender?.displayName ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],

                      // Unified message bubble (includes reply if present)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(
                            0), // No padding here, handled inside
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryColor : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2.5,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                            // Add selection glow effect when selected
                            if (isSelected)
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reply preview integrated at the top (if this message is a reply)
                            if (message.replyTo != null) ...[
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Straight left border bar
                                    Container(
                                      width: 4.5,
                                      margin: const EdgeInsets.only(
                                          left: 12, top: 12, bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? Colors.white
                                                .withValues(alpha: 0.9)
                                            : AppTheme.primaryColor,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                    // Reply content
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(
                                            8, 12, 12, 8),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.white
                                                  .withValues(alpha: 0.15)
                                              : AppTheme.primaryColor
                                                  .withValues(alpha: 0.08),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Sender name of the replied message
                                            Text(
                                              message.replyTo!.isFromMe
                                                  ? 'You'
                                                  : (message.replyTo!.sender
                                                          ?.displayName ??
                                                      'Unknown'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isMe
                                                    ? Colors.white
                                                        .withValues(alpha: 0.9)
                                                    : AppTheme.primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),

                                            // Content of the replied message
                                            Text(
                                              message.replyTo!.displayContent,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isMe
                                                    ? Colors.white
                                                        .withValues(alpha: 0.7)
                                                    : AppTheme.textSecondary
                                                        .withValues(alpha: 0.8),
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Subtle divider between reply and content
                              Container(
                                height: 1,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : AppTheme.borderColor
                                        .withValues(alpha: 0.3),
                              ),
                            ],

                            // Main message content
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                  12,
                                  message.replyTo != null
                                      ? 8
                                      : 12, // Less top padding if reply present
                                  12,
                                  8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Message content
                                  _buildMessageContent(),

                                  const SizedBox(height: 4),

                                  // Message metadata (time, status)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (message.isEdited)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 4),
                                          child: Text(
                                            'edited',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.white
                                                      .withValues(alpha: 0.7)
                                                  : AppTheme.textTertiary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        _formatTime(message.createdAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe
                                              ? Colors.white
                                                  .withValues(alpha: 0.7)
                                              : AppTheme.textTertiary,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          _getStatusIcon(),
                                          size: 14,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right side spacing for current user messages
              if (isMe) const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.messageType) {
      case MessageType.text:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            color: isMe ? Colors.white : AppTheme.textPrimary,
            height: 1.3,
          ),
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 40, color: AppTheme.textTertiary),
                    SizedBox(height: 8),
                    Text(
                      'Image',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (message.content?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                message.content!,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ],
        );

      case MessageType.file:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: isMe ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.metadata?['filename'] ?? 'File',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      message.metadata?['filesize'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.download,
                color: isMe ? Colors.white : AppTheme.primaryColor,
              ),
            ],
          ),
        );

      case MessageType.audio:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_arrow,
                color: isMe ? Colors.white : AppTheme.primaryColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.3, // Progress indicator
                        child: Container(
                          decoration: BoxDecoration(
                            color: isMe ? Colors.white : AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.metadata?['duration'] ?? '0:00',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            color: isMe ? Colors.white : AppTheme.textPrimary,
          ),
        );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Same day - show time
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else {
      // Different day - show relative time
      return timeago.format(dateTime, locale: 'en_short');
    }
  }

  IconData _getStatusIcon() {
    switch (message.readStatus) {
      case ReadStatus.sent:
        return Icons.done;
      case ReadStatus.delivered:
        return Icons.done_all;
      case ReadStatus.read:
        return Icons.done_all;
      default:
        return Icons.schedule;
    }
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onReply != null)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onReply!(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.of(context).pop();

                  Clipboard.setData(ClipboardData(text: message.content ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                    ),
                  );
                },
              ),
              if (onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onEdit!(message);
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppTheme.errorColor),
                  title: const Text('Delete',
                      style: TextStyle(color: AppTheme.errorColor)),
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete!(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Message Info'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showMessageInfo(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Sent', _formatFullDateTime(message.createdAt)),
            if (message.deliveredAt != null)
              _buildInfoRow(
                  'Delivered', _formatFullDateTime(message.deliveredAt!)),
            if (message.readAt != null)
              _buildInfoRow('Read', _formatFullDateTime(message.readAt!)),
            if (message.isEdited)
              _buildInfoRow('Edited', _formatFullDateTime(message.updatedAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatFullDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }
}
