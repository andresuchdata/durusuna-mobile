import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_chat_service.dart';
import '../models/local_conversation.dart';
import '../models/local_message.dart';
import '../models/local_user.dart';
import '../database/chat_database.dart';
import '../../core/storage/storage_service.dart';
import '../services/realtime_service.dart';

/// Provider for local conversations (instant loading)
final localConversationsProvider = StateNotifierProvider<
    LocalConversationsNotifier, AsyncValue<List<LocalConversation>>>(
  (ref) => LocalConversationsNotifier(ref.read(localChatServiceProvider)),
);

class LocalConversationsNotifier
    extends StateNotifier<AsyncValue<List<LocalConversation>>> {
  final LocalChatService _chatService;
  StreamSubscription? _realtimeSubscription;

  LocalConversationsNotifier(this._chatService)
      : super(const AsyncValue.loading()) {
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      // Load instantly from local database
      final conversations = await _chatService.getConversations();
      if (mounted) {
        state = AsyncValue.data(conversations);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() => _loadConversations();

  void markAsRead(String conversationId) {
    // Update database immediately
    _chatService.markConversationAsRead(conversationId);

    // Optimistically update UI
    state.whenData((conversations) {
      final updated = conversations
          .map((c) =>
              c.serverId == conversationId ? c.copyWith(unreadCount: 0) : c)
          .toList();
      if (mounted) {
        state = AsyncValue.data(updated);
      }
    });
  }

  void addOrUpdateConversation(LocalConversation conversation) {
    state.whenData((conversations) {
      final existingIndex =
          conversations.indexWhere((c) => c.serverId == conversation.serverId);

      List<LocalConversation> updated;
      if (existingIndex != -1) {
        // Update existing conversation
        updated = [...conversations];
        updated[existingIndex] = conversation;
      } else {
        // Add new conversation at the top
        updated = [conversation, ...conversations];
      }

      // Sort by last activity (most recent first)
      updated.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      if (mounted) {
        state = AsyncValue.data(updated);
      }
    });
  }

  void updateLastMessage(String conversationId, LocalMessage message) {
    state.whenData((conversations) {
      final updated = conversations.map((c) {
        if (c.serverId == conversationId) {
          return c.copyWith(
            lastMessage: message.content,
            lastMessageAt: message.createdAt,
            lastActivity: message.createdAt,
            unreadCount: message.isFromMe ? c.unreadCount : c.unreadCount + 1,
          );
        }
        return c;
      }).toList();

      // Sort by last activity
      updated.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      if (mounted) {
        state = AsyncValue.data(updated);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for local messages in a specific conversation
final localMessagesProvider = StateNotifierProvider.family<
    LocalMessagesNotifier, AsyncValue<List<LocalMessage>>, String>(
  (ref, conversationId) => LocalMessagesNotifier(
    ref.read(localChatServiceProvider),
    conversationId,
    ref,
  ),
);

class LocalMessagesNotifier
    extends StateNotifier<AsyncValue<List<LocalMessage>>> {
  final LocalChatService _chatService;
  final String _conversationId;
  final Ref _ref;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize = 50;
  StreamSubscription<List<LocalMessage>>? _streamSub;

  LocalMessagesNotifier(this._chatService, this._conversationId, this._ref)
      : super(const AsyncValue.loading()) {
    _watchMessages();
  }

  void _watchMessages() {
    _streamSub?.cancel();
    _streamSub = ChatDatabase.watchMessages(_conversationId, limit: _pageSize)
        .listen((messages) async {
      // Force an initial server sync on empty state
      if (messages.isEmpty) {
        try {
          await _chatService.forceSyncMessagesFromServer(_conversationId);
        } catch (_) {}
      }
      if (mounted) {
        state = AsyncValue.data(messages);
        _currentOffset = messages.length;
        _hasMore = messages.length >= _pageSize;
      }
    }, onError: (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    });
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    try {
      if (loadMore && !_hasMore) return;

      final offset = loadMore ? _currentOffset : 0;

      // Load instantly from local database
      final messages = await _chatService.getMessages(
        _conversationId,
        limit: _pageSize,
        offset: offset,
      );

      // 🔥 CRITICAL: If no local messages found and it's initial load, force server sync
      if (messages.isEmpty && offset == 0) {
        print(
            '🔄 No local messages found, forcing server sync for conversation: $_conversationId');
        try {
          // Force immediate sync from server for this conversation
          await _chatService.forceSyncMessagesFromServer(_conversationId);

          // Reload from local database after sync
          final syncedMessages = await _chatService.getMessages(
            _conversationId,
            limit: _pageSize,
            offset: 0,
          );

          if (mounted) {
            state = AsyncValue.data(syncedMessages);
            _currentOffset = syncedMessages.length;
            _hasMore = syncedMessages.length >= _pageSize;
          }
          return;
        } catch (e) {
          print('⚠️ Failed to force sync messages from server: $e');
          // Continue with empty local messages
        }
      }

      if (mounted) {
        if (loadMore) {
          // Append older messages
          state.whenData((existingMessages) {
            final combined = [...existingMessages, ...messages];
            state = AsyncValue.data(combined);
          });
        } else {
          // Replace with fresh data
          state = AsyncValue.data(messages);
        }

        _currentOffset = offset + messages.length;
        _hasMore = messages.length >= _pageSize;
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> sendMessage(
    String content, {
    LocalMessageType messageType = LocalMessageType.text,
    String? replyToId,
  }) async {
    final startTime = DateTime.now();
    print(
        '🐛 [DEBUG] sendMessage called at ${startTime.millisecondsSinceEpoch}');

    // 🚀 INSTANT OPTIMISTIC UPDATE - Message appears immediately!
    final currentUser = StorageService.getUser();
    if (currentUser == null) {
      print('🐛 [DEBUG] No current user, returning early');
      return;
    }

    final userCheckTime = DateTime.now();
    print(
        '🐛 [DEBUG] User check took: ${userCheckTime.difference(startTime).inMilliseconds}ms');

    // Create optimistic message with temporary ID
    final optimisticMessage = LocalMessage(
      serverId: null, // Will be set when synced to server
      conversationId: _conversationId,
      senderId: currentUser['id'],
      content: content,
      messageType: messageType,
      replyToId: replyToId,
      createdAt: DateTime.now(),
      isFromMe: true,
      isSynced: false,
      readStatus: 'sending', // Special status for optimistic messages
    );

    final messageCreateTime = DateTime.now();
    print(
        '🐛 [DEBUG] Message creation took: ${messageCreateTime.difference(userCheckTime).inMilliseconds}ms');

    // 🚀 STEP 1: Persist to DB immediately so the stream updates UI and we have stable localId
    try {
      await _chatService.saveMessageLocally(optimisticMessage);
    } catch (e) {
      print('❌ Failed to save optimistic message locally: $e');
    }

    // 🚀 STEP 2: Update conversations list
    print('🐛 [DEBUG] Updating conversations list...');
    final convUpdateStart = DateTime.now();

    _ref
        .read(localConversationsProvider.notifier)
        .updateLastMessage(_conversationId, optimisticMessage);

    final convUpdateTime = DateTime.now();
    print(
        '🐛 [DEBUG] Conversations update took: ${convUpdateTime.difference(convUpdateStart).inMilliseconds}ms');

    // 🚀 STEP 3: Sync to server (fire-and-forget)
    () async {
      try {
        final serverMessage =
            await _chatService.syncMessageToServer(optimisticMessage);
        if (serverMessage.serverId != null) {
          // Prefer adopting into optimistic row to avoid double insertions
          final adopted = await ChatDatabase.adoptServerMessage(serverMessage);
          if (!adopted) {
            await ChatDatabase.markMessageSynced(
              optimisticMessage.id.toString(),
              serverMessage.serverId!,
            );
          }

          // Hard-dedupe: remove any other optimistic duplicates that match content/time
          try {
            final all = await ChatDatabase.getLatestMessages(_conversationId,
                limit: 100);
            for (final m in all) {
              final isSamePending = m.serverId == null &&
                  m.isFromMe &&
                  m.id != optimisticMessage.id &&
                  (m.content ?? '') == (optimisticMessage.content ?? '') &&
                  (m.createdAt
                          .difference(optimisticMessage.createdAt)
                          .abs()
                          .inSeconds <=
                      5);
              if (isSamePending) {
                await ChatDatabase.deleteMessage(m.id.toString());
              }
            }
          } catch (_) {}
        }
      } catch (e) {
        print('🐛 [BACKGROUND] syncMessageToServer failed: $e');
        // Mark failed to prevent infinite retry loops
        await ChatDatabase.removePendingMessage(
            optimisticMessage.id.toString());
      }
    }();

    final totalTime = DateTime.now();
    print(
        '🐛 [DEBUG] ✅ sendMessage COMPLETED in: ${totalTime.difference(startTime).inMilliseconds}ms');
    print('🐛 [DEBUG] 🚀 Message should be visible in UI now!');
  }

  // Removed _sendMessageInBackground in favor of DB-stream-first flow

  Future<void> loadMore() async {
    await _loadMessages(loadMore: true);
  }

  Future<void> refresh() async {
    _currentOffset = 0;
    _hasMore = true;
    await _loadMessages();
  }

  void addMessage(LocalMessage message) {
    state.whenData((messages) {
      // Check if message already exists
      final exists = messages.any((m) =>
          (m.serverId != null && m.serverId == message.serverId) ||
          (m.id == message.id));

      if (!exists && mounted) {
        state = AsyncValue.data([...messages, message]);
      }
    });
  }

  void updateMessage(LocalMessage updatedMessage) {
    state.whenData((messages) {
      final index = messages.indexWhere((m) =>
          (m.serverId != null && m.serverId == updatedMessage.serverId) ||
          (m.id == updatedMessage.id));

      if (index != -1 && mounted) {
        final updated = [...messages];
        updated[index] = updatedMessage;
        state = AsyncValue.data(updated);
      }
    });
  }

  /// Delete a single message with modal confirmation
  /// Returns true if message was deleted, false if cancelled
  Future<bool> deleteMessage(LocalMessage message, BuildContext context) async {
    return await deleteBatchMessages([message], context);
  }

  /// Delete multiple messages with batch confirmation
  /// Returns true if messages were deleted, false if cancelled
  Future<bool> deleteBatchMessages(
      List<LocalMessage> messages, BuildContext context) async {
    if (messages.isEmpty) return true;

    // Step 1: Show batch confirmation modal
    final confirmed =
        await _showBatchDeleteConfirmation(context, messages.length);
    if (!confirmed) {
      return false;
    }

    int successCount = 0;
    int failCount = 0;

    try {
      // Step 2: Delete all messages locally first (optimistic update)
      for (final message in messages) {
        try {
          await _deleteMessageLocally(message);
          successCount++;
        } catch (e) {
          print('❌ Failed to delete message locally: ${message.id} - $e');
          failCount++;
        }
      }

      // Step 3: Attempt to delete on server (batch or individual)
      for (final message in messages) {
        if (message.serverId != null) {
          try {
            await _deleteMessageOnServer(
                message.serverId!, message.conversationId);
          } catch (e) {
            print(
                '⚠️ Failed to delete message on server: ${message.serverId} - $e');
            // Continue - local deletion already succeeded
          }
        }
      }

      // Show result feedback
      if (context.mounted) {
        final String resultMessage;
        Color backgroundColor;

        if (failCount == 0) {
          resultMessage = successCount == 1
              ? 'Message deleted successfully'
              : '$successCount messages deleted successfully';
          backgroundColor = Colors.green;
        } else if (successCount == 0) {
          resultMessage =
              'Failed to delete ${messages.length} message${messages.length > 1 ? 's' : ''}';
          backgroundColor = Colors.red;
        } else {
          resultMessage = '$successCount deleted, $failCount failed';
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultMessage),
            backgroundColor: backgroundColor,
          ),
        );
      }

      return failCount == 0;
    } catch (e) {
      print('❌ Failed to delete messages: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Show confirmation dialog for batch message deletion
  Future<bool> _showBatchDeleteConfirmation(
      BuildContext context, int messageCount) async {
    final isPlural = messageCount > 1;
    final title = isPlural ? 'Delete $messageCount Messages' : 'Delete Message';
    final content = isPlural
        ? 'Are you sure you want to delete $messageCount messages? This action cannot be undone.'
        : 'Are you sure you want to delete this message? This action cannot be undone.';

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(isPlural ? 'Delete All' : 'Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Delete message locally (instant UI update)
  Future<void> _deleteMessageLocally(LocalMessage message) async {
    // Remove from UI immediately
    state.whenData((messages) {
      if (mounted) {
        final updated = messages
            .where(
                (m) => !(m.serverId == message.serverId || m.id == message.id))
            .toList();
        state = AsyncValue.data(updated);
      }
    });

    // Delete from local database
    final messageId = message.serverId ?? message.id.toString();
    await ChatDatabase.deleteMessage(messageId);

    // CRITICAL: Remove from pending sync queue to prevent reappearing
    await ChatDatabase.removePendingMessage(messageId);

    print(
        '🗑️ Deleted message locally and removed from pending sync: $messageId');
  }

  /// Delete message on server
  Future<void> _deleteMessageOnServer(
      String serverId, String conversationId) async {
    try {
      final chatService = _ref.read(localChatServiceProvider);
      await chatService.deleteMessageOnServer(serverId, conversationId);
      debugPrint('🗑️ Message deleted on server: $serverId');
    } catch (e) {
      debugPrint('❌ Failed to delete message on server: $e');
      rethrow;
    }
  }

  bool get hasMore => _hasMore;

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

/// Provider for local contacts/users
final localContactsProvider =
    StateNotifierProvider<LocalContactsNotifier, AsyncValue<List<LocalUser>>>(
  (ref) => LocalContactsNotifier(ref.read(localChatServiceProvider)),
);

class LocalContactsNotifier extends StateNotifier<AsyncValue<List<LocalUser>>> {
  final LocalChatService _chatService; // retained for future expansion

  LocalContactsNotifier(this._chatService) : super(const AsyncValue.loading()) {
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      // For now, return empty list - implement contact caching later
      if (mounted) {
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> searchContacts(String query) async {
    try {
      // Search locally first, then from API if needed
      final localResults = await ChatDatabase.searchContacts(query);

      if (mounted) {
        state = AsyncValue.data(localResults);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() => _loadContacts();
}

/// Provider for message search
final messageSearchProvider = StateNotifierProvider.family<
    MessageSearchNotifier, AsyncValue<List<LocalMessage>>, String>(
  (ref, query) => MessageSearchNotifier(
    ref.read(localChatServiceProvider),
    query,
  ),
);

class MessageSearchNotifier
    extends StateNotifier<AsyncValue<List<LocalMessage>>> {
  final LocalChatService _chatService;
  final String _query;

  MessageSearchNotifier(this._chatService, this._query)
      : super(const AsyncValue.loading()) {
    if (_query.trim().isNotEmpty) {
      _searchMessages();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> _searchMessages() async {
    try {
      // Search locally (instant results)
      final results = await _chatService.searchMessages(_query);
      if (mounted) {
        state = AsyncValue.data(results);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> searchInConversation(String conversationId) async {
    try {
      final results = await _chatService.searchMessages(
        _query,
        conversationId: conversationId,
      );
      if (mounted) {
        state = AsyncValue.data(results);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}

/// Provider for real-time integration
final localChatRealtimeProvider = Provider<LocalChatRealtime>((ref) {
  return LocalChatRealtime(ref);
});

class LocalChatRealtime {
  final Ref _ref;

  LocalChatRealtime(this._ref) {
    _initialize();
  }

  void _initialize() {
    // Wire realtime messages → local DB via LocalChatService
    _ref.listen(realtimeMessagesProvider, (prev, next) {
      next.whenData((rtMessage) {
        try {
          final msgJson = rtMessage.message.toJson();
          _ref.read(localChatServiceProvider).handleRealtimeMessage(msgJson);
        } catch (e) {
          // swallow errors to keep stream healthy
        }
      });
    });

    // Wire message status updates → update Isar rows (delivered/read)
    _ref.listen(realtimeMessageStatusProvider, (prev, next) {
      next.whenData((statusEvent) async {
        try {
          for (final id in statusEvent.messageIds) {
            await ChatDatabase.updateMessageStatus(
              id,
              readStatus: statusEvent.status == 'read'
                  ? 'read'
                  : statusEvent.status == 'delivered'
                      ? 'delivered'
                      : null,
              readAt:
                  statusEvent.status == 'read' ? statusEvent.timestamp : null,
              deliveredAt: statusEvent.status == 'delivered'
                  ? statusEvent.timestamp
                  : null,
            );
          }
        } catch (_) {}
      });
    });
  }

  // _handleRealtimeMessage no longer needed; DB-stream handles updates
}
