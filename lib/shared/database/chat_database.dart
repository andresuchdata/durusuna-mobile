import 'dart:io';
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
    try {
      await _isar.writeTxn(() async {
        // Enhanced duplicate checking for both serverId and content+time
        if (message.serverId != null) {
          final existingByServerId = await _isar.localMessages
              .where()
              .serverIdEqualTo(message.serverId!)
              .findFirst();
          if (existingByServerId != null) {
            return;
          }
        }

        // Additional check: Look for optimistic messages that match content and time
        // This catches cases where optimistic -> server ID update -> real-time duplicate
        final potentialDuplicates = await _isar.localMessages
            .where()
            .conversationIdEqualTo(message.conversationId)
            .filter()
            .contentEqualTo(message.content)
            .and()
            .senderIdEqualTo(message.senderId)
            .findAll();

        for (final existing in potentialDuplicates) {
          // Check if timestamps are very close (within 5 seconds)
          final timeDiff =
              message.createdAt.difference(existing.createdAt).abs();
          if (timeDiff.inSeconds <= 5) {
            return;
          }
        }

        await _isar.localMessages.put(message);
      });
    } catch (e) {
      if (e.toString().contains('Unique index violated')) {
        // Duplicate message, ignore silently
        return;
      }
      rethrow; // Re-throw other errors
    }
  }

  /// Save and return assigned local Id (also updates message.id)
  static Future<int> saveMessageAndReturnId(LocalMessage message) async {
    await saveMessage(message);
    return message.id;
  }

  /// Try to adopt a server message into an existing optimistic local row.
  /// If a matching optimistic message is found, we upgrade it with server fields
  /// and do NOT insert a new row. Returns true if adopted, false otherwise.
  static Future<bool> adoptServerMessage(LocalMessage serverMessage) async {

    return await _isar.writeTxn(() async {
      // 1) Try match by clientMessageId first (best-effort, in-memory scan to avoid codegen dependency)
      if (serverMessage.clientMessageId != null) {
        final allInConv = await _isar.localMessages
            .where()
            .conversationIdEqualTo(serverMessage.conversationId)
            .findAll();

        final optimistic = allInConv.firstWhere(
          (m) => m.clientMessageId == serverMessage.clientMessageId,
          orElse: () => LocalMessage(
            serverId: null,
            clientMessageId: null,
            conversationId: '',
            senderId: '',
            content: null,
            messageType: LocalMessageType.text,
            replyToId: null,
            replyToContent: null,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: null,
            readAt: null,
            deliveredAt: null,
            isFromMe: false,
            readStatus: 'sent',
            isSynced: true,
            needsUpload: false,
            attachmentUrl: null,
            attachmentType: null,
            attachmentSize: null,
            thumbnailPath: null,
            metadataJson: null,
            reactions: null,
          ),
        );
        // Check sentinel
        if (optimistic.conversationId.isNotEmpty) {
          final upgraded = optimistic.copyWith(
            serverId: serverMessage.serverId,
            isSynced: true,
            readStatus: serverMessage.readStatus ?? optimistic.readStatus,
            createdAt: serverMessage.createdAt,
            updatedAt: serverMessage.updatedAt,
            deliveredAt: serverMessage.deliveredAt,
            readAt: serverMessage.readAt,
            metadataJson: serverMessage.metadataJson,
            attachmentUrl: serverMessage.attachmentUrl,
            attachmentType: serverMessage.attachmentType,
            attachmentSize: serverMessage.attachmentSize,
            thumbnailPath: serverMessage.thumbnailPath,
            reactions: serverMessage.reactions,
          );
          await _isar.localMessages.put(upgraded);
          // Cleanup any other optimistic duplicates (same content, same sender) after adoption
          try {
            final duplicates = await _isar.localMessages
                .where()
                .conversationIdEqualTo(serverMessage.conversationId)
                .filter()
                .serverIdIsNull()
                .and()
                .isFromMeEqualTo(true)
                .and()
                .contentEqualTo(serverMessage.content)
                .findAll();
            for (final dup in duplicates) {
              if (dup.id != upgraded.id) {
                await _isar.localMessages.delete(dup.id);
              }
            }
          } catch (_) {}
          return true;
        } else {
        }
      }

      // If a row with this serverId already exists, ensure it's marked synced and exit
      final existingServer = await _isar.localMessages
          .where()
          .serverIdEqualTo(serverMessage.serverId ?? '')
          .findFirst();
      if (existingServer != null) {
        final updated = existingServer.copyWith(
          isSynced: true,
          readStatus: existingServer.readStatus ?? 'sent',
          updatedAt: serverMessage.updatedAt ?? existingServer.updatedAt,
          deliveredAt: serverMessage.deliveredAt ?? existingServer.deliveredAt,
          readAt: serverMessage.readAt ?? existingServer.readAt,
        );
        await _isar.localMessages.put(updated);
        // Cleanup any leftover optimistic duplicates with same content
        try {
          final duplicates = await _isar.localMessages
              .where()
              .conversationIdEqualTo(serverMessage.conversationId)
              .filter()
              .serverIdIsNull()
              .and()
              .isFromMeEqualTo(true)
              .and()
              .contentEqualTo(serverMessage.content)
              .findAll();
          for (final dup in duplicates) {
            await _isar.localMessages.delete(dup.id);
          }
        } catch (_) {}
        return true;
      }

      // Find candidates: same conversation, no serverId, same author and content
      final candidates = await _isar.localMessages
          .where()
          .conversationIdEqualTo(serverMessage.conversationId)
          .filter()
          .serverIdIsNull()
          .and()
          .isFromMeEqualTo(serverMessage.isFromMe)
          .and()
          .contentEqualTo(serverMessage.content)
          .findAll();

      LocalMessage? best;
      Duration bestDiff = const Duration(days: 3650);
      for (final m in candidates) {
        final diff = m.createdAt.difference(serverMessage.createdAt).abs();
        if (diff < bestDiff) {
          best = m;
          bestDiff = diff;
        }
      }

      // Accept if reasonably close (<= 60s)
      if (best != null && bestDiff.inSeconds <= 60) {
        final upgraded = best.copyWith(
          serverId: serverMessage.serverId,
          isSynced: true,
          readStatus: serverMessage.readStatus ?? best.readStatus,
          createdAt: serverMessage.createdAt,
          updatedAt: serverMessage.updatedAt,
          deliveredAt: serverMessage.deliveredAt,
          readAt: serverMessage.readAt,
          metadataJson: serverMessage.metadataJson,
          attachmentUrl: serverMessage.attachmentUrl,
          attachmentType: serverMessage.attachmentType,
          attachmentSize: serverMessage.attachmentSize,
          thumbnailPath: serverMessage.thumbnailPath,
          reactions: serverMessage.reactions,
        );
        await _isar.localMessages.put(upgraded);
        // Cleanup any other optimistic duplicates (same content, same sender)
        try {
          final duplicates = await _isar.localMessages
              .where()
              .conversationIdEqualTo(serverMessage.conversationId)
              .filter()
              .serverIdIsNull()
              .and()
              .isFromMeEqualTo(true)
              .and()
              .contentEqualTo(serverMessage.content)
              .findAll();
          for (final dup in duplicates) {
            if (dup.id != upgraded.id) {
              await _isar.localMessages.delete(dup.id);
            }
          }
        } catch (_) {}
        return true;
      }

      // No adopt candidate; insert new server row directly within this txn (no nested txn)
      try {
        await _isar.localMessages.put(serverMessage);
        // Cleanup any leftover optimistic duplicates (same content, same sender)
        try {
          final duplicates = await _isar.localMessages
              .where()
              .conversationIdEqualTo(serverMessage.conversationId)
              .filter()
              .serverIdIsNull()
              .and()
              .isFromMeEqualTo(true)
              .and()
              .contentEqualTo(serverMessage.content)
              .findAll();
          for (final dup in duplicates) {
            await _isar.localMessages.delete(dup.id);
          }
        } catch (_) {}
        return false;
      } catch (e) {
        // Handle race: unique index may be taken by another concurrent save
        final isUnique = e.toString().contains('Unique index violated');
        if (isUnique && serverMessage.serverId != null) {
          final existing = await _isar.localMessages
              .where()
              .serverIdEqualTo(serverMessage.serverId!)
              .findFirst();
          if (existing != null) {
            final updated = existing.copyWith(
              isSynced: true,
              readStatus: existing.readStatus ?? 'sent',
              updatedAt: serverMessage.updatedAt ?? existing.updatedAt,
              deliveredAt: serverMessage.deliveredAt ?? existing.deliveredAt,
              readAt: serverMessage.readAt ?? existing.readAt,
            );
            await _isar.localMessages.put(updated);
            return true;
          }
        }
        rethrow;
      }
    });
  }

  /// Save multiple messages (batch operation for sync)
  static Future<void> saveMessages(List<LocalMessage> messages) async {
    // Important: use the single-save path to leverage duplicate checks
    for (final message in messages) {
      try {
        await saveMessage(message);
      } catch (_) {
        // Ignore duplicates or transient errors for individual items
      }
    }
  }

  /// Get all messages (for debugging)
  static Future<List<LocalMessage>> getAllMessages() async {
    return await _isar.localMessages.where().findAll();
  }

  /// Debug method: Get conversation IDs in database
  static Future<Set<String>> getAllConversationIds() async {
    final messages = await _isar.localMessages.where().findAll();
    return messages.map((m) => m.conversationId).toSet();
  }

  /// Debug method: Print detailed info about a conversation
  static Future<void> debugConversation(String conversationId) async {

    final messages = await _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAt()
        .findAll();


    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
    }

  }

  /// Get message by local ID
  static Future<LocalMessage?> getMessage(String localId) async {
    final intLocalId = int.tryParse(localId);
    if (intLocalId == null) return null;
    return await _isar.localMessages.get(intLocalId);
  }

  /// Get message by server ID
  static Future<LocalMessage?> getMessageByServerId(String serverId) async {
    return await _isar.localMessages
        .where()
        .serverIdEqualTo(serverId)
        .findFirst();
  }

  /// Get messages for conversation (instant loading)
  /// Returns messages in chronological order (oldest first) for proper chat display
  static Future<List<LocalMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAt() // chronological order (oldest first)
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Get latest N messages for conversation, returned in chronological order
  /// Fetches using descending sort for efficiency, then reverses for UI
  static Future<List<LocalMessage>> getLatestMessages(
    String conversationId, {
    int limit = 50,
    int offsetFromLatest = 0,
  }) async {
    final desc = await _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .offset(offsetFromLatest)
        .limit(limit)
        .findAll();
    return desc.reversed.toList(growable: false);
  }

  /// Watch messages for a conversation as a stream.
  /// Emits updates whenever the underlying data changes.
  /// Results are in chronological order (oldest first) for UI rendering.
  static Stream<List<LocalMessage>> watchMessages(
    String conversationId, {
    int? limit,
  }) {

    final query = _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAt();

    // Isar doesn't support limit directly on watch queries; consumers can trim.
    return query.watch(fireImmediately: true).map((messages) {
      for (int i = 0; i < messages.length && i < 3; i++) {
      }

      if (limit != null && messages.length > limit) {
        return messages.sublist(messages.length - limit);
      }
      return messages;
    });
  }

  /// Get pending optimistic messages for a conversation (unsynced or 'sending').
  static Future<List<LocalMessage>> getPendingMessagesForConversation(
      String conversationId) async {
    final unsynced = await _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    // Include any rows marked 'sending' defensively
    final sending = await _isar.localMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .filter()
        .readStatusEqualTo('sending')
        .findAll();

    // Merge by id
    final byId = <int, LocalMessage>{};
    for (final m in [...unsynced, ...sending]) {
      byId[m.id] = m;
    }
    return byId.values.toList();
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
          .sortByCreatedAt() // Changed to chronological order for consistency
          .limit(limit)
          .findAll();
    } else {
      return await _isar.localMessages
          .filter()
          .contentContains(query, caseSensitive: false)
          .sortByCreatedAt() // Changed to chronological order for consistency
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
    try {
      await _isar.writeTxn(() async {
        final message = await _isar.localMessages
            .where()
            .serverIdEqualTo(messageId)
            .findFirst();
        if (message != null) {
          // Only update if status actually changed
          if (message.readStatus != readStatus) {
            final updated = message.copyWith(
              readStatus: readStatus,
              readAt: readAt,
              deliveredAt: deliveredAt,
            );
            await _isar.localMessages.put(updated);
          }
        }
      });
    } catch (e) {
      if (e.toString().contains('Unique index violated')) {
        // Message status update conflict - ignore silently
        return;
      }
      rethrow; // Re-throw other errors
    }
  }

  // Update reactions JSON for a message by serverId or local id
  static Future<void> updateMessageReactions({
    String? serverId,
    int? localId,
    required String reactionsJson,
  }) async {
    await _isar.writeTxn(() async {
      LocalMessage? target;
      if (serverId != null) {
        target = await _isar.localMessages
            .where()
            .serverIdEqualTo(serverId)
            .findFirst();
      } else if (localId != null) {
        target = await _isar.localMessages.get(localId);
      }

      if (target != null) {
        final updated = target.copyWith(reactions: reactionsJson);
        await _isar.localMessages.put(updated);
      }
    });
  }

  /// Delete message locally (and remove from pending sync)
  static Future<void> deleteMessage(String messageId) async {
    await _isar.writeTxn(() async {
      // Try to find by serverId first
      LocalMessage? message = await _isar.localMessages
          .where()
          .serverIdEqualTo(messageId)
          .findFirst();

      // If not found by serverId, try by local ID (for unsent messages)
      if (message == null) {
        try {
          final intId = int.parse(messageId);
          message =
              await _isar.localMessages.where().idEqualTo(intId).findFirst();
        } catch (e) {
          // messageId is not an int, so it's not a local ID
        }
      }

      if (message != null) {
        await _isar.localMessages.delete(message.id);
      } else {
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
      final conversation = await _isar.localConversations
          .filter()
          .serverIdEqualTo(conversationId)
          .findFirst();

      if (conversation != null && conversation.unreadCount > 0) {
        // Update in place to avoid unique index violations
        conversation.unreadCount = 0;
        await _isar.localConversations.put(conversation);
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

  /// Get messages that need to be synced to server (excluding failed messages)
  static Future<List<LocalMessage>> getPendingSyncMessages() async {
    final pendingMessages =
        await _isar.localMessages.where().isSyncedEqualTo(false).findAll();

    // Filter out messages that are marked as failed (serverId starts with 'failed_')
    final validPendingMessages = pendingMessages.where((message) {
      if (message.serverId != null && message.serverId!.startsWith('failed_')) {
        return false; // Skip failed messages
      }
      return true;
    }).toList();

    return validPendingMessages;
  }

  /// Remove message from pending sync queue (mark as synced or delete)
  static Future<void> removePendingMessage(String messageId) async {
    await _isar.writeTxn(() async {
      // Try to find by serverId first
      LocalMessage? message = await _isar.localMessages
          .where()
          .serverIdEqualTo(messageId)
          .findFirst();

      // If not found by serverId, try by local ID
      if (message == null) {
        try {
          final intId = int.parse(messageId);
          message =
              await _isar.localMessages.where().idEqualTo(intId).findFirst();
        } catch (e) {
          // messageId is not an int
        }
      }

      if (message != null && !message.isSynced) {
        // Mark as synced with special 'deleted' serverId to prevent future sync
        final updated = message.copyWith(
          isSynced: true,
          serverId: 'deleted_${DateTime.now().millisecondsSinceEpoch}',
        );
        await _isar.localMessages.put(updated);
      }
    });
  }

  /// Mark message as synced
  static Future<void> markMessageSynced(String localId, String serverId) async {
    await _isar.writeTxn(() async {
      // If a row with this serverId already exists, merge by removing the optimistic one
      final existingByServerId = await _isar.localMessages
          .where()
          .serverIdEqualTo(serverId)
          .findFirst();

      // Try to get the optimistic (local) message row by local id
      final intLocalId = int.tryParse(localId);
      final optimisticLocal =
          intLocalId != null ? await _isar.localMessages.get(intLocalId) : null;

      if (existingByServerId != null) {
        // Ensure server row is marked synced and has at least 'sent' status
        final updatedServerRow = existingByServerId.copyWith(
          isSynced: true,
          readStatus: existingByServerId.readStatus ?? 'sent',
        );
        await _isar.localMessages.put(updatedServerRow);

        // Remove optimistic duplicate if present
        if (optimisticLocal != null &&
            optimisticLocal.id != updatedServerRow.id) {
          await _isar.localMessages.delete(optimisticLocal.id);
        }
        return;
      }

      // No server row exists yet: upgrade the optimistic row to the server-backed row
      if (optimisticLocal != null) {
        // If optimistic already has a different serverId, keep first serverId
        if (optimisticLocal.serverId != null &&
            optimisticLocal.serverId != serverId) {
        } else {
          final updated = optimisticLocal.copyWith(
            serverId: serverId,
            isSynced: true,
            readStatus: 'sent',
          );
          await _isar.localMessages.put(updated);
        }
      } else {
      }
    });
  }

  /// Mark a local optimistic message as failed to prevent infinite retries.
  /// Sets readStatus='failed', isSynced=true, and assigns a synthetic failed_* serverId.
  static Future<void> markMessageFailed(String localId) async {
    await _isar.writeTxn(() async {
      final intLocalId = int.tryParse(localId);
      if (intLocalId == null) return;
      final message = await _isar.localMessages.get(intLocalId);
      if (message == null) return;
      final updated = message.copyWith(
        isSynced: true, // stop pending sync loops
        readStatus: 'failed',
        serverId: message.serverId ??
            'failed_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _isar.localMessages.put(updated);
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

  /// Force recreate database to fix corruption issues
  static Future<void> forceRecreateDatabase() async {
    try {
      // Close current instance
      if (_initialized) {
        await _isar.close();
        _initialized = false;
      }

      // Delete database files
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/durusuna_chat';
      final dbFile = File('$dbPath.isar');
      final lockFile = File('$dbPath.isar.lock');

      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      if (await lockFile.exists()) {
        await lockFile.delete();
      }

      // Reinitialize fresh database
      await initialize();
    } catch (e) {
      // Fallback to normal initialization
      await initialize();
    }
  }
}
