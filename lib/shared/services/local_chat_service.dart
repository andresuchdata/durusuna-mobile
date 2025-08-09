import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/chat_database.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../../core/storage/storage_service.dart';
import 'api_service.dart';
import 'realtime_service.dart';

/// Local-first chat service that provides instant loading and background sync
/// Similar to WhatsApp's architecture
class LocalChatService {
  final ApiService _apiService;
  final RealtimeService _realtimeService; // Reserved for future realtime acks

  // Background sync controller
  Timer? _syncTimer;
  bool _isInitialSyncComplete = false;

  // Sync throttling to prevent loops
  DateTime? _lastSyncTime;
  static const _syncThrottleDelay = Duration(seconds: 10);

  LocalChatService(this._apiService, this._realtimeService) {
    _initialize();
  }

  Future<void> _initialize() async {
    await ChatDatabase.initialize();
    // Touch realtime service so the field is considered used and ensure it's ready
    try {
      if (_realtimeService.canConnect) {
        // no-op: LocalChatService does not manage connection lifecycle
      }
    } catch (_) {}
    _startBackgroundSync();
  }

  // ========== INSTANT LOCAL OPERATIONS ==========

  /// Get conversations instantly from local database
  Future<List<LocalConversation>> getConversations() async {
    try {
      // Get from local database instantly
      final conversations = await ChatDatabase.getConversations();

      // Trigger background sync if needed
      if (!_isInitialSyncComplete) {
        _triggerConversationsSync();
      }

      return conversations;
    } catch (e) {
      throw LocalChatException('Failed to load conversations locally: $e');
    }
  }

  /// Get messages instantly from local database
  Future<List<LocalMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // If requesting the first page, pull latest N messages to ensure newest appear
      final messages = offset == 0
          ? await ChatDatabase.getLatestMessages(
              conversationId,
              limit: limit,
              offsetFromLatest: 0,
            )
          : await ChatDatabase.getMessages(
              conversationId,
              limit: limit,
              offset: offset,
            );

      // Trigger background sync for this conversation
      _triggerMessagesSync(conversationId);

      return messages;
    } catch (e) {
      throw LocalChatException('Failed to load messages locally: $e');
    }
  }

  /// Send message with optimistic update (appears instantly)
  Future<LocalMessage> sendMessage({
    required String conversationId,
    required String content,
    LocalMessageType messageType = LocalMessageType.text,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    final serviceStartTime = DateTime.now();
    print(
        '🐛 [SERVICE] LocalChatService.sendMessage called at ${serviceStartTime.millisecondsSinceEpoch}');

    final currentUser = StorageService.getUser();
    if (currentUser == null) {
      print('🐛 [SERVICE] No authenticated user found');
      throw LocalChatException('User not authenticated');
    }

    final userCheckTime = DateTime.now();
    print(
        '🐛 [SERVICE] User auth check took: ${userCheckTime.difference(serviceStartTime).inMilliseconds}ms');

    // Create local message instantly
    // Generate a clientMessageId for deterministic merging/dedupe
    final clientMessageId =
        '${DateTime.now().millisecondsSinceEpoch}_${currentUser['id']}_${content.hashCode}';

    final localMessage = LocalMessage(
      conversationId: conversationId,
      senderId: currentUser['id'],
      content: content,
      messageType: messageType,
      replyToId: replyToId,
      createdAt: DateTime.now(),
      isFromMe: true,
      isSynced: false, // Will be synced in background
      clientMessageId: clientMessageId,
      metadataJson: metadata != null ? jsonEncode(metadata) : null,
    );

    final messageCreateTime = DateTime.now();
    print(
        '🐛 [SERVICE] LocalMessage creation took: ${messageCreateTime.difference(userCheckTime).inMilliseconds}ms');

    // 🚀 Persist immediately to get a stable localId used for dedupe
    try {
      await ChatDatabase.saveMessage(localMessage);
    } catch (_) {}

    final returnTime = DateTime.now();
    print(
        '🐛 [SERVICE] ✅ Returning message instantly after: ${returnTime.difference(serviceStartTime).inMilliseconds}ms');

    // Return the persisted message (has local id)
    return localMessage;
  }

  /// Save message to database and sync to server in background
  // _saveMessageInBackground removed; we persist immediately in send flow

  /// Search messages locally (instant results)
  Future<List<LocalMessage>> searchMessages(
    String query, {
    String? conversationId,
  }) async {
    try {
      return await ChatDatabase.searchMessages(
        query,
        conversationId: conversationId,
      );
    } catch (e) {
      throw LocalChatException('Failed to search messages: $e');
    }
  }

  /// Save message to local database only (for optimistic updates)
  Future<void> saveMessageLocally(LocalMessage message) async {
    try {
      await ChatDatabase.saveMessage(message);
      // Update conversation's last message
      await ChatDatabase.updateConversationLastMessage(
        message.conversationId,
        message,
      );
    } catch (e) {
      if (e.toString().contains('Unique index violated')) {
        // Duplicate message, this is ok - just log and continue
        print(
            '🐛 [SERVICE] Duplicate message detected during local save: ${message.serverId}');
        return; // Don't rethrow for duplicates
      }
      print('Failed to save message locally: $e');
      rethrow;
    }
  }

  /// Sync message to server only (after local save)
  Future<LocalMessage> syncMessageToServer(LocalMessage localMessage) async {
    try {
      final response = await _apiService.post(
        '/conversations/${localMessage.conversationId}/messages',
        data: localMessage.toApiJson(),
      );

      final serverMessage = response.data['message'] as Map<String, dynamic>;
      final currentUserId = StorageService.getUser()?['id'];

      // Create a local message from server response
      return LocalMessageExtension.fromApiJson(
        serverMessage,
        isFromMe: serverMessage['sender_id'] == currentUserId,
      );
    } catch (e) {
      print('Failed to sync message to server: $e');
      // Mark failed and rethrow to allow caller to decide UI handling
      try {
        await ChatDatabase.markMessageFailed(localMessage.id.toString());
      } catch (_) {}
      rethrow;
    }
  }

  /// Mark conversation as read locally (instant)
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      // Update locally instantly
      await ChatDatabase.markConversationAsRead(conversationId);

      // Sync to server in background
      _syncReadStatusToServer(conversationId);
    } catch (e) {
      // Just log the error instead of throwing to avoid crashes
      print('Failed to mark conversation as read: $e');
      // Still try to sync to server even if local update failed
      _syncReadStatusToServer(conversationId);
    }
  }

  /// Get contacts (placeholder for now - will use cached data later)
  Future<List<dynamic>> getContacts() async {
    try {
      // For now, return empty list - this will be implemented with proper contact caching
      return [];
    } catch (e) {
      throw LocalChatException('Failed to get contacts: $e');
    }
  }

  // ========== BACKGROUND SYNC OPERATIONS ==========

  void _startBackgroundSync() {
    // 🚫 DISABLED: Temporarily stop background sync to prevent message loops
    print('⚠️ Background sync DISABLED to stop pending message loops');
    return;
  }

  Future<void> _performInitialSync() async {
    try {
      // Sync conversations first
      await _syncConversationsFromServer();

      // Sync recent messages for each conversation
      final conversations = await ChatDatabase.getConversations();
      for (final conversation in conversations.take(10)) {
        // Sync top 10 conversations
        await _syncMessagesFromServer(conversation.serverId, limit: 50);
      }

      _isInitialSyncComplete = true;
    } catch (e) {
      // Log error but don't block app
      print('Initial sync failed: $e');
    }
  }

  Future<void> _performBackgroundSync() async {
    try {
      // Sync unsent messages first
      await _syncPendingMessages();

      // Sync new messages from server
      await _syncNewMessagesFromServer();

      // Sync conversation updates (disabled - endpoint doesn't exist on backend)
      // await _syncConversationUpdatesFromServer();
    } catch (e) {
      // Log error but don't block app
      print('Background sync failed: $e');
    }
  }

  Future<void> _triggerConversationsSync() async {
    // Run in background without blocking UI
    Future.microtask(() async {
      try {
        await _syncConversationsFromServer();
      } catch (e) {
        print('Conversations sync failed: $e');
      }
    });
  }

  Future<void> _triggerMessagesSync(String conversationId) async {
    // Run in background without blocking UI
    Future.microtask(() async {
      try {
        await _syncMessagesFromServer(conversationId);
      } catch (e) {
        print('Messages sync failed for $conversationId: $e');
      }
    });
  }

  Future<void> _syncConversationsFromServer() async {
    try {
      // Get conversations from API
      final response = await _apiService.get('/conversations');
      final data = response.data as Map<String, dynamic>;
      final conversationsList = data['conversations'] as List;

      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) return;

      // Convert and save to local database
      final localConversations = conversationsList
          .map((json) =>
              LocalConversationExtension.fromApiJson(json, currentUserId))
          .toList();

      // Save all conversations with error handling
      for (final conversation in localConversations) {
        try {
          await ChatDatabase.saveConversation(conversation);
        } catch (e) {
          // Skip duplicate conversations instead of crashing
          print(
              'Skipping duplicate conversation: ${conversation.serverId} - $e');
        }
      }
    } catch (e) {
      throw LocalChatException('Failed to sync conversations from server: $e');
    }
  }

  /// Force immediate sync of messages from server (for empty conversations)
  Future<void> forceSyncMessagesFromServer(String conversationId) async {
    print(
        '🔄 Force syncing messages from server for conversation: $conversationId');
    await _syncMessagesFromServer(conversationId, limit: 50);

    // Reconcile pending locals against the newly fetched window
    try {
      final pending =
          await ChatDatabase.getPendingMessagesForConversation(conversationId);
      if (pending.isEmpty) return;

      // Attempt tolerant match with existing server rows by content + ~5s time proximity
      final latest = await ChatDatabase.getLatestMessages(conversationId,
          limit: 200, offsetFromLatest: 0);

      for (final p in pending) {
        final match = latest.firstWhere(
          (m) =>
              m.serverId != null &&
              m.isFromMe == p.isFromMe &&
              (m.content ?? '') == (p.content ?? '') &&
              (m.createdAt.difference(p.createdAt).abs().inSeconds <= 5),
          orElse: () => p,
        );

        if (!identical(match, p) && match.serverId != null) {
          // Merge: assign serverId to local pending and mark synced
          await ChatDatabase.markMessageSynced(
              p.id.toString(), match.serverId!);
        }
      }
    } catch (e) {
      print('⚠️ Reconcile after forceSync failed: $e');
    }
  }

  /// Reconcile pending items when opening a chat: adopt server copies, fail stale
  Future<void> reconcilePendingOnOpen(String conversationId,
      {Duration staleAfter = const Duration(seconds: 45)}) async {
    try {
      // DEBUG: Check what conversation IDs exist in database
      final allMessages = await ChatDatabase.getAllMessages();
      final uniqueConversationIds =
          allMessages.map((m) => m.conversationId).toSet();
      print(
          '🔍 [DEBUG] All conversation IDs in database: $uniqueConversationIds');
      print('🔍 [DEBUG] Looking for conversationId: "$conversationId"');

      // Only reconcile if we have pending messages to avoid unnecessary work
      final pending =
          await ChatDatabase.getPendingMessagesForConversation(conversationId);
      if (pending.isEmpty) {
        print('🔄 No pending messages to reconcile for $conversationId');
        return;
      }

      print(
          '🔄 Reconciling ${pending.length} pending messages for $conversationId');

      // Pull a recent window so we can adopt - but catch any unique violations
      try {
        await _syncMessagesFromServer(conversationId, limit: 100);
      } catch (e) {
        if (e.toString().contains('Unique index violated')) {
          print(
              'ℹ️ Some messages already exist during reconcile sync - continuing');
        } else {
          rethrow;
        }
      }

      // Try adopting each recent server message into any optimistic row
      final recent = await ChatDatabase.getLatestMessages(conversationId,
          limit: 200, offsetFromLatest: 0);
      for (final m in recent) {
        if (m.serverId != null) {
          try {
            await ChatDatabase.adoptServerMessage(m);
          } catch (e) {
            if (e.toString().contains('Unique index violated')) {
              // Skip if already exists
              continue;
            }
            print('⚠️ Failed to adopt message ${m.serverId}: $e');
          }
        }
      }

      // Any remaining pending older than threshold become failed
      final stillPending =
          await ChatDatabase.getPendingMessagesForConversation(conversationId);
      final now = DateTime.now();
      for (final p in stillPending) {
        if (now.difference(p.createdAt) > staleAfter) {
          await ChatDatabase.markMessageFailed(p.id.toString());
        }
      }

      print('🔄 Reconcile completed for $conversationId');
    } catch (e) {
      print('⚠️ reconcilePendingOnOpen failed: $e');
    }
  }

  /// Delete single message on server
  Future<void> deleteMessageOnServer(
      String messageId, String conversationId) async {
    try {
      await _apiService
          .delete('/conversations/$conversationId/messages/$messageId');
      print('✅ Message deleted on server: $messageId');
    } catch (e) {
      print('❌ Failed to delete message on server: $e');
      rethrow;
    }
  }

  /// Delete multiple messages on server (batch)
  Future<Map<String, dynamic>> deleteBatchMessagesOnServer(
      List<String> messageIds, String conversationId) async {
    try {
      final response = await _apiService.delete(
        '/conversations/$conversationId/messages/batch',
        data: {
          'message_ids': messageIds,
        },
      );

      final result = response.data as Map<String, dynamic>;
      print(
          '✅ Batch delete response: ${result['deleted_count']} deleted, ${result['failed_count']} failed');

      return result;
    } catch (e) {
      print('❌ Failed to delete batch messages on server: $e');
      rethrow;
    }
  }

  Future<void> _syncMessagesFromServer(String conversationId,
      {int limit = 50}) async {
    try {
      // Get last sync time for this conversation based on latest local message
      // This prevents the server from re-sending messages we already have locally
      final lastSyncTime = await _getLastMessageSyncTime(conversationId);

      final queryParams = <String, dynamic>{
        'limit': limit,
      };

      if (lastSyncTime != null) {
        queryParams['after'] = lastSyncTime.toIso8601String();
      }

      // Get messages from API
      final response = await _apiService.get(
        '/conversations/$conversationId/messages',
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final messagesList = data['messages'] as List;

      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) return;

      // Convert and save to local database
      final localMessages = messagesList
          .map((json) => LocalMessageExtension.fromApiJson(
                json,
                isFromMe: json['sender_id'] == currentUserId,
              ))
          .toList();

      // Save all messages with error handling
      try {
        await ChatDatabase.saveMessages(localMessages);
      } catch (e) {
        // Skip duplicate messages instead of crashing
        print('Some messages already exist, skipping duplicates: $e');
        // Try saving individual messages to identify which ones are duplicates
        for (final message in localMessages) {
          try {
            await ChatDatabase.saveMessage(message);
          } catch (duplicateError) {
            // Skip this specific message
            print('Skipping duplicate message: ${message.serverId}');
          }
        }
      }

      // No explicit last-sync persistence needed since we derive it from DB
    } catch (e) {
      throw LocalChatException('Failed to sync messages from server: $e');
    }
  }

  Future<void> _syncMessageToServer(LocalMessage message) async {
    try {
      // Send to server with timeout to prevent hanging
      final response = await _apiService
          .post(
            '/conversations/${message.conversationId}/messages',
            data: message.toApiJson(),
          )
          .timeout(const Duration(seconds: 10));

      final serverMessage = response.data['message'] as Map<String, dynamic>;

      // Update local message with server ID and mark as synced
      await ChatDatabase.markMessageSynced(
        message.id.toString(),
        serverMessage['id'],
      );

      print('✅ Message synced successfully: ${serverMessage['id']}');
    } catch (e) {
      print('❌ Failed to sync message to server: $e');

      // 🔥 CRITICAL: Mark failed explicitly to stop infinite retries
      await ChatDatabase.markMessageFailed(message.id.toString());
      print('🚫 Message marked as failed - will not retry: ${message.id}');
      // Don't rethrow - we handled the failure by marking it as "failed"
    }
  }

  Future<void> _syncPendingMessages() async {
    try {
      // Throttle sync calls to prevent loops
      final now = DateTime.now();
      if (_lastSyncTime != null &&
          now.difference(_lastSyncTime!) < _syncThrottleDelay) {
        print(
            '⏳ Sync throttled - last sync was ${now.difference(_lastSyncTime!).inSeconds}s ago');
        return;
      }
      _lastSyncTime = now;

      final pendingMessages = await ChatDatabase.getPendingSyncMessages();

      // STOP: Don't sync if there are too many pending messages (indicates a loop)
      if (pendingMessages.length > 20) {
        print(
            '⚠️ Too many pending messages (${pendingMessages.length}) - stopping sync to prevent loops');
        return;
      }

      // Limit to prevent infinite loops
      final messagesToSync =
          pendingMessages.take(5).toList(); // Reduced from 10 to 5
      print('🔄 Syncing ${messagesToSync.length} pending messages');

      if (messagesToSync.isEmpty) {
        return; // No messages to sync
      }

      for (final message in messagesToSync) {
        // Sync message - failures are now handled inside _syncMessageToServer
        await _syncMessageToServer(message);
      }
    } catch (e) {
      print('Failed to sync pending messages: $e');
    }
  }

  Future<void> _syncReadStatusToServer(String conversationId) async {
    try {
      await _apiService.put('/conversations/$conversationId/mark-read');
    } catch (e) {
      print('Failed to sync read status to server: $e');
    }
  }

  Future<void> _syncNewMessagesFromServer() async {
    try {
      final conversations = await ChatDatabase.getConversations();

      // Check for new messages in active conversations
      for (final conversation in conversations.take(5)) {
        await _syncMessagesFromServer(conversation.serverId, limit: 10);
      }
    } catch (e) {
      print('Failed to sync new messages from server: $e');
    }
  }

  // _syncConversationUpdatesFromServer disabled

  // ========== HELPER METHODS ==========

  Future<DateTime?> _getLastMessageSyncTime(String conversationId) async {
    try {
      // Use the latest local message timestamp as the watermark
      final latest = await ChatDatabase.getLatestMessage(conversationId);
      return latest?.createdAt;
    } catch (_) {
      return null;
    }
  }

  // _updateLastMessageSyncTime not used; watermark derived from DB

  // ========== REAL-TIME INTEGRATION ==========

  void handleRealtimeMessage(Map<String, dynamic> messageData) {
    // Handle incoming real-time messages
    Future.microtask(() async {
      try {
        final currentUserId = StorageService.getUser()?['id'];
        if (currentUserId == null) return;

        final localMessage = LocalMessageExtension.fromApiJson(
          messageData,
          isFromMe: messageData['sender_id'] == currentUserId,
        );

        // First try to adopt into an existing optimistic local row
        final adopted = await ChatDatabase.adoptServerMessage(localMessage);
        if (!adopted) {
          // Fallback saved by adoptServerMessage already if not adopted
        }

        // Update conversation
        await ChatDatabase.updateConversationLastMessage(
          localMessage.conversationId,
          localMessage,
          unreadCount:
              localMessage.isFromMe ? null : 1, // Increment if not from me
        );

        // Immediately acknowledge delivery so sender status updates
        if (!localMessage.isFromMe && localMessage.serverId != null) {
          try {
            _realtimeService.markAsDelivered([localMessage.serverId!]);
          } catch (_) {}
        }
      } catch (e) {
        print('Failed to handle real-time message: $e');
      }
    });
  }

  // ========== CLEANUP ==========

  void dispose() {
    _syncTimer?.cancel();
  }
}

class LocalChatException implements Exception {
  final String message;
  LocalChatException(this.message);

  @override
  String toString() => 'LocalChatException: $message';
}

// Provider for LocalChatService
final localChatServiceProvider = Provider<LocalChatService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  final realtimeService = ref.read(realtimeServiceProvider);
  return LocalChatService(apiService, realtimeService);
});
