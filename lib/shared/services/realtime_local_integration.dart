import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/chat_database.dart';
import '../models/local_message.dart';
import '../models/local_conversation.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../../core/storage/storage_service.dart';
import 'realtime_service.dart';
import 'local_chat_service.dart';
import '../providers/local_chat_providers.dart';

/// Integration service for real-time updates with local database
/// Bridges real-time events to local storage and UI updates
class RealtimeLocalIntegration {
  final Ref _ref;
  final LocalChatService _localChatService;

  RealtimeLocalIntegration(this._ref, this._localChatService) {
    _initialize();
  }

  void _initialize() {
    // Listen for real-time messages and store locally
    _ref.listen(realtimeMessagesProvider, (previous, next) {
      next?.whenData((realtimeMessage) {
        _handleRealtimeMessage(realtimeMessage);
      });
    });

    // Listen for real-time presence updates
    _ref.listen(realtimePresenceProvider, (previous, next) {
      next?.whenData((presence) {
        _handlePresenceUpdate(presence);
      });
    });

    // Listen for real-time message status updates
    _ref.listen(realtimeMessageStatusProvider, (previous, next) {
      next?.whenData((statusEvent) {
        _handleMessageStatusUpdate(statusEvent);
      });
    });
  }

  Future<void> _handleRealtimeMessage(RealtimeMessage realtimeMessage) async {
    try {
      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) return;

      // Convert real-time message to LocalMessage
      final localMessage = _convertToLocalMessage(
        realtimeMessage.message,
        realtimeMessage.conversationId,
        currentUserId,
      );

      // Save to local database immediately
      await ChatDatabase.saveMessage(localMessage);

      // Update conversation's last message
      await ChatDatabase.updateConversationLastMessage(
        realtimeMessage.conversationId,
        localMessage,
        unreadCount: localMessage.isFromMe ? null : 1,
      );

      // Update UI providers
      _updateUIProviders(realtimeMessage.conversationId, localMessage);
    } catch (e) {
      print('Failed to handle real-time message: $e');
    }
  }

  Future<void> _handlePresenceUpdate(PresenceUpdate presence) async {
    try {
      // Update local conversations with user presence
      final conversations = await ChatDatabase.getConversations();

      for (final conversation in conversations) {
        if (conversation.type == LocalConversationType.direct &&
            conversation.otherUserId == presence.userId) {
          final updated = conversation.copyWith(isOnline: presence.isOnline);
          await ChatDatabase.saveConversation(updated);

          // Update UI
          _ref
              .read(localConversationsProvider.notifier)
              .addOrUpdateConversation(updated);
        }
      }
    } catch (e) {
      print('Failed to handle presence update: $e');
    }
  }

  Future<void> _handleMessageStatusUpdate(
      MessageStatusEvent statusEvent) async {
    try {
      // Update message read/delivery status in local database
      for (final messageId in statusEvent.messageIds) {
        await ChatDatabase.updateMessageStatus(
          messageId,
          readStatus: statusEvent.status,
          readAt: statusEvent.status == 'read' ? statusEvent.timestamp : null,
          deliveredAt:
              statusEvent.status == 'delivered' ? statusEvent.timestamp : null,
        );
      }

      // Update UI for the specific conversation
      final conversationId = statusEvent.conversationId;
      _ref.read(localMessagesProvider(conversationId).notifier).refresh();
    } catch (e) {
      print('Failed to handle message status update: $e');
    }
  }

  void _updateUIProviders(String conversationId, LocalMessage message) {
    // Update conversations list
    _ref
        .read(localConversationsProvider.notifier)
        .updateLastMessage(conversationId, message);

    // Update messages list for active conversation
    _ref
        .read(localMessagesProvider(conversationId).notifier)
        .addMessage(message);
  }

  LocalMessage _convertToLocalMessage(
    Message apiMessage,
    String conversationId,
    String currentUserId,
  ) {
    return LocalMessage(
      serverId: apiMessage.id,
      conversationId: conversationId,
      senderId: apiMessage.senderId,
      content: apiMessage.content,
      messageType: _convertMessageType(apiMessage.messageType),
      replyToId: apiMessage.replyToId,
      replyToContent: apiMessage.replyTo?.content,
      createdAt: apiMessage.createdAt,
      updatedAt: apiMessage.updatedAt,
      readAt: apiMessage.readAt,
      deliveredAt: apiMessage.deliveredAt,
      isFromMe: apiMessage.senderId == currentUserId,
      readStatus: _convertReadStatus(apiMessage.readStatus),
      isSynced: true, // Coming from real-time, so it's synced
      metadataJson:
          apiMessage.metadata != null ? jsonEncode(apiMessage.metadata) : null,
      reactions: apiMessage.reactions != null
          ? jsonEncode(apiMessage.reactions)
          : null,
    );
  }

  LocalMessageType _convertMessageType(MessageType apiType) {
    switch (apiType) {
      case MessageType.text:
        return LocalMessageType.text;
      case MessageType.image:
        return LocalMessageType.image;
      case MessageType.video:
        return LocalMessageType.video;
      case MessageType.audio:
        return LocalMessageType.audio;
      case MessageType.file:
        return LocalMessageType.file;
      case MessageType.emoji:
        return LocalMessageType.emoji;
    }
  }

  String _convertReadStatus(ReadStatus? readStatus) {
    switch (readStatus) {
      case ReadStatus.sent:
        return 'sent';
      case ReadStatus.delivered:
        return 'delivered';
      case ReadStatus.read:
        return 'read';
      case null:
        return 'sent';
    }
  }

  /// Convert API Conversation to LocalConversation
  Future<LocalConversation> convertToLocalConversation(
    Conversation apiConversation,
    String currentUserId,
  ) async {
    return LocalConversation(
      serverId: apiConversation.id,
      type: apiConversation.type == 'group'
          ? LocalConversationType.group
          : LocalConversationType.direct,
      name: apiConversation.name,
      description: apiConversation.description,
      avatarUrl: apiConversation.avatarUrl,
      otherUserId: apiConversation.otherUser?.id,
      otherUserName: apiConversation.otherUser?.displayName,
      otherUserAvatar: apiConversation.otherUser?.avatarUrl,
      lastMessage: apiConversation.lastMessage?.content,
      lastMessageAt: apiConversation.lastMessage?.createdAt,
      lastActivity: apiConversation.lastActivity ?? DateTime.now(),
      unreadCount: apiConversation.unreadCount,
      isOnline: apiConversation.isOnline,
      participantsJson: apiConversation.participants != null
          ? jsonEncode(
              apiConversation.participants.map((p) => p.toJson()).toList())
          : null,
      createdAt: apiConversation.createdAt,
      updatedAt: apiConversation.updatedAt,
    );
  }

  /// Sync conversations from API to local database
  Future<void> syncConversationsFromApi(
      List<Conversation> apiConversations) async {
    try {
      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) return;

      final localConversations = <LocalConversation>[];

      for (final apiConversation in apiConversations) {
        final localConversation = await convertToLocalConversation(
          apiConversation,
          currentUserId,
        );
        localConversations.add(localConversation);

        // Save to database
        await ChatDatabase.saveConversation(localConversation);
      }

      // Update UI
      for (final conversation in localConversations) {
        _ref
            .read(localConversationsProvider.notifier)
            .addOrUpdateConversation(conversation);
      }
    } catch (e) {
      print('Failed to sync conversations from API: $e');
    }
  }

  /// Sync messages from API to local database
  Future<void> syncMessagesFromApi(
    String conversationId,
    List<Message> apiMessages,
  ) async {
    try {
      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) return;

      final localMessages = <LocalMessage>[];

      for (final apiMessage in apiMessages) {
        final localMessage = _convertToLocalMessage(
          apiMessage,
          conversationId,
          currentUserId,
        );
        localMessages.add(localMessage);
      }

      // Save to database in batch
      await ChatDatabase.saveMessages(localMessages);

      // Update UI if this conversation is currently being viewed
      try {
        _ref.read(localMessagesProvider(conversationId).notifier).refresh();
      } catch (e) {
        // Provider might not be active, which is fine
      }
    } catch (e) {
      print('Failed to sync messages from API: $e');
    }
  }
}

// Provider for real-time local integration
final realtimeLocalIntegrationProvider =
    Provider<RealtimeLocalIntegration>((ref) {
  final localChatService = ref.read(localChatServiceProvider);
  return RealtimeLocalIntegration(ref, localChatService);
});

// Mock classes for real-time events (adapt to your existing structure)
class RealtimeMessage {
  final Message message;
  final String conversationId;
  final String action;

  RealtimeMessage({
    required this.message,
    required this.conversationId,
    required this.action,
  });
}

class PresenceUpdate {
  final String userId;
  final bool isOnline;
  final DateTime timestamp;

  PresenceUpdate({
    required this.userId,
    required this.isOnline,
    required this.timestamp,
  });
}

class MessageStatusEvent {
  final String conversationId;
  final List<String> messageIds;
  final String status; // 'sent', 'delivered', 'read'
  final DateTime timestamp;

  MessageStatusEvent({
    required this.conversationId,
    required this.messageIds,
    required this.status,
    required this.timestamp,
  });
}
