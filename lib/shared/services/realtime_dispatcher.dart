import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_repository_service.dart';
import '../models/local_message.dart';
import '../providers/local_chat_providers.dart';
import '../services/chat_service.dart';
import '../models/message.dart' as remote;
import 'realtime_service.dart';
import '../../core/storage/storage_service.dart';

/// Centralized real-time event dispatcher (SINGLETON)
/// Single source of truth for all real-time events
/// Handles deduplication and proper event routing
class RealtimeDispatcher {
  static RealtimeDispatcher? _instance;
  Ref? _ref;

  // Deduplication tracking
  final Set<String> _processedMessageIds = <String>{};
  Timer? _cleanupTimer;

  // Track recently sent messages to avoid duplicate adoption
  final Set<String> _recentlySentMessages = <String>{};

  // Circuit breaker to prevent message loops
  int _processingErrors = 0;
  bool _circuitBreakerOpen = false;
  DateTime? _circuitBreakerOpenTime;

  // Private constructor for singleton
  RealtimeDispatcher._internal();

  /// Get singleton instance
  static RealtimeDispatcher get instance {
    _instance ??= RealtimeDispatcher._internal();
    return _instance!;
  }

  /// Initialize with Riverpod ref (call once)
  void initialize(Ref ref) {
    if (_ref != null) {
      debugPrint('🔌 RealtimeDispatcher: Already initialized');
      return;
    }

    _ref = ref;
    _setupListeners();
    _startCleanupTimer();
    _startSentMessagesCleanup();
    debugPrint('🔌 RealtimeDispatcher: Singleton initialized');
  }

  /// Register a message as recently sent to avoid duplicate adoption
  void registerRecentlySent(String messageContent) {
    _recentlySentMessages.add(messageContent);
    debugPrint(
        '📝 RealtimeDispatcher: Registered recently sent message: "$messageContent"');
  }

  void _setupListeners() {
    if (_ref == null) {
      debugPrint('❌ RealtimeDispatcher: Cannot setup listeners - ref is null');
      return;
    }

    // Single message listener - handles all message events
    _ref!.listen(
      realtimeMessagesProvider,
      (previous, next) {
        next.whenData((realtimeMessage) {
          _handleMessage(realtimeMessage);
        });
      },
    );

    // Single typing listener
    _ref!.listen(
      realtimeTypingProvider,
      (previous, next) {
        next.whenData((typingEvent) {
          _handleTyping(typingEvent);
        });
      },
    );

    // Single presence listener
    _ref!.listen(
      realtimePresenceProvider,
      (previous, next) {
        next.whenData((presenceEvent) {
          _handlePresence(presenceEvent);
        });
      },
    );

    // Single status listener
    _ref!.listen(
      realtimeMessageStatusProvider,
      (previous, next) {
        next.whenData((statusEvent) {
          _handleMessageStatus(statusEvent);
        });
      },
    );

    // Single reaction listener
    _ref!.listen(
      realtimeReactionProvider,
      (previous, next) {
        next.whenData((reactionEvent) {
          _handleReaction(reactionEvent);
        });
      },
    );

    // Message reaction updated listener
    _ref!.listen(
      realtimeMessageReactionUpdatedProvider,
      (previous, next) {
        next.whenData((reactionEvent) {
          debugPrint(
              '🎭 RealtimeDispatcher: Received reaction updated event from stream');
          _handleMessageReactionUpdated(reactionEvent);
        });
      },
    );

    // Conversation event listener
    _ref!.listen(
      realtimeConversationProvider,
      (previous, next) {
        next.whenData((conversationEvent) {
          debugPrint(
              '📋 RealtimeDispatcher: Received conversation event: ${conversationEvent.action}');
          _handleConversationEvent(conversationEvent);
        });
      },
    );
  }

  /// Handle incoming messages with deduplication and circuit breaker
  Future<void> _handleMessage(RealtimeMessage realtimeMessage) async {
    final messageId = realtimeMessage.message.serverId ??
        realtimeMessage.message.id.toString();
    final senderId = realtimeMessage.message.senderId;
    final conversationId = realtimeMessage.conversationId;

    debugPrint(
        '🔄 RealtimeDispatcher: Received message $messageId from $senderId in conversation $conversationId');

    // CRITICAL: Check for recently sent messages FIRST (before any other processing)
    final currentUserId = StorageService.getUser()?['id'];
    final isOwnMessage = senderId == currentUserId;

    if (isOwnMessage) {
      // Check if this is a recently sent message using multiple strategies
      final clientMessageId = realtimeMessage.message.clientMessageId;
      final messageContent = realtimeMessage.message.content ?? '';

      debugPrint(
          '🔍 RealtimeDispatcher: CHECKING OWN MESSAGE - clientMessageId: "$clientMessageId", content: "$messageContent"');
      debugPrint(
          '🔍 RealtimeDispatcher: Registered keys: ${_recentlySentMessages.toList()}');

      // Strategy 1: Try clientMessageId + timestamp key (if clientMessageId exists)
      if (clientMessageId != null) {
        final messageKey =
            '${clientMessageId}_${realtimeMessage.message.createdAt.microsecondsSinceEpoch}';
        debugPrint('🔍 RealtimeDispatcher: Trying exact key: "$messageKey"');
        if (_recentlySentMessages.contains(messageKey)) {
          debugPrint(
              '⏭️ RealtimeDispatcher: EARLY SKIP - clientMessageId key: "$messageKey"');
          _recentlySentMessages.remove(messageKey);
          return;
        }
      }

      // Strategy 2: Fallback to content-based matching (for cases where server doesn't echo clientMessageId)
      debugPrint(
          '🔍 RealtimeDispatcher: Trying content fallback for: "$messageContent"');
      final isRecentContent = _recentlySentMessages.any(
          (key) => key.contains(messageContent) && messageContent.isNotEmpty);
      debugPrint(
          '🔍 RealtimeDispatcher: Content match result: $isRecentContent');
      if (isRecentContent) {
        debugPrint(
            '⏭️ RealtimeDispatcher: EARLY SKIP - content fallback: "$messageContent"');
        // Remove all keys containing this content
        _recentlySentMessages
            .removeWhere((key) => key.contains(messageContent));
        return;
      }

      debugPrint(
          '🔍 RealtimeDispatcher: NO MATCH FOUND - message will be processed normally');
    }

    // Circuit breaker check
    if (_circuitBreakerOpen) {
      final now = DateTime.now();
      final openTime = _circuitBreakerOpenTime!;

      // Check if circuit breaker should be reset (after 1 minute)
      if (now.difference(openTime).inMinutes >= 1) {
        debugPrint('🔧 RealtimeDispatcher: Circuit breaker reset');
        _circuitBreakerOpen = false;
        _processingErrors = 0;
        _circuitBreakerOpenTime = null;
      } else {
        debugPrint(
            '⚡ RealtimeDispatcher: Circuit breaker OPEN - blocking message processing');
        return; // Block processing while circuit breaker is open
      }
    }

    // Deduplication check
    if (_processedMessageIds.contains(messageId)) {
      debugPrint(
          '🐛 RealtimeDispatcher: Skipping duplicate message: $messageId');
      return; // Already processed
    }

    _processedMessageIds.add(messageId);

    try {
      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) {
        debugPrint(
            '❌ RealtimeDispatcher: No current user ID, skipping message');
        return;
      }

      final isOwnMessage = senderId == currentUserId;
      debugPrint(
          '🔍 RealtimeDispatcher: Message $messageId isOwnMessage: $isOwnMessage (currentUserId: $currentUserId, senderId: $senderId)');

      if (isOwnMessage) {
        // Own message - update optimistic message status only
        debugPrint('🔄 RealtimeDispatcher: Processing own message: $messageId');
        await _handleOwnMessage(realtimeMessage);
      } else {
        // Other user's message - full processing
        debugPrint(
            '📨 RealtimeDispatcher: Processing OTHER USER message: $messageId');
        await _handleOtherUserMessage(realtimeMessage, currentUserId);
      }

      // Reset error counter on successful processing
      _processingErrors = 0;
    } catch (e) {
      debugPrint('❌ RealtimeDispatcher: Failed to handle message: $e');

      // Increment error counter
      _processingErrors++;

      // Open circuit breaker if too many errors
      if (_processingErrors >= 5) {
        _circuitBreakerOpen = true;
        _circuitBreakerOpenTime = DateTime.now();
        debugPrint(
            '⚡ RealtimeDispatcher: Circuit breaker OPENED after $_processingErrors errors');
      }

      // Remove from processed set to allow retry (when circuit breaker resets)
      _processedMessageIds.remove(messageId);
    }
  }

  /// Handle own messages (update status only - DO NOT save new message)
  Future<void> _handleOwnMessage(RealtimeMessage realtimeMessage) async {
    debugPrint(
        '🔄 RealtimeDispatcher: Updating own message status: ${realtimeMessage.message.id}, clientMessageId: ${realtimeMessage.message.clientMessageId}');

    // Check if this message was recently sent via background sync
    final clientMessageId = realtimeMessage.message.clientMessageId ?? '';
    final messageContent = realtimeMessage.message.content ?? '';
    if (_recentlySentMessages.contains(clientMessageId) ||
        _recentlySentMessages.contains(messageContent)) {
      debugPrint(
          '⏭️ RealtimeDispatcher: Skipping adoption for recently sent message: clientId="$clientMessageId", content="$messageContent"');
      _recentlySentMessages.remove(clientMessageId); // Remove after use
      _recentlySentMessages.remove(messageContent);
      return;
    }

    try {
      // CRITICAL: For own messages, try to adopt the server message first
      // This is more reliable than just updating status
      final localMessage = realtimeMessage.message;

      debugPrint(
          '🔄 RealtimeDispatcher: Attempting to adopt own message via real-time handler');
      final adopted =
          await ChatRepositoryService.adoptServerMessage(localMessage);
      if (adopted) {
        debugPrint(
            '✅ RealtimeDispatcher: Own message adopted successfully via real-time: ${realtimeMessage.message.id}');
        // Update conversations list (legacy provider) so ConversationsPage shows latest
        try {
          final converted =
              _convertLocalToRemote(realtimeMessage.message, isFromMe: true);
          _ref!
              .read(conversationsProvider.notifier)
              .updateConversationLastMessage(
                realtimeMessage.conversationId,
                converted,
              );
        } catch (_) {}
        return; // Don't refresh - the stream will update automatically
      }

      debugPrint(
          '⚠️ RealtimeDispatcher: Adoption failed, trying status update fallback');
      // Fallback: try to update status if adoption failed
      final messageServerId = realtimeMessage.message.serverId;
      if (messageServerId != null) {
        await ChatRepositoryService.updateMessageStatus(
          messageServerId,
          'sent',
          DateTime.now(),
        );
      }

      debugPrint(
          '✅ RealtimeDispatcher: Own message status updated to "sent": ${realtimeMessage.message.id}');
      // Also update conversations list with the latest message for own sends
      try {
        final converted =
            _convertLocalToRemote(realtimeMessage.message, isFromMe: true);
        _ref!
            .read(conversationsProvider.notifier)
            .updateConversationLastMessage(
              realtimeMessage.conversationId,
              converted,
            );
      } catch (_) {}
    } catch (e) {
      if (e.toString().contains('Unique index violated') ||
          e.toString().contains('not found')) {
        debugPrint(
            '✅ RealtimeDispatcher: Message already processed - ${realtimeMessage.message.id}');
        return; // Not an error - message may already be adopted
      }
      debugPrint('❌ RealtimeDispatcher: Failed to process own message: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Handle messages from other users (full processing)
  Future<void> _handleOtherUserMessage(
      RealtimeMessage realtimeMessage, String currentUserId) async {
    debugPrint(
        '📨 RealtimeDispatcher: Processing incoming message: ${realtimeMessage.message.id}');

    // The message is already a LocalMessage from the updated RealtimeMessage.fromJson
    final localMessage = realtimeMessage.message;

    try {
      // Save to database (ignore duplicates silently)
      await ChatRepositoryService.saveMessage(localMessage);
    } catch (_) {}

    try {
      // Update conversation last message
      // Only increment unread count for messages NOT from current user
      final currentUserId = StorageService.getUser()?['id'];
      final shouldIncrementUnread = currentUserId != null &&
          realtimeMessage.message.senderId != currentUserId;

      await ChatRepositoryService.updateConversationLastMessage(
        realtimeMessage.conversationId,
        localMessage,
        unreadCount:
            shouldIncrementUnread ? 1 : null, // Only increment if not from me
      );
    } catch (_) {}

    // Always refresh UI, even if DB write collided
    await _updateUIForIncomingMessage(
        realtimeMessage.conversationId, localMessage);

    // Update global conversations list - using localMessage (already a LocalMessage)
    _ref!.read(localConversationsProvider.notifier).updateLastMessage(
          realtimeMessage.conversationId,
          localMessage,
        );

    // Also update legacy conversations provider so ConversationsPage reflects last message/unread
    try {
      final converted = _convertLocalToRemote(localMessage, isFromMe: false);
      _ref!.read(conversationsProvider.notifier).updateConversationLastMessage(
            realtimeMessage.conversationId,
            converted,
          );
    } catch (_) {}
  }

  /// Update UI providers for incoming messages
  Future<void> _updateUIForIncomingMessage(
      String conversationId, LocalMessage localMessage) async {
    // Always refresh messages for that conversation so chat page updates even
    // if currentConversationProvider hasn't been set yet
    debugPrint(
        '🔄 [DEBUG] Refreshing localMessagesProvider for conversation $conversationId');
    _ref!.read(localMessagesProvider(conversationId).notifier).refresh();

    // Check if user is currently viewing this conversation to mark as read
    final currentConversationId = _ref!.read(currentConversationProvider);
    debugPrint(
        '🐛 [DEBUG] _updateUIForIncomingMessage: conversationId=$conversationId, currentConversationId=$currentConversationId');

    // Only auto-mark read if:
    // 1. The chat page is actually open for this conversation
    // 2. The app is in foreground
    // 3. The message is NOT from the current user (don't auto-mark own messages as read)
    final appLifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground = appLifecycleState == AppLifecycleState.resumed;
    final isFromCurrentUser =
        StorageService.getUser()?['id'] == localMessage.senderId;

    if (currentConversationId == conversationId &&
        isForeground &&
        !isFromCurrentUser) {
      await ChatRepositoryService.markConversationAsRead(conversationId);
      debugPrint(
          '✅ [DEBUG] Conversation marked as read (not from current user)');
    } else {
      // Refresh list for unread badge updates
      _ref!.read(localConversationsProvider.notifier).refresh();
      if (isFromCurrentUser) {
        debugPrint('📝 [DEBUG] Skipping auto-mark-read for own message');
      }
    }
  }

  // Convert LocalMessage to remote.Message for conversationsProvider updates
  remote.Message _convertLocalToRemote(LocalMessage m,
      {required bool isFromMe}) {
    final remoteType = _mapType(m.messageType);
    return remote.Message(
      id: m.serverId ?? m.id.toString(),
      conversationId: m.conversationId,
      senderId: m.senderId,
      content: m.content,
      messageType: remoteType,
      isFromMe: isFromMe,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt ?? m.createdAt,
      readStatus: remote.ReadStatus.sent,
    );
  }

  remote.MessageType _mapType(LocalMessageType t) {
    switch (t) {
      case LocalMessageType.text:
        return remote.MessageType.text;
      case LocalMessageType.image:
        return remote.MessageType.image;
      case LocalMessageType.video:
        return remote.MessageType.video;
      case LocalMessageType.audio:
        return remote.MessageType.audio;
      case LocalMessageType.file:
        return remote.MessageType.file;
      case LocalMessageType.emoji:
        return remote.MessageType.emoji;
      case LocalMessageType.location:
        return remote.MessageType.text;
    }
  }

  /// Handle typing events
  void _handleTyping(TypingEvent typingEvent) {
    // Typing events are handled by individual UI components
    // No additional processing needed here
    debugPrint(
        '⌨️ RealtimeDispatcher: Typing event - ${typingEvent.isTyping ? "started" : "stopped"}');
  }

  /// Handle presence events
  void _handlePresence(PresenceEvent presenceEvent) {
    debugPrint(
        '👤 RealtimeDispatcher: Presence event for user ${presenceEvent.userId}: ${presenceEvent.isOnline ? "Online" : "Offline"}');

    // Presence events are handled by individual UI components
    // The local_chat_page listens to realtimePresenceProvider directly
    // No additional database processing needed here
  }

  /// Handle message status events
  Future<void> _handleMessageStatus(MessageStatusEvent statusEvent) async {
    debugPrint(
        '✅ RealtimeDispatcher: Message status update: ${statusEvent.status}');

    // Update message status in database for all affected messages
    final conversationId = statusEvent.conversationId;
    if (conversationId != null) {
      for (final messageId in statusEvent.messageIds) {
        await ChatRepositoryService.updateMessageStatus(
          messageId,
          statusEvent.status,
          DateTime.now(),
        );
      }

      // Refresh UI if user is viewing this conversation
      final currentConversationId = _ref!.read(currentConversationProvider);
      if (currentConversationId == conversationId) {
        _ref!.read(localMessagesProvider(conversationId).notifier).refresh();
      }
    }
  }

  // Conversion methods removed - RealtimeMessage now contains LocalMessage directly

  /// Handle reaction events
  Future<void> _handleReaction(ReactionEvent reactionEvent) async {
    try {
      debugPrint(
          '🎭 RealtimeDispatcher: Handling reaction event: ${reactionEvent.action} for message ${reactionEvent.messageId}');
      // For individual reaction:added/removed events (legacy format)
      debugPrint(
          '🎭 RealtimeDispatcher: Individual reaction events not yet implemented');
    } catch (e) {
      debugPrint('❌ RealtimeDispatcher: Failed to handle reaction: $e');
    }
  }

  /// Handle message reaction updated events
  Future<void> _handleMessageReactionUpdated(
      MessageReactionUpdatedEvent event) async {
    try {
      debugPrint(
          '🎭 RealtimeDispatcher: Handling message reaction updated for message ${event.messageId}');

      // Convert reactions map to JSON string for database storage
      final reactionsJson = json.encode(event.reactions);

      // Update the message reactions in the database
      await ChatRepositoryService.updateMessageReactions(
        event.messageId,
        reactionsJson,
      );

      // Refresh the messages provider to show updated reactions in UI
      if (_ref != null) {
        // Find the conversation ID for this message and refresh its messages
        try {
          final message =
              await ChatRepositoryService.getMessageByServerId(event.messageId);
          if (message != null) {
            _ref!
                .read(localMessagesProvider(message.conversationId).notifier)
                .refresh();
            debugPrint(
                '🔄 RealtimeDispatcher: Refreshed messages for conversation ${message.conversationId} after reaction update');
          }
        } catch (e) {
          debugPrint(
              '⚠️ RealtimeDispatcher: Failed to refresh messages after reaction update: $e');
        }
      }

      debugPrint(
          '✅ RealtimeDispatcher: Updated reactions for message ${event.messageId}');
    } catch (e) {
      debugPrint(
          '❌ RealtimeDispatcher: Failed to handle message reaction updated: $e');
    }
  }

  /// Handle conversation events (created, updated, etc.)
  Future<void> _handleConversationEvent(ConversationEvent event) async {
    try {
      debugPrint(
          '📋 RealtimeDispatcher: Handling conversation ${event.action} for ${event.conversationId}');

      if (event.action == 'created') {
        // Refresh conversations list when a new conversation is created
        if (_ref != null) {
          // Force refresh the conversations provider to pick up the new conversation
          final conversationsNotifier =
              _ref!.read(localConversationsProvider.notifier);
          await conversationsNotifier.refresh();

          debugPrint(
              '✅ RealtimeDispatcher: Refreshed conversations list after creation of ${event.conversationId}');
        }
      } else if (event.action == 'updated') {
        // Handle conversation updates (e.g., name changes)
        debugPrint(
            '📋 RealtimeDispatcher: Conversation updated: ${event.conversationId}');
        // Could implement specific update handling here if needed
      }
    } catch (e) {
      debugPrint(
          '❌ RealtimeDispatcher: Failed to handle conversation event: $e');
    }
  }

  /// Start cleanup timer to prevent memory leaks
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupProcessedMessages();
    });
  }

  /// Start cleanup for recently sent messages
  void _startSentMessagesCleanup() {
    Timer.periodic(const Duration(minutes: 2), (_) {
      _cleanupRecentlySentMessages();
    });
  }

  /// Clean up recently sent messages (prevent memory leak)
  void _cleanupRecentlySentMessages() {
    _recentlySentMessages.clear();
    debugPrint('🧹 RealtimeDispatcher: Cleaned up recently sent messages');
  }

  /// Clean up old processed message IDs to prevent memory leaks
  void _cleanupProcessedMessages() {
    if (_processedMessageIds.length > 1000) {
      final messagesList = _processedMessageIds.toList();
      _processedMessageIds.clear();
      // Keep only the most recent 500 IDs
      _processedMessageIds.addAll(messagesList.skip(messagesList.length - 500));
      debugPrint('🧹 RealtimeDispatcher: Cleaned up processed message IDs');
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _processedMessageIds.clear();
    debugPrint('🔌 RealtimeDispatcher: Disposed');
  }
}
