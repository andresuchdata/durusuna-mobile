import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../models/local_user.dart';
import 'chat_repository.dart';
import 'package:flutter/foundation.dart';

/// SQLite implementation of the chat repository
class SQLiteChatRepository implements ChatRepository {
  Database? _database;
  bool _initialized = false;
  static const int _version = 1;

  // Database name
  static const String _dbName = 'durusuna_chat.db';

  // Table names
  static const String _messagesTable = 'local_messages';
  static const String _conversationsTable = 'local_conversations';
  static const String _usersTable = 'local_users';

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, _dbName);

    _database = await openDatabase(
      dbPath,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    _initialized = true;
    debugPrint('✅ [SQLite] Repository initialized successfully');
  }

  @override
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _initialized = false;
      debugPrint('✅ [SQLite] Repository closed successfully');
    }
  }

  /// Get database instance
  Database get _db {
    if (!_initialized || _database == null) {
      throw StateError('Repository not initialized. Call initialize() first.');
    }
    return _database!;
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Create messages table
    await db.execute('''
      CREATE TABLE $_messagesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        client_message_id TEXT UNIQUE,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT,
        message_type TEXT NOT NULL,
        reply_to_id TEXT,
        reply_to_content TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        read_at TEXT,
        delivered_at TEXT,
        is_from_me INTEGER NOT NULL,
        read_status TEXT DEFAULT 'sent',
        is_synced INTEGER NOT NULL DEFAULT 0,
        needs_upload INTEGER NOT NULL DEFAULT 0,
        attachment_url TEXT,
        attachment_type TEXT,
        attachment_size INTEGER,
        thumbnail_path TEXT,
        metadata_json TEXT,
        reactions TEXT,
        created_at_timestamp INTEGER NOT NULL,
        updated_at_timestamp INTEGER,
        read_at_timestamp INTEGER,
        delivered_at_timestamp INTEGER
      )
    ''');

    // Create conversations table
    await db.execute('''
      CREATE TABLE $_conversationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        name TEXT,
        description TEXT,
        avatar_url TEXT,
        other_user_id TEXT,
        other_user_name TEXT,
        other_user_avatar TEXT,
        last_message TEXT,
        last_message_at TEXT,
        last_activity TEXT NOT NULL,
        unread_count INTEGER DEFAULT 0,
        is_online INTEGER DEFAULT 0,
        is_muted INTEGER DEFAULT 0,
        is_pinned INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        participants_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        created_at_timestamp INTEGER NOT NULL,
        updated_at_timestamp INTEGER
      )
    ''');

    // Create users table
    await db.execute('''
      CREATE TABLE $_usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        avatar_url TEXT,
        phone TEXT,
        user_type TEXT NOT NULL,
        school_id TEXT,
        school_name TEXT,
        is_contact INTEGER DEFAULT 0,
        is_blocked INTEGER DEFAULT 0,
        is_online INTEGER DEFAULT 0,
        last_seen TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        created_at_timestamp INTEGER NOT NULL,
        updated_at_timestamp INTEGER
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_messages_conversation_id ON $_messagesTable(conversation_id)');
    await db.execute(
        'CREATE INDEX idx_messages_sender_id ON $_messagesTable(sender_id)');
    await db.execute(
        'CREATE INDEX idx_messages_created_at ON $_messagesTable(created_at_timestamp)');
    await db.execute(
        'CREATE INDEX idx_messages_is_synced ON $_messagesTable(is_synced)');
    await db.execute(
        'CREATE INDEX idx_messages_read_status ON $_messagesTable(read_status)');
    await db.execute(
        'CREATE INDEX idx_messages_server_id ON $_messagesTable(server_id)');
    await db.execute(
        'CREATE INDEX idx_messages_client_message_id ON $_messagesTable(client_message_id)');

    debugPrint('✅ [SQLite] Database tables created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        '🔄 [SQLite] Database upgraded from v$oldVersion to v$newVersion');
  }

  // ========== MESSAGE OPERATIONS ==========

  @override
  Future<void> saveMessage(LocalMessage message) async {
    try {
      // Check for existing message by serverId
      if (message.serverId != null) {
        final existing = await _db.query(
          _messagesTable,
          where: 'server_id = ?',
          whereArgs: [message.serverId],
        );

        if (existing.isNotEmpty) {
          final existingMessage = existing.first;
          if (existingMessage['conversation_id'] != message.conversationId) {
            // Migrate to correct conversation
            await _updateMessageConversation(
                message.serverId!, message.conversationId);
            debugPrint(
                '🔄 [SQLite] Migrated message ${message.serverId} to conversation ${message.conversationId}');
            return;
          } else {
            // Update existing message
            await _updateMessage(message);
            return;
          }
        }
      }

      // Check for existing message by clientMessageId
      if (message.clientMessageId != null) {
        final existing = await _db.query(
          _messagesTable,
          where: 'client_message_id = ?',
          whereArgs: [message.clientMessageId],
        );

        if (existing.isNotEmpty) {
          // Update existing message
          await _updateMessage(message);
          return;
        }
      }

      // Insert new message
      await _db.insert(_messagesTable, _messageToMap(message));
      final contentPreview =
          message.content != null && message.content!.length > 20
              ? '${message.content!.substring(0, 20)}...'
              : message.content ?? 'No content';
      debugPrint('✅ [SQLite] New message saved: $contentPreview');
    } catch (e) {
      debugPrint('❌ [SQLite] Error saving message: $e');
      rethrow;
    }
  }

  /// Update existing message
  Future<void> _updateMessage(LocalMessage message) async {
    final updateData = <String, dynamic>{};

    if (message.updatedAt != null) {
      updateData['updated_at'] = message.updatedAt!.toIso8601String();
    }
    if (message.readAt != null) {
      updateData['read_at'] = message.readAt!.toIso8601String();
    }
    if (message.deliveredAt != null) {
      updateData['delivered_at'] = message.deliveredAt!.toIso8601String();
    }
    if (message.readStatus != null) {
      updateData['read_status'] = message.readStatus;
    }
    if (message.metadataJson != null) {
      updateData['metadata_json'] = message.metadataJson;
    }
    if (message.attachmentUrl != null) {
      updateData['attachment_url'] = message.attachmentUrl;
    }
    if (message.attachmentType != null) {
      updateData['attachment_type'] = message.attachmentType;
    }
    if (message.attachmentSize != null) {
      updateData['attachment_size'] = message.attachmentSize;
    }
    if (message.thumbnailPath != null) {
      updateData['thumbnail_path'] = message.thumbnailPath;
    }
    if (message.reactions != null) {
      updateData['reactions'] = message.reactions;
    }

    updateData['is_synced'] = message.isSynced ? 1 : 0;
    updateData['updated_at_timestamp'] =
        message.updatedAt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch;

    String whereClause;
    List<dynamic> whereArgs;

    if (message.serverId != null) {
      whereClause = 'server_id = ?';
      whereArgs = [message.serverId];
    } else if (message.clientMessageId != null) {
      whereClause = 'client_message_id = ?';
      whereArgs = [message.clientMessageId];
    } else {
      throw ArgumentError(
          'Message must have either serverId or clientMessageId');
    }

    await _db.update(
      _messagesTable,
      updateData,
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Update message conversation (for migration)
  Future<void> _updateMessageConversation(
      String serverId, String newConversationId) async {
    await _db.update(
      _messagesTable,
      {
        'conversation_id': newConversationId,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_at_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
  }

  @override
  Future<List<LocalMessage>> getConversationMessages(
    String conversationId, {
    int? limit,
    int? offset,
  }) async {
    try {
      String query =
          'SELECT * FROM $_messagesTable WHERE conversation_id = ? ORDER BY created_at_timestamp DESC';
      List<dynamic> args = [conversationId];

      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }

      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }

      final results = await _db.rawQuery(query, args);
      return results.map((row) => _mapToMessage(row)).toList();
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting conversation messages: $e');
      rethrow;
    }
  }

  @override
  Future<LocalMessage?> getMessage(int localId) async {
    try {
      final results = await _db.query(
        _messagesTable,
        where: 'id = ?',
        whereArgs: [localId],
      );

      if (results.isNotEmpty) {
        return _mapToMessage(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting message: $e');
      rethrow;
    }
  }

  @override
  Future<LocalMessage?> getMessageByServerId(String serverId) async {
    try {
      final results = await _db.query(
        _messagesTable,
        where: 'server_id = ?',
        whereArgs: [serverId],
      );

      if (results.isNotEmpty) {
        return _mapToMessage(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting message by server ID: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalMessage>> getUnsyncedMessages() async {
    try {
      final results = await _db.query(
        _messagesTable,
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'created_at_timestamp DESC',
      );

      return results.map((row) => _mapToMessage(row)).toList();
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting unsynced messages: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalMessage>> getMessagesByStatus(String status) async {
    try {
      final results = await _db.query(
        _messagesTable,
        where: 'read_status = ?',
        whereArgs: [status],
        orderBy: 'created_at_timestamp DESC',
      );

      return results.map((row) => _mapToMessage(row)).toList();
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting messages by status: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(int localId) async {
    try {
      await _db.delete(
        _messagesTable,
        where: 'id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      debugPrint('❌ [SQLite] Error deleting message: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDuplicateMessages() async {
    try {
      // Delete duplicates based on server_id
      await _db.execute('''
        DELETE FROM $_messagesTable 
        WHERE id NOT IN (
          SELECT MIN(id) 
          FROM $_messagesTable 
          WHERE server_id IS NOT NULL 
          GROUP BY server_id
        )
        AND server_id IS NOT NULL
      ''');

      // Delete duplicates based on client_message_id
      await _db.execute('''
        DELETE FROM $_messagesTable 
        WHERE id NOT IN (
          SELECT MIN(id) 
          FROM $_messagesTable 
          WHERE client_message_id IS NOT NULL 
          GROUP BY client_message_id
        )
        AND client_message_id IS NOT NULL
      ''');

      debugPrint('✅ [SQLite] Duplicate messages cleaned up');
    } catch (e) {
      debugPrint('❌ [SQLite] Error deleting duplicate messages: $e');
    }
  }

  // ========== CONVERSATION OPERATIONS ==========

  @override
  Future<void> saveConversation(LocalConversation conversation) async {
    try {
      final existing = await _db.query(
        _conversationsTable,
        where: 'server_id = ?',
        whereArgs: [conversation.serverId],
      );

      if (existing.isNotEmpty) {
        // Update existing conversation
        await _db.update(
          _conversationsTable,
          _conversationToMap(conversation),
          where: 'server_id = ?',
          whereArgs: [conversation.serverId],
        );
      } else {
        // Insert new conversation
        await _db.insert(_conversationsTable, _conversationToMap(conversation));
      }
    } catch (e) {
      debugPrint('❌ [SQLite] Error saving conversation: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocalConversation>> getAllConversations() async {
    try {
      final results = await _db.query(
        _conversationsTable,
        orderBy: 'updated_at_timestamp DESC',
      );

      return results.map((row) => _mapToConversation(row)).toList();
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting conversations: $e');
      rethrow;
    }
  }

  @override
  Future<LocalConversation?> getConversation(String conversationId) async {
    try {
      final results = await _db.query(
        _conversationsTable,
        where: 'server_id = ?',
        whereArgs: [conversationId],
      );

      if (results.isNotEmpty) {
        return _mapToConversation(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting conversation: $e');
      rethrow;
    }
  }

  // ========== USER OPERATIONS ==========

  @override
  Future<void> saveUser(LocalUser user) async {
    try {
      final existing = await _db.query(
        _usersTable,
        where: 'server_id = ?',
        whereArgs: [user.serverId],
      );

      if (existing.isNotEmpty) {
        // Update existing user
        await _db.update(
          _usersTable,
          _userToMap(user),
          where: 'server_id = ?',
          whereArgs: [user.serverId],
        );
      } else {
        // Insert new user
        await _db.insert(_usersTable, _userToMap(user));
      }
    } catch (e) {
      debugPrint('❌ [SQLite] Error saving user: $e');
      rethrow;
    }
  }

  @override
  Future<LocalUser?> getUser(String userId) async {
    try {
      final results = await _db.query(
        _usersTable,
        where: 'server_id = ?',
        whereArgs: [userId],
      );

      if (results.isNotEmpty) {
        return _mapToUser(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting user: $e');
      rethrow;
    }
  }

  // ========== UTILITY METHODS ==========

  @override
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final messageCount = Sqflite.firstIntValue(
              await _db.rawQuery('SELECT COUNT(*) FROM $_messagesTable')) ??
          0;

      final conversationCount = Sqflite.firstIntValue(await _db
              .rawQuery('SELECT COUNT(*) FROM $_conversationsTable')) ??
          0;

      final userCount = Sqflite.firstIntValue(
              await _db.rawQuery('SELECT COUNT(*) FROM $_usersTable')) ??
          0;

      return {
        'messages': messageCount,
        'conversations': conversationCount,
        'users': userCount,
      };
    } catch (e) {
      debugPrint('❌ [SQLite] Error getting database stats: $e');
      return {'messages': 0, 'conversations': 0, 'users': 0};
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      await _db.delete(_messagesTable);
      await _db.delete(_conversationsTable);
      await _db.delete(_usersTable);
      debugPrint('✅ [SQLite] All data cleared');
    } catch (e) {
      debugPrint('❌ [SQLite] Error clearing data: $e');
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
        'databaseType': 'SQLite',
        'stats': stats,
        'initialized': _initialized,
        'version': _version,
      };
    } catch (e) {
      return {
        'isHealthy': false,
        'databaseType': 'SQLite',
        'error': e.toString(),
        'initialized': _initialized,
      };
    }
  }

  // ========== DATA CONVERSION METHODS ==========

  /// Convert LocalMessage to Map for database
  Map<String, dynamic> _messageToMap(LocalMessage message) {
    return {
      'server_id': message.serverId,
      'client_message_id': message.clientMessageId,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'content': message.content,
      'message_type': message.messageType.name,
      'reply_to_id': message.replyToId,
      'reply_to_content': message.replyToContent,
      'created_at': message.createdAt.toIso8601String(),
      'updated_at': message.updatedAt?.toIso8601String(),
      'read_at': message.readAt?.toIso8601String(),
      'delivered_at': message.deliveredAt?.toIso8601String(),
      'is_from_me': message.isFromMe ? 1 : 0,
      'read_status': message.readStatus,
      'is_synced': message.isSynced ? 1 : 0,
      'needs_upload': message.needsUpload ? 1 : 0,
      'attachment_url': message.attachmentUrl,
      'attachment_type': message.attachmentType,
      'attachment_size': message.attachmentSize,
      'thumbnail_path': message.thumbnailPath,
      'metadata_json': message.metadataJson,
      'reactions': message.reactions,
      'created_at_timestamp': message.createdAt.millisecondsSinceEpoch,
      'updated_at_timestamp': message.updatedAt?.millisecondsSinceEpoch,
      'read_at_timestamp': message.readAt?.millisecondsSinceEpoch,
      'delivered_at_timestamp': message.deliveredAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert Map from database to LocalMessage
  LocalMessage _mapToMessage(Map<String, dynamic> row) {
    return LocalMessage(
      serverId: row['server_id'],
      clientMessageId: row['client_message_id'],
      conversationId: row['conversation_id'],
      senderId: row['sender_id'],
      content: row['content'],
      messageType: LocalMessageType.values.firstWhere(
        (e) => e.name == row['message_type'],
        orElse: () => LocalMessageType.text,
      ),
      replyToId: row['reply_to_id'],
      replyToContent: row['reply_to_content'],
      createdAt: DateTime.parse(row['created_at']),
      updatedAt:
          row['updated_at'] != null ? DateTime.parse(row['updated_at']) : null,
      readAt: row['read_at'] != null ? DateTime.parse(row['read_at']) : null,
      deliveredAt: row['delivered_at'] != null
          ? DateTime.parse(row['delivered_at'])
          : null,
      isFromMe: row['is_from_me'] == 1,
      readStatus: row['read_status'],
      isSynced: row['is_synced'] == 1,
      needsUpload: row['needs_upload'] == 1,
      attachmentUrl: row['attachment_url'],
      attachmentType: row['attachment_type'],
      attachmentSize: row['attachment_size'],
      thumbnailPath: row['thumbnail_path'],
      metadataJson: row['metadata_json'],
      reactions: row['reactions'],
    );
  }

  /// Convert LocalConversation to Map for database
  Map<String, dynamic> _conversationToMap(LocalConversation conversation) {
    return {
      'server_id': conversation.serverId,
      'type': conversation.type.name,
      'name': conversation.name,
      'description': conversation.description,
      'avatar_url': conversation.avatarUrl,
      'other_user_id': conversation.otherUserId,
      'other_user_name': conversation.otherUserName,
      'other_user_avatar': conversation.otherUserAvatar,
      'last_message': conversation.lastMessage,
      'last_message_at': conversation.lastMessageAt?.toIso8601String(),
      'last_activity': conversation.lastActivity.toIso8601String(),
      'unread_count': conversation.unreadCount,
      'is_online': conversation.isOnline ? 1 : 0,
      'is_muted': conversation.isMuted ? 1 : 0,
      'is_pinned': conversation.isPinned ? 1 : 0,
      'is_archived': conversation.isArchived ? 1 : 0,
      'participants_json': conversation.participantsJson,
      'created_at': conversation.createdAt.toIso8601String(),
      'updated_at': conversation.updatedAt?.toIso8601String(),
      'created_at_timestamp': conversation.createdAt.millisecondsSinceEpoch,
      'updated_at_timestamp': conversation.updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert Map from database to LocalConversation
  LocalConversation _mapToConversation(Map<String, dynamic> row) {
    return LocalConversation(
      serverId: row['server_id'],
      type: LocalConversationType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => LocalConversationType.direct,
      ),
      name: row['name'],
      description: row['description'],
      avatarUrl: row['avatar_url'],
      otherUserId: row['other_user_id'],
      otherUserName: row['other_user_name'],
      otherUserAvatar: row['other_user_avatar'],
      lastMessage: row['last_message'],
      lastMessageAt: row['last_message_at'] != null
          ? DateTime.parse(row['last_message_at'])
          : null,
      lastActivity: DateTime.parse(row['last_activity']),
      unreadCount: row['unread_count'] ?? 0,
      isOnline: row['is_online'] == 1,
      isMuted: row['is_muted'] == 1,
      isPinned: row['is_pinned'] == 1,
      isArchived: row['is_archived'] == 1,
      participantsJson: row['participants_json'],
      createdAt: DateTime.parse(row['created_at']),
      updatedAt:
          row['updated_at'] != null ? DateTime.parse(row['updated_at']) : null,
    );
  }

  /// Convert LocalUser to Map for database
  Map<String, dynamic> _userToMap(LocalUser user) {
    return {
      'server_id': user.serverId,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'email': user.email,
      'avatar_url': user.avatarUrl,
      'phone': user.phone,
      'user_type': user.userType.name,
      'school_id': user.schoolId,
      'school_name': user.schoolName,
      'is_contact': user.isContact ? 1 : 0,
      'is_blocked': user.isBlocked ? 1 : 0,
      'is_online': user.isOnline ? 1 : 0,
      'last_seen': user.lastSeen?.toIso8601String(),
      'created_at': user.createdAt.toIso8601String(),
      'updated_at': user.updatedAt?.toIso8601String(),
      'created_at_timestamp': user.createdAt.millisecondsSinceEpoch,
      'updated_at_timestamp': user.updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert Map from database to LocalUser
  LocalUser _mapToUser(Map<String, dynamic> row) {
    return LocalUser(
      serverId: row['server_id'],
      firstName: row['first_name'],
      lastName: row['last_name'],
      email: row['email'],
      avatarUrl: row['avatar_url'],
      phone: row['phone'],
      userType: LocalUserType.values.firstWhere(
        (e) => e.name == row['user_type'],
        orElse: () => LocalUserType.student,
      ),
      schoolId: row['school_id'],
      schoolName: row['school_name'],
      isContact: row['is_contact'] == 1,
      isBlocked: row['is_blocked'] == 1,
      isOnline: row['is_online'] == 1,
      lastSeen:
          row['last_seen'] != null ? DateTime.parse(row['last_seen']) : null,
      createdAt: DateTime.parse(row['created_at']),
      updatedAt:
          row['updated_at'] != null ? DateTime.parse(row['updated_at']) : null,
    );
  }
}
