import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_service.dart';
import 'auth_service.dart';
import '../models/message.dart';

/// Production-grade mark-read service that handles all read status operations
/// with debouncing, batching, and proper state coordination
///
/// ## Usage Scenarios:
///
/// **1. User opens chat page (Requirement #1):**
/// ```dart
/// markReadService.markOnChatPageEnter(conversationId);
/// ```
/// - Fetches 20 messages then marks conversation as read
/// - Uses debounced API call (1.5s delay)
/// - Optimistic UI update for immediate feedback
///
/// **2. User is viewing chat and new messages arrive:**
/// ```dart
/// markReadService.markMessagesRead(conversationId, [messageId], immediate: true);
/// ```
/// - Auto-marks incoming messages since user is actively viewing
/// - Uses immediate mode (0.5s delay) for better UX
/// - No duplication with initial page load
///
/// **3. User scrolls to bottom:**
/// ```dart
/// markReadService.markOnScrollToBottom(conversationId);
/// ```
/// - Debounced mark-read when user confirms they've seen messages
///
/// **4. User sends message:**
/// ```dart
/// markReadService.markOnMessageSent(conversationId);
/// ```
/// - Implicit read since user is actively participating
///
/// The service prevents duplicate API calls through:
/// - Debouncing (batches rapid calls)
/// - Duplicate detection (skips if already pending)
/// - Immediate mode for active viewing scenarios
class MarkReadService {
  final ChatService _chatService;
  final Ref _ref;

  // Debouncing timers for different conversations
  final Map<String, Timer> _conversationTimers = {};

  // Track pending operations to avoid duplicates
  final Set<String> _pendingConversations = {};

  // Batch message IDs for efficient API calls
  final Map<String, Set<String>> _pendingMessageIds = {};

  static const Duration _debounceDelay = Duration(milliseconds: 1500);

  MarkReadService(this._chatService, this._ref);

  /// Main entry point: Mark conversation as read when user views it
  /// This is the primary method that should be called from UI
  Future<void> markConversationViewed(
    String conversationId, {
    bool immediate = false,
  }) async {
    print('📖 MarkReadService: Conversation viewed: $conversationId');

    if (immediate) {
      await _executeMarkConversationRead(conversationId);
    } else {
      _scheduleMarkConversationRead(conversationId);
    }
  }

  /// Mark specific messages as read (used for real-time updates when user is viewing chat)
  void markMessagesRead(String conversationId, List<String> messageIds,
      {bool immediate = false}) {
    if (messageIds.isEmpty) return;

    print(
        '📖 MarkReadService: Marking ${messageIds.length} messages as read in conversation: $conversationId (immediate: $immediate)');

    // Add to pending batch
    _pendingMessageIds.putIfAbsent(conversationId, () => <String>{});
    _pendingMessageIds[conversationId]!.addAll(messageIds);

    if (immediate) {
      // For messages that arrive while user is actively viewing chat
      // Mark immediately with minimal delay to ensure good UX
      Timer(const Duration(milliseconds: 500), () {
        _executeMarkConversationRead(conversationId);
      });
    } else {
      // Schedule conversation read (which will include these messages)
      _scheduleMarkConversationRead(conversationId);
    }
  }

  /// Auto-mark when user enters chat page (your requirement #1)
  Future<void> markOnChatPageEnter(String conversationId) async {
    print(
        '📖 MarkReadService: Auto-marking on chat page enter: $conversationId');

    // Immediate optimistic update for better UX
    _updateConversationStateOptimistically(conversationId);

    // Schedule the actual API call with debouncing
    _scheduleMarkConversationRead(conversationId);
  }

  /// Mark when user scrolls to bottom and views messages
  void markOnScrollToBottom(String conversationId) {
    print(
        '📖 MarkReadService: Auto-marking on scroll to bottom: $conversationId');
    _scheduleMarkConversationRead(conversationId);
  }

  /// Mark when user sends a message (implicit read)
  void markOnMessageSent(String conversationId) {
    print('📖 MarkReadService: Auto-marking on message sent: $conversationId');
    _scheduleMarkConversationRead(conversationId);
  }

  /// Schedule a debounced mark-read operation
  void _scheduleMarkConversationRead(String conversationId) {
    // Cancel existing timer for this conversation
    _conversationTimers[conversationId]?.cancel();

    // Skip if already pending
    if (_pendingConversations.contains(conversationId)) {
      print(
          '📖 MarkReadService: Already pending for conversation: $conversationId');
      return;
    }

    // Schedule new operation
    _conversationTimers[conversationId] = Timer(_debounceDelay, () {
      _executeMarkConversationRead(conversationId);
    });

    print(
        '📖 MarkReadService: Scheduled mark-read for conversation: $conversationId');
  }

  /// Execute the actual mark-read operation
  Future<void> _executeMarkConversationRead(String conversationId) async {
    if (_pendingConversations.contains(conversationId)) {
      print(
          '📖 MarkReadService: Operation already in progress for: $conversationId');
      return;
    }

    try {
      _pendingConversations.add(conversationId);

      // Get current conversation state
      final conversationsNotifier = _ref.read(conversationsProvider.notifier);
      final conversationsState = _ref.read(conversationsProvider);
      final conversation = conversationsState.conversations
          .where((c) => c.id == conversationId)
          .firstOrNull;

      if (conversation == null) {
        print('❌ MarkReadService: Conversation not found: $conversationId');
        return;
      }

      if (conversation.unreadCount == 0) {
        print('📖 MarkReadService: Conversation already read: $conversationId');
        return;
      }

      print(
          '📖 MarkReadService: Executing mark-read for conversation: $conversationId (unread: ${conversation.unreadCount})');

      // Update local state immediately (optimistic)
      await conversationsNotifier.markConversationAsRead(conversationId);

      // Also update individual messages if we have pending ones
      final pendingMessages = _pendingMessageIds[conversationId];
      if (pendingMessages != null && pendingMessages.isNotEmpty) {
        _updateIndividualMessagesOptimistically(
            conversationId, pendingMessages.toList());
        _pendingMessageIds.remove(conversationId);
      }

      print(
          '✅ MarkReadService: Successfully marked conversation as read: $conversationId');
    } catch (e) {
      print(
          '❌ MarkReadService: Failed to mark conversation as read: $conversationId - $e');
      // The conversation provider will handle rollback on API failure
    } finally {
      _pendingConversations.remove(conversationId);
      _conversationTimers.remove(conversationId);
    }
  }

  /// Optimistically update conversation state immediately
  void _updateConversationStateOptimistically(String conversationId) {
    try {
      final conversationsNotifier = _ref.read(conversationsProvider.notifier);
      // This will update the UI immediately while API call happens in background
      conversationsNotifier.markConversationAsRead(conversationId);
    } catch (e) {
      print('❌ MarkReadService: Failed to update conversation state: $e');
    }
  }

  /// Update individual message read status optimistically
  void _updateIndividualMessagesOptimistically(
      String conversationId, List<String> messageIds) {
    try {
      final messagesNotifier =
          _ref.read(chatMessagesProvider(conversationId).notifier);
      final now = DateTime.now();

      for (final messageId in messageIds) {
        messagesNotifier.updateMessageStatus(messageId, 'read', now);
      }

      print(
          '📖 MarkReadService: Updated ${messageIds.length} messages optimistically');
    } catch (e) {
      print('❌ MarkReadService: Failed to update message states: $e');
    }
  }

  /// Cancel all pending operations for a conversation (when leaving chat)
  void cancelPendingOperations(String conversationId) {
    _conversationTimers[conversationId]?.cancel();
    _conversationTimers.remove(conversationId);
    _pendingConversations.remove(conversationId);
    _pendingMessageIds.remove(conversationId);

    print(
        '📖 MarkReadService: Cancelled pending operations for: $conversationId');
  }

  /// Clean up all timers
  void dispose() {
    for (final timer in _conversationTimers.values) {
      timer.cancel();
    }
    _conversationTimers.clear();
    _pendingConversations.clear();
    _pendingMessageIds.clear();
  }
}

// Provider for the mark-read service
final markReadServiceProvider = Provider<MarkReadService>((ref) {
  final chatService = ref.read(chatServiceProvider);
  return MarkReadService(chatService, ref);
});
