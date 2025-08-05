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
  final RealtimeService _realtimeService;

  // Background sync controller
  Timer? _syncTimer;
  bool _isInitialSyncComplete = false;

  LocalChatService(this._apiService, this._realtimeService) {
    _initialize();
  }

  Future<void> _initialize() async {
    await ChatDatabase.initialize();
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
      // Get from local database instantly
      final messages = await ChatDatabase.getMessages(
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
    final currentUser = StorageService.getUser();
    if (currentUser == null) {
      throw LocalChatException('User not authenticated');
    }

    // Create local message instantly
    final localMessage = LocalMessage(
      conversationId: conversationId,
      senderId: currentUser['id'],
      content: content,
      messageType: messageType,
      replyToId: replyToId,
      createdAt: DateTime.now(),
      isFromMe: true,
      isSynced: false, // Will be synced in background
      metadataJson: metadata != null ? jsonEncode(metadata) : null,
    );

    try {
      // Save to local database instantly
      await ChatDatabase.saveMessage(localMessage);

      // Update conversation's last message instantly
      await ChatDatabase.updateConversationLastMessage(
        conversationId,
        localMessage,
      );

      // Sync to server in background (no await)
      _syncMessageToServer(localMessage);

      return localMessage;
    } catch (e) {
      throw LocalChatException('Failed to send message locally: $e');
    }
  }

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

  /// Mark conversation as read locally (instant)
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      // Update locally instantly
      await ChatDatabase.markConversationAsRead(conversationId);

      // Sync to server in background
      _syncReadStatusToServer(conversationId);
    } catch (e) {
      throw LocalChatException('Failed to mark conversation as read: $e');
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
    // Sync every 30 seconds when app is active
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performBackgroundSync();
    });

    // Initial sync
    _performInitialSync();
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

      // Sync conversation updates
      await _syncConversationUpdatesFromServer();
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

      // Save all conversations
      for (final conversation in localConversations) {
        await ChatDatabase.saveConversation(conversation);
      }
    } catch (e) {
      throw LocalChatException('Failed to sync conversations from server: $e');
    }
  }

  Future<void> _syncMessagesFromServer(String conversationId,
      {int limit = 50}) async {
    try {
      // Get last sync time for this conversation
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

      // Save all messages
      await ChatDatabase.saveMessages(localMessages);

      // Update last sync time
      if (localMessages.isNotEmpty) {
        await _updateLastMessageSyncTime(
          conversationId,
          localMessages.last.createdAt,
        );
      }
    } catch (e) {
      throw LocalChatException('Failed to sync messages from server: $e');
    }
  }

  Future<void> _syncMessageToServer(LocalMessage message) async {
    try {
      // Send to server
      final response = await _apiService.post(
        '/conversations/${message.conversationId}/messages',
        data: message.toApiJson(),
      );

      final serverMessage = response.data['message'] as Map<String, dynamic>;

      // Update local message with server ID and mark as synced
      await ChatDatabase.markMessageSynced(
        message.id.toString(),
        serverMessage['id'],
      );
    } catch (e) {
      // Message will remain unsynced and retry later
      print('Failed to sync message to server: $e');
    }
  }

  Future<void> _syncPendingMessages() async {
    try {
      final pendingMessages = await ChatDatabase.getPendingSyncMessages();

      for (final message in pendingMessages) {
        await _syncMessageToServer(message);
      }
    } catch (e) {
      print('Failed to sync pending messages: $e');
    }
  }

  Future<void> _syncReadStatusToServer(String conversationId) async {
    try {
      await _apiService.put('/conversations/$conversationId/read');
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

  Future<void> _syncConversationUpdatesFromServer() async {
    try {
      // Get conversation updates (read receipts, typing indicators, etc.)
      final lastSyncTime = await ChatDatabase.getLastSyncTime();

      final queryParams = <String, dynamic>{};
      if (lastSyncTime != null) {
        queryParams['after'] = lastSyncTime.toIso8601String();
      }

      final response = await _apiService.get(
        '/conversations/updates',
        queryParameters: queryParams,
      );

      final updates = response.data['updates'] as List;

      // Process updates (read receipts, etc.)
      for (final update in updates) {
        await _processConversationUpdate(update);
      }

      await ChatDatabase.updateLastSyncTime(DateTime.now());
    } catch (e) {
      print('Failed to sync conversation updates: $e');
    }
  }

  Future<void> _processConversationUpdate(Map<String, dynamic> update) async {
    final type = update['type'];

    switch (type) {
      case 'message_read':
        await ChatDatabase.updateMessageStatus(
          update['message_id'],
          readStatus: 'read',
          readAt: DateTime.parse(update['timestamp']),
        );
        break;
      case 'message_delivered':
        await ChatDatabase.updateMessageStatus(
          update['message_id'],
          deliveredAt: DateTime.parse(update['timestamp']),
        );
        break;
      // Add more update types as needed
    }
  }

  // ========== HELPER METHODS ==========

  Future<DateTime?> _getLastMessageSyncTime(String conversationId) async {
    // Implement based on your sync tracking needs
    return null;
  }

  Future<void> _updateLastMessageSyncTime(
      String conversationId, DateTime time) async {
    // Implement based on your sync tracking needs
  }

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

        // Save to local database
        await ChatDatabase.saveMessage(localMessage);

        // Update conversation
        await ChatDatabase.updateConversationLastMessage(
          localMessage.conversationId,
          localMessage,
          unreadCount:
              localMessage.isFromMe ? null : 1, // Increment if not from me
        );
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
