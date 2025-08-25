import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../models/local_user.dart';
import 'chat_repository.dart';
import 'package:flutter/foundation.dart';

/// Isar implementation of the chat repository (fallback option)
class IsarChatRepository implements ChatRepository {
  Isar? _isar;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();

    try {
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
      debugPrint('✅ [Isar] Repository initialized successfully');
    } catch (e) {
      debugPrint('❌ [Isar] Repository initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_isar != null) {
      await _isar!.close();
      _isar = null;
      _initialized = false;
      debugPrint('✅ [Isar] Repository closed successfully');
    }
  }

  /// Get Isar instance
  Isar get _db {
    if (!_initialized || _isar == null) {
      throw StateError('Repository not initialized. Call initialize() first.');
    }
    return _isar!;
  }

  // ========== MESSAGE OPERATIONS ==========

  @override
  Future<void> saveMessage(LocalMessage message) async {
    try {
      await _db.writeTxn(() async {
        await _db.localMessages.put(message);
      });
      debugPrint('✅ [Isar] Message saved successfully');
    } catch (e) {
      debugPrint('❌ [Isar] Error saving message: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalMessage>> getConversationMessages(
    String conversationId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final messages = await _db.localMessages
          .where()
          .conversationIdEqualTo(conversationId)
          .sortByCreatedAt()
          .limit(limit ?? 1000)
          .findAll();

      if (offset != null && offset > 0) {
        return messages.skip(offset).toList();
      }

      return messages;
    } catch (e) {
      debugPrint('❌ [Isar] Error getting conversation messages: $e');
      rethrow;
    }
  }

  @override
  Future<LocalMessage?> getMessage(int localId) async {
    try {
      return await _db.localMessages.get(localId);
    } catch (e) {
      debugPrint('❌ [Isar] Error getting message: $e');
      rethrow;
    }
  }

  @override
  Future<LocalMessage?> getMessageByServerId(String serverId) async {
    try {
      return await _db.localMessages
          .where()
          .serverIdEqualTo(serverId)
          .findFirst();
    } catch (e) {
      debugPrint('❌ [Isar] Error getting message by server ID: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalMessage>> getUnsyncedMessages() async {
    try {
      return await _db.localMessages.where().isSyncedEqualTo(false).findAll();
    } catch (e) {
      debugPrint('❌ [Isar] Error getting unsynced messages: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalMessage>> getMessagesByStatus(String status) async {
    try {
      return await _db.localMessages
          .where()
          .readStatusEqualTo(status)
          .sortByCreatedAt()
          .findAll();
    } catch (e) {
      debugPrint('❌ [Isar] Error getting messages by status: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(int localId) async {
    try {
      await _db.writeTxn(() async {
        await _db.localMessages.delete(localId);
      });
      debugPrint('✅ [Isar] Message deleted successfully');
    } catch (e) {
      debugPrint('❌ [Isar] Error deleting message: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDuplicateMessages() async {
    try {
      // Get all messages with server IDs
      final messagesWithServerId =
          await _db.localMessages.where().serverIdIsNotNull().findAll();

      // Group by server ID and find duplicates
      final serverIdGroups = <String, List<LocalMessage>>{};
      for (final message in messagesWithServerId) {
        if (message.serverId != null) {
          serverIdGroups.putIfAbsent(message.serverId!, () => []).add(message);
        }
      }

      // Delete duplicates (keep the first one)
      int deletedCount = 0;
      await _db.writeTxn(() async {
        for (final group in serverIdGroups.values) {
          if (group.length > 1) {
            // Sort by creation time and delete all but the first
            group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            for (int i = 1; i < group.length; i++) {
              await _db.localMessages.delete(group[i].id);
              deletedCount++;
            }
          }
        }
      });

      debugPrint('✅ [Isar] Deleted $deletedCount duplicate messages');
    } catch (e) {
      debugPrint('❌ [Isar] Error deleting duplicate messages: $e');
    }
  }

  // ========== CONVERSATION OPERATIONS ==========

  @override
  Future<void> saveConversation(LocalConversation conversation) async {
    try {
      await _db.writeTxn(() async {
        await _db.localConversations.put(conversation);
      });
      debugPrint('✅ [Isar] Conversation saved successfully');
    } catch (e) {
      debugPrint('❌ [Isar] Error saving conversation: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalConversation>> getAllConversations() async {
    try {
      return await _db.localConversations.where().sortByUpdatedAt().findAll();
    } catch (e) {
      debugPrint('❌ [Isar] Error getting conversations: $e');
      rethrow;
    }
  }

  @override
  Future<LocalConversation?> getConversation(String conversationId) async {
    try {
      return await _db.localConversations
          .where()
          .serverIdEqualTo(conversationId)
          .findFirst();
    } catch (e) {
      debugPrint('❌ [Isar] Error getting conversation: $e');
      rethrow;
    }
  }

  // ========== USER OPERATIONS ==========

  @override
  Future<void> saveUser(LocalUser user) async {
    try {
      await _db.writeTxn(() async {
        await _db.localUsers.put(user);
      });
      debugPrint('✅ [Isar] User saved successfully');
    } catch (e) {
      debugPrint('❌ [Isar] Error saving user: $e');
      rethrow;
    }
  }

  @override
  Future<LocalUser?> getUser(String userId) async {
    try {
      return await _db.localUsers.where().serverIdEqualTo(userId).findFirst();
    } catch (e) {
      debugPrint('❌ [Isar] Error getting user: $e');
      rethrow;
    }
  }

  // ========== UTILITY METHODS ==========

  @override
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final messageCount = await _db.localMessages.count();
      final conversationCount = await _db.localConversations.count();
      final userCount = await _db.localUsers.count();

      return {
        'messages': messageCount,
        'conversations': conversationCount,
        'users': userCount,
      };
    } catch (e) {
      debugPrint('❌ [Isar] Error getting database stats: $e');
      return {'messages': 0, 'conversations': 0, 'users': 0};
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      await _db.writeTxn(() async {
        await _db.clear();
      });
      debugPrint('✅ [Isar] All data cleared');
    } catch (e) {
      debugPrint('❌ [Isar] Error clearing data: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final stats = await getDatabaseStats();
      final isHealthy = stats.values.every((count) => count >= 0);

      return {
        'isHealthy': isHealthy,
        'databaseType': 'Isar',
        'stats': stats,
        'initialized': _initialized,
        'version': '3.1.0+1',
      };
    } catch (e) {
      return {
        'isHealthy': false,
        'databaseType': 'Isar',
        'error': e.toString(),
        'initialized': _initialized,
      };
    }
  }
}
