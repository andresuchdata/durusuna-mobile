import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/conversation.dart';
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
            // Enhanced error logging for debugging
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
        ApiConstants.getConversationMessages(conversationWithId),
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

  /// Load more messages for a conversation (optimized endpoint)
  Future<List<Message>> loadMoreMessages(
    String conversationId, {
    String? beforeMessageId,
    int limit = 50,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'limit': limit,
      };

      if (beforeMessageId != null) {
        queryParameters['before'] = beforeMessageId;
      }

      final response = await _apiService.get(
        ApiConstants.loadMoreMessages(conversationId),
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final messages = (data['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        return messages;
      } else {
        throw ApiException(
          message: 'Failed to load more messages',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to load more messages: ${e.toString()}',
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
        if (content != null) 'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (metadata != null) 'metadata': metadata,
      };

      String endpoint;

      // Determine which endpoint to use based on whether it's a conversation message or direct message
      if (conversationId != null) {
        // Send message to existing conversation
        endpoint = ApiConstants.sendConversationMessage(conversationId);
        data['conversation_id'] = conversationId;
      } else if (receiverId != null) {
        // Send direct message (creates conversation if needed)
        endpoint = ApiConstants.sendMessage;
        data['receiver_id'] = receiverId;
      } else {
        throw ApiException(
          message: 'Either conversation_id or receiver_id is required',
          statusCode: 400,
        );
      }

      final response = await _apiService.post(endpoint, data: data);

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

  /// Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final response = await _apiService.put(
        ApiConstants.markConversationAsRead(conversationId),
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

  /// Delete a message (Note: This functionality may not be available in the current backend)
  Future<void> deleteMessage(String messageId) async {
    try {
      // TODO: Update this when message deletion endpoint is available in backend
      throw ApiException(
        message: 'Message deletion not currently supported',
        statusCode: 501,
      );
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

  /// Search messages
  Future<List<Message>> searchMessages(String query) async {
    try {
      final response = await _apiService.get(
        ApiConstants.searchMessages,
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final messages = (data['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        return messages;
      } else {
        throw ApiException(
          message: 'Failed to search messages',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to search messages: ${e.toString()}',
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

// Helper function to safely parse message type
MessageType _parseMessageType(dynamic messageType) {
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
  final Set<String> _processedMessageIds = {}; // Track processed message IDs

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
    // Check for duplicate processing
    if (_processedMessageIds.contains(message.id)) {
      return;
    }

    // Mark message as processed
    _processedMessageIds.add(message.id);

    // Cleanup: Keep only the last 100 processed message IDs to prevent memory issues
    if (_processedMessageIds.length > 100) {
      final messagesList = _processedMessageIds.toList();
      _processedMessageIds.clear();
      _processedMessageIds
          .addAll(messagesList.skip(messagesList.length - 50)); // Keep last 50
    }

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
      // Convert full Message to simplified LastMessage
      final lastMessage = LastMessage(
        content: message.content,
        messageType: message.messageType,
        createdAt: message.createdAt,
        isFromMe: message.isFromMe,
      );

      updatedConversations[index] = conversation.copyWith(
        lastMessage: lastMessage,
        lastActivity: message.createdAt,
        unreadCount: newUnreadCount,
      );

      // Move to top
      final updatedConversation = updatedConversations.removeAt(index);
      updatedConversations.insert(0, updatedConversation);

      state = state.copyWith(conversations: updatedConversations);
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

      if (conversation != null && conversation.lastActivity != null) {
        final timeSinceLastActivity =
            DateTime.now().difference(conversation.lastActivity!);
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

        // Check by content and recent time since LastMessage doesn't have ID
        final recentThreshold =
            DateTime.now().subtract(const Duration(minutes: 5));
        final isRecentlyIncluded = loadedMessages.any((m) =>
            m.content == lastMessage.content &&
            m.createdAt.isAfter(recentThreshold) &&
            m.messageType == lastMessage.messageType);

        if (!isRecentlyIncluded) {
          // Create a basic message from the conversation's lastMessage
          // Note: LastMessage has limited data, so we'll create a minimal Message
          final missingMessage = Message(
            id: 'last_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: _conversationWithId,
            senderId: '', // Not available in LastMessage
            content: lastMessage.content,
            messageType: lastMessage.messageType,
            createdAt: lastMessage.createdAt,
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
    final currentUser = StorageService.getUser();
    final optimisticMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
      conversationId: _conversationWithId,
      senderId: currentUser?['id']?.toString() ?? '',
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
