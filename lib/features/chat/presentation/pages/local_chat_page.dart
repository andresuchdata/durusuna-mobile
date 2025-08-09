import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/performance_constants.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/models/local_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/providers/local_chat_providers.dart';
import '../../../../shared/services/local_chat_service.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_action_bar.dart';
import '../widgets/local_message_bubble.dart';
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

  // Auto-scroll handling removed - not used

  // Key for tracking highlighted message
  final Map<String, GlobalKey> _messageKeys = {};

  // Selection mode state
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;

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

      // Reconcile any leftover pending messages on initial open
      Future.delayed(const Duration(milliseconds: 250), () async {
        try {
          final chatService = ref.read(localChatServiceProvider);
          await chatService.reconcilePendingOnOpen(widget.conversation.id);
        } catch (_) {}
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
    _messageKeys.clear(); // Clear message keys to prevent memory leaks

    // Leave conversation room and clear current conversation ID
    try {
      final realtimeService = ref.read(realtimeServiceProvider);
      realtimeService.leaveConversation(widget.conversation.id);
      ref.read(currentConversationProvider.notifier).state = null;
    } catch (e) {
      // Error in dispose
    }

    super.dispose();
  }

  @override
  void deactivate() {
    // Clear current conversation when leaving page
    try {
      ref.read(currentConversationProvider.notifier).state = null;
    } catch (e) {
      // Error in deactivate
    }
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

  // Track if we've already marked as read when at bottom to avoid multiple calls
  bool _hasMarkedAsReadAtBottom = false;

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
    // TODO: Implement profile card
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile card coming soon')),
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
      final messageKey = _messageKeys[widget.highlightMessageId];
      if (messageKey?.currentContext != null) {
        Scrollable.ensureVisible(
          messageKey!.currentContext!,
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

  GlobalKey _getMessageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
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

  /// Handle delete of a single message
  Future<void> _handleDeleteMessage(LocalMessage message) async {
    final notifier =
        ref.read(localMessagesProvider(widget.conversation.id).notifier);

    // Use batch delete for consistency (single message batch)
    await notifier.deleteBatchMessages([message], context);

    // Feedback is already handled in deleteBatchMessages method
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
    print(
        '🐛 [UI] _sendMessage called at ${uiStartTime.millisecondsSinceEpoch}');
    print('🐛 [UI] Content: "$content"');

    if (content?.trim().isEmpty ?? true) {
      print('🐛 [UI] Empty content, returning early');
      return;
    }

    try {
      // Convert LocalMessageType to match the message type system
      LocalMessageType messageType = LocalMessageType.text;

      print('🐛 [UI] Calling provider.sendMessage...');
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
      print(
          '🐛 [UI] Provider.sendMessage took: ${providerCallEnd.difference(providerCallStart).inMilliseconds}ms');

      print('🐛 [UI] Clearing message controller...');
      _messageController.clear();

      // Clear reply state after sending
      if (_replyingToMessage != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }

      print('🐛 [UI] Scrolling to bottom...');
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
      print(
          '🐛 [UI] ✅ _sendMessage COMPLETED in: ${uiEndTime.difference(uiStartTime).inMilliseconds}ms');
    } catch (e) {
      print('🐛 [UI] ❌ _sendMessage FAILED: $e');
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
    print(
        '🔍 [UI] LocalChatPage.build() called for conversationId: "${widget.conversation.id}"');
    final authState = ref.watch(authStateProvider);
    final messagesAsync =
        ref.watch(localMessagesProvider(widget.conversation.id));
    print('🔍 [UI] messagesAsync state: ${messagesAsync.runtimeType}');

    // Real-time messages are now handled by the centralized RealtimeDispatcher
    // This ensures no duplicate processing and better performance

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
      print(
          '🐛 [DEBUG] LocalChatPage: conversationId="${widget.conversation.id}" has ${messages.length} messages');
      print('🐛 [DEBUG] Conversation type: ${widget.conversation.type}');
      print(
          '🐛 [DEBUG] Last message in conversation model: ${widget.conversation.lastMessage?.content ?? "null"}');
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                  color: AppTheme.backgroundColor,
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
    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate item count including typing indicator
    final itemCount = messages.length + (_isOtherUserTyping ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      physics: const HighRefreshScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 24),
      itemCount: itemCount,
      cacheExtent: 500, // Cache more items for smoother scrolling
      addRepaintBoundaries: true, // Isolate repaints
      itemBuilder: (context, index) {
        // Show typing indicator at the end of the list
        if (index == messages.length && _isOtherUserTyping) {
          return _buildTypingIndicator();
        }

        if (index >= messages.length) {
          return const SizedBox.shrink();
        }
        final message = messages[index];
        final isMe = message.isFromMe;
        final showTimestamp = _shouldShowTimestamp(
          message,
          index > 0 ? messages[index - 1] : null,
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
                key: _getMessageKey(message.serverId ??
                    '${message.createdAt.millisecondsSinceEpoch}_${message.senderId}'),
                message: message,
                isMe: isMe,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedMessageIds
                    .contains(message.serverId ?? message.id.toString()),
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleMessageSelection(message);
                  } else {
                    _showMessageOptions(context, message);
                  }
                },
                onLongPress: () =>
                    _isSelectionMode ? null : _enterSelectionMode(message),
              ),
            ),
          ],
        );
      },
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

  /// Show message options bottom sheet (only when not in selection mode)
  void _showMessageOptions(BuildContext context, LocalMessage message) {
    if (_isSelectionMode) return; // Don't show options in selection mode

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
              // Header
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Reply option
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(context).pop();
                  _replyToMessage(message);
                },
              ),

              // Select option
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Select'),
                onTap: () {
                  Navigator.of(context).pop();
                  _enterSelectionMode(message);
                },
              ),

              // Copy option
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.of(context).pop();
                  _copyMessage(message);
                },
              ),

              // Delete option (only for own messages or if user is admin)
              if (message.isFromMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppTheme.errorColor),
                  title: const Text('Delete',
                      style: TextStyle(color: AppTheme.errorColor)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleDeleteMessage(message);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Copy message content to clipboard
  void _copyMessage(LocalMessage message) {
    Clipboard.setData(ClipboardData(text: message.content ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Status icon logic moved to LocalMessageBubble
}
