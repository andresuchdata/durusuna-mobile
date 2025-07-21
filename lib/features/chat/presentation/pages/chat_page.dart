import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/models/message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatPage extends ConsumerStatefulWidget {
  final Conversation conversation;

  const ChatPage({
    super.key,
    required this.conversation,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Join conversation room for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📱 ChatPage: Joining conversation ${widget.conversation.id}');
      final realtimeService = ref.read(realtimeServiceProvider);
      print(
          '📱 ChatPage: Realtime service connected: ${realtimeService.isConnected}');

      realtimeService.joinConversation(widget.conversation.id);

      // Update last seen when entering conversation
      realtimeService.updateLastSeen(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();

    // Leave conversation room
    final realtimeService = ref.read(realtimeServiceProvider);
    realtimeService.leaveConversation(widget.conversation.id);

    super.dispose();
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
      final words = name.split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}';
      }
      return name.isNotEmpty ? name[0].toUpperCase() : 'G';
    }
    final otherUser = widget.conversation.otherUser;
    if (otherUser != null) {
      return '${otherUser.firstName[0]}${otherUser.lastName[0]}';
    }
    return 'U';
  }

  void _onScroll() {
    // Load more messages when scrolling to the top (older messages)
    if (_scrollController.position.pixels <= 200) {
      final state = ref.read(chatMessagesProvider(widget.conversation.id));
      if (!state.isLoadingMore && state.hasMore) {
        ref
            .read(chatMessagesProvider(widget.conversation.id).notifier)
            .loadMessages(loadMore: true);
      }
    }
  }

  Future<void> _sendMessage({String? content, MessageType? messageType}) async {
    if (content?.trim().isEmpty ?? true) return;

    try {
      await ref
          .read(chatMessagesProvider(widget.conversation.id).notifier)
          .sendMessage(
            content: content,
            messageType: messageType ?? MessageType.text,
          );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _refreshMessages() async {
    try {
      // Refresh messages and conversations
      await Future.wait([
        ref
            .read(chatMessagesProvider(widget.conversation.id).notifier)
            .loadMessages(),
        ref.read(conversationsProvider.notifier).loadConversations(),
      ]);

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages refreshed'),
            duration: Duration(seconds: 1),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _handleTyping(bool isTyping) {
    final realtimeService = ref.read(realtimeServiceProvider);
    if (isTyping) {
      realtimeService.startTyping(widget.conversation.id);
    } else {
      realtimeService.stopTyping(widget.conversation.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final messagesState =
        ref.watch(chatMessagesProvider(widget.conversation.id));

    // Auto-scroll to bottom when messages finish loading initially
    ref.listen(chatMessagesProvider(widget.conversation.id), (previous, next) {
      if (previous?.isLoading == true &&
          next.isLoading == false &&
          next.messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print('📱 ChatPage: Auto-scrolling to bottom after messages loaded');
          _scrollToBottom();
        });
      }
    });

    // Listen for realtime connection status
    ref.listen(realtimeConnectionProvider, (previous, next) {
      next?.when(
        data: (isConnected) {
          print('📱 ChatPage: Realtime connection status: $isConnected');
          if (isConnected) {
            print(
                '📱 ChatPage: Realtime service connected - joining conversation');
            final realtimeService = ref.read(realtimeServiceProvider);
            realtimeService.joinConversation(widget.conversation.id);
          }
        },
        loading: () {
          print('📱 ChatPage: Realtime connection loading...');
        },
        error: (error, stack) {
          print('❌ ChatPage: Realtime connection error: $error');
        },
      );
    });

    // Listen for new messages from realtime service
    ref.listen(realtimeMessagesProvider, (previous, next) {
      print('📱 ChatPage: realtimeMessagesProvider state change');
      next?.when(
        data: (realtimeMessage) {
          print(
              '📱 ChatPage: Received realtime message - Action: ${realtimeMessage.action}');
          print(
              '📱 ChatPage: Message conversation ID: ${realtimeMessage.conversationId}');
          print(
              '📱 ChatPage: Current conversation ID: ${widget.conversation.id}');
          print(
              '📱 ChatPage: Message content: ${realtimeMessage.message.content}');

          if (realtimeMessage.conversationId == widget.conversation.id) {
            // Skip messages from current user (already added optimistically)
            final currentUserId = authState.user?.id;
            final isOwnMessage =
                realtimeMessage.message.senderId == currentUserId;

            if (isOwnMessage) {
              print(
                  '📱 ChatPage: Replacing optimistic message with server version');
              // Replace optimistic message with server version (has updated timestamps, delivery status, etc.)
              ref
                  .read(chatMessagesProvider(widget.conversation.id).notifier)
                  .replaceMessage(realtimeMessage.message);
            } else {
              print('📱 ChatPage: Adding message from other user');
              ref
                  .read(chatMessagesProvider(widget.conversation.id).notifier)
                  .addMessage(realtimeMessage.message);

              if (realtimeMessage.action == 'created') {
                print('📱 ChatPage: Scrolling to bottom for new message');
                _scrollToBottom();
              }
            }
          } else {
            print(
                '📱 ChatPage: Message is for different conversation - ignoring');
          }
        },
        loading: () {
          print('📱 ChatPage: Realtime messages loading...');
        },
        error: (error, stack) {
          print('❌ ChatPage: Error listening to realtime messages: $error');
          print('❌ Stack: $stack');
        },
      );
    });

    // Listen for typing indicators
    ref.listen(realtimeTypingProvider, (previous, next) {
      print('⌨️ ChatPage: realtimeTypingProvider state change');
      next?.when(
        data: (typing) {
          print(
              '⌨️ ChatPage: Received typing event - User: ${typing.userId}, Typing: ${typing.isTyping}');
          print(
              '⌨️ ChatPage: Typing conversation ID: ${typing.conversationId}');
          print(
              '⌨️ ChatPage: Current conversation ID: ${widget.conversation.id}');
          print(
              '⌨️ ChatPage: Current user ID: ${ref.read(authStateProvider).user?.id}');

          if (typing.conversationId == widget.conversation.id &&
              typing.userId != ref.read(authStateProvider).user?.id) {
            print(
                '⌨️ ChatPage: Setting typing indicator to: ${typing.isTyping}');
            ref
                .read(chatMessagesProvider(widget.conversation.id).notifier)
                .setTyping(typing.isTyping);
          } else {
            print(
                '⌨️ ChatPage: Ignoring typing event (wrong conversation or own typing)');
          }
        },
        loading: () {
          print('⌨️ ChatPage: Realtime typing loading...');
        },
        error: (error, stack) {
          print('❌ ChatPage: Error listening to typing indicators: $error');
          print('❌ Stack: $stack');
        },
      );
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
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
            const SizedBox(width: 12),
            Expanded(
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
                    widget.conversation.isOnline
                        ? 'Online'
                        : messagesState.isTyping
                            ? 'Typing...'
                            : 'Last seen ${timeago.format(widget.conversation.lastActivity)}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          widget.conversation.isOnline || messagesState.isTyping
                              ? AppTheme.successColor
                              : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // TODO: Implement voice call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice call coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // TODO: Implement video call
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
      ),
      body: Column(
        children: [
          // Messages list with pull-to-refresh
          Expanded(
            child: messagesState.isLoading && messagesState.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messagesState.messages.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _refreshMessages,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: _buildEmptyState(),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshMessages,
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: false,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: messagesState.messages.length +
                              (messagesState.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the top when loading older messages
                            if (messagesState.isLoadingMore && index == 0) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }

                            // Adjust index if loading indicator is shown
                            final messageIndex =
                                messagesState.isLoadingMore ? index - 1 : index;

                            // Return empty container if index is out of bounds
                            if (messageIndex < 0 ||
                                messageIndex >= messagesState.messages.length) {
                              return const SizedBox.shrink();
                            }

                            final message =
                                messagesState.messages[messageIndex];
                            final isMe = message.senderId == authState.user?.id;
                            final showTimestamp = _shouldShowTimestamp(
                              message,
                              messageIndex > 0
                                  ? messagesState.messages[messageIndex - 1]
                                  : null,
                            );

                            return Column(
                              children: [
                                if (showTimestamp)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Text(
                                      _formatTimestamp(message.createdAt),
                                      style: const TextStyle(
                                        color: AppTheme.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                MessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  onReply: (msg) => _replyToMessage(msg),
                                  onEdit:
                                      isMe ? (msg) => _editMessage(msg) : null,
                                  onDelete: isMe
                                      ? (msg) => _deleteMessage(msg)
                                      : null,
                                ),
                                const SizedBox(height: 4),
                              ],
                            );
                          },
                        ),
                      ),
          ),

          // Typing indicator
          if (messagesState.isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      _getInitials()[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(3, (index) {
                              return AnimatedContainer(
                                duration:
                                    Duration(milliseconds: 600 + (index * 200)),
                                curve: Curves.easeInOut,
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppTheme.textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Chat input
          ChatInput(
            controller: _messageController,
            focusNode: _focusNode,
            onSend: (content) => _sendMessage(content: content),
            onTyping: _handleTyping,
            onAttachment: () => _showAttachmentOptions(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Icon(
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

  bool _shouldShowTimestamp(Message current, Message? previous) {
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

    return !currentDate.isAtSameDate(previousDate);
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _replyToMessage(Message message) {
    // TODO: Implement reply functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reply feature coming soon')),
    );
  }

  void _editMessage(Message message) {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit feature coming soon')),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final chatService = ref.read(chatServiceProvider);
                await chatService.deleteMessage(message.id);
                ref
                    .read(chatMessagesProvider(widget.conversation.id).notifier)
                    .deleteMessage(message.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete message: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
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
              'Share',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Implement camera
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Implement gallery
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.attach_file,
                  label: 'Document',
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Implement file picker
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  onTap: () {
                    Navigator.of(context).pop();
                    // TODO: Implement location sharing
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
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
}

extension DateTimeExtension on DateTime {
  bool isAtSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
