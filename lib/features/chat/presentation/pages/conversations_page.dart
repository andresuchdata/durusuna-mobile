import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io' show Platform;
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/widgets/performance_optimized_list.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/widgets/global_app_scaffold.dart';
import '../../../../shared/database/chat_database.dart';
import 'local_chat_page.dart';
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

    if (conversationsState.conversations.isEmpty) {
      return;
    }

    if (!realtimeService.isConnected) {
      return;
    }

    for (final conversation in conversationsState.conversations) {
      if (Platform.isAndroid) {}
      realtimeService.joinConversation(conversation.id);
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

  /// Show confirmation dialog for clearing local data
  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Debug: Clear Local Data'),
          ],
        ),
        content: const Text(
            'This will clear all local messages, conversations, and contacts. '
            'Data will be re-synced from the server when you use the app.\n\n'
            '⚠️ This is a debug feature for development.\n\n'
            'Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _clearLocalData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  /// Clear all local data (messages, conversations, users)
  Future<void> _clearLocalData() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🧹 Clearing local data...')),
      );

      await ChatDatabase.clearAllData();

      // Refresh the conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Local data cleared! Will re-sync from server.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Clear failed: $e')),
      );
    }
  }

  /// Recreate database (existing functionality)
  Future<void> _recreateDatabase() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔄 FORCE RECREATING database...')),
      );

      await ChatDatabase.forceRecreateDatabase();

      // Refresh the conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Database RECREATED! Sync should work now.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Recreate failed: $e')),
      );
    }
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

    // Real-time conversations updates are now handled by the centralized RealtimeDispatcher

    return GlobalAppScaffold(
      title: _isSearching ? null : 'Messages',
      showNotifications: !_isSearching,
      actions: _isSearching
          ? [
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _startSearch,
              ),
              // Only show database management options in debug mode
              if (kDebugMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Debug Options',
                  onSelected: (value) async {
                    switch (value) {
                      case 'clear_data':
                        _showClearDataDialog();
                        break;
                      case 'recreate_db':
                        _recreateDatabase();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear_data',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Clear Local Data'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'recreate_db',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Recreate Database'),
                        ],
                      ),
                    ),
                  ],
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
      child: _isSearching
          ? Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search conversations...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      // TODO: Implement search
                    },
                  ),
                ),
                Expanded(
                  child: _buildConversationsList(conversationsState),
                ),
              ],
            )
          : _buildConversationsList(conversationsState),
    );
  }

  Widget _buildConversationsList(ConversationsState conversationsState) {
    return RefreshIndicator(
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
                  : PerformanceOptimizedList(
                      itemCount: conversationsState.conversations.length,
                      itemBuilder: (context, index) {
                        if (index <
                            conversationsState.conversations.length - 1) {
                          // Add separator for all items except the last
                          return Column(
                            children: [
                              _buildConversationTile(
                                  conversationsState.conversations[index]),
                              const Divider(height: 0.5, indent: 64),
                            ],
                          );
                        }
                        return _buildConversationTile(
                            conversationsState.conversations[index]);
                      },
                    ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    return RepaintBoundary(
      child: ConversationTile(
        conversation: conversation,
        onTap: () {
          ref.read(currentConversationProvider.notifier).state = null;
          Navigator.of(context)
              .push(
            HighRefreshPageRoute(
              child: LocalChatPage(
                conversation: conversation,
              ),
            ),
          )
              .then((_) {
            // When returning from chat page, ensure current conversation is cleared
            // Add small delay to ensure dispose methods have completed
            Future.delayed(const Duration(milliseconds: 100), () {
              ref.read(currentConversationProvider.notifier).state = null;

              // Refresh conversations to get latest unread counts
              ref.read(conversationsProvider.notifier).loadConversations();
            });
          });
        },
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
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4), // Reduced vertical padding from 8 to 4
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24, // Reduced from 28 to 24 for more compact look
            backgroundColor: AppTheme.primaryColor,
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize:
                          16, // Reduced from 18 to 16 to match smaller avatar
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
