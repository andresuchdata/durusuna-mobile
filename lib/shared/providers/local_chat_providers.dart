import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/local_chat_service.dart';
import '../models/local_conversation.dart';
import '../models/local_message.dart';
import '../models/local_user.dart';
import '../services/chat_repository_service.dart';
import '../../core/storage/storage_service.dart';
import '../services/realtime_service.dart';
import '../services/realtime_dispatcher.dart';
import '../repositories/repository_factory.dart';

/// Provider to ensure repository is initialized before other services
final repositoryInitializationProvider = FutureProvider<void>((ref) async {
  if (!RepositoryFactory.isInitialized) {
    debugPrint('🔄 [Provider] Initializing repository factory...');
    await RepositoryFactory.initialize(preferSQLite: true);
    debugPrint('✅ [Provider] Repository factory initialized successfully');
  }
  return;
});

/// Provider for local conversations (instant loading)
final localConversationsProvider = StateNotifierProvider<
    LocalConversationsNotifier, AsyncValue<List<LocalConversation>>>(
  (ref) {
    // Ensure repository is initialized before creating the notifier
    ref.watch(repositoryInitializationProvider);
    return LocalConversationsNotifier(ref.read(localChatServiceProvider));
  },
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
          final newUnreadCount =
              message.isFromMe ? c.unreadCount : c.unreadCount + 1;
          debugPrint(
              '🐛 [LOCAL] updateLastMessage: conversationId=$conversationId, isFromMe=${message.isFromMe}, oldUnread=${c.unreadCount}, newUnread=$newUnreadCount');
          return c.copyWith(
            lastMessage: message.content,
            lastMessageAt: message.createdAt,
            lastActivity: message.createdAt,
            unreadCount: newUnreadCount,
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
  (ref, conversationId) {
    debugPrint(
        '🔍 [PROVIDER] Creating LocalMessagesNotifier for conversationId: "$conversationId"');
    return LocalMessagesNotifier(
      ref.read(localChatServiceProvider),
      conversationId,
      ref,
    );
  },
);

class LocalMessagesNotifier
    extends StateNotifier<AsyncValue<List<LocalMessage>>> {
  final LocalChatService _chatService;
  final String _conversationId;
  final Ref _ref;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize = 50;
  bool _initialSyncTriggered = false;

  LocalMessagesNotifier(this._chatService, this._conversationId, this._ref)
      : super(const AsyncValue.loading()) {
    debugPrint(
        '🔍 [PROVIDER] LocalMessagesNotifier created for conversationId: "$_conversationId"');
    _loadMessages();
  }

  // Modern production pattern: refresh only when needed
  void _watchMessages() {
    debugPrint(
        '🔍 [PROVIDER] _watchMessages() called for conversationId: "$_conversationId"');
    _loadMessages();
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

      debugPrint(
          '🔍 [PROVIDER] _loadMessages: got ${messages.length} messages for "$_conversationId" (loadMore: $loadMore, offset: $offset)');

      if (mounted) {
        // If DB is empty on first open, trigger initial force sync
        if (!_initialSyncTriggered && messages.isEmpty) {
          _initialSyncTriggered = true;
          debugPrint(
              '🔄 [PROVIDER] Messages empty for "$_conversationId" → triggering initial force sync');
          Future.microtask(() async {
            try {
              await _chatService.forceSyncMessagesFromServer(_conversationId);
              await _chatService.fetchLatestFromServer(_conversationId,
                  limit: 20);
              debugPrint(
                  '✅ [PROVIDER] Initial force sync completed for "$_conversationId"');
              // Refresh after sync to show new messages
              _loadMessages();
            } catch (e) {
              debugPrint(
                  '⚠️ Initial force sync failed for $_conversationId: $e');
            }
          });
        }

        if (loadMore) {
          state.whenData((existingMessages) {
            final combined = [...existingMessages, ...messages];
            debugPrint(
                '🔍 [PROVIDER] _loadMessages: combined ${existingMessages.length} + ${messages.length} = ${combined.length} messages');
            state = AsyncValue.data(combined);
          });
        } else {
          debugPrint(
              '🔍 [PROVIDER] _loadMessages: setting state with ${messages.length} messages');
          state = AsyncValue.data(messages);
        }

        _currentOffset = offset + messages.length;
        _hasMore = messages.length >= _pageSize;
        debugPrint(
            '✅ [PROVIDER] _loadMessages completed for "$_conversationId"');
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
    debugPrint(
        '🐛 [DEBUG] sendMessage called at ${startTime.millisecondsSinceEpoch}');

    // 🚀 INSTANT OPTIMISTIC UPDATE - Message appears immediately!
    final currentUser = StorageService.getUser();
    if (currentUser == null) {
      debugPrint('🐛 [DEBUG] No current user, returning early');
      return;
    }

    final userCheckTime = DateTime.now();
    debugPrint(
        '🐛 [DEBUG] User check took: ${userCheckTime.difference(startTime).inMilliseconds}ms');

    // Generate a clientMessageId for deterministic merging/dedupe
    final clientMessageId =
        '${DateTime.now().millisecondsSinceEpoch}_${currentUser['id']}_${const Uuid().v4()}';

    // Create optimistic message with temporary ID
    final optimisticMessage = LocalMessage(
      serverId: null, // Will be set when synced to server
      clientMessageId: clientMessageId, // Attach client-side ID
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
    debugPrint(
        '🐛 [DEBUG] Message creation took: ${messageCreateTime.difference(userCheckTime).inMilliseconds}ms');

    // 🚀 STEP 1: Persist immediately to get a stable localId used for dedupe
    // This will trigger the stream and update the UI instantly
    try {
      await ChatRepositoryService.saveMessage(optimisticMessage);
      debugPrint(
          '🐛 [DEBUG] Optimistic message saved to DB: ${optimisticMessage.id}');

      // 🚀 CRITICAL: Register immediately to prevent real-time duplicates using SINGLETON
      final dispatcher = RealtimeDispatcher.instance;
      // Register both the composite key AND the content for fallback matching
      final messageKey =
          '${optimisticMessage.clientMessageId}_${optimisticMessage.createdAt.microsecondsSinceEpoch}';
      dispatcher.registerRecentlySent(messageKey);
      dispatcher.registerRecentlySent(
          optimisticMessage.content ?? ''); // Content fallback
    } catch (e) {
      debugPrint('🐛 [DEBUG] Failed to save optimistic message locally: $e');
      // If local save fails, mark as failed and return
      if (mounted) {
        state.whenData((messages) {
          final updated = messages.map((msg) {
            if (msg.clientMessageId == optimisticMessage.clientMessageId) {
              return msg.copyWith(readStatus: 'failed');
            }
            return msg;
          }).toList();
          state = AsyncValue.data(updated);
        });
      }
      return;
    }

    // 🚀 STEP 2: Update conversations list INSTANTLY
    _ref
        .read(localConversationsProvider.notifier)
        .updateLastMessage(_conversationId, optimisticMessage);

    // 🚀 STEP 3: Sync to server in background (non-blocking)
    _syncMessageInBackground(optimisticMessage);

    final totalTime = DateTime.now();
    debugPrint(
        '🐛 [DEBUG] ✅ sendMessage COMPLETED in: ${totalTime.difference(startTime).inMilliseconds}ms');
  }

  /// Background operation - doesn't block UI
  Future<void> _syncMessageInBackground(LocalMessage optimisticMessage) async {
    final bgStartTime = DateTime.now();
    debugPrint(
        '🐛 [BACKGROUND] Starting background sync at ${bgStartTime.millisecondsSinceEpoch}');

    // Message already registered earlier to prevent real-time duplicates

    try {
      // Now sync to server
      debugPrint('🐛 [BACKGROUND] Syncing to server...');
      final serverStart = DateTime.now();

      final serverMessage =
          await _chatService.syncMessageToServer(optimisticMessage);

      final serverEnd = DateTime.now();
      debugPrint(
          '🐛 [BACKGROUND] Server sync took: ${serverEnd.difference(serverStart).inMilliseconds}ms');

      // Persist sync state in local DB (replace local optimistic with real serverId)
      // This will trigger the stream and update the UI
      if (serverMessage.serverId != null) {
        // First check if a message with this serverId already exists (from real-time handler)
        final existingServerMessage =
            await ChatRepositoryService.getMessageByServerId(
                serverMessage.serverId!);
        if (existingServerMessage != null) {
          debugPrint(
              '✅ [BACKGROUND] Server message ${serverMessage.serverId} already exists - skipping adoption');
          return; // Server message already processed by real-time handler
        }

        // Check if the optimistic message still exists and needs adoption
        final optimisticStillExists =
            await ChatRepositoryService.getMessage(optimisticMessage.id);
        debugPrint(
            '🔍 [BACKGROUND] Checking optimistic message ${optimisticMessage.id}: serverId=${optimisticStillExists?.serverId}, exists=${optimisticStillExists != null}');

        if (optimisticStillExists?.serverId == null) {
          debugPrint(
              '🔄 [BACKGROUND] Optimistic message needs adoption - proceeding');
          // Only try adoption if the optimistic message still exists and hasn't been adopted yet
          try {
            final adopted =
                await ChatRepositoryService.adoptServerMessage(serverMessage);
            if (adopted) {
              debugPrint(
                  '🔄 [BACKGROUND] Server message adopted into existing optimistic message.');

              // CRITICAL: Refresh the provider state to reflect the adoption
              await _loadMessages(loadMore: false);
              debugPrint(
                  '🔄 [BACKGROUND] Provider state refreshed after message adoption');
            } else {
              // Fallback if adoption failed (e.g., optimistic message was deleted)
              debugPrint(
                  '⚠️ [BACKGROUND] Server message not adopted, will refresh state.');

              // Also refresh state for fallback case
              await _loadMessages(loadMore: false);
            }
          } catch (e) {
            if (e.toString().contains('Unique index violated') ||
                e.toString().contains('already exists')) {
              debugPrint(
                  '✅ [BACKGROUND] Message already adopted by real-time handler - skipping duplicate adoption.');
              // This is expected when real-time handler beats the background sync
              // The message is already properly synced, so we're done
            } else {
              debugPrint('❌ [BACKGROUND] Adoption error: $e');
              // Refresh state anyway to show current data
              await _loadMessages(loadMore: false);
            }
          }
        } else {
          debugPrint(
              '✅ [BACKGROUND] Optimistic message already adopted by real-time handler - skipping background adoption.');
        }
      }

      // The adoptServerMessage method should handle deduplication via clientMessageId matching

      final totalBgTime = DateTime.now();
      debugPrint(
          '🐛 [BACKGROUND] ✅ Background sync completed in: ${totalBgTime.difference(bgStartTime).inMilliseconds}ms');
    } catch (e) {
      debugPrint('🐛 [BACKGROUND] ❌ Background sync FAILED: $e');

      // Mark message as failed for genuine errors
      await ChatRepositoryService.markMessageFailed(
          optimisticMessage.id.toString());
      debugPrint(
          '🚫 Message marked as failed - will not retry: ${optimisticMessage.id}');
    }
  }

  Future<void> loadMore() async {
    await _loadMessages(loadMore: true);
  }

  Future<void> refresh() async {
    _currentOffset = 0;
    _hasMore = true;
    // Instead of manually loading, restart the stream watcher
    // to ensure it reflects the latest database state
    _watchMessages();
  }

  /// Force cleanup of duplicate messages
  Future<void> forceCleanupDuplicates() async {
    try {
      debugPrint('🧹 [PROVIDER] Starting force cleanup of duplicates...');

      // First fix negative ID issue
      await ChatRepositoryService.fixNegativeIdIssue();

      // Then force cleanup duplicates
      await ChatRepositoryService.forceCleanupDuplicates();

      // Refresh the messages after cleanup
      await _loadMessages(loadMore: false);
      debugPrint(
          '🧹 [PROVIDER] Force cleanup completed and messages refreshed');
    } catch (e) {
      debugPrint('❌ [PROVIDER] Force cleanup failed: $e');
    }
  }

  /// Manual cleanup trigger for testing/debugging
  Future<void> manualCleanup() async {
    try {
      debugPrint('🧹 [PROVIDER] Manual cleanup triggered...');
      await forceCleanupDuplicates();
      debugPrint('🧹 [PROVIDER] Manual cleanup completed');
    } catch (e) {
      debugPrint('❌ [PROVIDER] Manual cleanup failed: $e');
    }
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
          debugPrint('❌ Failed to delete message locally: ${message.id} - $e');
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
            debugPrint(
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
      debugPrint('❌ Failed to delete messages: $e');
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
    await ChatRepositoryService.deleteMessage(message.id);

    // CRITICAL: Remove from pending sync queue to prevent reappearing
    final messageId = message.serverId ?? message.id.toString();
    await ChatRepositoryService.removePendingMessage(messageId);

    debugPrint(
        '🗑️ Deleted message locally and removed from pending sync: ${message.id}');
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
    super.dispose();
  }
}

/// Provider for local contacts/users
final localContactsProvider =
    StateNotifierProvider<LocalContactsNotifier, AsyncValue<List<LocalUser>>>(
  (ref) => LocalContactsNotifier(),
);

class LocalContactsNotifier extends StateNotifier<AsyncValue<List<LocalUser>>> {
  LocalContactsNotifier() : super(const AsyncValue.loading()) {
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
      final localResults = await ChatRepositoryService.searchContacts(query);

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
    // DISABLED: Real-time message handling is now done by RealtimeDispatcher
    // This prevents duplicate processing of messages
    // _ref.listen(realtimeMessagesProvider, (prev, next) {
    //   next.whenData((rtMessage) {
    //     try {
    //       final msgJson = rtMessage.message.toJson();
    //       _ref.read(localChatServiceProvider).handleRealtimeMessage(msgJson);
    //     } catch (e) {
    //       // swallow errors to keep stream healthy
    //     }
    //   });
    // });

    // Wire message status updates → update Isar rows (delivered/read)
    _ref.listen(realtimeMessageStatusProvider, (prev, next) {
      next.whenData((statusEvent) async {
        try {
          for (final id in statusEvent.messageIds) {
            await ChatRepositoryService.updateMessageStatus(
              id,
              statusEvent.status == 'read' ? 'read' : 'delivered',
              statusEvent.timestamp,
            );
          }
        } catch (_) {}
      });
    });
  }

  // _handleRealtimeMessage no longer needed; DB-stream handles updates
}

/// Provider for total unread messages count across all conversations
final unreadMessagesCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(localConversationsProvider);

  return conversationsAsync.when(
    data: (conversations) {
      // Sum up unread counts from all conversations
      return conversations.fold<int>(
          0, (total, conversation) => total + conversation.unreadCount);
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for RealtimeDispatcher (Singleton)
final realtimeDispatcherProvider = Provider<RealtimeDispatcher>((ref) {
  final dispatcher = RealtimeDispatcher.instance;
  dispatcher.initialize(ref);
  return dispatcher;
});
