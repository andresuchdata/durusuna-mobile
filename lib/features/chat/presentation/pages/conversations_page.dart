import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_theme.dart';
import '../../../../shared/widgets/performance_optimized_list.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/local_chat_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/local_conversation.dart';
import '../../../../shared/widgets/global_app_scaffold.dart';
import '../../../../shared/services/chat_repository_service.dart';
import '../../../../shared/providers/typing_status_provider.dart';
import '../../../../shared/providers/local_chat_providers.dart';
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
      // Defensive: ensure we're NOT considered to be viewing any conversation
      // while on the conversations list. This prevents accidental auto
      // mark-as-read on incoming messages.
      try {
        ref.read(currentConversationProvider.notifier).state = null;
      } catch (_) {}

      // Force load conversations to ensure provider is active
      // Don't refresh here to prevent flickering - let the provider load naturally

      // NEW: Ensure Isar has conversation rows after fresh install/reset
      // by syncing from server once when this page opens
      try {
        ref.read(localChatServiceProvider).syncConversationsNow();
      } catch (_) {}

      // Join all conversation rooms for real-time updates
      _joinAllConversationRooms();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update conversations when dependencies change (e.g., when returning to this page)
    // This ensures unread counts are up-to-date when navigating back from chat pages
    // Use targeted updates instead of full refresh to prevent flickering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Don't refresh the entire list - just ensure the provider is up-to-date
        // The unread counts should already be updated via the markAsRead calls
      } catch (e) {
        debugPrint('⚠️ [ConversationsPage] Error in didChangeDependencies: $e');
      }
    });
  }

  /// Join all conversation rooms to receive real-time updates
  void _joinAllConversationRooms() {
    final conversationsAsync = ref.read(localConversationsProvider);
    final realtimeService = ref.read(realtimeServiceProvider);

    conversationsAsync.whenData((conversations) {
      if (conversations.isEmpty) {
        return;
      }

      for (final conversation in conversations) {
        realtimeService.joinConversation(conversation.serverId);
      }
    });
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

      await ChatRepositoryService.clearAllData();

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

      await ChatRepositoryService.forceRecreateDatabase();

      // Refresh the conversations list
      ref.read(localConversationsProvider.notifier).refresh();

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

  /// Force sync conversations from server
  Future<void> _forceSyncConversations() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('🔄 Force syncing conversations from server...')),
      );

      await ref.read(localChatServiceProvider).syncConversationsNow();

      // Refresh the conversations list
      ref.read(localConversationsProvider.notifier).refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Conversations synced from server!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Force sync failed: $e')),
      );
    }
  }

  /// Test typing indicator functionality
  Future<void> _testTypingIndicator() async {
    try {
      final conversationsAsync = ref.read(localConversationsProvider);
      conversationsAsync.whenData((conversations) {
        if (conversations.isNotEmpty) {
          final firstConversation = conversations.first;
          final realtimeService = ref.read(realtimeServiceProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('🧪 Testing typing for: ${firstConversation.name}')),
          );

          // Send typing start
          realtimeService.startTyping(firstConversation.serverId);

          // Stop after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            realtimeService.stopTyping(firstConversation.serverId);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Typing test completed')),
            );
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ No conversations to test with')),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Typing test failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsState = ref.watch(localConversationsProvider);

    // Debug logging to see what's happening
    conversationsState.when(
      loading: () =>
          debugPrint('🔄 [ConversationsPage] Loading conversations...'),
      error: (error, stack) => debugPrint(
          '❌ [ConversationsPage] Error loading conversations: $error'),
      data: (conversations) => debugPrint(
          '✅ [ConversationsPage] Loaded ${conversations.length} conversations'),
    );

    // Join conversation rooms when conversations are loaded
    ref.listen(localConversationsProvider, (previous, next) {
      next.whenData((conversations) {
        if (conversations.isNotEmpty) {
          _joinAllConversationRooms();
        }
      });
    });

    // Ensure rooms are (re)joined when the socket connects
    ref.listen(realtimeConnectionProvider, (previous, next) {
      next.whenData((isConnected) {
        if (isConnected) {
          _joinAllConversationRooms();
        }
      });
    });

    // Real-time conversation updates are now handled by the centralized RealtimeDispatcher.
    // Removed the loadConversations() call that was overriding local unread count increments.
    // ref.listen(realtimeMessagesProvider, (previous, next) {
    //   next.whenData((rtMessage) {
    //     // This was causing auto-mark-as-read by overriding local increments with server data
    //     ref.read(conversationsProvider.notifier).loadConversations();
    //   });
    // });

    // Listen for real-time conversation events (creation, updates)
    ref.listen(realtimeConversationProvider, (previous, next) {
      next.whenData((conversationEvent) {
        if (conversationEvent.action == 'created') {
          // Don't refresh here to prevent flickering - let realtime dispatcher handle updates
          debugPrint(
              '📋 ConversationsPage: New conversation created, letting realtime dispatcher handle update');
        }
      });
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
                      case 'force_sync':
                        _forceSyncConversations();
                        break;
                      case 'test_typing':
                        _testTypingIndicator();
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
                    const PopupMenuItem(
                      value: 'force_sync',
                      child: Row(
                        children: [
                          Icon(Icons.sync, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Force Sync Conversations'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'test_typing',
                      child: Row(
                        children: [
                          Icon(Icons.keyboard, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Test Typing Indicator'),
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

  Widget _buildConversationsList(
      AsyncValue<List<LocalConversation>> conversationsAsync) {
    return RefreshIndicator(
      onRefresh: () async {
        // Try to sync from server first, then refresh local data
        try {
          await ref.read(localChatServiceProvider).syncConversationsNow();
        } catch (e) {
          debugPrint('⚠️ [ConversationsPage] Sync failed: $e');
        }
        await ref.read(localConversationsProvider.notifier).refresh();
      },
      child: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          debugPrint(
              '❌ [ConversationsPage] Local conversations failed: $error');
          // Fallback to legacy provider if local fails
          return _buildFallbackConversationsList();
        },
        data: (conversations) {
          if (conversations.isEmpty) {
            debugPrint(
                '⚠️ [ConversationsPage] No local conversations found, trying fallback');
            return _buildFallbackConversationsList();
          }
          return PerformanceOptimizedList(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              if (index < conversations.length - 1) {
                // Add separator for all items except the last
                return Column(
                  children: [
                    _buildConversationTile(conversations[index]),
                    const Divider(height: 0.5, indent: 64),
                  ],
                );
              }
              return _buildConversationTile(conversations[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildFallbackConversationsList() {
    final legacyConversationsState = ref.watch(conversationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(conversationsProvider.notifier).loadConversations();
      },
      child: legacyConversationsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : legacyConversationsState.error != null
              ? _buildErrorState(legacyConversationsState.error!)
              : legacyConversationsState.conversations.isEmpty
                  ? _buildEmptyState()
                  : PerformanceOptimizedList(
                      itemCount: legacyConversationsState.conversations.length,
                      itemBuilder: (context, index) {
                        if (index <
                            legacyConversationsState.conversations.length - 1) {
                          return Column(
                            children: [
                              _buildLegacyConversationTile(
                                  legacyConversationsState
                                      .conversations[index]),
                              const Divider(height: 0.5, indent: 64),
                            ],
                          );
                        }
                        return _buildLegacyConversationTile(
                            legacyConversationsState.conversations[index]);
                      },
                    ),
    );
  }

  Widget _buildConversationTile(LocalConversation localConversation) {
    return RepaintBoundary(
      child: ConversationTile(
        conversation: localConversation,
        onTap: () {
          ref.read(currentConversationProvider.notifier).state = null;

          // Convert LocalConversation to Conversation for LocalChatPage
          final conversation = Conversation(
            id: localConversation.serverId,
            type: localConversation.type.value,
            name: localConversation.name,
            description: localConversation.description,
            avatarUrl: localConversation.avatarUrl,
            createdBy: '', // Not available in LocalConversation
            participants:
                _buildParticipantsFromLocalConversation(localConversation),
            otherUser: _buildOtherUserFromLocalConversation(localConversation),
            unreadCount: localConversation.unreadCount,
            lastActivity: localConversation.lastActivity,
            isOnline: localConversation.isOnline,
          );

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

              // Don't refresh conversations here to prevent flickering
              // The unread counts are already updated via realtime updates
            });
          });
        },
      ),
    );
  }

  Widget _buildLegacyConversationTile(Conversation conversation) {
    // Get the display name - for direct chats, use other user's name
    String getDisplayName() {
      if (conversation.type == 'direct' && conversation.otherUser != null) {
        final otherUser = conversation.otherUser!;
        if (otherUser.firstName.isNotEmpty || otherUser.lastName.isNotEmpty) {
          return '${otherUser.firstName} ${otherUser.lastName}'.trim();
        }
        return otherUser.email;
      }
      return conversation.name ?? 'Unknown conversation';
    }

    // Get the avatar URL - for direct chats, use other user's avatar
    String? getAvatarUrl() {
      if (conversation.type == 'direct' && conversation.otherUser != null) {
        return conversation.otherUser!.avatarUrl;
      }
      return conversation.avatarUrl;
    }

    // Get initials for avatar
    String getInitials() {
      if (conversation.type == 'direct' && conversation.otherUser != null) {
        final otherUser = conversation.otherUser!;
        if (otherUser.firstName.isNotEmpty) {
          return otherUser.firstName[0].toUpperCase();
        }
        if (otherUser.lastName.isNotEmpty) {
          return otherUser.lastName[0].toUpperCase();
        }
        if (otherUser.email.isNotEmpty) {
          return otherUser.email[0].toUpperCase();
        }
        return 'U';
      }

      if (conversation.type == 'group') {
        final name = conversation.name ?? 'Group';
        final words = name.split(' ');
        if (words.length >= 2) {
          return '${words[0][0]}${words[1][0]}';
        }
        return name.isNotEmpty ? name[0].toUpperCase() : 'G';
      }
      return 'U';
    }

    return RepaintBoundary(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: getAvatarUrl()?.isNotEmpty == true
                  ? NetworkImage(getAvatarUrl()!)
                  : null,
              child: getAvatarUrl()?.isEmpty != false
                  ? Text(
                      getInitials(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
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
                getDisplayName(),
                style: TextStyle(
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            if (conversation.lastMessageAt != null)
              Text(
                timeago.format(conversation.lastMessageAt!),
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
            Future.delayed(const Duration(milliseconds: 100), () {
              ref.read(currentConversationProvider.notifier).state = null;

              // CRITICAL: Update the specific conversation's unread count to 0
              // This ensures that when returning from chat page, unread counts are updated
              // Use targeted update instead of full refresh to prevent flickering
              try {
                ref
                    .read(localConversationsProvider.notifier)
                    .markAsRead(conversation.id);
                debugPrint(
                    '🔄 [ConversationsPage] Updated conversation ${conversation.id} unread count to 0');
              } catch (e) {
                debugPrint(
                    '⚠️ [ConversationsPage] Failed to update conversation unread count: $e');
                // Fallback: try to refresh the conversations list
                try {
                  ref.read(localConversationsProvider.notifier).refresh();
                } catch (refreshError) {
                  debugPrint(
                      '⚠️ [ConversationsPage] Failed to refresh conversations: $refreshError');
                }
              }
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
              ref.read(localConversationsProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build participants list from LocalConversation data
  List<User> _buildParticipantsFromLocalConversation(
      LocalConversation localConversation) {
    final participants = <User>[];

    if (localConversation.type == LocalConversationType.direct) {
      // Add the other user if this is a direct conversation
      if (localConversation.otherUserId != null &&
          localConversation.otherUserName != null) {
        // Parse the other user's name
        final nameParts = localConversation.otherUserName!.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        participants.add(User(
          id: localConversation.otherUserId!,
          firstName: firstName,
          lastName: lastName,
          email: '', // Not available in LocalConversation
          avatarUrl: localConversation.otherUserAvatar,
          phone: null,
          userType: UserType.student, // Default to student type
          role: UserRole.user,
          schoolId: null,
          school: null,
          isActive: true,
          lastActiveAt: null,
          createdAt: localConversation.createdAt,
          updatedAt: localConversation.updatedAt,
        ));
      }
    } else if (localConversation.type == LocalConversationType.group) {
      // For group conversations, we need to load participants from the local chat service
      // This is a temporary solution - ideally the LocalConversation should store participant info
      try {
        // Try to get participants from the local chat service
        final localChatService = ref.read(localChatServiceProvider);
        // Note: This is a synchronous call, but we need async data
        // We'll handle this in the LocalChatPage by loading participants there
        debugPrint(
            '🔍 [ConversationsPage] Group conversation ${localConversation.serverId}: Will load participants in LocalChatPage');
      } catch (e) {
        debugPrint(
            '⚠️ [ConversationsPage] Could not access localChatService: $e');
      }
    }

    return participants;
  }

  /// Build otherUser from LocalConversation data
  User? _buildOtherUserFromLocalConversation(
      LocalConversation localConversation) {
    if (localConversation.type == LocalConversationType.direct) {
      if (localConversation.otherUserId == null ||
          localConversation.otherUserName == null) {
        return null;
      }

      // Parse the other user's name
      final nameParts = localConversation.otherUserName!.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      return User(
        id: localConversation.otherUserId!,
        firstName: firstName,
        lastName: lastName,
        email: '', // Not available in LocalConversation
        avatarUrl: localConversation.otherUserAvatar,
        phone: null,
        userType: UserType.student, // Default to student type
        role: UserRole.user,
        schoolId: null,
        school: null,
        isActive: true,
        lastActiveAt: null,
        createdAt: localConversation.createdAt,
        updatedAt: localConversation.updatedAt,
      );
    } else if (localConversation.type == LocalConversationType.group) {
      // For group conversations, return null as there's no single "other user"
      return null;
    }

    return null;
  }
}

class ConversationTile extends ConsumerWidget {
  final LocalConversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  String get displayName {
    if (conversation.type == LocalConversationType.group) {
      return conversation.name;
    }
    // For direct conversations, use otherUserName if available, otherwise fall back to name
    final displayName = conversation.otherUserName ?? conversation.name;
    debugPrint(
        '🔍 [ConversationTile] Direct conversation ${conversation.serverId}: name="${conversation.name}", otherUserName="${conversation.otherUserName}", displayName="$displayName"');
    return displayName;
  }

  String get avatarUrl {
    if (conversation.type == LocalConversationType.group) {
      return conversation.avatarUrl ?? '';
    }
    return conversation.otherUserAvatar ?? '';
  }

  String get initials {
    if (conversation.type == LocalConversationType.group) {
      final name = conversation.name;
      final words = name.split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}';
      }
      return name.isNotEmpty ? name[0].toUpperCase() : 'G';
    }
    // For direct conversations, use otherUserName if available
    final name = conversation.otherUserName ?? conversation.name;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _getTypingText(List<String> typingUsers) {
    if (typingUsers.isEmpty) return '';

    if (conversation.type == LocalConversationType.direct) {
      // For direct conversations, just show "typing..."
      return 'typing...';
    } else {
      // For group conversations, show who is typing
      if (typingUsers.length == 1) {
        // For now, just show "Someone is typing..." since we don't have participant names
        return 'Someone is typing...';
      } else if (typingUsers.length == 2) {
        return '2 people are typing...';
      } else {
        return '${typingUsers.length} people are typing...';
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get typing status for this conversation
    final isTyping =
        ref.watch(conversationIsTypingProvider(conversation.serverId));
    final typingUsers =
        ref.watch(conversationTypingUsersProvider(conversation.serverId));

    // Debug logging for typing status
    debugPrint(
        '🔍 [ConversationTile] ${conversation.serverId}: isTyping=$isTyping, typingUsers=$typingUsers');

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
          if (conversation.type == LocalConversationType.group)
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
          if (conversation.lastMessageAt != null)
            Text(
              timeago.format(conversation.lastMessageAt!),
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
              isTyping
                  ? _getTypingText(typingUsers)
                  : (conversation.lastMessage ?? 'No messages yet'),
              style: TextStyle(
                color: isTyping
                    ? Colors.green[600] // Green color for typing indicator
                    : (conversation.unreadCount > 0
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary),
                fontWeight: isTyping || conversation.unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
                fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.unreadCount > 0 && !isTyping)
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
