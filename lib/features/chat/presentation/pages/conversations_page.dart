import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io' show Platform;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/models/conversation.dart';
import 'chat_page.dart';
import 'contacts_page.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    // Ensure conversations are loaded and provider is properly initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force load conversations to ensure provider is active
      ref.read(conversationsProvider.notifier).loadConversations();

      // Join all conversation rooms for real-time updates
      _joinAllConversationRooms();
    });
  }

  /// Join all conversation rooms to receive real-time updates
  void _joinAllConversationRooms() {
    final conversationsState = ref.read(conversationsProvider);
    final realtimeService = ref.read(realtimeServiceProvider);

    if (Platform.isAndroid) {
      print('🤖 ANDROID ConversationsPage: Starting room join process');
      print(
          '🤖 ANDROID - Conversations count: ${conversationsState.conversations.length}');
      print('🤖 ANDROID - Socket connected: ${realtimeService.isConnected}');
    }

    if (conversationsState.conversations.isEmpty) {
      print('🏠 ConversationsPage: No conversations to join rooms for');
      return;
    }

    if (!realtimeService.isConnected) {
      print(
          '🏠 ConversationsPage: Realtime service not connected, skipping room joins');
      return;
    }

    print(
        '🏠 ConversationsPage: Joining ${conversationsState.conversations.length} conversation rooms');

    for (final conversation in conversationsState.conversations) {
      if (Platform.isAndroid) {
        print('🤖 ANDROID - Joining room for conversation: ${conversation.id}');
        print('🤖 ANDROID - Conversation type: ${conversation.type}');
        print(
            '🤖 ANDROID - Conversation name: ${conversation.name ?? "No name"}');
      }
      realtimeService.joinConversation(conversation.id);
      if (Platform.isAndroid) {
        print('🤖 ANDROID - Join request sent for: ${conversation.id}');
      } else {
        print(
            '🏠 ConversationsPage: Joined room for conversation ${conversation.id}');
      }
    }

    if (Platform.isAndroid) {
      print('🤖 ANDROID ConversationsPage: Completed room join process');
    } else {
      print('🏠 ConversationsPage: Successfully joined all conversation rooms');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationsState = ref.watch(conversationsProvider);

    // Join conversation rooms when conversations are loaded
    ref.listen(conversationsProvider, (previous, next) {
      if (previous?.isLoading == true &&
          next.isLoading == false &&
          next.conversations.isNotEmpty) {
        _joinAllConversationRooms();
      }
    });

    // LOCAL BACKUP LISTENER: Ensure conversations list updates in real-time
    // This is a backup in case the global listener in main.dart isn't active
    ref.listen(realtimeMessagesProvider, (previous, next) {
      next?.when(
        data: (realtimeMessage) {
          // Update conversation's last message and unread count
          ref
              .read(conversationsProvider.notifier)
              .updateConversationLastMessage(
                  realtimeMessage.conversationId, realtimeMessage.message);
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  // TODO: Implement search
                },
              )
            : const Text('Messages'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ContactsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(conversationsProvider.notifier).loadConversations();
        },
        child: conversationsState.isLoading &&
                conversationsState.conversations.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : conversationsState.error != null
                ? _buildErrorState(conversationsState.error!)
                : conversationsState.conversations.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: conversationsState.conversations.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 72,
                        ),
                        itemBuilder: (context, index) {
                          final conversation =
                              conversationsState.conversations[index];
                          return ConversationTile(
                            conversation: conversation,
                            onTap: () {
                              // Clear any currently viewed conversation before navigating
                              ref
                                  .read(currentConversationProvider.notifier)
                                  .state = null;

                              Navigator.of(context)
                                  .push(
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    conversation: conversation,
                                  ),
                                ),
                              )
                                  .then((_) {
                                // When returning from chat page, ensure current conversation is cleared
                                // Add small delay to ensure dispose methods have completed
                                Future.delayed(
                                    const Duration(milliseconds: 100), () {
                                  ref
                                      .read(
                                          currentConversationProvider.notifier)
                                      .state = null;

                                  // Refresh conversations to get latest unread counts
                                  ref
                                      .read(conversationsProvider.notifier)
                                      .loadConversations();
                                });
                              });
                            },
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation with teachers,\nstudents, or parents.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ContactsPage(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading conversations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(conversationsProvider.notifier).loadConversations();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  String get displayName {
    if (conversation.type == 'group') {
      return conversation.name ?? 'Group Chat';
    }
    final otherUser = conversation.otherUser;
    if (otherUser != null) {
      return otherUser.displayName;
    }
    return 'Unknown User';
  }

  String get avatarUrl {
    if (conversation.type == 'group') {
      return conversation.avatarUrl ?? '';
    }
    return conversation.otherUser?.avatarUrl ?? '';
  }

  String get initials {
    if (conversation.type == 'group') {
      final name = conversation.name ?? 'Group';
      final words = name.split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}';
      }
      return name.isNotEmpty ? name[0].toUpperCase() : 'G';
    }
    final otherUser = conversation.otherUser;
    if (otherUser != null) {
      return '${otherUser.firstName[0]}${otherUser.lastName[0]}';
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          // Removed online indicator for direct conversations - only show in actual chat page
          if (conversation.type == 'group')
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.group,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          if (conversation.lastMessage != null)
            Text(
              timeago.format(conversation.lastMessage!.createdAt),
              style: TextStyle(
                color: conversation.unreadCount > 0
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.lastMessage?.displayContent ?? 'No messages yet',
              style: TextStyle(
                color: conversation.unreadCount > 0
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
