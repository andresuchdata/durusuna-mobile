import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/local_message.dart';
import '../../../../shared/services/chat_repository_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/helpers/link_text.dart';
import 'quote_preview.dart';
import 'dart:async';
import 'dart:convert';
import '../../../../shared/widgets/reactions_widget.dart';

class LocalMessageBubble extends StatefulWidget {
  final LocalMessage message;
  final bool isMe;
  final bool isGroup;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onAddReaction;
  final String? reactionsJson;
  final String? currentUserId;
  final void Function(String emoji)? onReactionTap;

  // Future: These can be configurable via user settings
  final Color? customSentBubbleColor;
  final Color? customReceivedBubbleColor;
  final String? senderName;
  final String? senderAvatarUrl;
  final List<User>? participants;

  const LocalMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isGroup,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.onDoubleTap,
    this.onAddReaction,
    this.customSentBubbleColor,
    this.customReceivedBubbleColor,
    this.senderName,
    this.senderAvatarUrl,
    this.participants,
    this.reactionsJson,
    this.currentUserId,
    this.onReactionTap,
  });

  @override
  State<LocalMessageBubble> createState() => _LocalMessageBubbleState();
}

class _LocalMessageBubbleState extends State<LocalMessageBubble> {
  bool _showReactionTrigger = false;
  Timer? _triggerHideTimer;
  static const double _reactionTriggerSize = 22.0;

  /// Get the bubble color based on theme and customization
  Color _getBubbleColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isMe) {
      // Use custom color if provided, otherwise use theme color
      return widget.customSentBubbleColor ??
          (isDark ? AppTheme.messageBubbleMeDark : AppTheme.messageBubbleMe);
    } else {
      // Use custom color if provided, otherwise use theme color
      return widget.customReceivedBubbleColor ??
          (isDark
              ? AppTheme.messageBubbleOtherDark
              : AppTheme.messageBubbleOther);
    }
  }

  Widget _buildReactionsChips() {
    try {
      final raw = widget.reactionsJson;
      if (raw == null || raw.isEmpty) return const SizedBox.shrink();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        return const SizedBox.shrink();
      }
      return ReactionsWidget(
        reactions: decoded,
        currentUserId: widget.currentUserId,
        onReactionTap: (emoji) => widget.onReactionTap?.call(emoji),
        onAddReaction: null, // no plus
        isMyMessage: widget.isMe,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  /// Get the text color based on bubble background
  Color _getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isMe) {
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

    if (widget.isMe) {
      // For sent messages: semi-transparent version of text color
      return isDark
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.black.withValues(alpha: 0.7);
    } else {
      // For received messages: tertiary text color
      return isDark ? AppTheme.darkTextSecondary : AppTheme.textTertiary;
    }
  }

  // Deterministic high-contrast color for sender names in group chats
  Color _senderColor(BuildContext context) {
    if (!widget.isGroup || widget.isMe) {
      return Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkTextSecondary
          : AppTheme.textSecondary;
    }

    final seed = widget.message.senderId.hashCode;
    // Palette tuned for contrast on light/dark backgrounds
    const palette = <Color>[
      Color(0xFF0F9D58), // green
      Color(0xFF4285F4), // blue
      Color(0xFFDB4437), // red
      Color(0xFFF4B400), // yellow
      Color(0xFF8E24AA), // purple
      Color(0xFF039BE5), // light blue
      Color(0xFF43A047), // dark green
      Color(0xFFF4511E), // deep orange
    ];
    return palette[seed.abs() % palette.length];
  }

  bool get _shouldShowAvatar => widget.isGroup && !widget.isMe;

  User? _findParticipant(String userId) {
    try {
      return widget.participants?.firstWhere((u) => u.id == userId);
    } catch (_) {
      return null;
    }
  }

  // Removed initials helper since quote preview no longer shows avatars

  // Delegate to shared helper
  String _wrapLinksForBreaking(String input) =>
      LinkTextHelper.wrapLinksForBreaking(input);

  // Delegate linkified text creation to shared helper
  Widget _buildLinkifiedText(
    BuildContext context,
    String text,
    TextStyle baseStyle, {
    int? maxLines,
    TextOverflow overflow = TextOverflow.fade,
  }) =>
      LinkTextHelper.buildLinkifiedText(
        context,
        text,
        baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );

  // Deterministic color by userId (for quoted sender sidebar)
  Color _colorForUserId(String userId) {
    final seed = userId.hashCode;
    const palette = <Color>[
      Color(0xFF0F9D58), // green
      Color(0xFF4285F4), // blue
      Color(0xFFDB4437), // red
      Color(0xFFF4B400), // yellow
      Color(0xFF8E24AA), // purple
      Color(0xFF039BE5), // light blue
      Color(0xFF43A047), // dark green
      Color(0xFFF4511E), // deep orange
    ];
    return palette[seed.abs() % palette.length];
  }

  // Build quoted message preview. Falls back to fetching quoted content
  // by replyToId if replyToContent is missing.
  Widget _buildQuotedPreview(BuildContext context) {
    if ((widget.message.replyToContent?.isNotEmpty ?? false)) {
      // Use sender color if group; otherwise default primary
      final leftColor =
          widget.isGroup ? _senderColor(context) : AppTheme.primaryColor;
      return QuotePreview(
        isMe: widget.isMe,
        isGroup: widget.isGroup,
        leftColor: leftColor,
        text: _wrapLinksForBreaking(widget.message.replyToContent!),
        quotedName: widget.isGroup ? widget.senderName : null,
      );
    }

    if (widget.message.replyToId == null || widget.message.replyToId!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use a FutureBuilder to lazily fetch the quoted message content by id
    return FutureBuilder<LocalMessage?>(
      future:
          ChatRepositoryService.getMessageByServerId(widget.message.replyToId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final leftColor =
              widget.isGroup ? _senderColor(context) : AppTheme.primaryColor;
          return QuotePreview(
            isMe: widget.isMe,
            isGroup: widget.isGroup,
            leftColor: leftColor,
            text: '...',
            quotedName: widget.isGroup ? widget.senderName : null,
          );
        }
        final quoted = snapshot.data;
        if (quoted == null || (quoted.content?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
        final leftColor = widget.isGroup
            ? _colorForUserId(quoted.senderId)
            : AppTheme.primaryColor;
        final user = _findParticipant(quoted.senderId);
        final quotedName = user?.displayName;
        // Avatar not used in quote preview; intentionally ignored
        return QuotePreview(
          isMe: widget.isMe,
          isGroup: widget.isGroup,
          leftColor: leftColor,
          text: _wrapLinksForBreaking(quoted.content!),
          quotedName: quotedName,
        );
      },
    );
  }

  // Quote rendering is handled by QuotePreview widget

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.isSelectionMode) ...[
          Container(
            margin: const EdgeInsets.only(left: 2, right: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? AppTheme.primaryColor
                    : Colors.transparent,
                border: Border.all(
                  color: widget.isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                  width: 2,
                ),
              ),
              child: widget.isSelected
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
            onTap: () {
              widget.onTap();
              setState(() => _showReactionTrigger = true);
              _triggerHideTimer?.cancel();
              _triggerHideTimer = Timer(const Duration(seconds: 2), () {
                if (mounted) setState(() => _showReactionTrigger = false);
              });
            },
            onLongPress: widget.onLongPress,
            onDoubleTap: widget.onDoubleTap,
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                  8, 2, 8, 24), // Add bottom margin for reactions
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: widget.isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (_shouldShowAvatar && !widget.isSelectionMode) ...[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: (widget.senderAvatarUrl != null &&
                              widget.senderAvatarUrl!.isNotEmpty)
                          ? NetworkImage(widget.senderAvatarUrl!)
                          : null,
                      child: (widget.senderAvatarUrl == null ||
                              widget.senderAvatarUrl!.isEmpty)
                          ? Text(
                              (widget.senderName?.trim().isNotEmpty == true)
                                  ? widget.senderName!
                                      .trim()
                                      .split(' ')
                                      .where((w) => w.isNotEmpty)
                                      .take(2)
                                      .map((w) => w[0].toUpperCase())
                                      .join()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Align(
                      alignment: widget.isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: IntrinsicWidth(
                        child: Container(
                          constraints: BoxConstraints(
                            // Increased min width for sender messages to accommodate read status, timestamp, and reactions
                            minWidth: 120,
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: EdgeInsets.fromLTRB(
                            2.0,
                            (() {
                              final hasQuote =
                                  (widget.message.replyToContent?.isNotEmpty ??
                                          false) ||
                                      (widget.message.replyToId != null &&
                                          widget.message.replyToId!.isNotEmpty);
                              final showsSenderLabel = (_shouldShowAvatar &&
                                  (widget.senderName?.isNotEmpty ?? false));
                              if (hasQuote) return 2.0;
                              if (!widget.isMe) {
                                return showsSenderLabel ? 2.0 : 8.0;
                              }
                              return 8.0;
                            })(),
                            4.0,
                            8.0,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? (widget.isMe
                                    ? _getBubbleColor(context)
                                        .withValues(alpha: 0.8)
                                    : Colors.grey[300])
                                : _getBubbleColor(context),
                            borderRadius: BorderRadius.circular(8),
                            border: widget.message.readStatus == 'failed'
                                ? Border.all(
                                    color: AppTheme.errorColor, width: 1)
                                : widget.isSelected
                                    ? Border.all(
                                        color: AppTheme.primaryColor, width: 2)
                                    : null,
                            boxShadow: widget.isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Bubble content
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_shouldShowAvatar &&
                                      (widget.senderName?.isNotEmpty ?? false))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 4, top: 2, left: 2, right: 2),
                                      child: Text(
                                        widget.senderName!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _senderColor(context),
                                        ),
                                      ),
                                    ),
                                  if (widget.message.replyToId != null ||
                                      widget.message.replyToContent != null)
                                    _buildQuotedPreview(context),
                                  // Main content and meta with normal horizontal padding
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 6,
                                      right: 6,
                                      top: 0,
                                      bottom: 0,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLinkifiedText(
                                          context,
                                          widget.message.content ?? '',
                                          TextStyle(
                                            color: _getTextColor(context),
                                            fontSize: 15,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: widget.isMe
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${widget.message.createdAt.hour.toString().padLeft(2, '0')}:${widget.message.createdAt.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: _getMetaTextColor(
                                                      context),
                                                ),
                                              ),
                                              if (widget.isMe) ...[
                                                const SizedBox(width: 4),
                                                _buildStatusIcon(
                                                    widget.message.readStatus,
                                                    context),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Reactions below the bubble (fully visible)
                              if (!widget.isSelectionMode)
                                Positioned(
                                  bottom:
                                      -20, // Position reactions below the bubble with proper spacing
                                  left: widget.isMe
                                      ? 8
                                      : null, // Left for isMe, right for others
                                  right: widget.isMe ? null : 8,
                                  child: _buildReactionsChips(),
                                ),
                              if (!widget.isSelectionMode)
                                Positioned(
                                  // Align the trigger so that its vertical center sits on the bubble's bottom edge
                                  bottom: -_reactionTriggerSize / 2,
                                  // For sender (my message), place trigger at bottom-left; otherwise bottom-right
                                  left: widget.isMe ? -4 : null,
                                  right: widget.isMe ? null : -4,
                                  child: IgnorePointer(
                                    ignoring: !_showReactionTrigger,
                                    child: AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      opacity: _showReactionTrigger ? 1.0 : 0.0,
                                      child: _buildReactionTrigger(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionTrigger() {
    return GestureDetector(
      onTap: widget.onAddReaction,
      onLongPress: widget.onAddReaction,
      child: Container(
        width: _reactionTriggerSize,
        height: _reactionTriggerSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black12,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          Icons.add_reaction_outlined,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
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
