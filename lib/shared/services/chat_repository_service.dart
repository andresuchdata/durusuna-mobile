import 'package:flutter/foundation.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../models/local_user.dart';
import '../repositories/repository_factory.dart';

/// Service class that provides chat operations using the repository pattern
/// This gives us a clean interface that can work with any database implementation
class ChatRepositoryService {
  /// Get all conversations
  static Future<List<LocalConversation>> getConversations() async {
    try {
      return await RepositoryFactory.repository.getAllConversations();
    } catch (e) {
      debugPrint('❌ [ChatRepositoryService] Failed to get conversations: $e');
      rethrow;
    }
  }

  /// Get a specific conversation
  static Future<LocalConversation?> getConversation(
      String conversationId) async {
    return await RepositoryFactory.repository.getConversation(conversationId);
  }

  /// Get messages for a conversation
  static Future<List<LocalMessage>> getConversationMessages(
    String conversationId, {
    int? limit,
    int? offset,
  }) async {
    return await RepositoryFactory.repository.getConversationMessages(
      conversationId,
      limit: limit,
      offset: offset,
    );
  }

  /// Save a message
  static Future<void> saveMessage(LocalMessage message) async {
    await RepositoryFactory.repository.saveMessage(message);
  }

  /// Get a message by ID
  static Future<LocalMessage?> getMessage(int localId) async {
    return await RepositoryFactory.repository.getMessage(localId);
  }

  /// Get a message by server ID
  static Future<LocalMessage?> getMessageByServerId(String serverId) async {
    return await RepositoryFactory.repository.getMessageByServerId(serverId);
  }

  /// Get unsynced messages
  static Future<List<LocalMessage>> getUnsyncedMessages() async {
    return await RepositoryFactory.repository.getUnsyncedMessages();
  }

  /// Get messages by status
  static Future<List<LocalMessage>> getMessagesByStatus(String status) async {
    return await RepositoryFactory.repository.getMessagesByStatus(status);
  }

  /// Delete a message
  static Future<void> deleteMessage(int localId) async {
    await RepositoryFactory.repository.deleteMessage(localId);
  }

  /// Save a conversation
  static Future<void> saveConversation(LocalConversation conversation) async {
    await RepositoryFactory.repository.saveConversation(conversation);
  }

  /// Save a user
  static Future<void> saveUser(LocalUser user) async {
    await RepositoryFactory.repository.saveUser(user);
  }

  /// Get a user by ID
  static Future<LocalUser?> getUser(String userId) async {
    return await RepositoryFactory.repository.getUser(userId);
  }

  /// Get database statistics
  static Future<Map<String, int>> getDatabaseStats() async {
    return await RepositoryFactory.repository.getDatabaseStats();
  }

  /// Clear all data
  static Future<void> clearAllData() async {
    await RepositoryFactory.repository.clearAllData();
  }

  /// Get repository health status
  static Future<Map<String, dynamic>> getHealthStatus() async {
    return await RepositoryFactory.getHealthStatus();
  }

  /// Get current repository type
  static String get currentRepositoryType =>
      RepositoryFactory.repositoryTypeName;

  /// Check if repository is healthy
  static Future<bool> isHealthy() async {
    final health = await getHealthStatus();
    return health['isHealthy'] ?? false;
  }

  /// Switch to a different repository type
  static Future<void> switchRepository(RepositoryType type) async {
    await RepositoryFactory.switchRepository(type);
  }

  /// Get current repository type enum
  static RepositoryType get currentType => RepositoryFactory.currentType;

  // ========== ADDITIONAL METHODS NEEDED FOR MIGRATION ==========

  /// Get latest messages for a conversation
  static Future<List<LocalMessage>> getLatestMessages(
    String conversationId, {
    int limit = 50,
    int offsetFromLatest = 0,
  }) async {
    // This is a convenience method that maps to getConversationMessages
    return await getConversationMessages(
      conversationId,
      limit: limit,
      offset: offsetFromLatest,
    );
  }

  /// Get messages with offset
  static Future<List<LocalMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await getConversationMessages(
      conversationId,
      limit: limit,
      offset: offset,
    );
  }

  /// Save multiple messages
  static Future<void> saveMessages(List<LocalMessage> messages) async {
    for (final message in messages) {
      await saveMessage(message);
    }
  }

  /// Get latest message for a conversation
  static Future<LocalMessage?> getLatestMessage(String conversationId) async {
    final messages = await getConversationMessages(conversationId, limit: 1);
    return messages.isNotEmpty ? messages.first : null;
  }

  /// Get pending sync messages
  static Future<List<LocalMessage>> getPendingSyncMessages() async {
    return await getUnsyncedMessages();
  }

  /// Get pending messages for a conversation
  static Future<List<LocalMessage>> getPendingMessagesForConversation(
      String conversationId) async {
    final messages = await getConversationMessages(conversationId);
    return messages.where((m) => !m.isSynced).toList();
  }

  /// Get all messages (for cleanup operations)
  static Future<List<LocalMessage>> getAllMessages() async {
    // This is a convenience method - get messages from all conversations
    final conversations = await getConversations();
    List<LocalMessage> allMessages = [];
    for (final conv in conversations) {
      final messages = await getConversationMessages(conv.serverId);
      allMessages.addAll(messages);
    }
    return allMessages;
  }

  /// Search messages
  static Future<List<LocalMessage>> searchMessages(String query) async {
    // This would need to be implemented in the repository
    // For now, return empty list
    return [];
  }

  /// Search contacts
  static Future<List<LocalUser>> searchContacts(String query) async {
    // This would need to be implemented in the repository
    // For now, return empty list
    return [];
  }

  /// Update conversation last message
  static Future<void> updateConversationLastMessage(
    String conversationId,
    LocalMessage message, {
    int? unreadCount,
  }) async {
    // This would need to be implemented in the repository
    // For now, just save the message
    await saveMessage(message);
  }

  /// Mark message as synced
  static Future<void> markMessageSynced(String localId, String serverId) async {
    // This would need to be implemented in the repository
    // For now, just update the message
    final message = await getMessage(int.tryParse(localId) ?? 0);
    if (message != null) {
      final updatedMessage = message.copyWith(
        serverId: serverId,
        isSynced: true,
      );
      await saveMessage(updatedMessage);
    }
  }

  /// Mark message as failed
  static Future<void> markMessageFailed(String localId) async {
    // This would need to be implemented in the repository
    // For now, just update the message
    final message = await getMessage(int.tryParse(localId) ?? 0);
    if (message != null) {
      final updatedMessage = message.copyWith(
        isSynced: true, // Mark as synced to prevent retries
        readStatus: 'failed',
      );
      await saveMessage(updatedMessage);
    }
  }

  /// Mark conversation as read
  static Future<void> markConversationAsRead(String conversationId) async {
    try {
      // This would need to be implemented in the repository
      // For now, just update all messages in the conversation
      final messages = await getConversationMessages(conversationId);
      for (final message in messages) {
        if (message.readStatus != 'read') {
          final updatedMessage = message.copyWith(
            readStatus: 'read',
            readAt: DateTime.now(),
          );
          await saveMessage(updatedMessage);
        }
      }
    } catch (e) {
      debugPrint(
          '❌ [ChatRepositoryService] Failed to mark conversation as read: $e');
      rethrow;
    }
  }

  /// Update message status
  static Future<void> updateMessageStatus(
    String messageId,
    String status,
    DateTime timestamp,
  ) async {
    try {
      debugPrint(
          '📖 [ChatRepositoryService] Updating message status: $messageId -> $status');

      // Try to find message by server ID first (most common case for read receipts)
      LocalMessage? message = await getMessageByServerId(messageId);

      // If not found by server ID, try by local ID (fallback)
      if (message == null) {
        final localId = int.tryParse(messageId);
        if (localId != null) {
          message = await getMessage(localId);
        }
      }

      if (message != null) {
        debugPrint(
            '📖 [ChatRepositoryService] Found message ${message.id}, updating status to $status');
        final updatedMessage = message.copyWith(
          readStatus: status,
          readAt: status == 'read' ? timestamp : null,
          deliveredAt: status == 'delivered' ? timestamp : null,
        );
        await saveMessage(updatedMessage);
        debugPrint(
            '📖 [ChatRepositoryService] ✅ Successfully updated message status');
      } else {
        debugPrint('❌ [ChatRepositoryService] Message not found: $messageId');
      }
    } catch (e) {
      debugPrint('❌ [ChatRepositoryService] Error updating message status: $e');
      rethrow;
    }
  }

  /// Update message reactions
  static Future<void> updateMessageReactions(
    String serverId,
    String reactionsJson,
  ) async {
    // This would need to be implemented in the repository
    // For now, just update the message
    final message = await getMessageByServerId(serverId);
    if (message != null) {
      final updatedMessage = message.copyWith(
        reactions: reactionsJson,
      );
      await saveMessage(updatedMessage);
    }
  }

  /// Adopt server message (for optimistic updates)
  /// This method should find and update the existing optimistic message with server data
  static Future<bool> adoptServerMessage(LocalMessage serverMessage) async {
    try {
      debugPrint(
          '🔄 [ChatRepositoryService] Starting adoption for server message: ${serverMessage.serverId}');
      debugPrint(
          '🔄 [ChatRepositoryService] Server message content: "${serverMessage.content}"');
      debugPrint(
          '🔄 [ChatRepositoryService] Server message timestamp: ${serverMessage.createdAt}');

      // Check if this server message already exists to prevent duplicates
      if (serverMessage.serverId != null) {
        final existing = await getMessageByServerId(serverMessage.serverId!);
        if (existing != null) {
          debugPrint(
              '✅ [ChatRepositoryService] Server message ${serverMessage.serverId} already exists - skipping');
          return true;
        }
      }

      // Find optimistic message by clientMessageId first (most reliable)
      LocalMessage? optimisticMessage;
      if (serverMessage.clientMessageId != null) {
        final messages =
            await getConversationMessages(serverMessage.conversationId);
        optimisticMessage = messages.firstWhere(
          (msg) =>
              msg.serverId == null &&
              msg.clientMessageId == serverMessage.clientMessageId,
          orElse: () => serverMessage, // Use as sentinel
        );

        if (!identical(optimisticMessage, serverMessage)) {
          debugPrint(
              '✅ [ChatRepositoryService] Found optimistic message by clientMessageId: ${optimisticMessage.id}');
        } else {
          optimisticMessage = null;
        }
      }

      // Fallback: Find by content match for recent messages
      if (optimisticMessage == null) {
        final messages =
            await getConversationMessages(serverMessage.conversationId);
        final recentOptimistic = messages
            .where((msg) =>
                msg.serverId == null &&
                msg.content == serverMessage.content &&
                msg.isFromMe == serverMessage.isFromMe &&
                msg.createdAt.isAfter(
                    DateTime.now().subtract(const Duration(minutes: 2))))
            .toList();

        if (recentOptimistic.isNotEmpty) {
          // Use the most recent one
          recentOptimistic.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          optimisticMessage = recentOptimistic.first;
          debugPrint(
              '🔄 [ChatRepositoryService] Using content match for recent optimistic message: ${optimisticMessage.id}');
        }
      }

      if (optimisticMessage != null) {
        debugPrint(
            '🔄 [ChatRepositoryService] Adopting server message into optimistic message ${optimisticMessage.id}');

        // Delete the optimistic message
        await deleteMessage(optimisticMessage.id);
        debugPrint(
            '🗑️ [ChatRepositoryService] Deleted optimistic message ${optimisticMessage.id}');

        // Save the server message
        await saveMessage(serverMessage);
        debugPrint(
            '✅ [ChatRepositoryService] Successfully adopted server message ${serverMessage.serverId}');

        return true;
      } else {
        // No optimistic message found, save as new
        debugPrint(
            '⚠️ [ChatRepositoryService] No optimistic message to adopt, saving server message as new');
        await saveMessage(serverMessage);
        debugPrint(
            '✅ [ChatRepositoryService] Saved server message ${serverMessage.serverId}');
        return true;
      }
    } catch (e) {
      debugPrint(
          '❌ [ChatRepositoryService] Failed to adopt server message: $e');
      // Fallback: just save the server message if it doesn't already exist
      try {
        if (serverMessage.serverId != null) {
          final existing = await getMessageByServerId(serverMessage.serverId!);
          if (existing == null) {
            await saveMessage(serverMessage);
          }
        }
      } catch (_) {}
      return false;
    }
  }

  /// Remove pending message
  static Future<void> removePendingMessage(String messageId) async {
    // This would need to be implemented in the repository
    // For now, just delete the message
    await deleteMessage(int.tryParse(messageId) ?? 0);
  }

  /// Force recreate database (for debug)
  static Future<void> forceRecreateDatabase() async {
    await clearAllData();
  }

  /// Simple cleanup of obvious duplicates
  static Future<void> forceCleanupDuplicates() async {
    try {
      debugPrint(
          '🧹 [ChatRepositoryService] Starting forced cleanup of duplicates...');

      // Use the repository's built-in duplicate cleanup
      await RepositoryFactory.repository.deleteDuplicateMessages();

      debugPrint(
          '🧹 [ChatRepositoryService] Force cleanup completed: removed duplicates');
    } catch (e) {
      debugPrint('❌ [ChatRepositoryService] Force cleanup failed: $e');
    }
  }

  /// Clean up duplicate messages (optimistic + server versions)
  static Future<void> cleanupDuplicateMessages() async {
    try {
      debugPrint(
          '🧹 [ChatRepositoryService] Starting cleanup of duplicates...');

      // Use the repository's built-in duplicate cleanup which is more reliable
      await RepositoryFactory.repository.deleteDuplicateMessages();

      debugPrint('🧹 [ChatRepositoryService] Cleanup completed');
    } catch (e) {
      debugPrint('❌ [ChatRepositoryService] Failed to cleanup duplicates: $e');
    }
  }

  /// Fix negative ID issue by cleaning up invalid messages
  /// This addresses the Isar -> SQLite migration issue
  static Future<void> fixNegativeIdIssue() async {
    try {
      debugPrint('🔧 [ChatRepositoryService] Starting negative ID cleanup...');

      // Use the duplicate cleanup which now includes negative ID removal
      await RepositoryFactory.repository.deleteDuplicateMessages();

      debugPrint('✅ [ChatRepositoryService] Negative ID cleanup completed');
    } catch (e) {
      debugPrint(
          '❌ [ChatRepositoryService] Failed to fix negative ID issue: $e');
    }
  }
}
