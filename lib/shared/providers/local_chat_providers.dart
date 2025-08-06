import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_chat_service.dart';
import '../services/realtime_service.dart';
import '../models/local_conversation.dart';
import '../models/local_message.dart';
import '../models/local_user.dart';
import '../database/chat_database.dart';
import '../../core/storage/storage_service.dart';

/// Provider for local conversations (instant loading)
final localConversationsProvider = StateNotifierProvider<
    LocalConversationsNotifier, AsyncValue<List<LocalConversation>>>(
  (ref) => LocalConversationsNotifier(ref.read(localChatServiceProvider)),
);

class LocalConversationsNotifier
    extends StateNotifier<AsyncValue<List<LocalConversation>>> {
  final LocalChatService _chatService;
  StreamSubscription? _realtimeSubscription;

  LocalConversationsNotifier(this._chatService)
      : super(const AsyncValue.loading()) {
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      // Load instantly from local database
      final conversations = await _chatService.getConversations();
      if (mounted) {
        state = AsyncValue.data(conversations);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() => _loadConversations();

  void markAsRead(String conversationId) {
    // Update database immediately
    _chatService.markConversationAsRead(conversationId);

    // Optimistically update UI
    state.whenData((conversations) {
      final updated = conversations
          .map((c) =>
              c.serverId == conversationId ? c.copyWith(unreadCount: 0) : c)
          .toList();
      if (mounted) {
        state = AsyncValue.data(updated);
      }
    });
  }

  void addOrUpdateConversation(LocalConversation conversation) {
    state.whenData((conversations) {
      final existingIndex =
          conversations.indexWhere((c) => c.serverId == conversation.serverId);

      List<LocalConversation> updated;
      if (existingIndex != -1) {
        // Update existing conversation
        updated = [...conversations];
        updated[existingIndex] = conversation;
      } else {
        // Add new conversation at the top
        updated = [conversation, ...conversations];
      }

      // Sort by last activity (most recent first)
      updated.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      if (mounted) {
        state = AsyncValue.data(updated);
      }
    });
  }

  void updateLastMessage(String conversationId, LocalMessage message) {
    state.whenData((conversations) {
      final updated = conversations.map((c) {
        if (c.serverId == conversationId) {
          return c.copyWith(
            lastMessage: message.content,
            lastMessageAt: message.createdAt,
            lastActivity: message.createdAt,
            unreadCount: message.isFromMe ? c.unreadCount : c.unreadCount + 1,
          );
        }
        return c;
      }).toList();

      // Sort by last activity
      updated.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      if (mounted) {
        state = AsyncValue.data(updated);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for local messages in a specific conversation
final localMessagesProvider = StateNotifierProvider.family<
    LocalMessagesNotifier, AsyncValue<List<LocalMessage>>, String>(
  (ref, conversationId) => LocalMessagesNotifier(
    ref.read(localChatServiceProvider),
    conversationId,
    ref,
  ),
);

class LocalMessagesNotifier
    extends StateNotifier<AsyncValue<List<LocalMessage>>> {
  final LocalChatService _chatService;
  final String _conversationId;
  final Ref _ref;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize = 50;

  LocalMessagesNotifier(this._chatService, this._conversationId, this._ref)
      : super(const AsyncValue.loading()) {
    _loadMessages();
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    try {
      if (loadMore && !_hasMore) return;

      final offset = loadMore ? _currentOffset : 0;

      // Load instantly from local database
      final messages = await _chatService.getMessages(
        _conversationId,
        limit: _pageSize,
        offset: offset,
      );

      if (mounted) {
        if (loadMore) {
          // Append older messages
          state.whenData((existingMessages) {
            final combined = [...existingMessages, ...messages];
            state = AsyncValue.data(combined);
          });
        } else {
          // Replace with fresh data
          state = AsyncValue.data(messages);
        }

        _currentOffset = offset + messages.length;
        _hasMore = messages.length >= _pageSize;
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> sendMessage(
    String content, {
    LocalMessageType messageType = LocalMessageType.text,
    String? replyToId,
  }) async {
    final startTime = DateTime.now();
    print(
        '🐛 [DEBUG] sendMessage called at ${startTime.millisecondsSinceEpoch}');

    // 🚀 INSTANT OPTIMISTIC UPDATE - Message appears immediately!
    final currentUser = StorageService.getUser();
    if (currentUser == null) {
      print('🐛 [DEBUG] No current user, returning early');
      return;
    }

    final userCheckTime = DateTime.now();
    print(
        '🐛 [DEBUG] User check took: ${userCheckTime.difference(startTime).inMilliseconds}ms');

    // Create optimistic message with temporary ID
    final optimisticMessage = LocalMessage(
      serverId: null, // Will be set when synced to server
      conversationId: _conversationId,
      senderId: currentUser['id'],
      content: content,
      messageType: messageType,
      replyToId: replyToId,
      createdAt: DateTime.now(),
      isFromMe: true,
      isSynced: false,
      readStatus: 'sending', // Special status for optimistic messages
    );

    final messageCreateTime = DateTime.now();
    print(
        '🐛 [DEBUG] Message creation took: ${messageCreateTime.difference(userCheckTime).inMilliseconds}ms');

    // 🚀 STEP 1: Update UI INSTANTLY (0ms delay)
    print('🐛 [DEBUG] Starting UI update...');
    final uiUpdateStart = DateTime.now();

    state.whenData((messages) {
      if (mounted) {
        state = AsyncValue.data([...messages, optimisticMessage]);
        final uiUpdateEnd = DateTime.now();
        print(
            '🐛 [DEBUG] UI state update took: ${uiUpdateEnd.difference(uiUpdateStart).inMilliseconds}ms');
      }
    });

    final uiUpdateTime = DateTime.now();
    print(
        '🐛 [DEBUG] UI update completed in: ${uiUpdateTime.difference(messageCreateTime).inMilliseconds}ms');

    // 🚀 STEP 2: Update conversations list INSTANTLY
    print('🐛 [DEBUG] Updating conversations list...');
    final convUpdateStart = DateTime.now();

    _ref
        .read(localConversationsProvider.notifier)
        .updateLastMessage(_conversationId, optimisticMessage);

    final convUpdateTime = DateTime.now();
    print(
        '🐛 [DEBUG] Conversations update took: ${convUpdateTime.difference(convUpdateStart).inMilliseconds}ms');

    // 🚀 STEP 3: Save to database and sync in background (no await!)
    print('🐛 [DEBUG] Starting background operations (non-blocking)...');
    _sendMessageInBackground(
        optimisticMessage, content, messageType, replyToId);

    final totalTime = DateTime.now();
    print(
        '🐛 [DEBUG] ✅ sendMessage COMPLETED in: ${totalTime.difference(startTime).inMilliseconds}ms');
    print('🐛 [DEBUG] 🚀 Message should be visible in UI now!');
  }

  /// Background operation - doesn't block UI
  void _sendMessageInBackground(
    LocalMessage optimisticMessage,
    String content,
    LocalMessageType messageType,
    String? replyToId,
  ) async {
    final bgStartTime = DateTime.now();
    print(
        '🐛 [BACKGROUND] Starting background save at ${bgStartTime.millisecondsSinceEpoch}');

    try {
      // Save to local database ONLY (optimistic message already in UI)
      print('🐛 [BACKGROUND] Saving optimistic message to database...');
      final saveStart = DateTime.now();

      await _chatService.saveMessageLocally(optimisticMessage);

      final saveEnd = DateTime.now();
      print(
          '🐛 [BACKGROUND] Database save took: ${saveEnd.difference(saveStart).inMilliseconds}ms');

      // Now sync to server separately
      print('🐛 [BACKGROUND] Syncing to server...');
      final serverStart = DateTime.now();

      final serverMessage =
          await _chatService.syncMessageToServer(optimisticMessage);

      final serverEnd = DateTime.now();
      print(
          '🐛 [BACKGROUND] Server sync took: ${serverEnd.difference(serverStart).inMilliseconds}ms');

      // Update the optimistic message with server response (has real ID)
      print('🐛 [BACKGROUND] Updating UI with server message...');
      final uiUpdateStart = DateTime.now();

      state.whenData((messages) {
        if (mounted) {
          final updated = messages.map((msg) {
            // Replace optimistic message with server message
            if (msg.createdAt == optimisticMessage.createdAt &&
                msg.content == optimisticMessage.content &&
                msg.isFromMe) {
              return serverMessage.copyWith(
                  readStatus: 'sent'); // Change from 'sending' to 'sent'
            }
            return msg;
          }).toList();
          state = AsyncValue.data(updated);
        }
      });

      final uiUpdateEnd = DateTime.now();
      print(
          '🐛 [BACKGROUND] UI update took: ${uiUpdateEnd.difference(uiUpdateStart).inMilliseconds}ms');

      final totalBgTime = DateTime.now();
      print(
          '🐛 [BACKGROUND] ✅ Background save completed in: ${totalBgTime.difference(bgStartTime).inMilliseconds}ms');
    } catch (e) {
      print('🐛 [BACKGROUND] ❌ Background save FAILED: $e');

      // Only mark as failed if it's not a duplicate error
      if (!e.toString().contains('Unique index violated')) {
        // Mark message as failed for genuine errors
        state.whenData((messages) {
          if (mounted) {
            final updated = messages.map((msg) {
              if (msg.createdAt == optimisticMessage.createdAt &&
                  msg.content == optimisticMessage.content &&
                  msg.isFromMe) {
                return msg.copyWith(readStatus: 'failed');
              }
              return msg;
            }).toList();
            state = AsyncValue.data(updated);
          }
        });

        print('Failed to send message: $e');
      } else {
        // For duplicate errors, just mark as sent since it succeeded
        print('🐛 [BACKGROUND] Duplicate message detected, marking as sent');
        state.whenData((messages) {
          if (mounted) {
            final updated = messages.map((msg) {
              if (msg.createdAt == optimisticMessage.createdAt &&
                  msg.content == optimisticMessage.content &&
                  msg.isFromMe) {
                return msg.copyWith(readStatus: 'sent');
              }
              return msg;
            }).toList();
            state = AsyncValue.data(updated);
          }
        });
      }
    }
  }

  Future<void> loadMore() async {
    await _loadMessages(loadMore: true);
  }

  Future<void> refresh() async {
    _currentOffset = 0;
    _hasMore = true;
    await _loadMessages();
  }

  void addMessage(LocalMessage message) {
    state.whenData((messages) {
      // Check if message already exists
      final exists = messages.any((m) =>
          (m.serverId != null && m.serverId == message.serverId) ||
          (m.id == message.id));

      if (!exists && mounted) {
        state = AsyncValue.data([...messages, message]);
      }
    });
  }

  void updateMessage(LocalMessage updatedMessage) {
    state.whenData((messages) {
      final index = messages.indexWhere((m) =>
          (m.serverId != null && m.serverId == updatedMessage.serverId) ||
          (m.id == updatedMessage.id));

      if (index != -1 && mounted) {
        final updated = [...messages];
        updated[index] = updatedMessage;
        state = AsyncValue.data(updated);
      }
    });
  }

  bool get hasMore => _hasMore;
}

/// Provider for local contacts/users
final localContactsProvider =
    StateNotifierProvider<LocalContactsNotifier, AsyncValue<List<LocalUser>>>(
  (ref) => LocalContactsNotifier(ref.read(localChatServiceProvider)),
);

class LocalContactsNotifier extends StateNotifier<AsyncValue<List<LocalUser>>> {
  final LocalChatService _chatService;

  LocalContactsNotifier(this._chatService) : super(const AsyncValue.loading()) {
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      // For now, return empty list - implement contact caching later
      if (mounted) {
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> searchContacts(String query) async {
    try {
      // Search locally first, then from API if needed
      final localResults = await ChatDatabase.searchContacts(query);

      if (mounted) {
        state = AsyncValue.data(localResults);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() => _loadContacts();
}

/// Provider for message search
final messageSearchProvider = StateNotifierProvider.family<
    MessageSearchNotifier, AsyncValue<List<LocalMessage>>, String>(
  (ref, query) => MessageSearchNotifier(
    ref.read(localChatServiceProvider),
    query,
  ),
);

class MessageSearchNotifier
    extends StateNotifier<AsyncValue<List<LocalMessage>>> {
  final LocalChatService _chatService;
  final String _query;

  MessageSearchNotifier(this._chatService, this._query)
      : super(const AsyncValue.loading()) {
    if (_query.trim().isNotEmpty) {
      _searchMessages();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> _searchMessages() async {
    try {
      // Search locally (instant results)
      final results = await _chatService.searchMessages(_query);
      if (mounted) {
        state = AsyncValue.data(results);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> searchInConversation(String conversationId) async {
    try {
      final results = await _chatService.searchMessages(
        _query,
        conversationId: conversationId,
      );
      if (mounted) {
        state = AsyncValue.data(results);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}

/// Provider for real-time integration
final localChatRealtimeProvider = Provider<LocalChatRealtime>((ref) {
  return LocalChatRealtime(ref);
});

class LocalChatRealtime {
  final Ref _ref;

  LocalChatRealtime(this._ref) {
    _initialize();
  }

  void _initialize() {
    // Listen for real-time messages and update local providers
    // TODO: Implement real-time integration after verifying existing provider structure
    print('LocalChatRealtime initialized - real-time integration pending');
  }

  void _handleRealtimeMessage(dynamic message, String conversationId) {
    // TODO: Convert message to LocalMessage and update providers
    // This will be implemented based on your existing Message model structure
    print('Handling real-time message for conversation: $conversationId');
  }
}
