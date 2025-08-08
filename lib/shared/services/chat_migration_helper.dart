import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/chat_database.dart';
import '../models/local_conversation.dart';
import '../models/local_message.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/local_chat_service.dart';
import '../services/realtime_local_integration.dart';
import '../../core/storage/storage_service.dart';

/// Helper service for migrating from API-first to local-first chat
/// Provides seamless transition and fallback mechanisms
class ChatMigrationHelper {
  final ChatService _apiChatService;
  final LocalChatService _localChatService;
  final RealtimeLocalIntegration _realtimeIntegration;
  final Ref _ref;

  ChatMigrationHelper(
    this._apiChatService,
    this._localChatService,
    this._realtimeIntegration,
    this._ref,
  );

  /// Perform initial migration of existing data to local database
  Future<void> performInitialMigration() async {
    try {
      print('🔄 Starting chat data migration...');

      // 1. Migrate conversations
      await _migrateConversations();

      // 2. Migrate recent messages for top conversations
      await _migrateRecentMessages();

      print('✅ Chat data migration completed successfully');
    } catch (e) {
      print('❌ Chat data migration failed: $e');
      rethrow;
    }
  }

  Future<void> _migrateConversations() async {
    try {
      print('📱 Migrating conversations...');

      // Get conversations from API
      final apiConversations = await _apiChatService.getConversations();

      // Sync to local database
      await _realtimeIntegration.syncConversationsFromApi(apiConversations);

      print('✅ Migrated ${apiConversations.length} conversations');
    } catch (e) {
      print('❌ Failed to migrate conversations: $e');
      throw MigrationException('Conversation migration failed', e);
    }
  }

  Future<void> _migrateRecentMessages() async {
    try {
      print('💬 Migrating recent messages...');

      // Get conversations from local database
      final localConversations = await ChatDatabase.getConversations();

      int totalMessages = 0;

      // Migrate messages for each conversation (limit to top 10 for performance)
      for (final conversation in localConversations.take(10)) {
        try {
          // Get recent messages from API
          final apiMessages = await _apiChatService.getMessages(
            conversation.serverId,
            limit: 50, // Last 50 messages per conversation
          );

          // Sync to local database
          await _realtimeIntegration.syncMessagesFromApi(
            conversation.serverId,
            apiMessages,
          );

          totalMessages += apiMessages.length;
        } catch (e) {
          print(
              '⚠️ Failed to migrate messages for conversation ${conversation.serverId}: $e');
          // Continue with other conversations
        }
      }

      print('✅ Migrated $totalMessages messages');
    } catch (e) {
      print('❌ Failed to migrate messages: $e');
      throw MigrationException('Message migration failed', e);
    }
  }

  /// Check if migration is needed
  Future<bool> isMigrationNeeded() async {
    try {
      // Check if we have any conversations in local database
      final localConversations = await ChatDatabase.getConversations();

      // If no local conversations, migration is needed
      if (localConversations.isEmpty) {
        return true;
      }

      // Check if local data is recent (less than 24 hours old)
      final lastSyncTime = await ChatDatabase.getLastSyncTime();
      if (lastSyncTime == null) {
        return true;
      }

      final timeSinceLastSync = DateTime.now().difference(lastSyncTime);
      return timeSinceLastSync.inHours > 24;
    } catch (e) {
      print('❌ Error checking migration status: $e');
      return true; // Default to migration needed if we can't check
    }
  }

  /// Perform background sync to keep local data up to date
  Future<void> performBackgroundSync() async {
    try {
      print('🔄 Starting background sync...');

      // 1. Sync pending local messages to server
      await _syncPendingMessages();

      // 2. Sync new messages from server
      await _syncNewMessages();

      // 3. Update sync timestamp
      await ChatDatabase.updateLastSyncTime(DateTime.now());

      print('✅ Background sync completed');
    } catch (e) {
      print('❌ Background sync failed: $e');
      // Don't rethrow - background sync failures shouldn't crash the app
    }
  }

  Future<void> _syncPendingMessages() async {
    try {
      final pendingMessages = await ChatDatabase.getPendingSyncMessages();

      for (final message in pendingMessages) {
        try {
          // Send to server using API service
          final serverMessage = await _apiChatService.sendMessage(
            conversationId: message.conversationId,
            content: message.content,
            messageType: _convertToApiMessageType(message.messageType),
            replyToId: message.replyToId,
            metadata: message.metadata,
          );

          // Update local message with server ID
          await ChatDatabase.markMessageSynced(
            message.id.toString(),
            serverMessage.id,
          );
        } catch (e) {
          print('⚠️ Failed to sync message ${message.id}: $e');
          // Continue with other messages
        }
      }

      print('✅ Synced ${pendingMessages.length} pending messages');
    } catch (e) {
      print('❌ Failed to sync pending messages: $e');
    }
  }

  Future<void> _syncNewMessages() async {
    try {
      // Get active conversations (recently updated)
      final conversations = await ChatDatabase.getConversations();
      final activeConversations = conversations.take(5).toList();

      for (final conversation in activeConversations) {
        try {
          // Get recent messages from API
          final lastMessageTime =
              conversation.lastMessageAt ?? conversation.lastActivity;

          final apiMessages = await _apiChatService.getMessages(
            conversation.serverId,
            limit: 20,
          );

          // Filter messages newer than what we have locally
          final newMessages = apiMessages
              .where((msg) =>
                  lastMessageTime == null ||
                  msg.createdAt.isAfter(lastMessageTime))
              .toList();

          if (newMessages.isNotEmpty) {
            await _realtimeIntegration.syncMessagesFromApi(
              conversation.serverId,
              newMessages,
            );
          }
        } catch (e) {
          print(
              '⚠️ Failed to sync new messages for ${conversation.serverId}: $e');
        }
      }
    } catch (e) {
      print('❌ Failed to sync new messages: $e');
    }
  }

  MessageType _convertToApiMessageType(LocalMessageType localType) {
    switch (localType) {
      case LocalMessageType.text:
        return MessageType.text;
      case LocalMessageType.image:
        return MessageType.image;
      case LocalMessageType.video:
        return MessageType.video;
      case LocalMessageType.audio:
        return MessageType.audio;
      case LocalMessageType.file:
        return MessageType.file;
      case LocalMessageType.emoji:
        return MessageType.emoji;
      case LocalMessageType.location:
        return MessageType.text; // Fallback for unsupported type
    }
  }

  /// Health check for local-first system
  Future<ChatSystemHealth> checkSystemHealth() async {
    try {
      final health = ChatSystemHealth();

      // Check database connectivity
      try {
        await ChatDatabase.getConversations();
        health.isDatabaseHealthy = true;
      } catch (e) {
        health.isDatabaseHealthy = false;
        health.issues.add('Database connectivity issue: $e');
      }

      // Check API connectivity
      try {
        await _apiChatService.getConversations();
        health.isApiHealthy = true;
      } catch (e) {
        health.isApiHealthy = false;
        health.issues.add('API connectivity issue: $e');
      }

      // Check local data freshness
      final lastSyncTime = await ChatDatabase.getLastSyncTime();
      if (lastSyncTime != null) {
        final timeSinceSync = DateTime.now().difference(lastSyncTime);
        health.lastSyncAge = timeSinceSync;
        health.isDataFresh = timeSinceSync.inHours < 24;
      } else {
        health.isDataFresh = false;
        health.issues.add('No sync timestamp found');
      }

      // Check pending messages count
      final pendingMessages = await ChatDatabase.getPendingSyncMessages();
      health.pendingMessagesCount = pendingMessages.length;

      return health;
    } catch (e) {
      throw MigrationException('Health check failed', e);
    }
  }
}

class ChatSystemHealth {
  bool isDatabaseHealthy = false;
  bool isApiHealthy = false;
  bool isDataFresh = false;
  Duration? lastSyncAge;
  int pendingMessagesCount = 0;
  List<String> issues = [];

  bool get isHealthy => isDatabaseHealthy && (isApiHealthy || isDataFresh);

  String get statusSummary {
    if (isHealthy) {
      return '✅ System healthy';
    } else {
      return '⚠️ Issues detected: ${issues.join(', ')}';
    }
  }
}

class MigrationException implements Exception {
  final String message;
  final Object? cause;

  MigrationException(this.message, [this.cause]);

  @override
  String toString() =>
      'MigrationException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

// Provider for migration helper
final chatMigrationHelperProvider = Provider<ChatMigrationHelper>((ref) {
  final apiChatService = ref.read(chatServiceProvider);
  final localChatService = ref.read(localChatServiceProvider);
  final realtimeIntegration = ref.read(realtimeLocalIntegrationProvider);

  return ChatMigrationHelper(
    apiChatService,
    localChatService,
    realtimeIntegration,
    ref,
  );
});
