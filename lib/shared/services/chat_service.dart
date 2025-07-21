import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';
import 'socket_service.dart';

class ChatService {
  final ApiService _apiService;

  ChatService(this._apiService);

  /// Get conversations list for current user
  Future<List<Conversation>> getConversations() async {
    try {
      final response = await _apiService.get(ApiConstants.getConversations);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final conversations = (data['conversations'] as List)
            .map((json) => Conversation.fromJson(json))
            .toList();
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
          ? Message.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      lastActivity: DateTime.parse(json['last_activity']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isOnline: json['is_online'] ?? false,
    );
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

// Conversations provider
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final chatService = ref.read(chatServiceProvider);
  return ConversationsNotifier(chatService);
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

  ConversationsNotifier(this._chatService) : super(ConversationsState()) {
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
      final updatedConversations = [...state.conversations];
      updatedConversations[index] = updatedConversations[index].copyWith(
        lastMessage: message,
        lastActivity: message.createdAt,
      );

      // Move to top
      final conversation = updatedConversations.removeAt(index);
      updatedConversations.insert(0, conversation);

      state = state.copyWith(conversations: updatedConversations);
    }
  }

  void markConversationAsRead(String conversationId) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final updatedConversations = [...state.conversations];
      updatedConversations[index] = updatedConversations[index].copyWith(
        unreadCount: 0,
      );
      state = state.copyWith(conversations: updatedConversations);
    }
  }

  void updateUserStatus(String userId, bool isOnline) {
    final index = state.conversations
        .indexWhere((c) => c.type == 'direct' && c.otherUser?.id == userId);
    if (index != -1) {
      final updatedConversations = [...state.conversations];
      updatedConversations[index] = updatedConversations[index].copyWith(
        isOnline: isOnline,
      );
      state = state.copyWith(conversations: updatedConversations);
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
    return ChatMessagesNotifier(chatService, conversationWithId);
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

  ChatMessagesNotifier(this._chatService, this._conversationWithId)
      : super(ChatMessagesState()) {
    loadMessages();
  }

  Future<void> loadMessages({bool loadMore = false}) async {
    if (loadMore && state.isLoadingMore) return;
    if (!loadMore && state.isLoading) return;

    if (mounted) {
      state = state.copyWith(
        isLoading: !loadMore,
        isLoadingMore: loadMore,
        error: null,
      );
    }

    try {
      final messages = await _chatService.getMessages(
        _conversationWithId,
        page: loadMore ? state.currentPage + 1 : 1,
      );

      if (mounted) {
        if (loadMore) {
          state = state.copyWith(
            messages: [...state.messages, ...messages],
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

  Future<void> sendMessage({
    String? content,
    MessageType messageType = MessageType.text,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final Message message;

      // Handle new conversations
      if (_conversationWithId.startsWith('new_')) {
        // Extract user ID from the conversation ID format: 'new_userId'
        final receiverId =
            _conversationWithId.substring(4); // Remove 'new_' prefix

        message = await _chatService.sendMessage(
          receiverId: receiverId,
          content: content,
          messageType: messageType,
          replyToId: replyToId,
          metadata: metadata,
        );
      } else {
        // Use existing conversation ID
        message = await _chatService.sendMessage(
          conversationId: _conversationWithId,
          content: content,
          messageType: messageType,
          replyToId: replyToId,
          metadata: metadata,
        );
      }

      // Add message to the beginning of the list (newest first)
      if (mounted) {
        state = state.copyWith(
          messages: [message, ...state.messages],
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  void addMessage(Message message) {
    // Check if message already exists
    if (mounted && !state.messages.any((m) => m.id == message.id)) {
      state = state.copyWith(
        messages: [message, ...state.messages],
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
