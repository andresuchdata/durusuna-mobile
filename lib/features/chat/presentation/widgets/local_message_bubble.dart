import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/local_message.dart';
import '../../../../shared/database/chat_database.dart';
import '../../../../shared/models/user.dart';

class LocalMessageBubble extends StatelessWidget {
  final LocalMessage message;
  final bool isMe;
  final bool isGroup;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
    this.customSentBubbleColor,
    this.customReceivedBubbleColor,
    this.senderName,
    this.senderAvatarUrl,
    this.participants,
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

  // Deterministic high-contrast color for sender names in group chats
  Color _senderColor(BuildContext context) {
    if (!isGroup || isMe) {
      return Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkTextSecondary
          : AppTheme.textSecondary;
    }

    final seed = message.senderId.hashCode;
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

  bool get _shouldShowAvatar => isGroup && !isMe;

  User? _findParticipant(String userId) {
    try {
      return participants?.firstWhere((u) => u.id == userId);
    } catch (_) {
      return null;
    }
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // Insert zero-width spaces after common URL delimiters to allow soft wrapping
  String _wrapLinksForBreaking(String input) {
    if (input.isEmpty) return input;
    const breakChars = ['/', '?', '&', '=', '.', '-', '_', ':'];
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      buffer.write(ch);
      if (breakChars.contains(ch)) {
        buffer.write('\u200B'); // zero-width space for wrapping
      }
    }
    return buffer.toString();
  }

  // Build linkified rich text for message/quote content
  Widget _buildLinkifiedText(
    BuildContext context,
    String text,
    TextStyle baseStyle,
  ) {
    final linkRegExp =
        RegExp(r'((https?:\/\/|www\.)[^\s]+)', caseSensitive: false);
    final spans = <InlineSpan>[];
    int currentIndex = 0;
    final matches = linkRegExp.allMatches(text).toList();

    for (final match in matches) {
      if (match.start > currentIndex) {
        final nonLink = text.substring(currentIndex, match.start);
        spans.add(
            TextSpan(text: _wrapLinksForBreaking(nonLink), style: baseStyle));
      }

      final urlText = text.substring(match.start, match.end);
      final display = _wrapLinksForBreaking(urlText);
      final uri =
          Uri.parse(urlText.startsWith('http') ? urlText : 'https://$urlText');
      final linkStyle = baseStyle.copyWith(
        color: const Color.fromARGB(255, 37, 77, 189),
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w600,
      );
      spans.add(TextSpan(
        text: display,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
      ));
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: _wrapLinksForBreaking(text.substring(currentIndex)),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      softWrap: true,
      maxLines: null,
    );
  }

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
    if ((message.replyToContent?.isNotEmpty ?? false)) {
      // Use sender color if group; otherwise default primary
      final leftColor = isGroup ? _senderColor(context) : AppTheme.primaryColor;
      return _quotedContainer(
        context,
        _wrapLinksForBreaking(message.replyToContent!),
        leftColor: leftColor,
      );
    }

    if (message.replyToId == null || message.replyToId!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use a FutureBuilder to lazily fetch the quoted message content by id
    return FutureBuilder<LocalMessage?>(
      future: ChatDatabase.getMessageByServerId(message.replyToId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final leftColor =
              isGroup ? _senderColor(context) : AppTheme.primaryColor;
          return _quotedContainer(context, '...', leftColor: leftColor);
        }
        final quoted = snapshot.data;
        if (quoted == null || (quoted.content?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
        final leftColor =
            isGroup ? _colorForUserId(quoted.senderId) : AppTheme.primaryColor;
        final user = _findParticipant(quoted.senderId);
        final quotedName = user?.displayName;
        final quotedAvatarUrl = user?.avatarUrl;
        return _quotedContainer(
          context,
          _wrapLinksForBreaking(quoted.content!),
          leftColor: leftColor,
          quotedName: quotedName,
          quotedAvatarUrl: quotedAvatarUrl,
        );
      },
    );
  }

  Widget _quotedContainer(
    BuildContext context,
    String text, {
    required Color leftColor,
    String? quotedName,
    String? quotedAvatarUrl,
  }) {
    final baseTextStyle = TextStyle(
      fontSize: 13,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkTextPrimary
          : AppTheme.textPrimary,
      height: 1.25,
    );

    final nameStyle = baseTextStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: quotedName != null && isGroup
          ? leftColor
          : (Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkTextSecondary
              : AppTheme.textSecondary),
    );

    Widget inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((quotedName?.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(quotedName!, style: nameStyle),
          ),
        _buildLinkifiedText(context, text, baseTextStyle),
      ],
    );

    if (isGroup && (quotedName?.isNotEmpty ?? false)) {
      final initials = _initialsFromName(quotedName!);
      inner = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: leftColor,
            backgroundImage:
                (quotedAvatarUrl != null && quotedAvatarUrl.isNotEmpty)
                    ? NetworkImage(quotedAvatarUrl)
                    : null,
            child: (quotedAvatarUrl == null || quotedAvatarUrl.isEmpty)
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: inner),
        ],
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.9)
            : AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: leftColor, width: 4),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.25,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: inner,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isSelectionMode) ...[
          Container(
            margin: const EdgeInsets.only(left: 2, right: 2),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (_shouldShowAvatar && !isSelectionMode) ...[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: (senderAvatarUrl != null &&
                              senderAvatarUrl!.isNotEmpty)
                          ? NetworkImage(senderAvatarUrl!)
                          : null,
                      child:
                          (senderAvatarUrl == null || senderAvatarUrl!.isEmpty)
                              ? Text(
                                  (senderName?.trim().isNotEmpty == true)
                                      ? senderName!
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
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: IntrinsicWidth(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isMe
                                    ? _getBubbleColor(context)
                                        .withValues(alpha: 0.8)
                                    : Colors.grey[300])
                                : _getBubbleColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: message.readStatus == 'failed'
                                ? Border.all(
                                    color: AppTheme.errorColor, width: 1)
                                : isSelected
                                    ? Border.all(
                                        color: AppTheme.primaryColor, width: 2)
                                    : null,
                            boxShadow: isSelected
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_shouldShowAvatar &&
                                  (senderName?.isNotEmpty ?? false))
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4, top: 0),
                                  child: Text(
                                    senderName!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _senderColor(context),
                                    ),
                                  ),
                                ),
                              _buildQuotedPreview(context),
                              // Main content
                              _buildLinkifiedText(
                                context,
                                message.content ?? '',
                                TextStyle(
                                  color: _getTextColor(context),
                                  fontSize: 15,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _getMetaTextColor(context),
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      _buildStatusIcon(
                                          message.readStatus, context),
                                    ],
                                  ],
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
