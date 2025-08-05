import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../models/local_user.dart';

class ChatDatabase {
  static late Isar _isar;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        LocalMessageSchema,
        LocalConversationSchema,
        LocalUserSchema,
      ],
      directory: dir.path,
      name: 'durusuna_chat',
    );

    _initialized = true;
  }

  static Isar get instance {
    if (!_initialized) {
      throw StateError(
          'Database not initialized. Call ChatDatabase.initialize() first.');
    }
    return _isar;
  }

  // ========== MESSAGE OPERATIONS ==========

  /// Save message to local database (instant)
  static Future<void> saveMessage(LocalMessage message) async {
    await _isar.writeTxn(() async {
      await _isar.localMessages.put(message);
    });
  }

  /// Save multiple messages (batch operation for sync)
  static Future<void> saveMessages(List<LocalMessage> messages) async {
    await _isar.writeTxn(() async {
      await _isar.localMessages.putAll(messages);
    });
  }

  /// Get messages for conversation (instant loading)
  static Future<List<LocalMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Get latest message for conversation (for conversation list)
  static Future<LocalMessage?> getLatestMessage(String conversationId) async {
    return await _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .findFirst();
  }

  /// Search messages (fast indexed search)
  static Future<List<LocalMessage>> searchMessages(
    String query, {
    String? conversationId,
    int limit = 100,
  }) async {
    if (conversationId != null) {
      return await _isar.localMessages
          .where()
          .conversationIdEqualTo(conversationId)
          .filter()
          .contentContains(query, caseSensitive: false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .findAll();
    } else {
      return await _isar.localMessages
          .filter()
          .contentContains(query, caseSensitive: false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .findAll();
    }
  }

  /// Update message status (read receipts, delivery status)
  static Future<void> updateMessageStatus(
    String messageId, {
    String? readStatus,
    DateTime? readAt,
    DateTime? deliveredAt,
  }) async {
    await _isar.writeTxn(() async {
      final message = await _isar.localMessages
          .where()
          .serverIdEqualTo(messageId)
          .findFirst();
      if (message != null) {
        final updated = message.copyWith(
          readStatus: readStatus,
          readAt: readAt,
          deliveredAt: deliveredAt,
        );
        await _isar.localMessages.put(updated);
      }
    });
  }

  /// Delete message locally
  static Future<void> deleteMessage(String messageId) async {
    await _isar.writeTxn(() async {
      final message = await _isar.localMessages
          .where()
          .serverIdEqualTo(messageId)
          .findFirst();
      if (message != null) {
        await _isar.localMessages.delete(message.id);
      }
    });
  }

  // ========== CONVERSATION OPERATIONS ==========

  /// Save conversation
  static Future<void> saveConversation(LocalConversation conversation) async {
    await _isar.writeTxn(() async {
      await _isar.localConversations.put(conversation);
    });
  }

  /// Get all conversations (instant loading)
  static Future<List<LocalConversation>> getConversations() async {
    return await _isar.localConversations
        .where()
        .sortByLastActivityDesc()
        .findAll();
  }

  /// Get conversation by ID
  static Future<LocalConversation?> getConversation(
      String conversationId) async {
    return await _isar.localConversations.getByServerId(conversationId);
  }

  /// Update conversation last message and unread count
  static Future<void> updateConversationLastMessage(
    String conversationId,
    LocalMessage lastMessage, {
    int? unreadCount,
  }) async {
    await _isar.writeTxn(() async {
      final conversation =
          await _isar.localConversations.getByServerId(conversationId);
      if (conversation != null) {
        final updated = conversation.copyWith(
          lastMessage: lastMessage.content,
          lastMessageAt: lastMessage.createdAt,
          lastActivity: DateTime.now(),
          unreadCount: unreadCount ?? conversation.unreadCount,
        );
        await _isar.localConversations.put(updated);
      }
    });
  }

  /// Mark conversation as read
  static Future<void> markConversationAsRead(String conversationId) async {
    await _isar.writeTxn(() async {
      final conversation =
          await _isar.localConversations.getByServerId(conversationId);
      if (conversation != null) {
        final updated = conversation.copyWith(unreadCount: 0);
        await _isar.localConversations.put(updated);
      }
    });
  }

  // ========== USER OPERATIONS ==========

  /// Save user info for contacts
  static Future<void> saveUser(LocalUser user) async {
    await _isar.writeTxn(() async {
      await _isar.localUsers.put(user);
    });
  }

  /// Get user by ID
  static Future<LocalUser?> getUser(String userId) async {
    return await _isar.localUsers.getByServerId(userId);
  }

  /// Search contacts
  static Future<List<LocalUser>> searchContacts(String query) async {
    return await _isar.localUsers
        .filter()
        .group((q) => q
            .firstNameContains(query, caseSensitive: false)
            .or()
            .lastNameContains(query, caseSensitive: false)
            .or()
            .emailContains(query, caseSensitive: false))
        .findAll();
  }

  // ========== SYNC OPERATIONS ==========

  /// Get messages that need to be synced to server
  static Future<List<LocalMessage>> getPendingSyncMessages() async {
    return await _isar.localMessages.where().isSyncedEqualTo(false).findAll();
  }

  /// Mark message as synced
  static Future<void> markMessageSynced(String localId, String serverId) async {
    await _isar.writeTxn(() async {
      final message = await _isar.localMessages.get(int.parse(localId));
      if (message != null) {
        final updated = message.copyWith(
          serverId: serverId,
          isSynced: true,
        );
        await _isar.localMessages.put(updated);
      }
    });
  }

  /// Get timestamp of last successful sync
  static Future<DateTime?> getLastSyncTime() async {
    // Store sync metadata in settings or separate collection
    return null; // Implement based on your needs
  }

  /// Update last sync time
  static Future<void> updateLastSyncTime(DateTime timestamp) async {
    // Implement sync timestamp tracking
  }

  // ========== CLEANUP OPERATIONS ==========

  /// Clean old messages (keep last N messages per conversation)
  static Future<void> cleanupOldMessages({int keepLastN = 1000}) async {
    final conversations = await getConversations();

    for (final conversation in conversations) {
      final allMessages = await _isar.localMessages
          .where()
          .conversationIdEqualTo(conversation.serverId)
          .sortByCreatedAtDesc()
          .findAll();

      if (allMessages.length > keepLastN) {
        final messagesToDelete = allMessages.skip(keepLastN).toList();

        await _isar.writeTxn(() async {
          for (final message in messagesToDelete) {
            await _isar.localMessages.delete(message.id);
          }
        });
      }
    }
  }

  /// Clear all chat data (logout)
  static Future<void> clearAllData() async {
    await _isar.writeTxn(() async {
      await _isar.localMessages.clear();
      await _isar.localConversations.clear();
      await _isar.localUsers.clear();
    });
  }
}
