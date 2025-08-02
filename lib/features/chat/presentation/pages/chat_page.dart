import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/services/mark_read_service.dart';
import '../../../../shared/models/message.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../shared/widgets/reactions_widget.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_action_bar.dart';
import '../widgets/reply_preview.dart';
import 'forward_contacts_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  final Conversation conversation;
  final String? highlightMessageId;
  final bool scrollToMessage;

  const ChatPage({
    super.key,
    required this.conversation,
    this.highlightMessageId,
    this.scrollToMessage = false,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
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
  Message? _replyingToMessage;

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

      // CRITICAL: Force refresh messages if conversation was recently active
      // This ensures chat messages are synced with conversation list
      final lastActivity = widget.conversation.lastActivity;
      final shouldForceRefresh = lastActivity != null &&
          DateTime.now().difference(lastActivity).inSeconds <
              30; // Last 30 seconds

      if (shouldForceRefresh) {
        ref
            .read(chatMessagesProvider(widget.conversation.id).notifier)
            .refreshMessages();
      }

      // Note: We don't immediately mark as read here - only when user scrolls to view messages
      // This ensures better UX where messages are only marked as read when actually viewed

      // Handle message highlighting and scrolling if requested
      if (widget.highlightMessageId != null && widget.scrollToMessage) {
        _scrollToHighlightedMessage();
      } else {
        // Use the more reliable scroll method with longer delays
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _ensureScrollToBottom();
          }
        });

        // Additional backup with even longer delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _shouldAutoScrollOnLoad) {
            _ensureScrollToBottom();
          }
        });
      }

      // REQUIREMENT #1: Auto-mark as read when entering chat page
      _markOnChatPageEnter();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();

    // Leave conversation room and clear current conversation ID
    try {
      final realtimeService = ref.read(realtimeServiceProvider);
      realtimeService.leaveConversation(widget.conversation.id);
      ref.read(currentConversationProvider.notifier).state = null;

      // Cancel any pending mark-read operations
      final markReadService = ref.read(markReadServiceProvider);
      markReadService.cancelPendingOperations(widget.conversation.id);
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
      return _getUserInitials(otherUser);
    }
    return 'U';
  }

  String _getUserInitials(User user) {
    final firstName = user.firstName.trim();
    final lastName = user.lastName.trim();
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
      final state = ref.read(chatMessagesProvider(widget.conversation.id));
      if (!state.isLoadingMore && state.hasMore) {
        ref
            .read(chatMessagesProvider(widget.conversation.id).notifier)
            .loadMessages(loadMore: true);
      }
    }

    // Mark conversation as read when user scrolls to bottom (indicating they've seen latest messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      // User is at or near the bottom - mark as read
      _markAsReadWhenAtBottom();
    }
  }

  // Track if we've already marked as read when at bottom to avoid multiple calls
  bool _hasMarkedAsReadAtBottom = false;

  void _markAsReadWhenAtBottom() {
    if (_hasMarkedAsReadAtBottom) return;

    _hasMarkedAsReadAtBottom = true;

    // Use centralized mark-read service
    final markReadService = ref.read(markReadServiceProvider);
    markReadService.markOnScrollToBottom(widget.conversation.id);

    // Reset flag after a delay to allow for future mark-as-read calls
    Future.delayed(const Duration(seconds: 2), () {
      _hasMarkedAsReadAtBottom = false;
    });
  }

  /// REQUIREMENT #1: Mark as read when user opens chat page after fetching messages
  void _markOnChatPageEnter() {
    final markReadService = ref.read(markReadServiceProvider);
    markReadService.markOnChatPageEnter(widget.conversation.id);
  }

  /// Show profile card for the conversation (user profile for direct, group profile for group)
  void _showProfileCard() {
    if (widget.conversation.type == 'group') {
      // Show group profile card - using showModalBottomSheet directly for now
      _showGroupProfileBottomSheet();
    } else if (widget.conversation.type == 'direct' &&
        widget.conversation.otherUser != null) {
      // Show individual user profile for direct conversations
      final otherUser = widget.conversation.otherUser!;

      ProfileCard.show(
        context,
        user: otherUser,
        isOnline: _isOtherUserOnline,
        lastSeen: widget.conversation.lastActivity,
        onStartChat: () {
          // Already in chat, just close the modal
          Navigator.of(context).pop();
        },
        onCall: () {
          Navigator.of(context).pop();
          // TODO: Implement voice call
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice call coming soon')),
          );
        },
        onVideoCall: () {
          Navigator.of(context).pop();
          // TODO: Implement video call
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video call coming soon')),
          );
        },
        onBlock: () {
          Navigator.of(context).pop();
          _showBlockUserDialog();
        },
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final messagesState =
        ref.watch(chatMessagesProvider(widget.conversation.id));

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
                          color: Colors.green, // Force bright green
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
                          : messagesState.isTyping
                              ? 'Typing...'
                              : widget.conversation.lastActivity != null
                                  ? 'Last seen ${timeago.format(widget.conversation.lastActivity!)}'
                                  : 'Last seen recently',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isOtherUserOnline || messagesState.isTyping
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
      );
    }
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
      builder: (context) => SafeArea(
        child: Container(
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
            decoration: const BoxDecoration(
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

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text(
            'Are you sure you want to leave "${_getDisplayName()}"? You won\'t be able to see new messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement leave group functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Leave group functionality coming soon')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showGroupProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Section
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Group Avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage:
                          widget.conversation.avatarUrl?.isNotEmpty == true
                              ? NetworkImage(widget.conversation.avatarUrl!)
                              : null,
                      child: widget.conversation.avatarUrl?.isEmpty != false
                          ? const Icon(
                              Icons.group,
                              size: 50,
                              color: Colors.white,
                            )
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Group Name
                    Text(
                      widget.conversation.name ?? 'Group Chat',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Group Description
                    if (widget.conversation.description?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          widget.conversation.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Group Info
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.people,
                                  size: 20, color: AppTheme.primaryColor),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.conversation.participants.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Text(
                                'Members',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppTheme.borderColor,
                          ),
                          Column(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 20, color: AppTheme.primaryColor),
                              const SizedBox(height: 4),
                              Text(
                                _formatGroupDate(widget.conversation.createdAt),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Text(
                                'Created',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Members Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Members Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          const Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${widget.conversation.participants.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Members List
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: widget.conversation.participants.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final member =
                              widget.conversation.participants[index];
                          return _buildGroupMemberTile(member);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundColor,
                  border: Border(
                    top: BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Media & Files Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Media & Files coming soon')),
                          );
                        },
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Media & Files'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Leave Group Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showLeaveGroupDialog();
                        },
                        icon: const Icon(Icons.exit_to_app, size: 18),
                        label: const Text('Leave Group'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupMemberTile(User member) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primaryColor,
        backgroundImage: member.avatarUrl?.isNotEmpty == true
            ? NetworkImage(member.avatarUrl!)
            : null,
        child: member.avatarUrl?.isEmpty != false
            ? Text(
                _getUserInitials(member),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              )
            : null,
      ),
      title: Text(
        member.displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getGroupMemberTypeColor(member.userType)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getGroupMemberTypeLabel(member.userType),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _getGroupMemberTypeColor(member.userType),
              ),
            ),
          ),
          if (member.email.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                member.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        onPressed: () {
          Navigator.of(context).pop();
          // Show individual member profile
          ProfileCard.show(
            context,
            user: member,
            isOnline: false,
            onStartChat: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Starting chat with ${member.displayName}')),
              );
            },
          );
        },
        icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
      ),
      onTap: () {
        Navigator.of(context).pop();
        // Show individual member profile
        ProfileCard.show(
          context,
          user: member,
          isOnline: false, // TODO: Get real-time status for group members
          onStartChat: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Starting chat with ${member.displayName}')),
            );
          },
        );
      },
    );
  }

  String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else {
      return 'Today';
    }
  }

  String _getGroupMemberTypeLabel(UserType userType) {
    switch (userType) {
      case UserType.teacher:
        return 'Teacher';
      case UserType.student:
        return 'Student';
      case UserType.parent:
        return 'Parent';
    }
  }

  Color _getGroupMemberTypeColor(UserType userType) {
    switch (userType) {
      case UserType.teacher:
        return AppTheme.primaryColor;
      case UserType.student:
        return AppTheme.successColor;
      case UserType.parent:
        return AppTheme.warningColor;
    }
  }

  /// Scroll to and highlight a specific message
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

  /// Highlight a specific message with animation
  void _highlightMessage(String messageId) {
    // This would typically involve updating the message's visual state
    // For now, we'll just log it - the UI highlighting would be handled in MessageBubble
    debugPrint('Highlighting message: $messageId');
  }

  /// Get or create a GlobalKey for a message
  GlobalKey _getMessageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  /// Scroll to a specific message by ID
  void _scrollToMessage(String messageId) {
    final messageKey = _messageKeys[messageId];

    // If message is currently visible, scroll to it directly
    if (messageKey?.currentContext != null) {
      _highlightAndScrollToMessage(messageId, messageKey!);
      return;
    }

    // Check if message exists in loaded messages
    final messagesState =
        ref.read(chatMessagesProvider(widget.conversation.id));
    final messageIndex =
        messagesState.messages.indexWhere((msg) => msg.id == messageId);

    if (messageIndex != -1) {
      // Message exists in loaded data but not currently visible
      // Calculate scroll position and scroll there first
      _scrollToMessageIndex(messageIndex, messageId);
    } else {
      // Message not in loaded messages (needs fetching or doesn't exist)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original message not found in loaded messages'),
          duration: Duration(seconds: 2),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  /// Highlight and scroll to a message that's already visible
  void _highlightAndScrollToMessage(String messageId, GlobalKey messageKey) {
    // Set highlight state
    setState(() {
      _highlightedMessageId = messageId;
    });

    // Scroll to message
    Scrollable.ensureVisible(
      messageKey.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );

    // Clear highlight after animation
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  /// Scroll to a message by its index in the loaded messages list
  void _scrollToMessageIndex(int messageIndex, String messageId) {
    if (!_scrollController.hasClients) return;

    // Estimate item height (message + timestamp + spacing)
    const double estimatedItemHeight = 80.0;

    // Calculate approximate scroll position
    // Account for loading indicator at top if present
    final messagesState =
        ref.read(chatMessagesProvider(widget.conversation.id));
    final loadingOffset = messagesState.isLoadingMore ? 60.0 : 0.0;
    final targetPosition = loadingOffset + (messageIndex * estimatedItemHeight);

    // Scroll to estimated position
    _scrollController
        .animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    )
        .then((_) {
      // Wait for ListView to render the message, then try to scroll to it precisely
      Future.delayed(const Duration(milliseconds: 500), () {
        final messageKey = _messageKeys[messageId];
        if (messageKey?.currentContext != null) {
          _highlightAndScrollToMessage(messageId, messageKey!);
        } else {
          // Still not visible, show feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Message found but could not scroll to it precisely'),
                duration: Duration(seconds: 2),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          }
        }
      });
    });
  }

  void _handleReactionTap(Message message, String emoji) async {
    try {
      // TODO: Implement message reaction API call
      // final chatService = ref.read(chatServiceProvider);
      // await chatService.toggleMessageReaction(
      //   messageId: message.id,
      //   emoji: emoji,
      // );

      // For now, show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reacted with $emoji'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reaction: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showReactionPicker(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: ReactionPicker(
          onEmojiSelected: (emoji) {
            _handleReactionTap(message, emoji);
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _sendMessage({String? content, MessageType? messageType}) async {
    if (content?.trim().isEmpty ?? true) return;

    // Validate reply ID - ensure it's a proper UUID, not a temporary ID
    String? validReplyToId;
    if (_replyingToMessage != null) {
      final replyId = _replyingToMessage!.id;
      if (!replyId.startsWith('temp_') && !replyId.startsWith('last_')) {
        validReplyToId = replyId;
      } else {
        // Clear invalid reply and show warning
        setState(() {
          _replyingToMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot reply to message that is still sending'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    }

    try {
      await ref
          .read(chatMessagesProvider(widget.conversation.id).notifier)
          .sendMessage(
            content: content,
            messageType: messageType ?? MessageType.text,
            replyToId: validReplyToId, // Only include if valid UUID
          );

      _messageController.clear();

      // Clear reply state after sending
      if (_replyingToMessage != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }

      _scrollToBottom(animated: true);

      // Mark as read when user sends a message (implicit read)
      final markReadService = ref.read(markReadServiceProvider);
      markReadService.markOnMessageSent(widget.conversation.id);
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
        _scrollController
            .animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
            .then((_) {
          // Verify we actually reached the bottom
          if (mounted && _scrollController.hasClients) {
            final currentPos = _scrollController.position.pixels;
            final maxPos = _scrollController.position.maxScrollExtent;
            final diff = (maxPos - currentPos).abs();
            if (diff > 10) {
              _scrollController.jumpTo(maxPos);
            }
          }
        });
      } else {
        _scrollController.jumpTo(targetPosition);
      }
    } catch (e) {
      // Error in scrollToBottom
    }
  }

  // More aggressive scroll method that waits for everything to be ready
  void _ensureScrollToBottom() {
    if (!mounted) return;

    // Wait for the next frame cycle to ensure ListView is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Try multiple times with increasing delays (more attempts for Android)
      _attemptScrollWithRetry(1, maxAttempts: 12);
    });
  }

  void _attemptScrollWithRetry(int attempt, {int maxAttempts = 12}) {
    if (!mounted || attempt > maxAttempts) {
      return;
    }

    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      // Use immediate jumpTo for better reliability on Android
      final targetPosition = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(targetPosition);

      // Verify we reached the bottom with longer delay for Android
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _scrollController.hasClients) {
          final currentPos = _scrollController.position.pixels;
          final maxPos = _scrollController.position.maxScrollExtent;
          final diff = (maxPos - currentPos).abs();

          if (diff > 5) {
            _scrollController.jumpTo(maxPos);

            // Double-check after another delay
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _scrollController.hasClients) {
                final finalPos = _scrollController.position.pixels;
                final finalMax = _scrollController.position.maxScrollExtent;
                if ((finalMax - finalPos).abs() > 5) {
                  _scrollController.jumpTo(finalMax);
                }
              }
            });
          } else {
            // User has been scrolled to bottom, mark conversation as read
            _markAsReadWhenAtBottom();
          }
        }
      });
    } else {
      // Wait longer between attempts for later retries (Android needs more time)
      final delay = Duration(milliseconds: 150 + (attempt * 75));
      Future.delayed(delay, () {
        _attemptScrollWithRetry(attempt + 1, maxAttempts: maxAttempts);
      });
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

  void _replyToMessage(Message message) {
    // Only allow replies to messages with proper server UUIDs (not temporary IDs)
    if (message.id.startsWith('temp_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reply to message that is still sending'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _replyingToMessage = message;
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
    _focusNode.requestFocus();
  }

  // Selection mode methods
  void _enterSelectionMode(Message message) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(message.id);
      _replyingToMessage = null; // Cancel any ongoing reply
    });
  }

  void _toggleMessageSelection(Message message) {
    if (!_isSelectionMode) return;

    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        if (_selectedMessageIds.length < 5) {
          // Max 5 for forwarding
          _selectedMessageIds.add(message.id);
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
    if (_selectedMessageIds.length == 1) {
      final messagesState =
          ref.read(chatMessagesProvider(widget.conversation.id));
      final message = messagesState.messages.firstWhere(
        (msg) => msg.id == _selectedMessageIds.first,
      );
      _replyToMessage(message);
    }
  }

  void _handleForwardSelection() {
    final messagesState =
        ref.read(chatMessagesProvider(widget.conversation.id));
    final messagesToForward = messagesState.messages
        .where((msg) => _selectedMessageIds.contains(msg.id))
        .toList();

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => ForwardContactsPage(
          messagesToForward: messagesToForward,
        ),
      ),
    )
        .then((_) {
      // Exit selection mode when returning from forward page
      _exitSelectionMode();
    });
  }

  void _handleDeleteSelection() {
    // TODO: Implement proper delete functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delete ${_selectedMessageIds.length} message(s)'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {},
        ),
      ),
    );
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final messagesState =
        ref.watch(chatMessagesProvider(widget.conversation.id));

    // Safety check: If someone is typing, they must be online
    if (messagesState.isTyping && !_isOtherUserOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isOtherUserOnline = true;
          });
        }
      });
    }

    // Final fallback: If messages are already loaded but we haven't scrolled yet
    if (!messagesState.isLoading &&
        messagesState.messages.isNotEmpty &&
        _shouldAutoScrollOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _shouldAutoScrollOnLoad = false;
          _ensureScrollToBottom();
        }
      });
    }

    // Auto-scroll to bottom when messages finish loading initially
    ref.listen(chatMessagesProvider(widget.conversation.id), (previous, next) {
      // Only auto-scroll on initial load, not on subsequent updates
      if (_shouldAutoScrollOnLoad &&
          previous?.isLoading == true &&
          next.isLoading == false &&
          next.messages.isNotEmpty) {
        _shouldAutoScrollOnLoad = false; // Prevent future auto-scrolls

        // Use multiple scroll attempts for Android reliability
        _ensureScrollToBottom();

        // Additional scroll attempts with longer delays for Android
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _ensureScrollToBottom();
          }
        });

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _scrollToBottom(animated: false); // Force immediate scroll
          }
        });
      }
    });

    // Listen for realtime connection status
    ref.listen(realtimeConnectionProvider, (previous, next) {
      next?.when(
        data: (isConnected) {
          if (isConnected) {
            final realtimeService = ref.read(realtimeServiceProvider);
            realtimeService.joinConversation(widget.conversation.id);
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    // Listen for new messages from realtime service
    ref.listen(realtimeMessagesProvider, (previous, next) {
      next?.when(
        data: (realtimeMessage) {
          if (realtimeMessage.conversationId == widget.conversation.id) {
            // Skip messages from current user (already added optimistically)
            final currentUserId = authState.user?.id;
            final isOwnMessage =
                realtimeMessage.message.senderId == currentUserId;

            if (isOwnMessage) {
              // Replace optimistic message with server version
              ref
                  .read(chatMessagesProvider(widget.conversation.id).notifier)
                  .replaceMessage(realtimeMessage.message);
            } else {
              ref
                  .read(chatMessagesProvider(widget.conversation.id).notifier)
                  .addMessage(realtimeMessage.message);

              // Since user is currently viewing this chat, auto-mark new messages as read immediately
              final markReadService = ref.read(markReadServiceProvider);
              markReadService.markMessagesRead(
                widget.conversation.id,
                [realtimeMessage.message.id],
                immediate: true, // User is actively viewing, mark immediately
              );
            }

            // Auto-scroll to bottom for any new message
            if (realtimeMessage.action == 'created') {
              // Check if user is near the bottom before auto-scrolling
              final shouldAutoScroll = !_scrollController.hasClients ||
                  _scrollController.position.pixels >=
                      _scrollController.position.maxScrollExtent - 200;

              if (shouldAutoScroll) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _scrollToBottom(animated: true);

                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) {
                        _scrollToBottom(animated: true);
                      }
                    });
                  }
                });
              }
            }
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    // Listen for typing indicators
    ref.listen(realtimeTypingProvider, (previous, next) {
      next?.when(
        data: (typing) {
          if (typing.conversationId == widget.conversation.id &&
              typing.userId != ref.read(authStateProvider).user?.id) {
            ref
                .read(chatMessagesProvider(widget.conversation.id).notifier)
                .setTyping(typing.isTyping);

            final otherUserId = widget.conversation.otherUser?.id;
            if (otherUserId != null &&
                typing.userId == otherUserId &&
                typing.isTyping) {
              setState(() {
                _isOtherUserOnline = true;
              });
            }
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    // Listen for presence updates
    ref.listen(realtimePresenceProvider, (previous, next) {
      next?.when(
        data: (presence) {
          final otherUserId = widget.conversation.otherUser?.id;
          if (otherUserId != null && presence.userId == otherUserId) {
            setState(() {
              _isOtherUserOnline = presence.isOnline;
            });
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    // Listen for message status updates
    ref.listen(realtimeMessageStatusProvider, (previous, next) {
      next?.when(
        data: (statusEvent) {
          if (statusEvent.conversationId == widget.conversation.id) {
            final messagesNotifier =
                ref.read(chatMessagesProvider(widget.conversation.id).notifier);
            for (final messageId in statusEvent.messageIds) {
              messagesNotifier.updateMessageStatus(
                  messageId, statusEvent.status, statusEvent.timestamp);
            }
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Padding(
        // Add keyboard padding to push content up when keyboard appears
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: messagesState.isLoading && messagesState.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : messagesState.messages.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: _buildEmptyState(),
                          ),
                        )
                      : _buildMessagesList(messagesState, authState),
            ),

            // Typing indicator
            if (messagesState.isTyping)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        _getInitials().isNotEmpty ? _getInitials()[0] : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                                  duration: Duration(
                                      milliseconds: 600 + (index * 200)),
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

            // Reply preview - positioned just above text input
            if (_replyingToMessage != null)
              ReplyPreview(
                replyToMessage: _replyingToMessage!,
                onCancel: _cancelReply,
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

  Widget _buildMessagesList(dynamic messagesState, dynamic authState) {
    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      itemCount:
          messagesState.messages.length + (messagesState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the top when loading older messages
        if (messagesState.isLoadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Adjust index if loading indicator is shown
        final messageIndex = messagesState.isLoadingMore ? index - 1 : index;

        // Return empty container if index is out of bounds
        if (messageIndex < 0 || messageIndex >= messagesState.messages.length) {
          return const SizedBox.shrink();
        }

        final message = messagesState.messages[messageIndex];
        final isMe = message.senderId == authState.user?.id;
        final showTimestamp = _shouldShowTimestamp(
          message,
          messageIndex > 0 ? messagesState.messages[messageIndex - 1] : null,
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
            MessageBubble(
              key: _getMessageKey(
                  message.id), // Always assign key for scroll-to functionality
              message: message,
              isMe: isMe,
              conversationType: widget.conversation.type,
              currentUserId: authState.user?.id,
              isSelected: _selectedMessageIds.contains(message.id),
              isSelectionMode: _isSelectionMode,
              isHighlighted: _highlightedMessageId == message.id,
              onReply: (msg) => _replyToMessage(msg),
              onEdit: isMe ? (msg) => _editMessage(msg) : null,
              onDelete: isMe ? (msg) => _deleteMessage(msg) : null,
              onLongPress: (msg) => _enterSelectionMode(msg),
              onTap: (msg) => _toggleMessageSelection(msg),
              onReactionTap: (msg, emoji) => _handleReactionTap(msg, emoji),
              onAddReaction: (msg) => _showReactionPicker(msg),
              onQuotedMessageTap: (msg) => _scrollToMessage(msg.id),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
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

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }
}

extension DateTimeExtension on DateTime {
  bool isAtSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
