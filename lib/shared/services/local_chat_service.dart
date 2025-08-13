import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/chat_database.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../../core/storage/storage_service.dart';
import 'api_service.dart';
import '../../core/constants/api_constants.dart';
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

    final currentUser = StorageService.getUser();
    if (currentUser == null) {
      throw LocalChatException('User not authenticated');
    }

    final userCheckTime = DateTime.now();

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

    // 🚀 Persist immediately to get a stable localId used for dedupe
    try {
      await ChatDatabase.saveMessage(localMessage);
    } catch (_) {}

    final returnTime = DateTime.now();

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
        return; // Don't rethrow for duplicates
      }
      rethrow;
    }
  }

  /// Sync message to server only (after local save)
  Future<LocalMessage> syncMessageToServer(LocalMessage localMessage) async {
    try {
      String endpoint;
      Map<String, dynamic> data = localMessage.toApiJson();

      // Handle new conversations that don't exist on server yet
      if (localMessage.conversationId.startsWith('new_')) {
        // Extract receiver ID from conversation ID format: 'new_userId'
        final receiverId = localMessage.conversationId.substring(4);

        if (receiverId.isEmpty) {
          throw LocalChatException(
              'Invalid receiver ID extracted from conversation ID: ${localMessage.conversationId}');
        }

        // Use direct message endpoint for new conversations
        endpoint = '/messages';
        data['receiver_id'] = receiverId;
        data.remove(
            'conversation_id'); // Remove conversation_id for direct messages
      } else {
        // Use existing conversation endpoint
        endpoint = '/conversations/${localMessage.conversationId}/messages';
      }

      final response = await _apiService.post(endpoint, data: data);

      final serverMessage = response.data['message'] as Map<String, dynamic>;
      final currentUserId = StorageService.getUser()?['id'];

      // Create a local message from server response
      return LocalMessageExtension.fromApiJson(
        serverMessage,
        isFromMe: serverMessage['sender_id'] == currentUserId,
      );
    } catch (e) {
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
      // Still try to sync to server even if local update failed
      _syncReadStatusToServer(conversationId);
    }
  }

  /// Clean up failed messages from database
  Future<void> cleanupFailedMessages(String conversationId) async {
    try {
      // This would need to be implemented in ChatDatabase
      // For now, just log that we should clean up
      debugPrint(
          '🧹 TODO: Clean up failed messages for conversation: $conversationId');
    } catch (e) {
      debugPrint('Failed to cleanup failed messages: $e');
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
    }
  }

  Future<void> _triggerConversationsSync() async {
    // Run in background without blocking UI
    Future.microtask(() async {
      try {
        await _syncConversationsFromServer();
      } catch (e) {
      }
    });
  }

  /// Public: force sync conversations from server now
  Future<void> syncConversationsNow() async {
    try {
      await _syncConversationsFromServer();
    } catch (e) {
    }
  }

  Future<void> _triggerMessagesSync(String conversationId) async {
    // Run in background without blocking UI
    Future.microtask(() async {
      try {
        await _syncMessagesFromServer(conversationId);
      } catch (e) {
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
        }
      }
    } catch (e) {
      throw LocalChatException('Failed to sync conversations from server: $e');
    }
  }

  /// Force immediate sync of messages from server (for empty conversations)
  Future<void> forceSyncMessagesFromServer(String conversationId) async {

    // Skip sync for new conversations that don't exist on server yet
    if (conversationId.startsWith('new_')) {
      return;
    }

    try {
      // Get last sync time for this conversation based on latest local message
      final lastLocalMessage =
          await ChatDatabase.getLatestMessage(conversationId);
      final lastSyncTime = lastLocalMessage?.createdAt;

      final queryParams = <String, dynamic>{
        'limit': 50, // Default limit
      };

      String path = ApiConstants.getConversationMessages(conversationId);

      if (lastSyncTime != null) {
        // Use cursor-based pagination if we have a last sync time
        queryParams['cursor'] = lastSyncTime.toIso8601String();
        queryParams['loadDirection'] = 'after';
      } else {
        // If no local messages, fetch the first page
        queryParams['page'] = 1;
      }

      // Get messages from API
      final response = await _apiService.get(
        path,
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final messagesList = data['messages'] as List;

      final currentUserId = StorageService.getUser()?['id'];

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
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch latest messages page from server regardless of local cursor
  /// Useful when conversation list shows a newer last message that isn't in local DB
  Future<void> fetchLatestFromServer(String conversationId,
      {int limit = 10}) async {
    // Skip sync for new conversations that don't exist on server yet
    if (conversationId.startsWith('new_')) {
      return;
    }

    try {
      final path = ApiConstants.getConversationMessages(conversationId);
      final response = await _apiService.get(
        path,
        queryParameters: {
          'page': 1,
          'limit': limit,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final messagesList = data['messages'] as List? ?? const [];
      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) return;

      final localMessages = messagesList
          .map((json) => LocalMessageExtension.fromApiJson(
                json,
                isFromMe: json['sender_id'] == currentUserId,
              ))
          .toList();

      await ChatDatabase.saveMessages(localMessages);
    } catch (e) {
      // Swallow errors; this is a best-effort helper
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

      // Only reconcile if we have pending messages to avoid unnecessary work
      final pending =
          await ChatDatabase.getPendingMessagesForConversation(conversationId);
      if (pending.isEmpty) {
        return;
      }


      // STEP 1: Clean up existing duplicates FIRST before syncing more
      await _cleanupDuplicateMessages(conversationId);

      // STEP 1.5: Clean up orphaned messages without clientMessageId
      await _cleanupOrphanedMessages(conversationId);

      // STEP 2: Only sync if we still have pending messages after cleanup
      final remainingPending =
          await ChatDatabase.getPendingMessagesForConversation(conversationId);

      if (remainingPending.isNotEmpty) {

        // Pull a recent window so we can adopt - but catch any unique violations
        try {
          await _syncMessagesFromServer(conversationId,
              limit: 50); // Reduced limit
        } catch (e) {
          if (e.toString().contains('Unique index violated')) {
          } else {
            rethrow;
          }
        }

        // Try adopting each recent server message into any optimistic row
        final recent = await ChatDatabase.getLatestMessages(conversationId,
            limit: 100, offsetFromLatest: 0); // Reduced limit
        for (final m in recent) {
          if (m.serverId != null) {
            try {
              await ChatDatabase.adoptServerMessage(m);
            } catch (e) {
              if (e.toString().contains('Unique index violated')) {
                // Skip if already exists
                continue;
              }
            }
          }
        }

        // STEP 3: Clean up again after sync in case new duplicates were created
        await _cleanupDuplicateMessages(conversationId);
      } else {
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

    } catch (e) {
    }
  }

  /// Clean up duplicate messages with same content in a conversation
  /// Keep only the best version: delivered > sent > failed > sending
  Future<void> _cleanupDuplicateMessages(String conversationId) async {
    try {
      final allMessages =
          await ChatDatabase.getLatestMessages(conversationId, limit: 200);

      // Group messages by content and sender
      final Map<String, List<LocalMessage>> messageGroups = {};

      for (final message in allMessages) {
        if (message.content?.trim().isNotEmpty == true) {
          final key = '${message.senderId}_${message.content?.trim()}';
          messageGroups[key] ??= [];
          messageGroups[key]!.add(message);
        }
      }

      // For each group with multiple messages, keep only the best one
      for (final group in messageGroups.values) {
        if (group.length > 1) {

          // Sort by priority: delivered > sent > failed > sending
          group.sort((a, b) {
            final aPriority = _getMessagePriority(a);
            final bPriority = _getMessagePriority(b);
            if (aPriority != bPriority) {
              return bPriority.compareTo(aPriority); // Higher priority first
            }
            // If same priority, prefer newer messages
            return b.createdAt.compareTo(a.createdAt);
          });

          // Keep the first (highest priority), delete the rest
          final toKeep = group.first;
          final toDelete = group.skip(1).toList();


          for (final duplicate in toDelete) {
            await ChatDatabase.deleteMessage(duplicate.id.toString());
          }
        }
      }
    } catch (e) {
    }
  }

  /// Get priority for message status (higher = better)
  int _getMessagePriority(LocalMessage message) {
    // Prefer messages with serverId (synced to server)
    if (message.serverId != null) {
      switch (message.readStatus) {
        case 'read':
          return 100;
        case 'delivered':
          return 90;
        case 'sent':
          return 80;
        default:
          return 70;
      }
    } else {
      // Local-only messages
      // CRITICAL: Old messages without clientMessageId should be deprioritized
      if (message.clientMessageId == null) {
        switch (message.readStatus) {
          case 'failed':
            return 2; // Very low priority
          case 'sending':
            return 1; // Lowest priority (likely orphaned)
          default:
            return 0;
        }
      } else {
        // Newer messages with clientMessageId
        switch (message.readStatus) {
          case 'failed':
            return 20;
          case 'sending':
            return 10;
          default:
            return 5;
        }
      }
    }
  }

  /// Clean up orphaned messages without clientMessageId that are stuck in "sending"
  Future<void> _cleanupOrphanedMessages(String conversationId) async {
    try {
      final allMessages =
          await ChatDatabase.getLatestMessages(conversationId, limit: 200);

      // Find old messages without clientMessageId that are stuck
      final orphaned = allMessages
          .where((message) =>
                  message.clientMessageId == null &&
                  message.serverId == null &&
                  message.readStatus == 'sending' &&
                  DateTime.now().difference(message.createdAt).inMinutes >
                      2 // Older than 2 minutes
              )
          .toList();

      if (orphaned.isNotEmpty) {

        for (final orphan in orphaned) {
          await ChatDatabase.markMessageFailed(orphan.id.toString());
        }
      }
    } catch (e) {
    }
  }

  /// Manual cleanup for testing - can be called directly
  Future<void> manualCleanupDuplicates(String conversationId) async {
    await _cleanupDuplicateMessages(conversationId);
    await _cleanupOrphanedMessages(conversationId);
  }

  /// Delete single message on server
  Future<void> deleteMessageOnServer(
      String messageId, String conversationId) async {
    try {
      await _apiService
          .delete('/conversations/$conversationId/messages/$messageId');
    } catch (e) {
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

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _syncMessagesFromServer(String conversationId,
      {int limit = 50}) async {
    // Skip sync for new conversations that don't exist on server yet
    if (conversationId.startsWith('new_')) {
      return;
    }

    try {
      // Get last sync time for this conversation based on latest local message
      // This prevents the server from re-sending messages we already have locally
      final lastSyncTime = await _getLastMessageSyncTime(conversationId);

      // Backend expects page/limit by default, or cursor + loadDirection for incremental loads
      final queryParams = <String, dynamic>{
        'limit': limit,
        'page': 1,
      };

      if (lastSyncTime != null) {
        queryParams.remove('page');
        queryParams['cursor'] = lastSyncTime.toIso8601String();
        queryParams['loadDirection'] = 'after';
      }

      // Get messages from API
      final response = await _apiService.get(
        ApiConstants.getConversationMessages(conversationId),
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final messagesList =
          (data['messages'] ?? data['data'] ?? data['items'] ?? []) as List;

      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) return;

      // Convert and save to local database
      final localMessages = messagesList
          .map((json) => LocalMessageExtension.fromApiJson(
                json,
                isFromMe: currentUserId != null
                    ? json['sender_id'] == currentUserId
                    : false,
              ))
          .toList();

      // Save all messages with error handling
      try {
        await ChatDatabase.saveMessages(localMessages);
      } catch (e) {
        // Skip duplicate messages instead of crashing
        // Try saving individual messages to identify which ones are duplicates
        for (final message in localMessages) {
          try {
            await ChatDatabase.saveMessage(message);
          } catch (duplicateError) {
            // Skip this specific message
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
      String endpoint;
      Map<String, dynamic> data = message.toApiJson();

      // Handle new conversations that don't exist on server yet
      if (message.conversationId.startsWith('new_')) {
        // Extract receiver ID from conversation ID format: 'new_userId'
        final receiverId = message.conversationId.substring(4);

        if (receiverId.isEmpty) {
          throw LocalChatException(
              'Invalid receiver ID extracted from conversation ID: ${message.conversationId}');
        }

        // Use direct message endpoint for new conversations
        endpoint = '/messages';
        data['receiver_id'] = receiverId;
        data.remove(
            'conversation_id'); // Remove conversation_id for direct messages

      } else {
        // Use existing conversation endpoint
        endpoint = '/conversations/${message.conversationId}/messages';
      }

      // Send to server with timeout to prevent hanging
      final response = await _apiService
          .post(endpoint, data: data)
          .timeout(const Duration(seconds: 10));

      final serverMessage = response.data['message'] as Map<String, dynamic>;

      // Update local message with server ID and mark as synced
      await ChatDatabase.markMessageSynced(
        message.id.toString(),
        serverMessage['id'],
      );

    } catch (e) {

      // 🔥 CRITICAL: Mark failed explicitly to stop infinite retries
      await ChatDatabase.markMessageFailed(message.id.toString());
      // Don't rethrow - we handled the failure by marking it as "failed"
    }
  }

  Future<void> _syncPendingMessages() async {
    try {
      // Throttle sync calls to prevent loops
      final now = DateTime.now();
      if (_lastSyncTime != null &&
          now.difference(_lastSyncTime!) < _syncThrottleDelay) {
        return;
      }
      _lastSyncTime = now;

      final pendingMessages = await ChatDatabase.getPendingSyncMessages();

      // STOP: Don't sync if there are too many pending messages (indicates a loop)
      if (pendingMessages.length > 20) {
        return;
      }

      // Limit to prevent infinite loops
      final messagesToSync =
          pendingMessages.take(5).toList(); // Reduced from 10 to 5

      if (messagesToSync.isEmpty) {
        return; // No messages to sync
      }

      for (final message in messagesToSync) {
        // Sync message - failures are now handled inside _syncMessageToServer
        await _syncMessageToServer(message);
      }
    } catch (e) {
    }
  }

  Future<void> _syncReadStatusToServer(String conversationId) async {
    try {
      // Skip sync for new conversations that don't exist on server yet
      if (conversationId.startsWith('new_')) {
        return;
      }

      await _apiService.put('/conversations/$conversationId/mark-read');
    } catch (e) {
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
    }
  }

  // ========== REACTIONS ==========

  /// Toggle a reaction on server and return the updated reactions map
  Future<Map<String, dynamic>> toggleReactionOnServer(
      String messageServerId, String emoji) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.messages}/$messageServerId/reactions',
        data: {'emoji': emoji},
      );
      final reactions = response.data['reactions'] as Map<String, dynamic>;
      return reactions;
    } catch (e) {
      throw LocalChatException('Failed to toggle reaction: $e');
    }
  }

  /// Sync existing reactions from server for specific messages
  /// This is called when chat page loads to ensure reactions are visible
  Future<void> syncMessageReactions(
      String conversationId, List<String> messageIds) async {
    try {
      if (messageIds.isEmpty) return;

      // Skip sync for new conversations that don't exist on server yet
      if (conversationId.startsWith('new_')) {
        debugPrint(
            '🔄 Skipping reaction sync for new conversation: $conversationId');
        return;
      }

      debugPrint(
          '🔄 [REACTION SYNC] Fetching reactions for ${messageIds.length} messages from server');

      // Fetch message data with reactions from server
      final response = await _apiService.post(
        '${ApiConstants.conversations}/$conversationId/messages/reactions',
        data: {'messageIds': messageIds},
      );

      final messagesWithReactions = response.data['messages'] as List<dynamic>;
      debugPrint(
          '🔄 [REACTION SYNC] Received ${messagesWithReactions.length} messages with reactions');

      // Update each message's reactions in local database
      for (final messageData in messagesWithReactions) {
        final messageId = messageData['id'] as String;
        final reactions = messageData['reactions'] as Map<String, dynamic>?;

        if (reactions != null && reactions.isNotEmpty) {
          debugPrint(
              '🔄 [REACTION SYNC] Updating reactions for message $messageId');
          await ChatDatabase.updateMessageReactions(
            serverId: messageId,
            reactionsJson: jsonEncode(reactions),
          );
        }
      }

      debugPrint(
          '✅ [REACTION SYNC] Successfully synced reactions for ${messagesWithReactions.length} messages');
    } catch (e) {
      debugPrint('❌ [REACTION SYNC] Failed to sync message reactions: $e');
      // Don't rethrow - this is a background sync operation
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
