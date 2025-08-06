import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/models/local_message.dart';
import '../../../../shared/models/local_conversation.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/providers/local_chat_providers.dart';
import '../../../../shared/services/local_chat_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_action_bar.dart';
import '../widgets/reply_preview.dart';

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

  // Track if we should auto-scroll to bottom on initial load
  bool _shouldAutoScrollOnLoad = true;

  // Key for tracking highlighted message
  final Map<String, GlobalKey> _messageKeys = {};

  // Selection mode state
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;

  // State for replying to a message
  LocalMessage? _replyingToMessage;

  // State for highlighting a message when scrolled to
  String? _highlightedMessageId;

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

      // Mark as read when entering chat page
      _markOnChatPageEnter();

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
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => _showProfileCard(),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage: _getAvatarUrl().isNotEmpty
                        ? NetworkImage(_getAvatarUrl())
                        : null,
                    child: _getAvatarUrl().isEmpty
                        ? Text(
                            _getInitials(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  // Online indicator for direct conversations
                  if (widget.conversation.type == 'direct' &&
                      _isOtherUserOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showProfileCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayName(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _isOtherUserOnline
                          ? 'Online'
                          : widget.conversation.lastActivity != null
                              ? 'Last seen ${timeago.format(widget.conversation.lastActivity!)}'
                              : 'Last seen recently',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isOtherUserOnline
                            ? AppTheme.successColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice call coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call coming soon')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _showClearChatDialog();
                  break;
                case 'block':
                  _showBlockUserDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('Block User',
                        style: TextStyle(color: AppTheme.errorColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
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
    setState(() {
      _highlightedMessageId = messageId;
    });

    // Clear highlight after animation
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
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

  // Selection mode methods
  void _enterSelectionMode(LocalMessage message) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(message.serverId ?? message.id.toString());
      _replyingToMessage = null;
    });
  }

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
          _selectedMessageIds.add(messageId);
        }
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _handleReplySelection() {
    // TODO: Implement reply selection
  }

  void _handleForwardSelection() {
    // TODO: Implement forward selection
  }

  void _handleDeleteSelection() {
    // TODO: Implement delete selection
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
    if (isTyping) {
      realtimeService.startTyping(widget.conversation.id);
    } else {
      realtimeService.stopTyping(widget.conversation.id);
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
    final authState = ref.watch(authStateProvider);
    final messagesAsync =
        ref.watch(localMessagesProvider(widget.conversation.id));

    // DEBUG: Force sync messages if empty
    messagesAsync.whenData((messages) {
      if (messages.isEmpty) {
        print(
            '🐛 [DEBUG] Messages empty, forcing manual sync for ${widget.conversation.id}');
        // Force sync in background
        Future.microtask(() async {
          try {
            final chatService = ref.read(localChatServiceProvider);
            // Force sync this conversation's messages
            await chatService.getMessages(widget.conversation.id);
          } catch (e) {
            print('🐛 [DEBUG] Manual sync failed: $e');
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) => _buildMessagesList(messages, authState),
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

    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      itemCount: messages.length,
      itemBuilder: (context, index) {
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
            // 🚀 Enhanced message bubble with instant status indicators
            Container(
              key: _getMessageKey(message.serverId ??
                  '${message.createdAt.millisecondsSinceEpoch}_${message.senderId}'),
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primaryColor : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    // Add subtle border for failed messages
                    border: message.readStatus == 'failed'
                        ? Border.all(color: AppTheme.errorColor, width: 1)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Message content
                      Text(
                        message.content ?? '',
                        style: TextStyle(
                          color: isMe ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),

                      // Status indicators for my messages
                      if (isMe) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Timestamp
                            Text(
                              '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Status icon - WhatsApp style
                            _buildStatusIcon(message.readStatus),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
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

  /// Build WhatsApp-style status icon for messages
  Widget _buildStatusIcon(String? status) {
    switch (status) {
      case 'sending':
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.7),
            ),
          ),
        );

      case 'sent':
        return Icon(
          Icons.check,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        );

      case 'delivered':
        return Icon(
          Icons.done_all,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        );

      case 'read':
        return Icon(
          Icons.done_all,
          size: 12,
          color: Colors.lightBlue[300], // Blue checkmarks for read
        );

      case 'failed':
        return Icon(
          Icons.error_outline,
          size: 12,
          color: AppTheme.errorColor,
        );

      default:
        return Icon(
          Icons.schedule,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        );
    }
  }
}
