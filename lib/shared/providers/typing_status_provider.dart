import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_service.dart';

// Map of conversationId -> Map of userId -> isTyping
class TypingStatusNotifier
    extends StateNotifier<Map<String, Map<String, bool>>> {
  final RealtimeService _realtimeService;

  TypingStatusNotifier(this._realtimeService) : super({}) {
    // Listen to typing events
    _realtimeService.typingStream.listen((typingEvent) {
      _updateTypingStatus(typingEvent);
    });
  }

  void _updateTypingStatus(TypingEvent typingEvent) {
    final conversationId = typingEvent.conversationId;
    final userId = typingEvent.userId;
    final isTyping = typingEvent.isTyping;

    final currentState = state;
    final newState = Map<String, Map<String, bool>>.from(currentState);

    if (!newState.containsKey(conversationId)) {
      newState[conversationId] = {};
    }

    if (isTyping) {
      newState[conversationId]![userId] = true;
    } else {
      newState[conversationId]!.remove(userId);

      // Remove conversation if no one is typing
      if (newState[conversationId]!.isEmpty) {
        newState.remove(conversationId);
      }
    }

    state = newState;
  }

  // Get typing users for a specific conversation
  List<String> getTypingUsers(String conversationId) {
    final typingUsers = state[conversationId];
    if (typingUsers == null) return [];
    return typingUsers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  // Check if anyone is typing in a conversation
  bool isAnyoneTyping(String conversationId) {
    final typingUsers = state[conversationId];
    return typingUsers != null &&
        typingUsers.values.any((isTyping) => isTyping);
  }

  // Clear typing status for a conversation (when leaving)
  void clearConversation(String conversationId) {
    final currentState = state;
    final newState = Map<String, Map<String, bool>>.from(currentState);
    newState.remove(conversationId);
    state = newState;
  }
}

final typingStatusProvider =
    StateNotifierProvider<TypingStatusNotifier, Map<String, Map<String, bool>>>(
        (ref) {
  final realtimeService = ref.watch(realtimeServiceProvider);
  return TypingStatusNotifier(realtimeService);
});

// Helper providers for specific conversations
final conversationTypingUsersProvider =
    Provider.family<List<String>, String>((ref, conversationId) {
  final typingStatus = ref.watch(typingStatusProvider);
  final typingUsers = typingStatus[conversationId];
  if (typingUsers == null) return [];
  return typingUsers.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();
});

final conversationIsTypingProvider =
    Provider.family<bool, String>((ref, conversationId) {
  final typingUsers =
      ref.watch(conversationTypingUsersProvider(conversationId));
  return typingUsers.isNotEmpty;
});
