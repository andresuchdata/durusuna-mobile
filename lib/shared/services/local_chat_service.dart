import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/repository_factory.dart';
import '../services/chat_repository_service.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../../core/storage/storage_service.dart';
import 'api_service.dart';
import '../../core/constants/api_constants.dart';
import 'realtime_service.dart';
import '../providers/local_chat_providers.dart';

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
    // Initialize repository factory if not already done
    if (!RepositoryFactory.isInitialized) {
      try {
        await RepositoryFactory.initialize(preferSQLite: true);
        debugPrint(
            '✅ [LocalChatService] Repository factory initialized successfully');
      } catch (e) {
        debugPrint(
            '❌ [LocalChatService] Failed to initialize repository factory: $e');
        // Don't rethrow - let the service continue without repository for now
        return;
      }
    }
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
      final conversations = await ChatRepositoryService.getConversations();

      // Trigger background sync if needed
      if (!_isInitialSyncComplete) {
        _triggerConversationsSync();
      }

      return conversations;
    } catch (e) {
      debugPrint('❌ [LocalChatService] Failed to get conversations: $e');
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
          ? await ChatRepositoryService.getLatestMessages(
              conversationId,
              limit: limit,
              offsetFromLatest: 0,
            )
          : await ChatRepositoryService.getMessages(
              conversationId,
              limit: limit,
              offset: offset,
            );

      // Trigger background sync for this conversation
      _triggerMessagesSync(conversationId);

      return messages;
    } catch (e) {
      debugPrint('❌ [LocalChatService] Failed to get messages: $e');
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
    debugPrint(
        '🐛 [SERVICE] LocalChatService.sendMessage called at ${serviceStartTime.millisecondsSinceEpoch}');

    final currentUser = StorageService.getUser();
    if (currentUser == null) {
      debugPrint('🐛 [SERVICE] No authenticated user found');
      throw LocalChatException('User not authenticated');
    }

    final userCheckTime = DateTime.now();
    debugPrint(
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
    debugPrint(
        '🐛 [SERVICE] LocalMessage creation took: ${messageCreateTime.difference(userCheckTime).inMilliseconds}ms');

    // 🚀 Persist immediately to get a stable localId used for dedupe
    try {
      await ChatRepositoryService.saveMessage(localMessage);
    } catch (_) {}

    final returnTime = DateTime.now();
    debugPrint(
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
      return await ChatRepositoryService.searchMessages(query);
    } catch (e) {
      throw LocalChatException('Failed to search messages: $e');
    }
  }

  /// Save message to local database only (for optimistic updates)
  Future<void> saveMessageLocally(LocalMessage message) async {
    try {
      await ChatRepositoryService.saveMessage(message);
      // Update conversation's last message
      await ChatRepositoryService.updateConversationLastMessage(
        message.conversationId,
        message,
      );
    } catch (e) {
      if (e.toString().contains('Unique index violated')) {
        // Duplicate message, this is ok - just log and continue
        debugPrint(
            '🐛 [SERVICE] Duplicate message detected during local save: ${message.serverId}');
        return; // Don't rethrow for duplicates
      }
      debugPrint('Failed to save message locally: $e');
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
      debugPrint('Failed to sync message to server: $e');
      // Mark failed and rethrow to allow caller to decide UI handling
      try {
        await ChatRepositoryService.markMessageFailed(
            localMessage.id.toString());
      } catch (_) {}
      rethrow;
    }
  }

  /// Mark conversation as read locally (instant)
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      // Update locally instantly
      await ChatRepositoryService.markConversationAsRead(conversationId);

      // Sync to server in background
      _syncReadStatusToServer(conversationId);
    } catch (e) {
      // Just log the error instead of throwing to avoid crashes
      debugPrint('Failed to mark conversation as read: $e');
      // Still try to sync to server even if local update failed
      _syncReadStatusToServer(conversationId);
    }
  }

  /// Clean up failed messages from database
  Future<void> cleanupFailedMessages(String conversationId) async {
    try {
      // This would need to be implemented in the repository
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
    debugPrint('⚠️ Background sync DISABLED to stop pending message loops');
    return;
  }

  Future<void> _performInitialSync() async {
    try {
      // Sync conversations first
      await _syncConversationsFromServer();

      // Sync recent messages for each conversation
      final conversations = await ChatRepositoryService.getConversations();
      for (final conversation in conversations.take(10)) {
        // Sync top 10 conversations
        await _syncMessagesFromServer(conversation.serverId, limit: 50);
      }

      _isInitialSyncComplete = true;
    } catch (e) {
      // Log error but don't block app
      debugPrint('Initial sync failed: $e');
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
      debugPrint('Background sync failed: $e');
    }
  }

  Future<void> _triggerConversationsSync() async {
    // Run in background without blocking UI
    Future.microtask(() async {
      try {
        await _syncConversationsFromServer();
      } catch (e) {
        debugPrint('Conversations sync failed: $e');
      }
    });
  }

  /// Public: force sync conversations from server now
  Future<void> syncConversationsNow() async {
    try {
      await _syncConversationsFromServer();
    } catch (e) {
      debugPrint('Conversations sync failed: $e');
    }
  }

  Future<void> _triggerMessagesSync(String conversationId) async {
    // Run in background without blocking UI
    Future.microtask(() async {
      try {
        await _syncMessagesFromServer(conversationId);
      } catch (e) {
        debugPrint('Messages sync failed for $conversationId: $e');
      }
    });
  }

  Future<void> _syncConversationsFromServer() async {
    try {
      // Get conversations from API
      debugPrint('🌐 [CONVERSATIONS] Fetching conversations from server...');
      final response = await _apiService.get('/conversations');
      final data = response.data as Map<String, dynamic>;
      final conversationsList = data['conversations'] as List;
      debugPrint(
          '🌐 [CONVERSATIONS] Server returned ${conversationsList.length} conversations');

      final currentUserId = StorageService.getUser()?['id'];
      debugPrint('🌐 [CONVERSATIONS] Current user ID: $currentUserId');

      // Convert and save to local database
      final localConversations = conversationsList.map((json) {
        debugPrint('🌐 [CONVERSATIONS] Processing conversation JSON: $json');
        return LocalConversationExtension.fromApiJson(json, currentUserId);
      }).toList();
      debugPrint(
          '🌐 [CONVERSATIONS] Converted ${localConversations.length} conversations to local format');

      // Save all conversations with error handling
      int saved = 0;
      int skipped = 0;
      for (final conversation in localConversations) {
        try {
          await ChatRepositoryService.saveConversation(conversation);
          saved++;
          debugPrint(
              '✅ [CONVERSATIONS] Saved: ${conversation.serverId} (${conversation.displayName})');
        } catch (e) {
          // Skip duplicate conversations instead of crashing
          skipped++;
          debugPrint(
              '⚠️ [CONVERSATIONS] Skipping duplicate conversation: ${conversation.serverId} - $e');
        }
      }
      debugPrint(
          '📊 [CONVERSATIONS] Sync complete: $saved saved, $skipped skipped');
    } catch (e) {
      debugPrint('❌ [CONVERSATIONS] Sync failed: $e');
      throw LocalChatException('Failed to sync conversations from server: $e');
    }
  }

  /// Force immediate sync of messages from server (for empty conversations)
  Future<void> forceSyncMessagesFromServer(String conversationId) async {
    debugPrint(
        '🔄 Force syncing messages from server for conversation: $conversationId');

    // Skip sync for new conversations that don't exist on server yet
    if (conversationId.startsWith('new_')) {
      debugPrint('🔄 Skipping sync for new conversation: $conversationId');
      return;
    }

    try {
      // Get last sync time for this conversation based on latest local message
      final lastLocalMessage =
          await ChatRepositoryService.getLatestMessage(conversationId);
      final lastSyncTime = lastLocalMessage?.createdAt;

      final queryParams = <String, dynamic>{
        'limit': 50, // Default limit
      };

      String path = ApiConstants.getConversationMessages(conversationId);

      if (lastSyncTime != null) {
        // Use cursor-based pagination if we have a last sync time
        queryParams['cursor'] = lastSyncTime.toIso8601String();
        queryParams['loadDirection'] = 'after';
        debugPrint(
            '🌐 [forceSyncMessagesFromServer] Using cursor: ${queryParams['cursor']}');
      } else {
        // If no local messages, fetch the first page
        queryParams['page'] = 1;
        debugPrint('🌐 [forceSyncMessagesFromServer] Using page: 1');
      }

      // Get messages from API
      debugPrint(
          '🌐 [forceSyncMessagesFromServer] GET $path with params: $queryParams');
      final response = await _apiService.get(
        path,
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      debugPrint(
          '🌐 [forceSyncMessagesFromServer] response keys: ${data.keys}');
      final messagesList = data['messages'] as List;
      debugPrint(
          '🌐 [forceSyncMessagesFromServer] Got ${messagesList.length} messages');

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
        await ChatRepositoryService.saveMessages(localMessages);
        debugPrint(
            '✅ [forceSyncMessagesFromServer] Saved ${localMessages.length} messages from server for $conversationId');
      } catch (e) {
        debugPrint(
            '⚠️ [forceSyncMessagesFromServer] Error saving messages from server: $e');
      }
    } catch (e) {
      debugPrint('❌ Force sync messages from server failed: $e');
      rethrow;
    }
  }

  /// Fetch latest messages page from server regardless of local cursor
  /// Useful when conversation list shows a newer last message that isn't in local DB
  Future<void> fetchLatestFromServer(String conversationId,
      {int limit = 10}) async {
    // Skip sync for new conversations that don't exist on server yet
    if (conversationId.startsWith('new_')) {
      debugPrint(
          '🔄 Skipping fetchLatestFromServer for new conversation: $conversationId');
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

      await ChatRepositoryService.saveMessages(localMessages);
    } catch (e) {
      // Swallow errors; this is a best-effort helper
      debugPrint('fetchLatestFromServer failed: $e');
    }
  }

  /// Reconcile pending items when opening a chat: adopt server copies, fail stale
  Future<void> reconcilePendingOnOpen(String conversationId,
      {Duration staleAfter = const Duration(seconds: 45)}) async {
    try {
      // DEBUG: Check what conversation IDs exist in database
      final allMessages = await ChatRepositoryService.getAllMessages();
      final uniqueConversationIds =
          allMessages.map((m) => m.conversationId).toSet();
      debugPrint(
          '🔍 [DEBUG] All conversation IDs in database: $uniqueConversationIds');
      debugPrint('🔍 [DEBUG] Looking for conversationId: "$conversationId"');

      // Only reconcile if we have pending messages to avoid unnecessary work
      final pending =
          await ChatRepositoryService.getPendingMessagesForConversation(
              conversationId);
      if (pending.isEmpty) {
        debugPrint('🔄 No pending messages to reconcile for $conversationId');
        return;
      }

      debugPrint(
          '🔄 Reconciling ${pending.length} pending messages for $conversationId');

      // STEP 1: Clean up existing duplicates FIRST before syncing more
      await _cleanupDuplicateMessages(conversationId);

      // STEP 1.5: Clean up orphaned messages without clientMessageId
      await _cleanupOrphanedMessages(conversationId);

      // STEP 2: Only sync if we still have pending messages after cleanup
      final remainingPending =
          await ChatRepositoryService.getPendingMessagesForConversation(
              conversationId);

      if (remainingPending.isNotEmpty) {
        debugPrint(
            '🔄 ${remainingPending.length} messages still pending after cleanup, syncing from server...');

        // Pull a recent window so we can adopt - but catch any unique violations
        try {
          await _syncMessagesFromServer(conversationId,
              limit: 50); // Reduced limit
        } catch (e) {
          if (e.toString().contains('Unique index violated')) {
            debugPrint(
                'ℹ️ Some messages already exist during reconcile sync - continuing');
          } else {
            rethrow;
          }
        }

        // Try adopting each recent server message into any optimistic row
        final recent = await ChatRepositoryService.getLatestMessages(
            conversationId,
            limit: 100,
            offsetFromLatest: 0); // Reduced limit
        for (final m in recent) {
          if (m.serverId != null) {
            try {
              await ChatRepositoryService.adoptServerMessage(m);
            } catch (e) {
              if (e.toString().contains('Unique index violated')) {
                // Skip if already exists
                continue;
              }
              debugPrint('⚠️ Failed to adopt message ${m.serverId}: $e');
            }
          }
        }

        // STEP 3: Clean up again after sync in case new duplicates were created
        await _cleanupDuplicateMessages(conversationId);
      } else {
        debugPrint(
            '🔄 No pending messages after cleanup, skipping server sync');
      }

      // Any remaining pending older than threshold become failed
      final stillPending =
          await ChatRepositoryService.getPendingMessagesForConversation(
              conversationId);
      final now = DateTime.now();
      for (final p in stillPending) {
        if (now.difference(p.createdAt) > staleAfter) {
          await ChatRepositoryService.markMessageFailed(p.id.toString());
        }
      }

      debugPrint('🔄 Reconcile completed for $conversationId');
    } catch (e) {
      debugPrint('⚠️ reconcilePendingOnOpen failed: $e');
    }
  }

  /// Clean up duplicate messages with same content in a conversation
  /// Keep only the best version: delivered > sent > failed > sending
  Future<void> _cleanupDuplicateMessages(String conversationId) async {
    try {
      final allMessages = await ChatRepositoryService.getLatestMessages(
          conversationId,
          limit: 200);

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
          debugPrint(
              '🧹 Found ${group.length} duplicate messages with content: "${group.first.content}"');

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

          debugPrint(
              '🧹 Keeping message: ${toKeep.serverId ?? toKeep.id} (${toKeep.readStatus}) at ${toKeep.createdAt}');

          for (final duplicate in toDelete) {
            debugPrint(
                '🧹 Deleting duplicate: ${duplicate.serverId ?? duplicate.id} (${duplicate.readStatus}) at ${duplicate.createdAt}');
            await ChatRepositoryService.deleteMessage(duplicate.id);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup duplicate messages: $e');
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
      final allMessages = await ChatRepositoryService.getLatestMessages(
          conversationId,
          limit: 200);

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
        debugPrint(
            '🧹 Found ${orphaned.length} orphaned messages without clientMessageId');

        for (final orphan in orphaned) {
          debugPrint(
              '🧹 Marking orphaned message as failed: "${orphan.content}" (age: ${DateTime.now().difference(orphan.createdAt).inMinutes}min)');
          await ChatRepositoryService.markMessageFailed(orphan.id.toString());
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup orphaned messages: $e');
    }
  }

  /// Manual cleanup for testing - can be called directly
  Future<void> manualCleanupDuplicates(String conversationId) async {
    debugPrint('🧹 Manual cleanup requested for $conversationId');
    await _cleanupDuplicateMessages(conversationId);
    await _cleanupOrphanedMessages(conversationId);
  }

  /// Delete single message on server
  Future<void> deleteMessageOnServer(
      String messageId, String conversationId) async {
    try {
      await _apiService
          .delete('/conversations/$conversationId/messages/$messageId');
      debugPrint('✅ Message deleted on server: $messageId');
    } catch (e) {
      debugPrint('❌ Failed to delete message on server: $e');
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
      debugPrint(
          '✅ Batch delete response: ${result['deleted_count']} deleted, ${result['failed_count']} failed');

      return result;
    } catch (e) {
      debugPrint('❌ Failed to delete batch messages on server: $e');
      rethrow;
    }
  }

  Future<void> _syncMessagesFromServer(String conversationId,
      {int limit = 50}) async {
    // Skip sync for new conversations that don't exist on server yet
    if (conversationId.startsWith('new_')) {
      debugPrint(
          '🔄 Skipping message sync for new conversation: $conversationId');
      return;
    }

    try {
      // Determine how many messages we currently have locally.
      // If we have very few (e.g., after a fresh install), avoid cursor mode
      // and fetch the first page explicitly to rebuild a baseline.
      final recentLocal = await ChatRepositoryService.getLatestMessages(
        conversationId,
        limit: 3,
        offsetFromLatest: 0,
      );
      final bool shallowLocal = recentLocal.length < 3;

      // Get last sync time for this conversation based on latest local message
      // This prevents the server from re-sending messages we already have locally
      final lastSyncTime = await _getLastMessageSyncTime(conversationId);

      // Backend expects page/limit by default, or cursor + loadDirection for incremental loads
      final queryParams = <String, dynamic>{
        'limit': limit,
        'page': 1,
      };

      if (!shallowLocal && lastSyncTime != null) {
        // Normal incremental sync via cursor when we already have a healthy local baseline
        queryParams.remove('page');
        queryParams['cursor'] = lastSyncTime.toIso8601String();
        queryParams['loadDirection'] = 'after';
      } else {
        // Fallback baseline fetch: explicitly request page 1 to repopulate local cache
        // Useful when local DB is empty or nearly empty and cursor would return 0 items
        debugPrint(
            '🌐 [_syncMessagesFromServer] Using baseline page fetch (shallowLocal=$shallowLocal, lastSyncTime=${lastSyncTime?.toIso8601String()})');
      }

      // Get messages from API
      debugPrint(
          '🌐 [_syncMessagesFromServer] GET ${ApiConstants.getConversationMessages(conversationId)} params=${queryParams.toString()}');
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
        await ChatRepositoryService.saveMessages(localMessages);
      } catch (e) {
        // Skip duplicate messages instead of crashing
        debugPrint('Some messages already exist, skipping duplicates: $e');
        // Try saving individual messages to identify which ones are duplicates
        for (final message in localMessages) {
          try {
            await ChatRepositoryService.saveMessage(message);
          } catch (duplicateError) {
            // Skip this specific message
            debugPrint('Skipping duplicate message: ${message.serverId}');
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

        debugPrint(
            '🔄 Sending message to new conversation via direct message endpoint');
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
      await ChatRepositoryService.markMessageSynced(
        message.id.toString(),
        serverMessage['id'],
      );

      debugPrint('✅ Message synced successfully: ${serverMessage['id']}');
    } catch (e) {
      debugPrint('❌ Failed to sync message to server: $e');

      // 🔥 CRITICAL: Mark failed explicitly to stop infinite retries
      await ChatRepositoryService.markMessageFailed(message.id.toString());
      debugPrint('🚫 Message marked as failed - will not retry: ${message.id}');
      // Don't rethrow - we handled the failure by marking it as "failed"
    }
  }

  Future<void> _syncPendingMessages() async {
    try {
      // Throttle sync calls to prevent loops
      final now = DateTime.now();
      if (_lastSyncTime != null &&
          now.difference(_lastSyncTime!) < _syncThrottleDelay) {
        debugPrint(
            '⏳ Sync throttled - last sync was ${now.difference(_lastSyncTime!).inSeconds}s ago');
        return;
      }
      _lastSyncTime = now;

      final pendingMessages =
          await ChatRepositoryService.getPendingSyncMessages();

      // STOP: Don't sync if there are too many pending messages (indicates a loop)
      if (pendingMessages.length > 20) {
        debugPrint(
            '⚠️ Too many pending messages (${pendingMessages.length}) - stopping sync to prevent loops');
        return;
      }

      // Limit to prevent infinite loops
      final messagesToSync =
          pendingMessages.take(5).toList(); // Reduced from 10 to 5
      debugPrint('🔄 Syncing ${messagesToSync.length} pending messages');

      if (messagesToSync.isEmpty) {
        return; // No messages to sync
      }

      for (final message in messagesToSync) {
        // Sync message - failures are now handled inside _syncMessageToServer
        await _syncMessageToServer(message);
      }
    } catch (e) {
      debugPrint('Failed to sync pending messages: $e');
    }
  }

  Future<void> _syncReadStatusToServer(String conversationId) async {
    try {
      // Skip sync for new conversations that don't exist on server yet
      if (conversationId.startsWith('new_')) {
        debugPrint(
            '🔄 Skipping read status sync for new conversation: $conversationId');
        return;
      }

      await _apiService.put('/conversations/$conversationId/mark-read');
    } catch (e) {
      debugPrint('Failed to sync read status to server: $e');
    }
  }

  Future<void> _syncNewMessagesFromServer() async {
    try {
      final conversations = await ChatRepositoryService.getConversations();

      // Check for new messages in active conversations
      for (final conversation in conversations.take(5)) {
        await _syncMessagesFromServer(conversation.serverId, limit: 10);
      }
    } catch (e) {
      debugPrint('Failed to sync new messages from server: $e');
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
          await ChatRepositoryService.updateMessageReactions(
            messageId,
            jsonEncode(reactions),
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
      final latest =
          await ChatRepositoryService.getLatestMessage(conversationId);
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
        final adopted =
            await ChatRepositoryService.adoptServerMessage(localMessage);
        if (!adopted) {
          // Fallback saved by adoptServerMessage already if not adopted
        }

        // Update conversation
        await ChatRepositoryService.updateConversationLastMessage(
          localMessage.conversationId,
          localMessage,
          unreadCount:
              localMessage.isFromMe ? null : 1, // Increment if not from me
        );

        // Immediately acknowledge delivery so sender status updates
        if (!localMessage.isFromMe && localMessage.serverId != null) {
          try {
            _realtimeService.markAsDelivered(
                [localMessage.serverId!], localMessage.conversationId);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Failed to handle real-time message: $e');
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
  // Ensure repository is initialized before creating the service
  ref.watch(repositoryInitializationProvider);
  final apiService = ref.read(apiServiceProvider);
  final realtimeService = ref.read(realtimeServiceProvider);
  return LocalChatService(apiService, realtimeService);
});
