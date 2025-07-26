import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService;

  ChatService(this._apiService);

  /// Get conversations list for current user
  Future<List<Conversation>> getConversations() async {
    try {
      final response = await _apiService.get(ApiConstants.getConversations);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final conversationsList = data['conversations'] as List;

        final conversations = conversationsList.map((json) {
          try {
            return Conversation.fromJson(json);
          } catch (e) {
            rethrow;
          }
        }).toList();

        return conversations;
      } else {
        throw ApiException(
          message: 'Failed to get conversations',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to get conversations: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get messages for a conversation
  Future<List<Message>> getMessages(
    String conversationWithId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      // Handle new conversations that don't exist yet
      if (conversationWithId.startsWith('new_')) {
        // Return empty list for new conversations
        return [];
      }

      final response = await _apiService.get(
        '${ApiConstants.getConversationMessages}/$conversationWithId',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final messages = (data['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        return messages;
      } else {
        throw ApiException(
          message: 'Failed to get messages',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to get messages: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Send a message
  Future<Message> sendMessage({
    String? conversationId,
    String? receiverId, // For backward compatibility
    String? content,
    MessageType messageType = MessageType.text,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{
        'message_type': messageType.name,
        if (conversationId != null) 'conversation_id': conversationId,
        if (receiverId != null) 'receiver_id': receiverId,
        if (content != null) 'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await _apiService.post(
        ApiConstants.sendMessage,
        data: data,
      );

      if (response.statusCode == 201) {
        final messageData = response.data['message'] as Map<String, dynamic>;
        return Message.fromJson(messageData);
      } else {
        throw ApiException(
          message: 'Failed to send message',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to send message: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(List<String> messageIds) async {
    try {
      final response = await _apiService.post(
        ApiConstants.markAsRead,
        data: {'message_ids': messageIds},
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to mark messages as read',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to mark messages as read: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      final response = await _apiService.delete(
        '${ApiConstants.deleteMessage}/$messageId',
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to delete message',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to delete message: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Edit a message
  Future<Message> editMessage(String messageId, String newContent) async {
    try {
      final response = await _apiService.put(
        '${ApiConstants.messages}/$messageId',
        data: {'content': newContent},
      );

      if (response.statusCode == 200) {
        final messageData = response.data['message'] as Map<String, dynamic>;
        return Message.fromJson(messageData);
      } else {
        throw ApiException(
          message: 'Failed to edit message',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to edit message: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Search users for starting conversations
  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.users}/search',
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final users =
            (data['users'] as List).map((json) => User.fromJson(json)).toList();
        return users;
      } else {
        throw ApiException(
          message: 'Failed to search users',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to search users: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get contacts list for messaging
  Future<List<User>> getContacts({
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiService.get(
        '${ApiConstants.users}/contacts',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final contacts = (data['contacts'] as List)
            .map((json) => User.fromJson(json))
            .toList();
        return contacts;
      } else {
        throw ApiException(
          message: 'Failed to get contacts',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to get contacts: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Toggle reaction on a message
  Future<Map<String, dynamic>> toggleMessageReaction(
      String messageId, String emoji) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.messages}/$messageId/reactions',
        data: {'emoji': emoji},
      );

      if (response.statusCode == 200) {
        return response.data['reactions'] as Map<String, dynamic>;
      } else {
        throw ApiException(
          message: 'Failed to toggle reaction',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to toggle reaction: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Mark a conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final response = await _apiService.put(
        '${ApiConstants.markConversationAsRead}/$conversationId/mark-read',
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to mark conversation as read',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to mark conversation as read: ${e.toString()}',
        statusCode: 0,
      );
    }
  }
}

// Conversation model for chat list
class Conversation {
  final String id;
  final String type; // 'direct' or 'group'
  final String? name; // For group chats
  final String? description; // For group chats
  final String? avatarUrl; // For group chats
  final List<User> participants; // All participants
  final User? otherUser; // For direct chats, the other participant
  final Message? lastMessage;
  final int unreadCount;
  final DateTime lastActivity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOnline; // For direct chats

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.avatarUrl,
    required this.participants,
    this.otherUser,
    this.lastMessage,
    required this.unreadCount,
    required this.lastActivity,
    required this.createdAt,
    required this.updatedAt,
    required this.isOnline,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      type: json['type'] ?? 'direct',
      name: json['name'],
      description: json['description'],
      avatarUrl: json['avatar_url'],
      participants: (json['participants'] as List?)
              ?.map((p) => User.fromJson(p))
              .toList() ??
          [],
      otherUser:
          json['other_user'] != null ? User.fromJson(json['other_user']) : null,
      lastMessage: json['last_message'] != null
          ? _parseLastMessage(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'])
          : DateTime.now(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isOnline: json['is_online'] ?? false,
    );
  }

  // Helper method to safely parse last message with minimal fields
  static Message? _parseLastMessage(Map<String, dynamic> json) {
    try {
      return Message(
        id: json['id'] ?? '',
        content: json['content'],
        messageType: _parseMessageType(json['message_type']),
        isFromMe: json['is_from_me'] ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );
    } catch (e) {
      // Return a minimal message if parsing fails
      return Message(
        id: json['id'] ?? 'unknown',
        content: json['content'] ?? 'Message',
        messageType: MessageType.text,
        createdAt: DateTime.now(),
      );
    }
  }

  // Helper method to safely parse message type
  static MessageType _parseMessageType(dynamic messageType) {
    if (messageType == null) return MessageType.text;

    switch (messageType.toString().toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      case 'emoji':
        return MessageType.emoji;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'participants': participants.map((p) => p.toJson()).toList(),
      'other_user': otherUser?.toJson(),
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'last_activity': lastActivity.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_online': isOnline,
    };
  }

  Conversation copyWith({
    String? id,
    String? type,
    String? name,
    String? description,
    String? avatarUrl,
    List<User>? participants,
    User? otherUser,
    Message? lastMessage,
    int? unreadCount,
    DateTime? lastActivity,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      participants: participants ?? this.participants,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Provider for ChatService
final chatServiceProvider = Provider<ChatService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ChatService(apiService);
});

// Provider to track currently viewed conversation
final currentConversationProvider = StateProvider<String?>((ref) => null);

// Conversations provider
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final chatService = ref.read(chatServiceProvider);
  return ConversationsNotifier(chatService, ref);
});

class ConversationsState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;

  ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationsState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ChatService _chatService;
  final Ref _ref;

  ConversationsNotifier(this._chatService, this._ref)
      : super(ConversationsState()) {
    loadConversations();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final conversations = await _chatService.getConversations();
      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void updateConversationLastMessage(String conversationId, Message message) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conversation = state.conversations[index];

      // Get current user ID from storage for more reliable comparison
      final currentUserId = StorageService.getUser()?['id'];

      // Determine if message is from another user
      final isFromOtherUser = message.senderId != currentUserId &&
          message.senderId?.isNotEmpty == true &&
          currentUserId?.isNotEmpty == true;

      // Check if user is currently viewing this conversation
      final currentlyViewedConversationId =
          _ref.read(currentConversationProvider);
      final isViewingThisConversation =
          currentlyViewedConversationId == conversationId;

      // Determine new unread count
      int newUnreadCount;

      if (isViewingThisConversation) {
        // If user is viewing this conversation, always set unread count to 0
        // regardless of who sent the message
        newUnreadCount = 0;
      } else if (isFromOtherUser && message.senderId?.isNotEmpty == true) {
        // Only increment if message is from another user and user is not viewing
        newUnreadCount = conversation.unreadCount + 1;
      } else {
        // Keep existing unread count for own messages when not viewing
        newUnreadCount = conversation.unreadCount;
      }

      final updatedConversations = [...state.conversations];
      updatedConversations[index] = conversation.copyWith(
        lastMessage: message,
        lastActivity: message.createdAt,
        unreadCount: newUnreadCount,
      );

      // Move to top
      final updatedConversation = updatedConversations.removeAt(index);
      updatedConversations.insert(0, updatedConversation);

      state = state.copyWith(conversations: updatedConversations);
    } else {
      // Conversation not found in list
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conversation = state.conversations[index];

      // Update local state immediately
      final updatedConversations = [...state.conversations];
      updatedConversations[index] = updatedConversations[index].copyWith(
        unreadCount: 0,
      );
      state = state.copyWith(conversations: updatedConversations);

      // Call server API to mark conversation as read
      try {
        await _chatService.markConversationAsRead(conversationId);
      } catch (e) {
        // Revert local state if server call fails
        final revertedConversations = [...state.conversations];
        revertedConversations[index] = revertedConversations[index].copyWith(
          unreadCount: conversation.unreadCount, // Restore original count
        );
        state = state.copyWith(conversations: revertedConversations);
      }
    } else {
      // Conversation not found in local state
    }
  }

  void updateUserStatus(String userId, bool isOnline) {
    final index = state.conversations
        .indexWhere((c) => c.type == 'direct' && c.otherUser?.id == userId);

    if (index != -1) {
      final conversation = state.conversations[index];

      final updatedConversations = [...state.conversations];
      updatedConversations[index] = updatedConversations[index].copyWith(
        isOnline: isOnline,
      );
      state = state.copyWith(conversations: updatedConversations);
    } else {
      // No conversation found for user
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Chat messages provider for specific conversation
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier,
    ChatMessagesState, String>(
  (ref, conversationWithId) {
    final chatService = ref.read(chatServiceProvider);
    return ChatMessagesNotifier(chatService, conversationWithId, ref);
  },
);

class ChatMessagesState {
  final List<Message> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final bool isTyping;

  ChatMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
    this.isTyping = false,
  });

  ChatMessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? currentPage,
    bool? isTyping,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  final ChatService _chatService;
  final String _conversationWithId;
  final Ref _ref;

  ChatMessagesNotifier(this._chatService, this._conversationWithId, this._ref)
      : super(ChatMessagesState()) {
    loadMessages();
  }

  Future<void> loadMessages(
      {bool loadMore = false, bool forceRefresh = false}) async {
    if (loadMore && state.isLoadingMore) return;
    if (!loadMore && state.isLoading && !forceRefresh) return;

    // Check if we should force refresh based on conversation's lastActivity
    if (!loadMore && !forceRefresh) {
      final conversationsState = _ref.read(conversationsProvider);
      final conversation =
          conversationsState.conversations.cast<Conversation?>().firstWhere(
                (c) => c?.id == _conversationWithId,
                orElse: () => null,
              );

      if (conversation != null) {
        final timeSinceLastActivity =
            DateTime.now().difference(conversation.lastActivity);
        final shouldForceRefresh =
            timeSinceLastActivity.inSeconds < 10; // Less than 10 seconds

        if (shouldForceRefresh) {
          forceRefresh = true;
        }
      }
    }

    if (mounted) {
      state = state.copyWith(
        isLoading: !loadMore || forceRefresh,
        isLoadingMore: loadMore && !forceRefresh,
        error: null,
      );
    }

    try {
      final messages = await _chatService.getMessages(
        _conversationWithId,
        page: loadMore ? state.currentPage + 1 : 1,
      );

      // CRITICAL: Always ensure conversation's last message is included on initial load
      if (!loadMore) {
        await _ensureLastMessageIncluded(messages);
      }

      if (mounted) {
        if (loadMore) {
          // Prepend older messages to the beginning for chronological order
          state = state.copyWith(
            messages: [...messages, ...state.messages],
            isLoadingMore: false,
            hasMore: messages.length == 50,
            currentPage: state.currentPage + 1,
          );
        } else {
          state = state.copyWith(
            messages: messages,
            isLoading: false,
            hasMore: messages.length == 50,
            currentPage: 1,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Ensure the conversation's last message is included in the loaded messages
  Future<void> _ensureLastMessageIncluded(List<Message> loadedMessages) async {
    try {
      // Get the conversation from the conversations provider to check its last message
      final conversationsState = _ref.read(conversationsProvider);
      final conversation =
          conversationsState.conversations.cast<Conversation?>().firstWhere(
                (c) => c?.id == _conversationWithId,
                orElse: () => null,
              );

      if (conversation?.lastMessage != null) {
        final lastMessage = conversation!.lastMessage!;

        // Check if the last message is already in the loaded messages
        final isIncluded = loadedMessages.any((m) => m.id == lastMessage.id);

        // Also check by content and recent time as fallback (in case ID format differs)
        final recentThreshold =
            DateTime.now().subtract(const Duration(minutes: 5));
        final isRecentlyIncluded = loadedMessages.any((m) =>
            m.content == lastMessage.content &&
            m.createdAt.isAfter(recentThreshold));

        if (!isIncluded && !isRecentlyIncluded) {
          // Create a properly formatted message from the conversation's lastMessage
          final missingMessage = Message(
            id: lastMessage.id.isNotEmpty
                ? lastMessage.id
                : 'missing_${DateTime.now().millisecondsSinceEpoch}',
            senderId: lastMessage.senderId ?? '',
            receiverId: lastMessage.receiverId,
            content: lastMessage.content,
            messageType: lastMessage.messageType,
            replyToId: lastMessage.replyToId,
            metadata: lastMessage.metadata,
            reactions: lastMessage.reactions ?? const {},
            attachments: lastMessage.attachments,
            isEdited: lastMessage.isEdited ?? false,
            editedAt: lastMessage.editedAt,
            deliveredAt: lastMessage.deliveredAt,
            readAt: lastMessage.readAt,
            createdAt: lastMessage.createdAt,
            updatedAt: lastMessage.updatedAt ?? lastMessage.createdAt,
            isFromMe: lastMessage.isFromMe ?? false,
          );

          // Add the last message at the end (chronological order)
          loadedMessages.add(missingMessage);

          // Sort messages by createdAt to maintain proper order
          loadedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
      }
    } catch (e) {
      // Error ensuring last message included
    }
  }

  /// Force refresh messages to ensure sync with conversation list
  Future<void> refreshMessages() async {
    await loadMessages(forceRefresh: true);
  }

  Future<void> sendMessage({
    String? content,
    MessageType messageType = MessageType.text,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    // Create optimistic message immediately with temporary ID
    final optimisticMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
      content: content,
      messageType: messageType,
      isFromMe: true,
      createdAt: DateTime.now(),
    );

    // Add optimistic message immediately for instant UI feedback
    if (mounted) {
      state = state.copyWith(
        messages: [...state.messages, optimisticMessage],
      );
    }

    try {
      final Message serverMessage;
      final bool isNewConversation = _conversationWithId.startsWith('new_');

      // Handle new conversations
      if (isNewConversation) {
        // Extract user ID from the conversation ID format: 'new_userId'
        final receiverId =
            _conversationWithId.substring(4); // Remove 'new_' prefix

        if (receiverId.isEmpty) {
          throw Exception(
              'Invalid receiver ID extracted from conversation ID: $_conversationWithId');
        }

        serverMessage = await _chatService.sendMessage(
          receiverId: receiverId,
          content: content,
          messageType: messageType,
          replyToId: replyToId,
          metadata: metadata,
        );

        // Refresh conversations list since a new conversation was created
        _ref.read(conversationsProvider.notifier).loadConversations();
      } else {
        // Use existing conversation ID
        serverMessage = await _chatService.sendMessage(
          conversationId: _conversationWithId,
          content: content,
          messageType: messageType,
          replyToId: replyToId,
          metadata: metadata,
        );
      }

      // Replace optimistic message with server response
      if (mounted) {
        final updatedMessages = state.messages.map((msg) {
          return msg.id == optimisticMessage.id ? serverMessage : msg;
        }).toList();

        state = state.copyWith(messages: updatedMessages);
      }
    } catch (e) {
      // Remove optimistic message on error
      if (mounted) {
        final updatedMessages = state.messages
            .where((msg) => msg.id != optimisticMessage.id)
            .toList();
        state = state.copyWith(
          messages: updatedMessages,
          error: e.toString(),
        );
      }
      rethrow;
    }
  }

  void addMessage(Message message) {
    // Check if message already exists
    if (mounted && !state.messages.any((m) => m.id == message.id)) {
      state = state.copyWith(
        messages: [...state.messages, message],
      );
    }
  }

  void updateMessage(Message updatedMessage) {
    final index = state.messages.indexWhere((m) => m.id == updatedMessage.id);
    if (index != -1) {
      final updatedMessages = [...state.messages];
      updatedMessages[index] = updatedMessage;
      state = state.copyWith(messages: updatedMessages);
    }
  }

  void replaceMessage(Message serverMessage) {
    // Try to find optimistic message by content and timestamp (since it has temp ID)
    final now = DateTime.now();
    final recentThreshold =
        now.subtract(const Duration(seconds: 5)); // Recent messages only

    final optimisticIndex = state.messages.indexWhere((m) =>
            m.content == serverMessage.content &&
            m.createdAt.isAfter(recentThreshold) &&
            m.id.startsWith('temp_') // Is a temporary message
        );

    if (optimisticIndex != -1) {
      final updatedMessages = [...state.messages];
      updatedMessages[optimisticIndex] = serverMessage;
      state = state.copyWith(messages: updatedMessages);
    } else {
      // Check if it already exists with real ID (avoid duplicates)
      final existsIndex =
          state.messages.indexWhere((m) => m.id == serverMessage.id);
      if (existsIndex == -1) {
        addMessage(serverMessage);
      }
    }
  }

  void deleteMessage(String messageId) {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
  }

  void setTyping(bool isTyping) {
    state = state.copyWith(isTyping: isTyping);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Update message status for real-time read receipts
  void updateMessageStatus(
      String messageId, String status, DateTime timestamp) {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final message = state.messages[messageIndex];
      final updatedMessage = message.copyWith(
        readStatus: status == 'read'
            ? ReadStatus.read
            : status == 'delivered'
                ? ReadStatus.delivered
                : message.readStatus,
        readAt: status == 'read' ? timestamp : message.readAt,
        deliveredAt: status == 'delivered' ? timestamp : message.deliveredAt,
      );

      final updatedMessages = [...state.messages];
      updatedMessages[messageIndex] = updatedMessage;

      state = state.copyWith(messages: updatedMessages);
    }
  }
}

// Contacts provider for contact selection
final contactsProvider =
    StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  final chatService = ref.read(chatServiceProvider);
  return ContactsNotifier(chatService);
});

class ContactsState {
  final List<User> contacts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int currentPage;

  ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
  });

  ContactsState copyWith({
    List<User>? contacts,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ContactsNotifier extends StateNotifier<ContactsState> {
  final ChatService _chatService;

  ContactsNotifier(this._chatService) : super(ContactsState());

  Future<void> loadContacts({bool loadMore = false}) async {
    if (loadMore && state.isLoadingMore) return;
    if (!loadMore && state.isLoading) return;

    state = state.copyWith(
      isLoading: !loadMore,
      isLoadingMore: loadMore,
      error: null,
    );

    try {
      final contacts = await _chatService.getContacts(
        page: loadMore ? state.currentPage + 1 : 1,
      );

      if (loadMore) {
        state = state.copyWith(
          contacts: [...state.contacts, ...contacts],
          isLoadingMore: false,
          hasMore: contacts.length == 50,
          currentPage: state.currentPage + 1,
        );
      } else {
        state = state.copyWith(
          contacts: contacts,
          isLoading: false,
          hasMore: contacts.length == 50,
          currentPage: 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> searchContacts(String query) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final contacts = await _chatService.getContacts(search: query);
      state = state.copyWith(
        contacts: contacts,
        isLoading: false,
        hasMore: false, // Search results don't have pagination
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
