import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../models/local_user.dart';
import 'chat_repository.dart';
import '../services/web_storage_service.dart';

/// Web-compatible chat repository using localStorage
/// This is used when SQLite is not available on web platform
class WebChatRepository implements ChatRepository {
  bool _initialized = false;
  static const String _messagesKey = 'messages';
  static const String _conversationsKey = 'conversations';
  static const String _usersKey = 'users';

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    await WebStorageService.initialize();
    _initialized = true;
    debugPrint('✅ [WebChat] Repository initialized successfully');
  }

  @override
  Future<void> close() async {
    _initialized = false;
    debugPrint('✅ [WebChat] Repository closed successfully');
  }

  // Messages
  @override
  Future<List<LocalMessage>> getConversationMessages(String conversationId,
      {int? limit, int? offset}) async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];
    final messages = messagesJson
        .map((json) => _messageFromJson(json as Map<String, dynamic>))
        .where((msg) => msg?.conversationId == conversationId)
        .whereType<LocalMessage>()
        .toList();

    // Sort by timestamp
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Apply pagination
    if (offset != null && limit != null) {
      final start = offset;
      final end = start + limit;
      return messages.sublist(
          start, end > messages.length ? messages.length : end);
    }

    return messages;
  }

  @override
  Future<LocalMessage?> getMessage(int localId) async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];
    final messageJson = messagesJson.firstWhere(
      (json) => (json as Map<String, dynamic>)['id'] == localId,
      orElse: () => null,
    );

    if (messageJson != null) {
      return _messageFromJson(messageJson as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<LocalMessage?> getMessageByServerId(String serverId) async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];
    final messageJson = messagesJson.firstWhere(
      (json) => (json as Map<String, dynamic>)['server_id'] == serverId,
      orElse: () => null,
    );

    if (messageJson != null) {
      return _messageFromJson(messageJson as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<List<LocalMessage>> getUnsyncedMessages() async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];
    return messagesJson
        .map((json) => _messageFromJson(json as Map<String, dynamic>))
        .where((msg) => msg != null && !msg!.isSynced)
        .whereType<LocalMessage>()
        .toList();
  }

  @override
  Future<List<LocalMessage>> getMessagesByStatus(String status) async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];
    return messagesJson
        .map((json) => _messageFromJson(json as Map<String, dynamic>))
        .where((msg) => msg != null && msg!.readStatus == status)
        .whereType<LocalMessage>()
        .toList();
  }

  @override
  Future<void> saveMessage(LocalMessage message) async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];

    // Remove existing message if it exists
    messagesJson.removeWhere(
        (json) => (json as Map<String, dynamic>)['id'] == message.id);

    // Add new message
    messagesJson.add(_messageToJson(message));

    await WebStorageService.setList(_messagesKey, messagesJson);
  }

  @override
  Future<void> deleteMessage(int localId) async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];
    messagesJson
        .removeWhere((json) => (json as Map<String, dynamic>)['id'] == localId);

    await WebStorageService.setList(_messagesKey, messagesJson);
  }

  @override
  Future<void> deleteDuplicateMessages() async {
    _ensureInitialized();

    final messagesJson = WebStorageService.getList(_messagesKey) ?? [];
    final seenIds = <String>{};
    final uniqueMessages = <dynamic>[];

    for (final json in messagesJson) {
      final messageMap = json as Map<String, dynamic>;
      final clientId = messageMap['client_message_id'] as String?;
      final serverId = messageMap['server_id'] as String?;

      final id = clientId ?? serverId;
      if (id != null && !seenIds.contains(id)) {
        seenIds.add(id);
        uniqueMessages.add(json);
      }
    }

    await WebStorageService.setList(_messagesKey, uniqueMessages);
  }

  // Conversations
  @override
  Future<List<LocalConversation>> getAllConversations() async {
    _ensureInitialized();

    final conversationsJson =
        WebStorageService.getList(_conversationsKey) ?? [];
    return conversationsJson
        .map((json) => LocalConversation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LocalConversation?> getConversation(String conversationId) async {
    _ensureInitialized();

    final conversationsJson =
        WebStorageService.getList(_conversationsKey) ?? [];
    final conversationJson = conversationsJson.firstWhere(
      (json) => (json as Map<String, dynamic>)['server_id'] == conversationId,
      orElse: () => null,
    );

    if (conversationJson != null) {
      return LocalConversation.fromJson(
          conversationJson as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<void> saveConversation(LocalConversation conversation) async {
    _ensureInitialized();

    final conversationsJson =
        WebStorageService.getList(_conversationsKey) ?? [];

    // Remove existing conversation if it exists
    conversationsJson.removeWhere((json) =>
        (json as Map<String, dynamic>)['server_id'] == conversation.serverId);

    // Add new conversation
    conversationsJson.add(conversation.toJson());

    await WebStorageService.setList(_conversationsKey, conversationsJson);
  }

  @override
  Future<void> updateConversationUnreadCount(
      String conversationId, int unreadCount) async {
    _ensureInitialized();

    final conversationsJson =
        WebStorageService.getList(_conversationsKey) ?? [];
    final index = conversationsJson.indexWhere((json) =>
        (json as Map<String, dynamic>)['server_id'] == conversationId);

    if (index != -1) {
      final conversationMap = Map<String, dynamic>.from(
          conversationsJson[index] as Map<String, dynamic>);
      conversationMap['unread_count'] = unreadCount;
      conversationsJson[index] = conversationMap;
      await WebStorageService.setList(_conversationsKey, conversationsJson);
    }
  }

  // Users
  @override
  Future<LocalUser?> getUser(String userId) async {
    _ensureInitialized();

    final usersJson = WebStorageService.getList(_usersKey) ?? [];
    final userJson = usersJson.firstWhere(
      (json) => (json as Map<String, dynamic>)['server_id'] == userId,
      orElse: () => null,
    );

    if (userJson != null) {
      return LocalUser.fromJson(userJson as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<void> saveUser(LocalUser user) async {
    _ensureInitialized();

    final usersJson = WebStorageService.getList(_usersKey) ?? [];

    // Remove existing user if it exists
    usersJson.removeWhere(
        (json) => (json as Map<String, dynamic>)['server_id'] == user.serverId);

    // Add new user
    usersJson.add(user.toJson());

    await WebStorageService.setList(_usersKey, usersJson);
  }

  // Utility methods
  @override
  Future<Map<String, int>> getDatabaseStats() async {
    _ensureInitialized();

    final messagesCount =
        (WebStorageService.getList(_messagesKey) ?? []).length;
    final conversationsCount =
        (WebStorageService.getList(_conversationsKey) ?? []).length;
    final usersCount = (WebStorageService.getList(_usersKey) ?? []).length;

    return {
      'messages': messagesCount,
      'conversations': conversationsCount,
      'users': usersCount,
    };
  }

  @override
  Future<void> clearAllData() async {
    _ensureInitialized();

    await WebStorageService.remove(_messagesKey);
    await WebStorageService.remove(_conversationsKey);
    await WebStorageService.remove(_usersKey);

    debugPrint('✅ [WebChat] All data cleared');
  }

  @override
  Future<Map<String, dynamic>> getHealthStatus() async {
    _ensureInitialized();

    final messagesCount =
        (WebStorageService.getList(_messagesKey) ?? []).length;
    final conversationsCount =
        (WebStorageService.getList(_conversationsKey) ?? []).length;
    final usersCount = (WebStorageService.getList(_usersKey) ?? []).length;
    final storageSize = WebStorageService.getStorageSize();

    return {
      'isHealthy': true,
      'repositoryType': 'web',
      'messagesCount': messagesCount,
      'conversationsCount': conversationsCount,
      'usersCount': usersCount,
      'storageSize': storageSize,
      'platform': 'web',
    };
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Repository not initialized. Call initialize() first.');
    }
  }

  // Helper methods for JSON conversion
  LocalMessage? _messageFromJson(Map<String, dynamic> json) {
    try {
      return LocalMessage(
        id: json['id'] ?? 0,
        serverId: json['server_id'],
        clientMessageId: json['client_message_id'],
        conversationId: json['conversation_id'],
        senderId: json['sender_id'],
        content: json['content'],
        messageType: _parseMessageType(json['message_type']),
        replyToId: json['reply_to_id'],
        replyToContent: json['reply_to_content'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
        readAt:
            json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'])
            : null,
        isFromMe: json['is_from_me'] ?? false,
        readStatus: json['read_status'],
        isSynced: json['is_synced'] ?? false,
        needsUpload: json['needs_upload'] ?? false,
        attachmentUrl: json['attachment_url'],
        attachmentType: json['attachment_type'],
        attachmentSize: json['attachment_size'],
        thumbnailPath: json['thumbnail_path'],
        metadataJson: json['metadata_json'],
        reactions: json['reactions'],
      );
    } catch (e) {
      debugPrint('❌ [WebChat] Failed to parse message: $e');
      return null;
    }
  }

  Map<String, dynamic> _messageToJson(LocalMessage message) {
    return {
      'id': message.id,
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
      'is_from_me': message.isFromMe,
      'read_status': message.readStatus,
      'is_synced': message.isSynced,
      'needs_upload': message.needsUpload,
      'attachment_url': message.attachmentUrl,
      'attachment_type': message.attachmentType,
      'attachment_size': message.attachmentSize,
      'thumbnail_path': message.thumbnailPath,
      'metadata_json': message.metadataJson,
      'reactions': message.reactions,
    };
  }

  LocalMessageType _parseMessageType(dynamic type) {
    switch (type.toString().toLowerCase()) {
      case 'image':
        return LocalMessageType.image;
      case 'video':
        return LocalMessageType.video;
      case 'audio':
        return LocalMessageType.audio;
      case 'file':
        return LocalMessageType.file;
      case 'emoji':
        return LocalMessageType.emoji;
      case 'location':
        return LocalMessageType.location;
      default:
        return LocalMessageType.text;
    }
  }
}
