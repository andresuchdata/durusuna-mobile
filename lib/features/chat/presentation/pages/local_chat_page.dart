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
import '../../../../shared/services/debug_sync_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_action_bar.dart';
import '../widgets/local_message_bubble.dart';
import '../widgets/reaction_bar.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../../../../shared/widgets/reactions_widget.dart';
import '../../../../shared/widgets/typing_indicator.dart';
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
  Timer? _typingAutoHideTimer;

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

  // CRITICAL: Prevent rapid message updates that cause flickering
  Timer? _messageUpdateTimer;
  int _pendingMessageCount = 0;

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

      // CRITICAL: Set current conversation provider to track that user is viewing this conversation
      // This is used by the realtime dispatcher to determine when to send read receipts
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
      }

      // Ensure scroll to bottom after initial load
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          debugPrint('🔄 [UI] Initial scroll to bottom after page load...');
          _scrollToBottom(animated: false);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _typingAutoHideTimer?.cancel();
    _messageUpdateTimer?.cancel();

    // Clean up GlobalKey management via service
    GlobalKeyManager.instance.forceCleanup();

    // CRITICAL: Clear current conversation provider when leaving chat page
    // This prevents read receipts from being sent when user is not viewing this conversation
    try {
      ref.read(currentConversationProvider.notifier).state = null;
    } catch (e) {
      // Error clearing providerx
    }

    // Leave conversation room
    try {
      final realtimeService = ref.read(realtimeServiceProvider);
      realtimeService.leaveConversation(widget.conversation.id);
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

    // For direct messages, try multiple fallback strategies
    final otherUser = widget.conversation.otherUser;
    if (otherUser != null) {
      // Try displayName first
      if (otherUser.displayName.isNotEmpty) {
        return otherUser.displayName;
      }

      // Try firstName + lastName
      if (otherUser.firstName.isNotEmpty || otherUser.lastName.isNotEmpty) {
        return '${otherUser.firstName} ${otherUser.lastName}'.trim();
      }

      // Try email as last resort
      if (otherUser.email.isNotEmpty) {
        return otherUser.email;
      }
    }

    // If otherUser is null or has no usable info, try to get from participants
    if (widget.conversation.participants.isNotEmpty) {
      // Find the other participant (not the current user)
      final currentUserId = ref.read(authStateProvider).user?.id;
      final otherParticipant = widget.conversation.participants
          .where((p) => p.id != currentUserId)
          .firstOrNull;

      if (otherParticipant != null) {
        if (otherParticipant.firstName.isNotEmpty ||
            otherParticipant.lastName.isNotEmpty) {
          return '${otherParticipant.firstName} ${otherParticipant.lastName}'
              .trim();
        }
        if (otherParticipant.email.isNotEmpty) {
          return otherParticipant.email;
        }
      }
    }

    // Final fallback - try to use the conversation name if it's not generic
    if (widget.conversation.name != null &&
        widget.conversation.name!.isNotEmpty &&
        widget.conversation.name != 'Direct Message' &&
        widget.conversation.name != 'Unknown User') {
      return widget.conversation.name!;
    }

    // Last resort
    return 'Unknown User';
  }

  String _getAvatarUrl() {
    if (widget.conversation.type == 'group') {
      return widget.conversation.avatarUrl ?? '';
    }

    // For direct messages, try multiple fallback strategies
    final otherUser = widget.conversation.otherUser;
    if (otherUser != null && otherUser.avatarUrl?.isNotEmpty == true) {
      return otherUser.avatarUrl!;
    }

    // If otherUser is null or has no avatar, try to get from participants
    if (widget.conversation.participants.isNotEmpty) {
      // Find the other participant (not the current user)
      final currentUserId = ref.read(authStateProvider).user?.id;
      final otherParticipant = widget.conversation.participants
          .where((p) => p.id != currentUserId)
          .firstOrNull;

      if (otherParticipant?.avatarUrl?.isNotEmpty == true) {
        return otherParticipant!.avatarUrl!;
      }
    }

    // Final fallback - try to use the conversation avatar
    return widget.conversation.avatarUrl ?? '';
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

    // For direct messages, try multiple fallback strategies
    final otherUser = widget.conversation.otherUser;
    if (otherUser != null) {
      final initials =
          _getUserInitials(otherUser.firstName, otherUser.lastName);
      if (initials != 'U') {
        return initials;
      }
    }

    // If otherUser is null or has no usable info, try to get from participants
    if (widget.conversation.participants.isNotEmpty) {
      // Find the other participant (not the current user)
      final currentUserId = ref.read(authStateProvider).user?.id;
      final otherParticipant = widget.conversation.participants
          .where((p) => p.id != currentUserId)
          .firstOrNull;

      if (otherParticipant != null) {
        final initials = _getUserInitials(
            otherParticipant.firstName, otherParticipant.lastName);
        if (initials != 'U') {
          return initials;
        }
      }
    }

    // Final fallback - try to use the conversation name if it's not generic
    if (widget.conversation.name != null &&
        widget.conversation.name!.isNotEmpty &&
        widget.conversation.name != 'Direct Message' &&
        widget.conversation.name != 'Unknown User') {
      final words = widget.conversation.name!
          .split(' ')
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
        return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
      }
      return widget.conversation.name![0].toUpperCase();
    }

    // Last resort
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
    // Since ListView is reversed:
    // - pixels = 0 means we're at the bottom (latest messages)
    // - pixels = maxScrollExtent means we're at the top (oldest messages)

    // Load more messages when scrolling to the top (older messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final messagesNotifier =
          ref.read(localMessagesProvider(widget.conversation.id).notifier);
      if (messagesNotifier.hasMore) {
        messagesNotifier.loadMore();
      }
    }

    // Mark conversation as read when user scrolls to bottom (latest messages)
    if (_scrollController.position.pixels <= 100) {
      debugPrint(
          '📖 [DEBUG] Scroll position <= 100, calling _markAsReadWhenAtBottom()');
      debugPrint(
          '📖 [DEBUG] Current pixels: ${_scrollController.position.pixels}');
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
    debugPrint('📖 [DEBUG] _markAsReadWhenAtBottom() called');
    if (_hasMarkedAsReadAtBottom) {
      debugPrint('📖 [DEBUG] Already marked as read at bottom, skipping');
      return;
    }

    debugPrint('📖 [DEBUG] Setting _hasMarkedAsReadAtBottom = true');
    _hasMarkedAsReadAtBottom = true;

    // Send read receipts via WebSocket (handles both database and notifications)
    debugPrint('📖 [DEBUG] Calling _sendReadReceiptsForUnreadMessages()');
    _sendReadReceiptsForUnreadMessages();

    // Reset flag after a delay to allow for future mark-as-read calls
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('📖 [DEBUG] Resetting _hasMarkedAsReadAtBottom = false');
      _hasMarkedAsReadAtBottom = false;
    });
  }

  void _markOnChatPageEnter() {
    debugPrint('📖 [DEBUG] _markOnChatPageEnter() called');
    // Send read receipts for unread messages from other users (WebSocket only - handles both database and notifications)
    debugPrint(
        '📖 [DEBUG] Calling _sendReadReceiptsForUnreadMessages() from _markOnChatPageEnter');
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
    debugPrint(
        '📖 [READ_RECEIPTS] _sendReadReceiptsForUnreadMessages() called (WebSocket only)');

    // Extra safety check: ensure user is actually viewing this conversation
    final currentConversationId = ref.read(currentConversationProvider);
    final isViewingThisConversation =
        currentConversationId == widget.conversation.id;

    if (!isViewingThisConversation) {
      debugPrint(
          '📖 [READ_RECEIPTS] Skipping - user not viewing this conversation (current: $currentConversationId, expected: ${widget.conversation.id})');
      return;
    }

    // Get current messages and send read receipts for unread ones from other users
    final messagesAsync =
        ref.read(localMessagesProvider(widget.conversation.id));
    messagesAsync.whenData((messages) {
      debugPrint(
          '📖 [READ_RECEIPTS] Processing ${messages.length} total messages');

      // Debug: Show status of each message
      for (final msg in messages) {
        debugPrint(
            '📖 [READ_RECEIPTS] Message ${msg.serverId}: isFromMe=${msg.isFromMe}, status=${msg.readStatus}');
      }

      final unreadFromOthers = messages
          .where((msg) =>
              !msg.isFromMe &&
              msg.serverId != null &&
              (msg.readStatus == 'sent' || msg.readStatus == 'delivered'))
          .map((msg) => msg.serverId!)
          .toList();

      debugPrint(
          '📖 [READ_RECEIPTS] Found ${unreadFromOthers.length} unread messages from others');

      if (unreadFromOthers.isNotEmpty) {
        debugPrint(
            '📖 [WEBSOCKET] Sending read receipts for ${unreadFromOthers.length} unread messages');
        debugPrint(
            '📖 [WEBSOCKET] Message IDs: ${unreadFromOthers.join(', ')}');
        final realtimeService = ref.read(realtimeServiceProvider);

        // Debug: Check WebSocket connection status
        debugPrint(
            '📖 [WEBSOCKET] Connection status: ${realtimeService.isConnected}');

        realtimeService.markAsRead(unreadFromOthers, widget.conversation.id);

        // CRITICAL: Also update the local conversations provider to reflect the unread count change
        try {
          ref
              .read(localConversationsProvider.notifier)
              .markAsRead(widget.conversation.id);
          debugPrint(
              '📖 [READ_RECEIPTS] Local conversations provider updated with unread count = 0');
        } catch (e) {
          debugPrint(
              '⚠️ [READ_RECEIPTS] Failed to update local conversations provider: $e');
        }
      } else {
        debugPrint(
            '📖 [READ_RECEIPTS] No unread messages to send read receipts for');
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
      debugPrint(
          '⚠️ [UI] Cannot scroll to bottom: mounted=$mounted, hasClients=${_scrollController.hasClients}');
      return;
    }

    try {
      final position = _scrollController.position;
      // Since ListView is reversed, scroll to 0 to show latest messages (bottom)
      final targetPosition = 0.0;

      debugPrint(
          '🔄 [UI] Scrolling to bottom: targetPosition=$targetPosition, animated=$animated, currentPosition=${position.pixels}');

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
      debugPrint('❌ [UI] Error in _scrollToBottom: $e');
    }
  }

  void _handleTyping(bool isTyping) {
    final realtimeService = ref.read(realtimeServiceProvider);
    debugPrint(
        '⌨️ [LOCAL_CHAT] _handleTyping called: isTyping=$isTyping, isConnected=${realtimeService.isConnected}');
    if (realtimeService.isConnected) {
      if (isTyping) {
        realtimeService.startTyping(widget.conversation.id);
      } else {
        realtimeService.stopTyping(widget.conversation.id);
      }
    } else {
      debugPrint(
          '⌨️ [LOCAL_CHAT] Realtime service not connected, cannot send typing event');
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
    debugPrint('🔍 [UI] _isOtherUserTyping: $_isOtherUserTyping');
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

            // CRITICAL: Send read receipt immediately for incoming messages from other users
            // Only if user is actually viewing this conversation
            final currentUserId = ref.read(authStateProvider).user?.id;
            final isFromOtherUser = currentUserId != null &&
                rtMessage.message.senderId != currentUserId;
            final currentConversationId = ref.read(currentConversationProvider);
            final isViewingThisConversation =
                currentConversationId == widget.conversation.id;

            if (isFromOtherUser &&
                rtMessage.message.serverId != null &&
                isViewingThisConversation) {
              debugPrint(
                  '📖 [REALTIME] Incoming message from other user, sending read receipt');
              debugPrint(
                  '📖 [REALTIME] Message ID: ${rtMessage.message.serverId}');
              debugPrint(
                  '📖 [REALTIME] Sender ID: ${rtMessage.message.senderId}');
              debugPrint('📖 [REALTIME] Current User ID: $currentUserId');

              // Send read receipt via WebSocket immediately
              final realtimeService = ref.read(realtimeServiceProvider);
              realtimeService.markAsRead(
                  [rtMessage.message.serverId!], widget.conversation.id);
            } else {
              if (!isFromOtherUser) {
                debugPrint(
                    '📖 [REALTIME] Skipping read receipt - message is from current user');
              } else if (rtMessage.message.serverId == null) {
                debugPrint(
                    '📖 [REALTIME] Skipping read receipt - missing serverId');
              } else if (!isViewingThisConversation) {
                debugPrint(
                    '📖 [REALTIME] Skipping read receipt - user not viewing this conversation');
              }
            }
          } catch (e) {
            debugPrint('❌ [REALTIME] Error processing incoming message: $e');
          }
        }
      });
    });

    // CRITICAL: Listen for real-time typing indicators
    ref.listen(realtimeTypingProvider, (previous, next) {
      debugPrint('🔍 [TYPING] Received typing event: $next');
      next.whenData((typingEvent) {
        debugPrint(
            '🔍 [TYPING] Processing typing event: conversationId=${typingEvent.conversationId}, userId=${typingEvent.userId}, isTyping=${typingEvent.isTyping}');
        debugPrint(
            '🔍 [TYPING] Current conversation ID: ${widget.conversation.id}');
        debugPrint(
            '🔍 [TYPING] Other user ID: ${widget.conversation.otherUser?.id}');
        debugPrint(
            '🔍 [TYPING] Conversation type: ${widget.conversation.type}');
        debugPrint(
            '🔍 [TYPING] All participants: ${widget.conversation.participants.map((p) => p.id).join(', ')}');

        if (typingEvent.conversationId == widget.conversation.id) {
          // Get current user ID to exclude own typing events
          final currentUserId = StorageService.getUser()?['id'];

          // For group conversations, check if the typing user is a participant and not the current user
          // For direct conversations, check if it's the other user
          bool shouldShowTyping = false;

          if (widget.conversation.type == 'group') {
            // For group conversations, show typing from any participant except current user
            shouldShowTyping = typingEvent.userId != currentUserId &&
                widget.conversation.participants
                    .any((p) => p.id == typingEvent.userId);
          } else {
            // For direct conversations, show typing from the other user only
            final otherUserId = widget.conversation.otherUser?.id;
            shouldShowTyping =
                otherUserId != null && typingEvent.userId == otherUserId;
          }

          debugPrint(
              '🔍 [TYPING] Conversation ID matches, checking user ID...');
          debugPrint(
              '🔍 [TYPING] Conversation type: ${widget.conversation.type}');
          debugPrint('🔍 [TYPING] Current user ID: $currentUserId');
          debugPrint('🔍 [TYPING] Typing user ID: ${typingEvent.userId}');
          debugPrint('🔍 [TYPING] Should show typing: $shouldShowTyping');

          if (shouldShowTyping) {
            debugPrint(
                '🔍 [TYPING] User ID matches! Setting typing state to: ${typingEvent.isTyping}');
            setState(() {
              _isOtherUserTyping = typingEvent.isTyping;
              debugPrint(
                  '🔍 [TYPING] State updated: _isOtherUserTyping = $_isOtherUserTyping');
            });

            // Auto-hide typing indicator after 1.5 seconds of no updates
            if (typingEvent.isTyping) {
              // Cancel any existing timer
              _typingAutoHideTimer?.cancel();
              debugPrint(
                  '🔍 [TYPING] Cancelled previous timer and setting new auto-hide timer for 1.5 seconds');
              _typingAutoHideTimer =
                  Timer(const Duration(milliseconds: 1500), () {
                if (mounted) {
                  debugPrint('🔍 [TYPING] Auto-hiding typing indicator');
                  setState(() {
                    _isOtherUserTyping = false;
                    debugPrint(
                        '🔍 [TYPING] Auto-hide: _isOtherUserTyping = $_isOtherUserTyping');
                  });
                }
              });
            } else {
              // Cancel timer when typing stops
              _typingAutoHideTimer?.cancel();
              debugPrint('🔍 [TYPING] Cancelled timer because typing stopped');
            }
          } else {
            debugPrint(
                '🔍 [TYPING] User ID mismatch or not a participant: typingUserId=${typingEvent.userId}, currentUserId=$currentUserId');
          }
        } else {
          debugPrint(
              '🔍 [TYPING] Conversation ID mismatch: expected ${widget.conversation.id}, got ${typingEvent.conversationId}');
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

    // CRITICAL: Listen for real-time message status updates (read receipts)
    ref.listen(realtimeMessageStatusProvider, (previous, next) {
      next.whenData((statusEvent) {
        debugPrint(
            '📖 [UI] Received message status update: ${statusEvent.status}');
        debugPrint(
            '📖 [UI] Status event conversation ID: ${statusEvent.conversationId}');
        debugPrint(
            '📖 [UI] Current conversation ID: ${widget.conversation.id}');
        debugPrint('📖 [UI] Message IDs: ${statusEvent.messageIds.join(', ')}');

        // Only refresh UI if the status update is for the current conversation
        if (statusEvent.conversationId == widget.conversation.id) {
          debugPrint('📖 [UI] Refreshing UI for message status update');
          try {
            // Refresh the messages list to show updated read status
            ref
                .read(localMessagesProvider(widget.conversation.id).notifier)
                .refresh();
            debugPrint('📖 [UI] ✅ UI refreshed for message status update');
          } catch (e) {
            debugPrint('❌ [UI] Error refreshing UI for message status: $e');
          }
        } else {
          debugPrint(
              '📖 [UI] Ignoring status update for different conversation');
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

    // CRITICAL: Listen for messages to be loaded and scroll to bottom
    ref.listen(localMessagesProvider(widget.conversation.id), (previous, next) {
      next.whenData((messages) {
        // Scroll to bottom on first load or when messages are added
        if (messages.isNotEmpty) {
          final shouldScroll = previous?.isLoading == true ||
              (previous?.value != null &&
                  messages.length > previous!.value!.length);

          if (shouldScroll) {
            debugPrint(
                '🔄 [UI] Messages loaded/updated, scrolling to bottom... (${messages.length} messages)');

            // Use a single delayed scroll to prevent multiple rapid scroll attempts
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scrollToBottom(animated: false);
              }
            });
          }
        }
      });
    });

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.chatBackgroundDark
          : AppTheme.chatBackgroundLight,
      appBar: _buildAppBar(),
      // Removed floating action button with keyboard icon
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
    // CRITICAL: Enhanced deduplication to prevent flickering
    // This prevents crashes when duplicate messages exist in the database
    final deduplicatedMessages = <LocalMessage>[];
    final seenLocalIds = <int>{};
    final seenServerIds = <String>{};
    final seenContentHashes = <String>{}; // Add content-based deduplication

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

      // CRITICAL: Check for duplicate content + timestamp to prevent flickering
      // This prevents the same message from appearing multiple times
      final contentHash =
          '${message.content}_${message.createdAt.millisecondsSinceEpoch}';
      if (seenContentHashes.contains(contentHash)) {
        debugPrint(
            '🚨 UI: Skipping duplicate content + timestamp: ${message.content}');
        shouldAdd = false;
      }

      if (shouldAdd) {
        deduplicatedMessages.add(message);
        seenLocalIds.add(message.id);
        if (message.serverId != null) {
          seenServerIds.add(message.serverId!);
        }
        seenContentHashes.add(contentHash);
      }
    }

    if (deduplicatedMessages.length != messages.length) {
      debugPrint(
          '🧹 UI: Filtered ${messages.length - deduplicatedMessages.length} duplicate messages from UI');
    }

    // AlwaysScrollable so RefreshIndicator can trigger even with few/no items
    // Calculate item count including typing indicator at index 0
    final itemCount =
        (deduplicatedMessages.isEmpty ? 0 : deduplicatedMessages.length) +
            (_isOtherUserTyping ? 1 : 0);
    debugPrint(
        '🔍 [UI] Item count: $itemCount (messages: ${deduplicatedMessages.length}, typing: $_isOtherUserTyping)');

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final position = _scrollController.position;
        // Since ListView is reversed, detect pull-up gesture near top (pixels = 0) to sync latest
        if (notification is OverscrollNotification &&
            notification.overscroll > 8 &&
            position.pixels <= 8 &&
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
          // Show typing indicator at the beginning of the list (since ListView is reversed)
          if (index == 0 && _isOtherUserTyping) {
            debugPrint(
                '🔍 [TYPING] Building typing indicator widget at index 0 - _isOtherUserTyping: $_isOtherUserTyping');
            return _buildTypingIndicator();
          }

          // Adjust index for messages since typing indicator is at index 0
          final messageIndex = _isOtherUserTyping ? index - 1 : index;

          if (messageIndex < 0 || messageIndex >= deduplicatedMessages.length) {
            return const SizedBox.shrink();
          }
          final message = deduplicatedMessages[messageIndex];
          final isMe = message.isFromMe;
          final showTimestamp = _shouldShowTimestamp(
            message,
            messageIndex > 0 ? deduplicatedMessages[messageIndex - 1] : null,
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
    debugPrint('🔍 [TYPING] _buildTypingIndicator() called');
    return TypingIndicator(
      key: ValueKey('typing_$_isOtherUserTyping'),
      isTyping: _isOtherUserTyping,
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
