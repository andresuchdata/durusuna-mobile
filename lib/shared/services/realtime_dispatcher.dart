import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/chat_database.dart';
import '../models/local_message.dart';

import '../models/message.dart';
import '../providers/local_chat_providers.dart';
import '../services/chat_service.dart';
import 'realtime_service.dart';
import '../../core/storage/storage_service.dart';

/// Centralized real-time event dispatcher
/// Single source of truth for all real-time events
/// Handles deduplication and proper event routing
class RealtimeDispatcher {
  final Ref _ref;

  // Deduplication tracking
  final Set<String> _processedMessageIds = <String>{};
  Timer? _cleanupTimer;

  // Circuit breaker to prevent message loops
  int _processingErrors = 0;
  bool _circuitBreakerOpen = false;
  DateTime? _circuitBreakerOpenTime;

  RealtimeDispatcher(this._ref) {
    _initialize();
    _startCleanupTimer();
    print('🔌 RealtimeDispatcher: Initialized');
  }

  void _initialize() {
    // Single message listener - handles all message events
    _ref.listen(
      realtimeMessagesProvider,
      (previous, next) {
        next.whenData((realtimeMessage) {
          _handleMessage(realtimeMessage);
        });
      },
    );

    // Single typing listener
    _ref.listen(
      realtimeTypingProvider,
      (previous, next) {
        next.whenData((typingEvent) {
          _handleTyping(typingEvent);
        });
      },
    );

    // Single presence listener
    _ref.listen(
      realtimePresenceProvider,
      (previous, next) {
        next.whenData((presenceEvent) {
          _handlePresence(presenceEvent);
        });
      },
    );

    // Single status listener
    _ref.listen(
      realtimeMessageStatusProvider,
      (previous, next) {
        next.whenData((statusEvent) {
          _handleMessageStatus(statusEvent);
        });
      },
    );
  }

  /// Handle incoming messages with deduplication and circuit breaker
  Future<void> _handleMessage(RealtimeMessage realtimeMessage) async {
    final messageId = realtimeMessage.message.id;
    final senderId = realtimeMessage.message.senderId;
    final conversationId = realtimeMessage.conversationId;

    print(
        '🔄 RealtimeDispatcher: Received message $messageId from $senderId in conversation $conversationId');

    // Circuit breaker check
    if (_circuitBreakerOpen) {
      final now = DateTime.now();
      final openTime = _circuitBreakerOpenTime!;

      // Check if circuit breaker should be reset (after 1 minute)
      if (now.difference(openTime).inMinutes >= 1) {
        print('🔧 RealtimeDispatcher: Circuit breaker reset');
        _circuitBreakerOpen = false;
        _processingErrors = 0;
        _circuitBreakerOpenTime = null;
      } else {
        print(
            '⚡ RealtimeDispatcher: Circuit breaker OPEN - blocking message processing');
        return; // Block processing while circuit breaker is open
      }
    }

    // Deduplication check
    if (_processedMessageIds.contains(messageId)) {
      print('🐛 RealtimeDispatcher: Skipping duplicate message: $messageId');
      return; // Already processed
    }

    _processedMessageIds.add(messageId);

    try {
      final currentUserId = StorageService.getUser()?['id'];
      if (currentUserId == null) {
        print('❌ RealtimeDispatcher: No current user ID, skipping message');
        return;
      }

      final isOwnMessage = senderId == currentUserId;
      print(
          '🔍 RealtimeDispatcher: Message $messageId isOwnMessage: $isOwnMessage (currentUserId: $currentUserId, senderId: $senderId)');

      if (isOwnMessage) {
        // Own message - update optimistic message status only
        print('🔄 RealtimeDispatcher: Processing own message: $messageId');
        await _handleOwnMessage(realtimeMessage);
      } else {
        // Other user's message - full processing
        print(
            '📨 RealtimeDispatcher: Processing OTHER USER message: $messageId');
        await _handleOtherUserMessage(realtimeMessage, currentUserId);
      }

      // Reset error counter on successful processing
      _processingErrors = 0;
    } catch (e) {
      print('❌ RealtimeDispatcher: Failed to handle message: $e');

      // Increment error counter
      _processingErrors++;

      // Open circuit breaker if too many errors
      if (_processingErrors >= 5) {
        _circuitBreakerOpen = true;
        _circuitBreakerOpenTime = DateTime.now();
        print(
            '⚡ RealtimeDispatcher: Circuit breaker OPENED after $_processingErrors errors');
      }

      // Remove from processed set to allow retry (when circuit breaker resets)
      _processedMessageIds.remove(messageId);
    }
  }

  /// Handle own messages (update status only - DO NOT save new message)
  Future<void> _handleOwnMessage(RealtimeMessage realtimeMessage) async {
    print(
        '🔄 RealtimeDispatcher: Updating own message status: ${realtimeMessage.message.id}');

    try {
      // CRITICAL: Only update status, never save as new message for own messages
      // This prevents duplicates when user sends message and receives real-time echo
      await ChatDatabase.updateMessageStatus(
        realtimeMessage.message.id,
        readStatus: 'sent',
      );

      // Notify specific conversation provider to refresh (lightweight update)
      final conversationId = realtimeMessage.conversationId;
      _ref.read(localMessagesProvider(conversationId).notifier).refresh();

      print(
          '✅ RealtimeDispatcher: Own message status updated to "sent": ${realtimeMessage.message.id}');
    } catch (e) {
      if (e.toString().contains('Unique index violated') ||
          e.toString().contains('not found')) {
        print(
            '✅ RealtimeDispatcher: Message status already updated or not found - ${realtimeMessage.message.id}');
        return; // Not an error - message may not exist locally yet or already correct
      }
      print('❌ RealtimeDispatcher: Failed to update own message status: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Handle messages from other users (full processing)
  Future<void> _handleOtherUserMessage(
      RealtimeMessage realtimeMessage, String currentUserId) async {
    print(
        '📨 RealtimeDispatcher: Processing incoming message: ${realtimeMessage.message.id}');

    // Convert to local message
    final localMessage = _convertToLocalMessage(
      realtimeMessage.message,
      realtimeMessage.conversationId,
      currentUserId,
    );

    try {
      // Save to database (ignore duplicates silently)
      await ChatDatabase.saveMessage(localMessage);
    } catch (_) {}

    try {
      // Update conversation last message
      await ChatDatabase.updateConversationLastMessage(
        realtimeMessage.conversationId,
        localMessage,
        unreadCount: 1,
      );
    } catch (_) {}

    // Always refresh UI, even if DB write collided
    await _updateUIForIncomingMessage(
        realtimeMessage.conversationId, localMessage);

    // Update global conversations list
    _ref.read(conversationsProvider.notifier).updateConversationLastMessage(
          realtimeMessage.conversationId,
          realtimeMessage.message,
        );
  }

  /// Update UI providers for incoming messages
  Future<void> _updateUIForIncomingMessage(
      String conversationId, LocalMessage localMessage) async {
    // Always refresh messages for that conversation so chat page updates even
    // if currentConversationProvider hasn't been set yet
    print(
        '🔄 [DEBUG] Refreshing localMessagesProvider for conversation $conversationId');
    _ref.read(localMessagesProvider(conversationId).notifier).refresh();

    // Check if user is currently viewing this conversation to mark as read
    final currentConversationId = _ref.read(currentConversationProvider);
    print(
        '🐛 [DEBUG] _updateUIForIncomingMessage: conversationId=$conversationId, currentConversationId=$currentConversationId');
    if (currentConversationId == conversationId) {
      await ChatDatabase.markConversationAsRead(conversationId);
      print('✅ [DEBUG] Conversation marked as read');
    } else {
      // Refresh list for unread badge updates
      _ref.read(localConversationsProvider.notifier).refresh();
    }
  }

  /// Handle typing events
  void _handleTyping(TypingEvent typingEvent) {
    // Typing events are handled by individual UI components
    // No additional processing needed here
    print(
        '⌨️ RealtimeDispatcher: Typing event - ${typingEvent.isTyping ? "started" : "stopped"}');
  }

  /// Handle presence events
  void _handlePresence(PresenceEvent presenceEvent) {
    print(
        '👤 RealtimeDispatcher: Presence event for user ${presenceEvent.userId}: ${presenceEvent.isOnline ? "Online" : "Offline"}');

    // Presence events are handled by individual UI components
    // The local_chat_page listens to realtimePresenceProvider directly
    // No additional database processing needed here
  }

  /// Handle message status events
  Future<void> _handleMessageStatus(MessageStatusEvent statusEvent) async {
    print('✅ RealtimeDispatcher: Message status update: ${statusEvent.status}');

    // Update message status in database for all affected messages
    final conversationId = statusEvent.conversationId;
    if (conversationId != null) {
      for (final messageId in statusEvent.messageIds) {
        await ChatDatabase.updateMessageStatus(
          messageId,
          readStatus: statusEvent.status,
          // TODO: Add readAt and deliveredAt when available in MessageStatusEvent
        );
      }

      // Refresh UI if user is viewing this conversation
      final currentConversationId = _ref.read(currentConversationProvider);
      if (currentConversationId == conversationId) {
        _ref.read(localMessagesProvider(conversationId).notifier).refresh();
      }
    }
  }

  /// Convert Message to LocalMessage
  LocalMessage _convertToLocalMessage(
    Message message,
    String conversationId,
    String currentUserId,
  ) {
    return LocalMessage(
      serverId: message.id,
      conversationId: conversationId,
      senderId: message.senderId,
      content: message.content,
      messageType: _convertMessageType(message.messageType),
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      isFromMe: message.senderId == currentUserId,
      isSynced: true, // Real-time messages are already synced
      readStatus: 'delivered',
      replyToId: message.replyToId,
    );
  }

  /// Convert MessageType to LocalMessageType
  LocalMessageType _convertMessageType(MessageType messageType) {
    switch (messageType) {
      case MessageType.text:
        return LocalMessageType.text;
      case MessageType.image:
        return LocalMessageType.image;
      case MessageType.file:
        return LocalMessageType.file;
      case MessageType.audio:
        return LocalMessageType.audio;
      case MessageType.video:
        return LocalMessageType.video;
      case MessageType.emoji:
        return LocalMessageType.emoji;
    }
  }

  /// Start cleanup timer to prevent memory leaks
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupProcessedMessages();
    });
  }

  /// Clean up old processed message IDs to prevent memory leaks
  void _cleanupProcessedMessages() {
    if (_processedMessageIds.length > 1000) {
      final messagesList = _processedMessageIds.toList();
      _processedMessageIds.clear();
      // Keep only the most recent 500 IDs
      _processedMessageIds.addAll(messagesList.skip(messagesList.length - 500));
      print('🧹 RealtimeDispatcher: Cleaned up processed message IDs');
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _processedMessageIds.clear();
    print('🔌 RealtimeDispatcher: Disposed');
  }
}

/// Provider for the centralized dispatcher
final realtimeDispatcherProvider = Provider<RealtimeDispatcher>((ref) {
  final dispatcher = RealtimeDispatcher(ref);
  ref.onDispose(() => dispatcher.dispose());
  return dispatcher;
});
