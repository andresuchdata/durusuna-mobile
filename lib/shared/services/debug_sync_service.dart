import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/chat_database.dart';
import 'local_chat_service.dart';
import 'chat_service.dart';
import '../models/local_conversation.dart';
import '../models/local_message.dart';
import '../../core/storage/storage_service.dart';

/// Debug service to force fresh sync from backend
class DebugSyncService {
  final ChatService _chatService;
  final LocalChatService _localChatService;
  final Ref _ref;

  DebugSyncService(this._chatService, this._localChatService, this._ref);

  /// Force complete resync from backend (useful for testing)
  Future<void> forceCompleteResync() async {
    try {

      // Step 1: Clear local database
      await ChatDatabase.clearAllData();

      // Step 2: Sync conversations from backend
      final apiConversations = await _chatService.getConversations();

      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Convert and save conversations
      for (final apiConv in apiConversations) {
        final localConv = LocalConversation(
          serverId: apiConv.id,
          type: apiConv.type == 'group'
              ? LocalConversationType.group
              : LocalConversationType.direct,
          name: apiConv.name,
          description: apiConv.description,
          avatarUrl: apiConv.avatarUrl,
          otherUserId: apiConv.otherUser?.id,
          lastActivity: apiConv.lastActivity ?? DateTime.now(),
          unreadCount: apiConv.unreadCount,
          isOnline: apiConv.isOnline,
          createdAt: apiConv.createdAt,
          updatedAt: apiConv.updatedAt,
        );

        await ChatDatabase.saveConversation(localConv);
      }

      // Step 3: Sync recent messages for each conversation
      for (final apiConv in apiConversations.take(10)) {
        // Top 10 conversations
        try {

          final apiMessages =
              await _chatService.getMessages(apiConv.id, limit: 50);

          // Convert and save messages
          for (final apiMsg in apiMessages) {
            final localMsg = LocalMessage(
              serverId: apiMsg.id,
              conversationId: apiMsg.conversationId,
              senderId: apiMsg.senderId,
              content: apiMsg.content,
              messageType: _mapMessageType(apiMsg.messageType),
              replyToId: apiMsg.replyToId,
              createdAt: apiMsg.createdAt,
              updatedAt: apiMsg.updatedAt,
              isFromMe: apiMsg.senderId == currentUserId,
              isSynced: true, // Already from server
              readStatus: (apiMsg.readStatus as String?) ?? 'sent',
            );

            await ChatDatabase.saveMessage(localMsg);
          }
        } catch (e) {
        }
      }

    } catch (e) {
      rethrow;
    }
  }

  LocalMessageType _mapMessageType(dynamic apiType) {
    switch (apiType.toString().toLowerCase()) {
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

// Provider for debug sync service
final debugSyncServiceProvider = Provider<DebugSyncService>((ref) {
  return DebugSyncService(
    ref.read(chatServiceProvider),
    ref.read(localChatServiceProvider),
    ref,
  );
});
