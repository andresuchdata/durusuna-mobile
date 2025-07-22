import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/models/message.dart';
import '../../../../shared/widgets/widgets.dart';
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

  // Track online status of the other user dynamically
  late bool _isOtherUserOnline;

  // Track if we should auto-scroll to bottom on initial load
  bool _shouldAutoScrollOnLoad = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize online status from conversation
    _isOtherUserOnline = widget.conversation.isOnline;

    // Join conversation room for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📱 ChatPage: Joining conversation ${widget.conversation.id}');
      final realtimeService = ref.read(realtimeServiceProvider);
      print(
          '📱 ChatPage: Realtime service connected: ${realtimeService.isConnected}');

      // Set current conversation ID to prevent unread count increments
      ref.read(currentConversationProvider.notifier).state =
          widget.conversation.id;
      print(
          '📱 ChatPage: Set current conversation ID to ${widget.conversation.id}');

      realtimeService.joinConversation(widget.conversation.id);

      // Update last seen when entering conversation
      realtimeService.updateLastSeen(widget.conversation.id);

      // CRITICAL: Force refresh messages if conversation was recently active
      // This ensures chat messages are synced with conversation list
      final timeSinceLastActivity =
          DateTime.now().difference(widget.conversation.lastActivity);
      final shouldForceRefresh =
          timeSinceLastActivity.inSeconds < 30; // Last 30 seconds

      if (shouldForceRefresh) {
        print(
            '📱 🔄 ChatPage: FORCE REFRESHING - Conversation was recently active (${timeSinceLastActivity.inSeconds}s ago)');
        ref
            .read(chatMessagesProvider(widget.conversation.id).notifier)
            .refreshMessages();
      }

      // Note: We don't immediately mark as read here - only when user scrolls to view messages
      // This ensures better UX where messages are only marked as read when actually viewed

      // Use the more reliable scroll method with longer delays
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('📱 ChatPage: Triggering initial scroll from initState');
          _ensureScrollToBottom();
        }
      });

      // Additional backup with even longer delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _shouldAutoScrollOnLoad) {
          print('📱 ChatPage: Final backup scroll from initState');
          _ensureScrollToBottom();
        }
      });

      // REAL-TIME READ STATUS: Mark messages as read when opening chat page
      _markAllUnreadMessagesAsReadOnOpen();

      // Note: Removed additional mark-as-read safety call
      // We now only mark as read when user actually scrolls to view messages
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();

    // Leave conversation room and clear current conversation tracking
    // Do this synchronously to ensure it happens before dispose completes
    try {
      final realtimeService = ref.read(realtimeServiceProvider);
      realtimeService.leaveConversation(widget.conversation.id);

      // Clear current conversation ID immediately to allow unread counts
      ref.read(currentConversationProvider.notifier).state = null;
      print('📱 ChatPage: Cleared current conversation ID in dispose');
    } catch (e) {
      print('⚠️ Error in dispose: $e');
    }

    super.dispose();
  }

  @override
  void deactivate() {
    // Additional cleanup when widget is deactivated (before dispose)
    // This ensures cleanup happens even if dispose is delayed on iOS
    try {
      final realtimeService = ref.read(realtimeServiceProvider);
      realtimeService.leaveConversation(widget.conversation.id);

      // Clear current conversation tracking to allow unread counts
      ref.read(currentConversationProvider.notifier).state = null;
      print('📱 ChatPage: Cleared current conversation ID in deactivate');
    } catch (e) {
      print('⚠️ Error in deactivate: $e');
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

    // Mark conversation as read since user has scrolled to see latest messages
    ref
        .read(conversationsProvider.notifier)
        .markConversationAsRead(widget.conversation.id);
    print(
        '📱 ChatPage: Marked conversation as read - user viewed bottom messages');

    // REAL-TIME READ STATUS: Mark individual messages as read via realtime service
    _markIndividualMessagesAsRead();

    // Reset flag after a delay to allow for future mark-as-read calls
    Future.delayed(const Duration(seconds: 2), () {
      _hasMarkedAsReadAtBottom = false;
    });
  }

  /// Mark individual unread messages as read and emit to realtime service
  void _markIndividualMessagesAsRead() {
    final messagesState =
        ref.read(chatMessagesProvider(widget.conversation.id));
    final currentUserId = ref.read(authStateProvider).user?.id;

    if (currentUserId == null) return;

    // Find unread messages from other users
    final unreadMessages = messagesState.messages
        .where((message) =>
            message.senderId != currentUserId &&
            message.readStatus != ReadStatus.read &&
            message.readAt == null)
        .toList();

    if (unreadMessages.isNotEmpty) {
      final messageIds = unreadMessages.map((m) => m.id).toList();
      print(
          '📱 ChatPage: Marking ${messageIds.length} messages as read via realtime service');

      // Emit to realtime service for immediate updates
      final realtimeService = ref.read(realtimeServiceProvider);
      realtimeService.markAsRead(messageIds, widget.conversation.id);

      // Also call API for persistence
      _markMessagesAsReadViaAPI(messageIds);
    }
  }

  /// Mark messages as read via API for persistence
  Future<void> _markMessagesAsReadViaAPI(List<String> messageIds) async {
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.markAsRead(messageIds);
      print('📱 ChatPage: Successfully marked messages as read via API');
    } catch (e) {
      print('⚠️ ChatPage: Failed to mark messages as read via API: $e');
    }
  }

  /// Mark all unread messages as read when opening chat page
  void _markAllUnreadMessagesAsReadOnOpen() {
    // Wait a bit for messages to load
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _markIndividualMessagesAsRead();
      }
    });
  }

  /// Show profile card for the other user in conversation
  void _showProfileCard() {
    // Only show profile for direct conversations
    if (widget.conversation.type != 'direct' ||
        widget.conversation.otherUser == null) {
      return;
    }

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
      _scrollToBottom(animated: true);

      // Ensure conversation is marked as read when user sends a message
      // This handles any edge cases where unread count might be wrong
      await ref
          .read(conversationsProvider.notifier)
          .markConversationAsRead(widget.conversation.id);
      print('📱 ChatPage: Marked conversation as read after sending message');
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
    print('📱 _scrollToBottom() called - Animated: $animated');

    if (!mounted || !_scrollController.hasClients) {
      print('❌ _scrollToBottom() - Not mounted or no clients');
      return;
    }

    final position = _scrollController.position;
    final targetPosition = position.maxScrollExtent;

    print(
        '📱 _scrollToBottom() - Target: $targetPosition, Current: ${position.pixels}');

    if (targetPosition <= 0) {
      print('📱 _scrollToBottom() - No content to scroll to');
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
            print(
                '📱 After animation - Current: $currentPos, Target: $maxPos, Diff: $diff');
            if (diff > 10) {
              print('📱 Animation didn\'t reach bottom, using jumpTo');
              _scrollController.jumpTo(maxPos);
            }
          }
        });
      } else {
        _scrollController.jumpTo(targetPosition);
        print('✅ _scrollToBottom() - Jumped to $targetPosition');
      }
    } catch (e) {
      print('⚠️ _scrollToBottom() failed: $e');
    }
  }

  // More aggressive scroll method that waits for everything to be ready
  void _ensureScrollToBottom() {
    if (!mounted) return;

    print('📱 _ensureScrollToBottom() called');

    // Wait for the next frame cycle to ensure ListView is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Try multiple times with increasing delays (more attempts for Android)
      _attemptScrollWithRetry(1, maxAttempts: 12);
    });
  }

  void _attemptScrollWithRetry(int attempt, {int maxAttempts = 12}) {
    if (!mounted || attempt > maxAttempts) {
      print('❌ _attemptScrollWithRetry - Stopped at attempt $attempt');
      return;
    }

    print('📱 _attemptScrollWithRetry - Attempt $attempt (Android optimized)');

    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      print('📱 ScrollController ready on attempt $attempt - executing scroll');

      // Use immediate jumpTo for better reliability on Android
      final targetPosition = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(targetPosition);

      // Verify we reached the bottom with longer delay for Android
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _scrollController.hasClients) {
          final currentPos = _scrollController.position.pixels;
          final maxPos = _scrollController.position.maxScrollExtent;
          final diff = (maxPos - currentPos).abs();
          print(
              '📱 Verify scroll - Current: $currentPos, Target: $maxPos, Diff: $diff');

          if (diff > 5) {
            print('📱 Not at bottom, trying again immediately');
            _scrollController.jumpTo(maxPos);

            // Double-check after another delay
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _scrollController.hasClients) {
                final finalPos = _scrollController.position.pixels;
                final finalMax = _scrollController.position.maxScrollExtent;
                print('📱 Final position check: $finalPos vs $finalMax');
                if ((finalMax - finalPos).abs() > 5) {
                  _scrollController.jumpTo(finalMax);
                }
              }
            });
          } else {
            print('✅ Successfully scrolled to bottom');
            // User has been scrolled to bottom, mark conversation as read
            _markAsReadWhenAtBottom();
          }
        }
      });
    } else {
      // Wait longer between attempts for later retries (Android needs more time)
      final delay = Duration(milliseconds: 150 + (attempt * 75));
      print(
          '📱 ScrollController not ready, retrying in ${delay.inMilliseconds}ms');
      Future.delayed(delay, () {
        _attemptScrollWithRetry(attempt + 1, maxAttempts: maxAttempts);
      });
    }
  }

  // Force scroll to bottom when ListView is definitely ready
  void _forceScrollToBottomWhenReady() {
    if (!mounted) return;

    print('📱 _forceScrollToBottomWhenReady() called');

    // Keep trying until scroll controller has clients and maxScrollExtent > 0
    void waitForScrollController(int attempt) {
      if (!mounted) return;

      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        print('📱 ScrollController ready, forcing scroll to bottom');
        _scrollToBottom(animated: false);

        // Additional attempts
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _scrollToBottom(animated: false);
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _scrollToBottom(animated: true);
        });
      } else if (attempt < 20) {
        // Try for up to 2 seconds
        print('📱 ScrollController not ready, attempt $attempt');
        Future.delayed(const Duration(milliseconds: 100), () {
          waitForScrollController(attempt + 1);
        });
      } else {
        print('❌ ScrollController never became ready');
      }
    }

    waitForScrollController(1);
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

    // Debug: Print green dot status every build
    print(
        '🟢 Build: Green dot status - type: ${widget.conversation.type}, online: $_isOtherUserOnline, typing: ${messagesState.isTyping}');

    // Safety check: If someone is typing, they must be online
    if (messagesState.isTyping && !_isOtherUserOnline) {
      print(
          '🔄 Safety check: User is typing but not marked online - fixing this');
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
      print('📱 Build: Messages already loaded, forcing scroll to bottom');
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
        print(
            '📱 ChatPage: Auto-scrolling to bottom after initial messages loaded');
        print('📱 ChatPage: Message count: ${next.messages.length}');
        _shouldAutoScrollOnLoad = false; // Prevent future auto-scrolls

        // Use multiple scroll attempts for Android reliability
        _ensureScrollToBottom();

        // Additional scroll attempts with longer delays for Android
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            print('📱 ChatPage: Secondary scroll attempt (800ms delay)');
            _ensureScrollToBottom();
          }
        });

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            print('📱 ChatPage: Final scroll attempt (1500ms delay)');
            _scrollToBottom(animated: false); // Force immediate scroll
          }
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
            }

            // Auto-scroll to bottom for any new message (own or from others)
            if (realtimeMessage.action == 'created') {
              print('📱 ChatPage: Scrolling to bottom for new message');

              // Check if user is near the bottom before auto-scrolling
              // Only auto-scroll if user is within 200 pixels of bottom
              final shouldAutoScroll = !_scrollController.hasClients ||
                  _scrollController.position.pixels >=
                      _scrollController.position.maxScrollExtent - 200;

              if (shouldAutoScroll) {
                print('📱 ChatPage: User is near bottom, auto-scrolling');

                // Add a small delay to ensure the message is fully rendered
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _scrollToBottom(animated: true);

                    // Additional scroll attempt with delay for reliability
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) {
                        print('📱 ChatPage: Secondary scroll for new message');
                        _scrollToBottom(animated: true);
                      }
                    });
                  }
                });
              } else {
                print(
                    '📱 ChatPage: User is reading older messages, not auto-scrolling');

                // Show a subtle indicator that there's a new message
                // (Optional: Could add a "New message" floating button here)
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

            // If someone is typing, they're definitely online - show green dot
            final otherUserId = widget.conversation.otherUser?.id;
            print(
                '🔍 Debug: otherUserId=$otherUserId, typing.userId=${typing.userId}, typing.isTyping=${typing.isTyping}');
            print('🔍 Debug: Current _isOtherUserOnline=$_isOtherUserOnline');

            if (otherUserId != null &&
                typing.userId == otherUserId &&
                typing.isTyping) {
              print(
                  '👤 ChatPage: User is typing → Setting as ONLINE (green dot should appear)');
              setState(() {
                _isOtherUserOnline = true;
              });
              print(
                  '🔍 Debug: After setState _isOtherUserOnline=$_isOtherUserOnline');
            }
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

    // Listen for presence updates (online/offline status)
    ref.listen(realtimePresenceProvider, (previous, next) {
      print('👤 ChatPage: realtimePresenceProvider state change');
      next?.when(
        data: (presence) {
          print(
              '👤 ChatPage: Received presence event - User: ${presence.userId}, Online: ${presence.isOnline}');

          // Check if this presence update is for the other user in this conversation
          final otherUserId = widget.conversation.otherUser?.id;
          print('👤 ChatPage: Other user ID: $otherUserId');
          print(
              '👤 ChatPage: Current user ID: ${ref.read(authStateProvider).user?.id}');

          if (otherUserId != null && presence.userId == otherUserId) {
            print(
                '👤 ChatPage: Updating presence for other user: ${presence.isOnline ? "Online" : "Offline"}');
            print(
                '👤 ChatPage: Green dot should ${presence.isOnline ? "APPEAR" : "DISAPPEAR"}');
            setState(() {
              _isOtherUserOnline = presence.isOnline;
            });
          } else {
            print(
                '👤 ChatPage: Ignoring presence event (not for other user in this conversation)');
          }
        },
        loading: () {
          print('👤 ChatPage: Realtime presence loading...');
        },
        error: (error, stack) {
          print('❌ ChatPage: Error listening to presence updates: $error');
          print('❌ Stack: $stack');
        },
      );
    });

    // REAL-TIME READ STATUS: Listen for message status updates
    ref.listen(realtimeMessageStatusProvider, (previous, next) {
      print('📋 ChatPage: realtimeMessageStatusProvider state change');
      next?.when(
        data: (statusEvent) {
          print(
              '📋 ChatPage: Received message status event - Status: ${statusEvent.status}');
          print('📋 ChatPage: Message IDs: ${statusEvent.messageIds}');
          print('📋 ChatPage: Conversation ID: ${statusEvent.conversationId}');

          // Only process if it's for this conversation
          if (statusEvent.conversationId == widget.conversation.id) {
            print(
                '📋 ChatPage: Updating message status for ${statusEvent.messageIds.length} messages');

            // Update message status in the local state
            final messagesNotifier =
                ref.read(chatMessagesProvider(widget.conversation.id).notifier);
            for (final messageId in statusEvent.messageIds) {
              messagesNotifier.updateMessageStatus(
                  messageId, statusEvent.status, statusEvent.timestamp);
            }

            print(
                '✅ ChatPage: Updated read status for messages - double ticks should update');
          } else {
            print(
                '📋 ChatPage: Ignoring status event (different conversation)');
          }
        },
        loading: () {
          print('📋 ChatPage: Realtime message status loading...');
        },
        error: (error, stack) {
          print(
              '❌ ChatPage: Error listening to message status updates: $error');
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
                              : 'Last seen ${timeago.format(widget.conversation.lastActivity)}',
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
      ),
      body: Column(
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

  Widget _buildMessagesList(dynamic messagesState, dynamic authState) {
    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
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
              message: message,
              isMe: isMe,
              onReply: (msg) => _replyToMessage(msg),
              onEdit: isMe ? (msg) => _editMessage(msg) : null,
              onDelete: isMe ? (msg) => _deleteMessage(msg) : null,
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
