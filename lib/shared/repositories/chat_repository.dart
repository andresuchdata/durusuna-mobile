import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../models/local_user.dart';

/// Abstract interface for chat data operations
/// This allows us to easily swap between different database implementations
abstract class ChatRepository {
  /// Initialize the repository
  Future<void> initialize();

  /// Close the repository
  Future<void> close();

  // ========== MESSAGE OPERATIONS ==========

  /// Save a message to the database
  Future<void> saveMessage(LocalMessage message);

  /// Get messages for a specific conversation
  Future<List<LocalMessage>> getConversationMessages(
    String conversationId, {
    int? limit,
    int? offset,
  });

  /// Get a message by its local ID
  Future<LocalMessage?> getMessage(int localId);

  /// Get a message by its server ID
  Future<LocalMessage?> getMessageByServerId(String serverId);

  /// Get all unsynced messages
  Future<List<LocalMessage>> getUnsyncedMessages();

  /// Get messages by read status
  Future<List<LocalMessage>> getMessagesByStatus(String status);

  /// Delete a message by local ID
  Future<void> deleteMessage(int localId);

  /// Delete duplicate messages
  Future<void> deleteDuplicateMessages();

  // ========== CONVERSATION OPERATIONS ==========

  /// Save a conversation
  Future<void> saveConversation(LocalConversation conversation);

  /// Get all conversations
  Future<List<LocalConversation>> getAllConversations();

  /// Get a conversation by ID
  Future<LocalConversation?> getConversation(String conversationId);

  /// Update conversation unread count
  Future<void> updateConversationUnreadCount(
      String conversationId, int unreadCount);

  // ========== USER OPERATIONS ==========

  /// Save a user
  Future<void> saveUser(LocalUser user);

  /// Get a user by ID
  Future<LocalUser?> getUser(String userId);

  // ========== UTILITY OPERATIONS ==========

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats();

  /// Clear all data
  Future<void> clearAllData();

  /// Get repository health status
  Future<Map<String, dynamic>> getHealthStatus();
}
