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
  static Future<bool> adoptServerMessage(LocalMessage serverMessage) async {
    // This would need to be implemented in the repository
    // For now, just save the message
    await saveMessage(serverMessage);
    return true;
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
}
