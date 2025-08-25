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
    return await RepositoryFactory.repository.getAllConversations();
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
  }

  /// Update message status
  static Future<void> updateMessageStatus(
    String messageId,
    String status,
    DateTime timestamp,
  ) async {
    // This would need to be implemented in the repository
    // For now, just update the message
    final message = await getMessage(int.tryParse(messageId) ?? 0);
    if (message != null) {
      final updatedMessage = message.copyWith(
        readStatus: status,
        readAt: status == 'read' ? timestamp : null,
        deliveredAt: status == 'delivered' ? timestamp : null,
      );
      await saveMessage(updatedMessage);
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

      // First, try to find an existing optimistic message by content and timestamp
      // This handles the case where the optimistic message was created locally
      final existingMessages = await getAllMessages();
      debugPrint(
          '🔄 [ChatRepositoryService] Found ${existingMessages.length} total messages in database');

      // Find optimistic messages for this conversation
      final optimisticMessages = existingMessages
          .where((msg) =>
              msg.serverId == null &&
              msg.conversationId == serverMessage.conversationId &&
              msg.isFromMe == serverMessage.isFromMe)
          .toList();
      debugPrint(
          '🔄 [ChatRepositoryService] Found ${optimisticMessages.length} optimistic messages for conversation ${serverMessage.conversationId}');

      for (final msg in optimisticMessages) {
        debugPrint(
            '🔄 [ChatRepositoryService] Optimistic message: id=${msg.id}, content="${msg.content}", timestamp=${msg.createdAt}');
      }

      // Find optimistic message that matches this server message
      // Use more flexible matching to handle timezone differences and recent messages
      final optimisticMessage = existingMessages.firstWhere(
        (msg) {
          final isMatch = msg.serverId == null && // Not yet synced
              msg.content == serverMessage.content && // Same content
              msg.isFromMe == serverMessage.isFromMe && // Same sender
              msg.conversationId ==
                  serverMessage.conversationId && // Same conversation
              // More flexible time matching - any optimistic message from last 30 minutes
              (msg.createdAt.isAfter(DateTime.now().subtract(
                  const Duration(minutes: 30)))); // Recent optimistic message

          if (isMatch) {
            debugPrint(
                '✅ [ChatRepositoryService] Found matching optimistic message: id=${msg.id}, content="${msg.content}"');
          }
          return isMatch;
        },
        orElse: () {
          debugPrint(
              '❌ [ChatRepositoryService] No matching optimistic message found, will save as new message');
          return serverMessage; // Fallback to server message
        },
      );

      if (optimisticMessage.id != serverMessage.id) {
        // Update the existing optimistic message with server data
        debugPrint(
            '🔄 [ChatRepositoryService] Adopting server message into optimistic message ${optimisticMessage.id}');

        final updatedMessage = optimisticMessage.copyWith(
          serverId: serverMessage.serverId,
          isSynced: true,
          readStatus: serverMessage.readStatus,
          createdAt: serverMessage.createdAt, // Use server timestamp
          reactions: serverMessage.reactions,
        );

        await saveMessage(updatedMessage);
        debugPrint(
            '✅ [ChatRepositoryService] Successfully adopted server message ${serverMessage.serverId} into optimistic message ${optimisticMessage.id}');
        debugPrint(
            '✅ [ChatRepositoryService] Updated message now has serverId: ${updatedMessage.serverId}, readStatus: ${updatedMessage.readStatus}');

        // Clean up any remaining duplicates
        await cleanupDuplicateMessages();

        return true;
      } else {
        // No optimistic message found, just save the server message
        debugPrint(
            '⚠️ [ChatRepositoryService] No optimistic message to adopt, saving server message as new');
        await saveMessage(serverMessage);
        debugPrint(
            '✅ [ChatRepositoryService] Saved server message ${serverMessage.serverId} (no optimistic message to adopt)');
        return true;
      }
    } catch (e) {
      debugPrint(
          '❌ [ChatRepositoryService] Failed to adopt server message: $e');
      // Fallback: just save the server message
      await saveMessage(serverMessage);
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

  /// Clean up duplicate messages (optimistic + server versions)
  static Future<void> cleanupDuplicateMessages() async {
    try {
      final allMessages = await getAllMessages();
      final duplicates = <String, List<LocalMessage>>{};

      // Group messages by content and conversation
      for (final message in allMessages) {
        final key =
            '${message.content}_${message.conversationId}_${message.isFromMe}';
        duplicates.putIfAbsent(key, () => []).add(message);
      }

      // Find and remove duplicates
      int removedCount = 0;
      for (final entry in duplicates.entries) {
        final messages = entry.value;
        if (messages.length > 1) {
          // Keep the one with serverId, remove optimistic ones
          final serverMessage = messages.firstWhere(
            (msg) => msg.serverId != null,
            orElse: () => messages.first,
          );

          for (final msg in messages) {
            if (msg.id != serverMessage.id) {
              await deleteMessage(msg.id);
              removedCount++;
              debugPrint(
                  '🧹 [ChatRepositoryService] Removed duplicate message: ${msg.id} (${msg.content})');
            }
          }
        }
      }

      if (removedCount > 0) {
        debugPrint(
            '🧹 [ChatRepositoryService] Cleaned up $removedCount duplicate messages');
      }
    } catch (e) {
      debugPrint('❌ [ChatRepositoryService] Failed to cleanup duplicates: $e');
    }
  }
}
