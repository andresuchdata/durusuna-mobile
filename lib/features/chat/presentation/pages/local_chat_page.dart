import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/performance_constants.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/models/local_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/providers/local_chat_providers.dart';
import '../../../../shared/services/local_chat_service.dart';
import '../../../../shared/services/chat_repository_service.dart';
import '../../../../shared/services/global_key_manager.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_action_bar.dart';
import '../widgets/local_message_bubble.dart';
import '../widgets/reaction_bar.dart';
import 'dart:convert';
import 'dart:async';
import '../../../../shared/widgets/reactions_widget.dart';
import '../widgets/chat_top_user_panel.dart';

/// Local-first chat page with instant loading and offline support
/// This is the new WhatsApp-style implementation
class LocalChatPage extends ConsumerStatefulWidget {
  final Conversation
      conversation; // Keep existing Conversation model for compatibility
  final String? highlightMessageId;
  final bool scrollToMessage;

  const LocalChatPage({
    super.key,
    required this.conversation,
    this.highlightMessageId,
    this.scrollToMessage = false,
  });

  @override
  ConsumerState<LocalChatPage> createState() => _LocalChatPageState();
}

class _LocalChatPageState extends ConsumerState<LocalChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Track online status of the other user dynamically
  late bool _isOtherUserOnline;

  // Track typing status of the other user
  bool _isOtherUserTyping = false;

  // Selection mode state
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;

  // UI: show floating reaction bar
  OverlayEntry? _reactionOverlay;
  void _showReactionBar(
      BuildContext context, Rect anchorRect, LocalMessage message) {
    _hideReactionBar();
    final overlay = Overlay.of(context);
    // Overlay is non-null in material apps; guard kept minimal
    // Position reaction bar near the trigger. If it's my message, place to the left.
    final currentUserId = ref.read(authStateProvider).user?.id;
    final isMe = currentUserId != null && message.senderId == currentUserId;
    final screenSize = MediaQuery.of(context).size;
    const estimatedBarWidth = 240.0;
    final top = anchorRect.bottom - 56;
    double left = isMe
        ? (anchorRect.left - estimatedBarWidth)
        : (anchorRect.right - estimatedBarWidth / 2);
    // Clamp to viewport
    if (left < 8) left = 8;
    if (left + estimatedBarWidth > screenSize.width - 8) {
      left = screenSize.width - estimatedBarWidth - 8;
    }
    _reactionOverlay = OverlayEntry(
      builder: (_) {
        final clampedTop =
            top.clamp(8.0, MediaQuery.of(context).size.height - 80);
        final clampedLeft = left;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideReactionBar,
                onSecondaryTap: _hideReactionBar,
              ),
            ),
            Positioned(
              top: clampedTop,
              left: clampedLeft,
              child: ReactionBar(
                emojis: const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
                onSelect: (emoji) async {
                  debugPrint(
                      '[Reaction] select: $emoji msg=${message.serverId ?? message.id}');
                  _hideReactionBar();
                  try {
                    if (message.serverId == null) return;
                    final reactionsMap = await ref
                        .read(localChatServiceProvider)
                        .toggleReactionOnServer(message.serverId!, emoji);
                    debugPrint('[Reaction] server updated: $reactionsMap');
                    await ChatRepositoryService.updateMessageReactions(
                      message.serverId!,
                      jsonEncode(reactionsMap),
                    );
                    // Refresh the messages to show updated reactions
                    ref
                        .read(localMessagesProvider(widget.conversation.id)
                            .notifier)
                        .refresh();
                  } catch (e) {
                    debugPrint('[Reaction] ERROR toggling reaction: $e');
                  }
                },
                onOpenPicker: () {
                  debugPrint(
                      '[Reaction] open picker for msg=${message.serverId ?? message.id}');
                  _hideReactionBar();
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(24),
                      child: ReactionPicker(
                        onEmojiSelected: (emoji) async {
                          debugPrint(
                              '[Reaction] picker select: $emoji msg=${message.serverId ?? message.id}');
                          try {
                            if (message.serverId == null) return;
                            final reactionsMap = await ref
                                .read(localChatServiceProvider)
                                .toggleReactionOnServer(
                                    message.serverId!, emoji);
                            debugPrint(
                                '[Reaction] server updated: $reactionsMap');
                            await ChatRepositoryService.updateMessageReactions(
                              message.serverId!,
                              jsonEncode(reactionsMap),
                            );
                            // Refresh the messages to show updated reactions
                            ref
                                .read(localMessagesProvider(
                                        widget.conversation.id)
                                    .notifier)
                                .refresh();
                          } catch (e) {
                            debugPrint(
                                '[Reaction] ERROR toggling reaction from picker: $e');
                          }
                        },
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_reactionOverlay!);
  }

  void _hideReactionBar() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }

  // Removed _buildReactionChips - reactions are now handled internally by LocalMessageBubble

  // State for replying to a message
  LocalMessage? _replyingToMessage;

  // Track last known message count to detect new arrivals
  int _lastMessageCount = 0;

  // Message highlighting removed - not used

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize online status from conversation
    _isOtherUserOnline = widget.conversation.isOnline;

    // Join conversation room for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final realtimeService = ref.read(realtimeServiceProvider);

      // Set current conversation ID to prevent unread count increments
      ref.read(currentConversationProvider.notifier).state =
          widget.conversation.id;

      realtimeService.joinConversation(widget.conversation.id);

      // Update last seen when entering conversation
      realtimeService.updateLastSeen(widget.conversation.id);

      // Request presence snapshot for the other user so we show status immediately
      final otherUserId = widget.conversation.otherUser?.id;
      if (otherUserId != null) {
        realtimeService.requestPresenceSnapshot(otherUserId);
      }

      // Mark as read when entering chat page
      _markOnChatPageEnter();
      // Connection state listening moved to build method to avoid assertion error

      // CRITICAL: Fix negative ID issue first
      Future.delayed(const Duration(milliseconds: 100), () async {
        try {
          await ChatRepositoryService.fixNegativeIdIssue();
        } catch (_) {
          // Silent fail - don't block chat loading
        }
      });

      // Reconcile any leftover pending messages on initial open
      Future.delayed(const Duration(milliseconds: 250), () async {
        try {
          final chatService = ref.read(localChatServiceProvider);
          await chatService.reconcilePendingOnOpen(widget.conversation.id);
        } catch (_) {}
      });

      // Ensure the most recent messages are present when opening chat, even if local DB isn't empty
      // Always perform a lightweight fetch + force sync to cover cases where
      // socket connection was delayed and message:new events were missed.
      Future.delayed(const Duration(milliseconds: 400), () async {
        try {
          final chatService = ref.read(localChatServiceProvider);
          await chatService.fetchLatestFromServer(
            widget.conversation.id,
            limit: 20,
          );
          await chatService.forceSyncMessagesFromServer(
            widget.conversation.id,
          );
          // Ensure UI reflects any new messages
          try {
            await ref
                .read(localMessagesProvider(widget.conversation.id).notifier)
                .refresh();
          } catch (_) {}
        } catch (_) {}
      });

      // NOTE: realtime message listener is attached in build() via ref.listen

      // CRITICAL: Sync existing reactions when chat page loads
      Future.delayed(const Duration(milliseconds: 800), () async {
        try {
          debugPrint(
              '🔄 [REACTION SYNC] Starting reaction sync for conversation ${widget.conversation.id}');
          await _syncExistingReactions();
          debugPrint(
              '✅ [REACTION SYNC] Completed reaction sync for conversation ${widget.conversation.id}');
        } catch (e) {
          debugPrint('❌ [REACTION SYNC] Failed to sync reactions: $e');
          debugPrint('❌ [REACTION SYNC] Error details: ${e.toString()}');
        }
      });

      // Handle message highlighting and scrolling if requested
      if (widget.highlightMessageId != null && widget.scrollToMessage) {
        _scrollToHighlightedMessage();
      } else {
        // Use delayed scroll method for better reliability
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _ensureScrollToBottom();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();

    // Clean up GlobalKey management via service
    GlobalKeyManager.instance.forceCleanup();

    // Leave conversation room and clear current conversation ID
    try {
      final realtimeService = ref.read(realtimeServiceProvider);
      realtimeService.leaveConversation(widget.conversation.id);
      // Safe to clear provider here
      ref.read(currentConversationProvider.notifier).state = null;
    } catch (e) {
      // Error in dispose
    }

    super.dispose();
  }

  @override
  void deactivate() {
    // Avoid modifying providers during lifecycle; handled in dispose()
    super.deactivate();
  }

  String _getDisplayName() {
    if (widget.conversation.type == 'group') {
      return widget.conversation.name ?? 'Group Chat';
    }
    final otherUser = widget.conversation.otherUser;
    return otherUser?.displayName ?? 'Unknown User';
  }

  String _getAvatarUrl() {
    if (widget.conversation.type == 'group') {
      return widget.conversation.avatarUrl ?? '';
    }
    return widget.conversation.otherUser?.avatarUrl ?? '';
  }

  String _getInitials() {
    if (widget.conversation.type == 'group') {
      final name = widget.conversation.name ?? 'Group';
      final words = name.split(' ').where((word) => word.isNotEmpty).toList();
      if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
        return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
      }
      return name.isNotEmpty ? name[0].toUpperCase() : 'G';
    }
    final otherUser = widget.conversation.otherUser;
    if (otherUser != null) {
      return _getUserInitials(otherUser.firstName, otherUser.lastName);
    }
    return 'U';
  }

  String _getUserInitials(String firstName, String lastName) {
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

  void _onScroll() {
    // Load more messages when scrolling to the top (older messages)
    if (_scrollController.position.pixels <= 200) {
      final messagesNotifier =
          ref.read(localMessagesProvider(widget.conversation.id).notifier);
      if (messagesNotifier.hasMore) {
        messagesNotifier.loadMore();
      }
    }

    // Mark conversation as read when user scrolls to bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _markAsReadWhenAtBottom();
    }
  }

  String? _getSenderDisplayName(LocalMessage message) {
    if (widget.conversation.type != 'group' || message.isFromMe) return null;
    try {
      final participant = widget.conversation.participants
          .firstWhere((p) => p.id == message.senderId);
      return '${participant.firstName} ${participant.lastName}'.trim();
    } catch (_) {
      return 'Unknown';
    }
  }

  String? _getSenderAvatarUrl(LocalMessage message) {
    if (widget.conversation.type != 'group' || message.isFromMe) return null;
    try {
      final participant = widget.conversation.participants
          .firstWhere((p) => p.id == message.senderId);
      return participant.avatarUrl;
    } catch (_) {
      return null;
    }
  }

  // Track if we've already marked as read when at bottom to avoid multiple calls
  bool _hasMarkedAsReadAtBottom = false;
  bool _isPullUpRefreshing = false;
  bool _showBottomPullHint = false;

  // Safely toggle bottom pull hint without mutating during layout
  void _setBottomPullHint(bool value) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showBottomPullHint = value);
      }
    });
  }

  void _markAsReadWhenAtBottom() {
    if (_hasMarkedAsReadAtBottom) return;

    _hasMarkedAsReadAtBottom = true;

    // Mark conversation as read locally (instant)
    ref
        .read(localConversationsProvider.notifier)
        .markAsRead(widget.conversation.id);

    // Reset flag after a delay to allow for future mark-as-read calls
    Future.delayed(const Duration(seconds: 2), () {
      _hasMarkedAsReadAtBottom = false;
    });
  }

  void _markOnChatPageEnter() {
    // Mark conversation as read when entering chat page
    ref
        .read(localConversationsProvider.notifier)
        .markAsRead(widget.conversation.id);

    // Also send read receipts for unread messages from other users
    _sendReadReceiptsForUnreadMessages();
  }

  Future<void> _syncLatestFromServer() async {
    try {
      final chatService = ref.read(localChatServiceProvider);
      await chatService.fetchLatestFromServer(
        widget.conversation.id,
        limit: 30,
      );
      await chatService.forceSyncMessagesFromServer(
        widget.conversation.id,
      );
      await ref
          .read(localMessagesProvider(widget.conversation.id).notifier)
          .refresh();
    } catch (_) {}
  }

  void _startPullUpRefresh() {
    if (_isPullUpRefreshing) return;
    _isPullUpRefreshing = true;
    _setBottomPullHint(true);
    _syncLatestFromServer().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 400), () {
        _isPullUpRefreshing = false;
        _setBottomPullHint(false);
      });
    });
  }

  void _sendReadReceiptsForUnreadMessages() {
    // Get current messages and send read receipts for unread ones from other users
    final messagesAsync =
        ref.read(localMessagesProvider(widget.conversation.id));
    messagesAsync.whenData((messages) {
      final unreadFromOthers = messages
          .where((msg) =>
              !msg.isFromMe &&
              msg.serverId != null &&
              (msg.readStatus == 'sent' || msg.readStatus == 'delivered'))
          .map((msg) => msg.serverId!)
          .toList();

      if (unreadFromOthers.isNotEmpty) {
        debugPrint(
            '📖 Sending read receipts for ${unreadFromOthers.length} unread messages');
        final realtimeService = ref.read(realtimeServiceProvider);
        realtimeService.markAsRead(unreadFromOthers, widget.conversation.id);
      }
    });
  }

  /// Sync existing reactions from server when chat page loads
  /// This ensures users see reactions that were added before they joined
  Future<void> _syncExistingReactions() async {
    try {
      debugPrint('🔄 [REACTION SYNC] _syncExistingReactions() called');
      final chatService = ref.read(localChatServiceProvider);

      // Get current local messages that have server IDs
      final messagesAsync =
          ref.read(localMessagesProvider(widget.conversation.id));
      debugPrint(
          '🔄 [REACTION SYNC] Got messagesAsync: ${messagesAsync.runtimeType}');

      await messagesAsync.when(
        data: (messages) async {
          debugPrint(
              '🔄 [REACTION SYNC] Processing ${messages.length} total messages');
          final serverMessageIds = messages
              .where((msg) =>
                  msg.serverId != null && !msg.serverId!.startsWith('failed_'))
              .map((msg) => msg.serverId!)
              .toList();

          debugPrint(
              '🔄 [REACTION SYNC] Found ${serverMessageIds.length} messages with server IDs');

          if (serverMessageIds.isEmpty) {
            debugPrint(
                '🔄 [REACTION SYNC] No server messages to sync reactions for');
            return;
          }

          debugPrint(
              '🔄 [REACTION SYNC] Syncing reactions for ${serverMessageIds.length} messages');
          debugPrint(
              '🔄 [REACTION SYNC] Message IDs: ${serverMessageIds.take(5).join(", ")}${serverMessageIds.length > 5 ? "..." : ""}');

          // Fetch updated message data including reactions from server
          await chatService.syncMessageReactions(
              widget.conversation.id, serverMessageIds);

          debugPrint(
              '✅ [REACTION SYNC] Successfully synced reactions for ${serverMessageIds.length} messages');
        },
        loading: () async {
          debugPrint(
              '🔄 [REACTION SYNC] Messages still loading, skipping reaction sync');
        },
        error: (error, stack) async {
          debugPrint(
              '❌ [REACTION SYNC] Error getting messages for reaction sync: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ [REACTION SYNC] Failed to sync existing reactions: $e');
      debugPrint('❌ [REACTION SYNC] Stack trace: ${StackTrace.current}');
    }
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return ChatActionBar(
        selectedCount: _selectedMessageIds.length,
        canReply: _selectedMessageIds.length == 1,
        onReply: _handleReplySelection,
        onForward: _handleForwardSelection,
        onDelete: _handleDeleteSelection,
        onCancel: _exitSelectionMode,
      );
    } else {
      return ChatTopUserPanel(
        displayName: _getDisplayName(),
        avatarUrl: _getAvatarUrl(),
        initials: _getInitials(),
        isDirect: widget.conversation.type == 'direct',
        isOnline: _isOtherUserOnline,
        isTyping: _isOtherUserTyping,
        lastSeenLabel: widget.conversation.lastActivity != null
            ? 'Last seen ${timeago.format(widget.conversation.lastActivity!)}'
            : 'Last seen recently',
        onAvatarTap: _showProfileCard,
        onVoiceCall: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice call coming soon')),
          );
        },
        onVideoCall: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video call coming soon')),
          );
        },
        onClearChat: _showClearChatDialog,
        onBlockUser: _showBlockUserDialog,
      );
    }
  }

  void _showProfileCard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isGroup = widget.conversation.type == 'group';
        final name = _getDisplayName();
        final avatarUrl = _getAvatarUrl();
        final initials = _getInitials();
        final description = isGroup
            ? (widget.conversation.description ?? 'No description')
            : (widget.conversation.otherUser?.email ?? '');

        return _ProfileCardSheet(
          isGroup: isGroup,
          name: name,
          avatarUrl: avatarUrl,
          initials: initials,
          description: description,
          participants: widget.conversation.participants,
          isOnline: widget.conversation.isOnline,
          lastSeenLabel: widget.conversation.lastActivity != null
              ? 'Last seen ${timeago.format(widget.conversation.lastActivity!)}'
              : null,
        );
      },
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
            'Are you sure you want to clear this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement clear chat
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${_getDisplayName()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement block user
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _scrollToHighlightedMessage() {
    if (widget.highlightMessageId == null) return;

    // Wait for messages to load, then scroll to the highlighted message
    Future.delayed(const Duration(milliseconds: 1000), () {
      final messageKey = GlobalKeyManager.instance
          .getMessageKey(widget.highlightMessageId!, widget.conversation.id);
      if (messageKey.currentContext != null) {
        Scrollable.ensureVisible(
          messageKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        // Add highlighting animation
        _highlightMessage(widget.highlightMessageId!);
      }
    });
  }

  void _highlightMessage(String messageId) {
    // TODO: Implement message highlighting if needed
    // For now, just show a snackbar to indicate the message was found
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scrolled to message: $messageId'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Get GlobalKey for local message (delegated to GlobalKeyManager service)
  /// Uses content hash for additional uniqueness to prevent conflicts
  GlobalKey _getMessageKeyByLocalId(int localId, {String? content}) {
    return GlobalKeyManager.instance.getLocalMessageKeyWithContent(
        localId, widget.conversation.id, content);
  }

  void _replyToMessage(LocalMessage message) {
    setState(() {
      _replyingToMessage = message;
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
    _focusNode.requestFocus();
  }

  // Selection mode methods moved below to avoid duplicates

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  /// Enter selection mode and select the tapped message
  void _enterSelectionMode(LocalMessage message) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(message.serverId ?? message.id.toString());
      _replyingToMessage = null; // Cancel any ongoing reply
    });
  }

  /// Toggle message selection in selection mode
  void _toggleMessageSelection(LocalMessage message) {
    if (!_isSelectionMode) return;

    setState(() {
      final messageId = message.serverId ?? message.id.toString();
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        if (_selectedMessageIds.length < 5) {
          // Max 5 for forwarding (like WhatsApp)
          _selectedMessageIds.add(messageId);
        }
      }
    });
  }

  void _handleReplySelection() {
    if (_selectedMessageIds.length == 1) {
      final messagesAsync =
          ref.read(localMessagesProvider(widget.conversation.id));

      messagesAsync.whenData((messages) {
        final message = messages.firstWhere(
          (msg) =>
              (msg.serverId ?? msg.id.toString()) == _selectedMessageIds.first,
          orElse: () => messages.first, // Fallback
        );
        _replyToMessage(message);
      });
    }
  }

  void _handleForwardSelection() {
    final messagesAsync =
        ref.read(localMessagesProvider(widget.conversation.id));

    messagesAsync.whenData((messages) {
      final messagesToForward = messages
          .where((msg) =>
              _selectedMessageIds.contains(msg.serverId ?? msg.id.toString()))
          .toList();

      // TODO: Implement proper forwarding when forward page is compatible with LocalMessage

      // Show forward contacts page (assuming it exists and works with Message objects)
      // For now, show a placeholder message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Forward ${messagesToForward.length} message${messagesToForward.length != 1 ? 's' : ''} (coming soon)'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );

      _exitSelectionMode();
    });
  }

  // Message type conversion removed - not used for now

  void _handleDeleteSelection() {
    if (_selectedMessageIds.isEmpty) return;
    // Single confirmation is handled inside deleteBatchMessages
    _deleteSelectedMessages();
  }

  /// Delete all selected messages using batch delete
  Future<void> _deleteSelectedMessages() async {
    final messagesAsync =
        ref.read(localMessagesProvider(widget.conversation.id));

    messagesAsync.whenData((messages) async {
      final messagesToDelete = messages
          .where((msg) =>
              _selectedMessageIds.contains(msg.serverId ?? msg.id.toString()))
          .toList();

      if (messagesToDelete.isEmpty) {
        _exitSelectionMode();
        return;
      }

      final notifier =
          ref.read(localMessagesProvider(widget.conversation.id).notifier);

      // Use batch delete - single confirmation modal for all messages
      await notifier.deleteBatchMessages(messagesToDelete, context);

      _exitSelectionMode();

      // Feedback is already handled in deleteBatchMessages method
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final targetPosition = position.maxScrollExtent;

    if (targetPosition <= 0) {
      return;
    }

    try {
      if (animated) {
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(targetPosition);
      }
    } catch (e) {
      // Error in scrollToBottom
    }
  }

  void _ensureScrollToBottom() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleTyping(bool isTyping) {
    final realtimeService = ref.read(realtimeServiceProvider);
    if (realtimeService.isConnected) {
      if (isTyping) {
        realtimeService.startTyping(widget.conversation.id);
      } else {
        realtimeService.stopTyping(widget.conversation.id);
      }
    }
  }

  Future<void> _sendMessage({String? content}) async {
    final uiStartTime = DateTime.now();
    debugPrint(
        '🐛 [UI] _sendMessage called at ${uiStartTime.millisecondsSinceEpoch}');
    debugPrint('🐛 [UI] Content: "$content"');

    if (content?.trim().isEmpty ?? true) {
      debugPrint('🐛 [UI] Empty content, returning early');
      return;
    }

    try {
      // Convert LocalMessageType to match the message type system
      LocalMessageType messageType = LocalMessageType.text;

      debugPrint('🐛 [UI] Calling provider.sendMessage...');
      final providerCallStart = DateTime.now();

      // Send message through local provider (instant UI update)
      await ref
          .read(localMessagesProvider(widget.conversation.id).notifier)
          .sendMessage(
            content!,
            messageType: messageType,
            replyToId: _replyingToMessage?.serverId,
          );

      final providerCallEnd = DateTime.now();
      debugPrint(
          '🐛 [UI] Provider.sendMessage took: ${providerCallEnd.difference(providerCallStart).inMilliseconds}ms');

      debugPrint('🐛 [UI] Clearing message controller...');
      _messageController.clear();

      // Clear reply state after sending
      if (_replyingToMessage != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }

      debugPrint('🐛 [UI] Scrolling to bottom...');
      // Wait for UI to update then scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom(animated: true);
        }
      });

      // Also add a slight delay as backup
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottom(animated: true);
        }
      });

      final uiEndTime = DateTime.now();
      debugPrint(
          '🐛 [UI] ✅ _sendMessage COMPLETED in: ${uiEndTime.difference(uiStartTime).inMilliseconds}ms');
    } catch (e) {
      debugPrint('🐛 [UI] ❌ _sendMessage FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔍 [UI] LocalChatPage.build() called for conversationId: "${widget.conversation.id}"');
    final authState = ref.watch(authStateProvider);
    final messagesAsync =
        ref.watch(localMessagesProvider(widget.conversation.id));
    debugPrint('🔍 [UI] messagesAsync state: ${messagesAsync.runtimeType}');

    // Real-time messages are now handled by the centralized RealtimeDispatcher
    // This ensures no duplicate processing and better performance

    // CRITICAL: Listen for real-time connection state and re-join when connected
    ref.listen(realtimeConnectionProvider, (previous, next) {
      next.whenData((isConnected) {
        if (isConnected) {
          try {
            final rs = ref.read(realtimeServiceProvider);
            rs.joinConversation(widget.conversation.id);
            debugPrint(
                '🔊 [UI] Re-joined room on connect: ${widget.conversation.id}');
          } catch (_) {}
        }
      });
    });

    // CRITICAL: Listen for real-time messages and refresh this conversation's list only
    ref.listen(realtimeMessagesProvider, (previous, next) {
      next.whenData((rtMessage) {
        if (rtMessage.conversationId == widget.conversation.id) {
          try {
            ref
                .read(localMessagesProvider(widget.conversation.id).notifier)
                .refresh();
          } catch (_) {}
        }
      });
    });

    // CRITICAL: Listen for real-time typing indicators
    ref.listen(realtimeTypingProvider, (previous, next) {
      next.whenData((typingEvent) {
        if (typingEvent.conversationId == widget.conversation.id) {
          final otherUserId = widget.conversation.otherUser?.id;
          if (otherUserId != null && typingEvent.userId == otherUserId) {
            setState(() {
              _isOtherUserTyping = typingEvent.isTyping;
            });

            // Auto-hide typing indicator after 3 seconds of no updates
            if (typingEvent.isTyping) {
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _isOtherUserTyping = false;
                  });
                }
              });
            }
          }
        }
      });
    });

    // CRITICAL: Listen for real-time presence updates
    ref.listen(realtimePresenceProvider, (previous, next) {
      next.whenData((presenceEvent) {
        final otherUserId = widget.conversation.otherUser?.id;
        if (otherUserId != null && presenceEvent.userId == otherUserId) {
          setState(() {
            _isOtherUserOnline = presenceEvent.isOnline;
          });
        }
      });
    });

    // DEBUG: Log message count and conversation details
    messagesAsync.whenData((messages) {
      debugPrint(
          '🐛 [DEBUG] LocalChatPage: conversationId="${widget.conversation.id}" has ${messages.length} messages');
      debugPrint('🐛 [DEBUG] Conversation type: ${widget.conversation.type}');
      debugPrint(
          '🐛 [DEBUG] Last message in conversation model: ${widget.conversation.lastMessage?.content ?? "null"}');
    });

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.chatBackgroundDark
          : AppTheme.chatBackgroundLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                // Auto-scroll when new incoming messages appear (no ref.listen here)
                if (messages.length > _lastMessageCount) {
                  final last = messages.isNotEmpty ? messages.last : null;
                  if (last != null && last.isFromMe == false) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _scrollToBottom(animated: true);
                      }
                    });
                  }
                }
                _lastMessageCount = messages.length;

                // Use bottom pull-up to refresh latest instead of top indicator
                return _buildMessagesList(messages, authState);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error),
            ),
          ),

          // Bottom section
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply preview
              if (_replyingToMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.chatBackgroundDark
                      : AppTheme.chatBackgroundLight,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Replying to ${_replyingToMessage!.isFromMe ? 'You' : 'them'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _replyingToMessage!.content ?? '',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _replyingToMessage = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

              // Chat input area
              ChatInput(
                controller: _messageController,
                focusNode: _focusNode,
                onSend: (content) => _sendMessage(content: content),
                onTyping: _handleTyping,
                onAttachment: () {
                  // TODO: Implement attachments
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<LocalMessage> messages, dynamic authState) {
    // CRITICAL: Deduplicate messages at UI level to prevent GlobalKey conflicts
    // This prevents crashes when duplicate messages exist in the database
    final deduplicatedMessages = <LocalMessage>[];
    final seenLocalIds = <int>{};
    final seenServerIds = <String>{};

    for (final message in messages) {
      bool shouldAdd = true;

      // Check for duplicate local IDs
      if (seenLocalIds.contains(message.id)) {
        debugPrint('🚨 UI: Skipping duplicate local ID: ${message.id}');
        shouldAdd = false;
      }

      // Check for duplicate server IDs
      if (message.serverId != null &&
          seenServerIds.contains(message.serverId)) {
        debugPrint('🚨 UI: Skipping duplicate server ID: ${message.serverId}');
        shouldAdd = false;
      }

      if (shouldAdd) {
        deduplicatedMessages.add(message);
        seenLocalIds.add(message.id);
        if (message.serverId != null) {
          seenServerIds.add(message.serverId!);
        }
      }
    }

    if (deduplicatedMessages.length != messages.length) {
      debugPrint(
          '🧹 UI: Filtered ${messages.length - deduplicatedMessages.length} duplicate messages from UI');
    }

    // AlwaysScrollable so RefreshIndicator can trigger even with few/no items
    // Calculate item count including typing indicator
    final itemCount =
        (deduplicatedMessages.isEmpty ? 0 : deduplicatedMessages.length) +
            (_isOtherUserTyping ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final position = _scrollController.position;
        // Detect pull-up gesture near bottom to sync latest
        if (notification is OverscrollNotification &&
            notification.overscroll > 8 &&
            position.pixels >= position.maxScrollExtent - 8 &&
            !_isPullUpRefreshing) {
          _startPullUpRefresh();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true, // Show latest messages at bottom
        physics: const AlwaysScrollableScrollPhysics(
            parent: HighRefreshScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 32),
        itemCount: itemCount + 1, // add spacer for bottom-overscroll affordance
        cacheExtent: 500, // Cache more items for smoother scrolling
        addRepaintBoundaries: true, // Isolate repaints
        itemBuilder: (context, index) {
          if (index == itemCount) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity:
                      _isPullUpRefreshing || _showBottomPullHint ? 1.0 : 0.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: _isPullUpRefreshing
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Icon(Icons.arrow_upward, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPullUpRefreshing
                            ? 'Syncing latest…'
                            : 'Pull up to fetch latest',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (deduplicatedMessages.isEmpty) {
            // Render a spacer so the list still lays out and allows pull-to-refresh
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: _buildEmptyState(),
            );
          }
          // Show typing indicator at the end of the list
          if (index == deduplicatedMessages.length && _isOtherUserTyping) {
            return _buildTypingIndicator();
          }

          if (index >= deduplicatedMessages.length) {
            return const SizedBox.shrink();
          }
          final message = deduplicatedMessages[index];
          final isMe = message.isFromMe;
          final showTimestamp = _shouldShowTimestamp(
            message,
            index > 0 ? deduplicatedMessages[index - 1] : null,
          );

          return Column(
            children: [
              if (showTimestamp)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _formatTimestamp(message.createdAt),
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              // 🚀 Enhanced message bubble with selection support
              RepaintBoundary(
                child: LocalMessageBubble(
                  // Use localId-based key to avoid duplicate GlobalKey errors when serverId/clientId change
                  key: _getMessageKeyByLocalId(message.id,
                      content: message.content),
                  message: message,
                  isMe: isMe,
                  isGroup: widget.conversation.type == 'group',
                  isSelectionMode: _isSelectionMode,
                  isSelected: _selectedMessageIds
                      .contains(message.serverId ?? message.id.toString()),
                  senderName: _getSenderDisplayName(message),
                  senderAvatarUrl: _getSenderAvatarUrl(message),
                  participants: widget.conversation.participants,
                  reactionsJson: message.reactions,
                  currentUserId: authState.user?.id,
                  onReactionTap: (emoji) async {
                    try {
                      if (message.serverId == null) return;
                      final reactionsMap = await ref
                          .read(localChatServiceProvider)
                          .toggleReactionOnServer(message.serverId!, emoji);
                      await ChatRepositoryService.updateMessageReactions(
                        message.serverId!,
                        jsonEncode(reactionsMap),
                      );
                      // Refresh the messages to show updated reactions
                      ref
                          .read(localMessagesProvider(widget.conversation.id)
                              .notifier)
                          .refresh();
                    } catch (_) {}
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleMessageSelection(message);
                    }
                  },
                  onLongPress: () {
                    if (_isSelectionMode) {
                      _toggleMessageSelection(message);
                    } else {
                      _enterSelectionMode(message);
                    }
                  },
                  onDoubleTap: () {
                    // Quick react: show bar centered over bubble for now
                    final key = _getMessageKeyByLocalId(message.id,
                        content: message.content);
                    final ctx = key.currentContext;
                    if (ctx != null) {
                      final box = ctx.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final rect = box.localToGlobal(Offset.zero) & box.size;
                        _showReactionBar(context, rect, message);
                      }
                    }
                  },
                  onAddReaction: () {
                    final key = _getMessageKeyByLocalId(message.id,
                        content: message.content);
                    final ctx = key.currentContext;
                    if (ctx != null) {
                      final box = ctx.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final rect = box.localToGlobal(Offset.zero) & box.size;
                        _showReactionBar(context, rect, message);
                      }
                    }
                  },
                ),
              ),
              // Reactions are now handled internally by LocalMessageBubble
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated typing dots
              SizedBox(
                width: 24,
                height: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTypingDot(0),
                    _buildTypingDot(1),
                    _buildTypingDot(2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppTheme.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (mounted && _isOtherUserTyping) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${_getDisplayName()}',
            style: const TextStyle(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load messages',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.errorColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(localMessagesProvider(widget.conversation.id).notifier)
                  .refresh();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  bool _shouldShowTimestamp(LocalMessage current, LocalMessage? previous) {
    if (previous == null) return true;

    final currentDate = DateTime(
      current.createdAt.year,
      current.createdAt.month,
      current.createdAt.day,
    );

    final previousDate = DateTime(
      previous.createdAt.year,
      previous.createdAt.month,
      previous.createdAt.day,
    );

    return !currentDate.isAtSameMomentAs(previousDate);
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (messageDate
        .isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Removed message options bottom sheet; long-press selects the message.

  // (unused)
  // void _copyMessage(LocalMessage message) {}

  // Status icon logic moved to LocalMessageBubble
}

class _ProfileCardSheet extends StatelessWidget {
  final bool isGroup;
  final String name;
  final String avatarUrl;
  final String initials;
  final String description;
  final List<User> users;
  final bool isOnline;
  final String? lastSeenLabel;

  const _ProfileCardSheet({
    required this.isGroup,
    required this.name,
    required this.avatarUrl,
    required this.initials,
    required this.description,
    required List<User> participants,
    required this.isOnline,
    required this.lastSeenLabel,
  }) : users = participants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.primaryColor,
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          if (!isGroup && isOnline)
                            Container(
                              margin:
                                  const EdgeInsets.only(right: 4, bottom: 4),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!isGroup && (lastSeenLabel != null))
                        Text(
                          isOnline ? 'Online' : lastSeenLabel!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isOnline
                                ? AppTheme.successColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      if (isGroup && description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (isGroup)
                        const Row(
                          children: [
                            Text(
                              'Participants',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (isGroup)
                SliverList.separated(
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        backgroundImage: (user.avatarUrl?.isNotEmpty ?? false)
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: (user.avatarUrl == null ||
                                user.avatarUrl!.isEmpty)
                            ? Text(
                                _initialsFrom(user.firstName, user.lastName),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              )
                            : null,
                      ),
                      title: Text('${user.firstName} ${user.lastName}'.trim()),
                      subtitle: Text(user.email),
                    );
                  },
                  separatorBuilder: (context, _) => const Divider(height: 1),
                  itemCount: users.length,
                ),
              SliverToBoxAdapter(
                  child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16)),
            ],
          ),
        );
      },
    );
  }

  String _initialsFrom(String first, String last) {
    final a = first.isNotEmpty ? first[0].toUpperCase() : '';
    final b = last.isNotEmpty ? last[0].toUpperCase() : '';
    return (a + b).isNotEmpty ? (a + b) : 'U';
  }
}
