import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message.dart';
import '../models/user.dart';
import '../../core/storage/storage_service.dart';
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class SocketService {
  late IO.Socket _socket;
  bool _isConnected = false;
  
  // Stream controllers for real-time events
  final _messageStreamController = StreamController<Message>.broadcast();
  final _typingStreamController = StreamController<TypingIndicator>.broadcast();
  final _userStatusStreamController = StreamController<UserStatus>.broadcast();
  final _connectionStreamController = StreamController<bool>.broadcast();

  // Getters for streams
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<TypingIndicator> get typingStream => _typingStreamController.stream;
  Stream<UserStatus> get userStatusStream => _userStatusStreamController.stream;
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  bool get isConnected => _isConnected;

  /// Initialize and connect to socket
  Future<void> connect() async {
    final token = StorageService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final user = StorageService.getUser();
    if (user == null) {
      throw Exception('No user data found');
    }

    _socket = IO.io(
      ApiConstants.baseUrl.replaceAll('/api', ''), // Remove /api for socket connection
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({
            'token': token,
            'userId': user['id'],
          })
          .build(),
    );

    _setupEventListeners();
    _socket.connect();
  }

  /// Setup event listeners for socket events
  void _setupEventListeners() {
    // Connection events
    _socket.onConnect((_) {
      print('Socket connected');
      _isConnected = true;
      _connectionStreamController.add(true);
    });

    _socket.onDisconnect((_) {
      print('Socket disconnected');
      _isConnected = false;
      _connectionStreamController.add(false);
    });

    _socket.onConnectError((error) {
      print('Socket connection error: $error');
      _isConnected = false;
      _connectionStreamController.add(false);
    });

    // Message events
    _socket.on(ApiConstants.wsNewMessage, (data) {
      try {
        final messageData = data as Map<String, dynamic>;
        final message = Message.fromJson(messageData);
        _messageStreamController.add(message);
      } catch (e) {
        print('Error parsing new message: $e');
      }
    });

    _socket.on(ApiConstants.wsMessageReceived, (data) {
      try {
        final messageData = data as Map<String, dynamic>;
        final message = Message.fromJson(messageData);
        _messageStreamController.add(message);
      } catch (e) {
        print('Error parsing message received: $e');
      }
    });

    // Typing events
    _socket.on(ApiConstants.wsTypingStart, (data) {
      try {
        final typingData = data as Map<String, dynamic>;
        _typingStreamController.add(TypingIndicator(
          userId: typingData['userId'],
          conversationWith: typingData['conversationWith'],
          isTyping: true,
        ));
      } catch (e) {
        print('Error parsing typing start: $e');
      }
    });

    _socket.on(ApiConstants.wsTypingStop, (data) {
      try {
        final typingData = data as Map<String, dynamic>;
        _typingStreamController.add(TypingIndicator(
          userId: typingData['userId'],
          conversationWith: typingData['conversationWith'],
          isTyping: false,
        ));
      } catch (e) {
        print('Error parsing typing stop: $e');
      }
    });

    // User status events
    _socket.on(ApiConstants.wsUserOnline, (data) {
      try {
        final statusData = data as Map<String, dynamic>;
        _userStatusStreamController.add(UserStatus(
          userId: statusData['userId'],
          isOnline: true,
          lastSeen: DateTime.now(),
        ));
      } catch (e) {
        print('Error parsing user online: $e');
      }
    });

    _socket.on(ApiConstants.wsUserOffline, (data) {
      try {
        final statusData = data as Map<String, dynamic>;
        _userStatusStreamController.add(UserStatus(
          userId: statusData['userId'],
          isOnline: false,
          lastSeen: DateTime.parse(statusData['lastSeen']),
        ));
      } catch (e) {
        print('Error parsing user offline: $e');
      }
    });
  }

  /// Join a conversation room
  void joinConversation(String conversationId) {
    if (_isConnected) {
      _socket.emit(ApiConstants.wsJoinRoom, {'conversationId': conversationId});
    }
  }

  /// Leave a conversation room
  void leaveConversation(String conversationId) {
    if (_isConnected) {
      _socket.emit(ApiConstants.wsLeaveRoom, {'conversationId': conversationId});
    }
  }

  /// Send a message through socket
  void sendMessage(Message message) {
    if (_isConnected) {
      _socket.emit(ApiConstants.wsNewMessage, message.toJson());
    }
  }

  /// Start typing indicator
  void startTyping(String conversationWith) {
    if (_isConnected) {
      _socket.emit(ApiConstants.wsTypingStart, {
        'conversationWith': conversationWith,
      });
    }
  }

  /// Stop typing indicator
  void stopTyping(String conversationWith) {
    if (_isConnected) {
      _socket.emit(ApiConstants.wsTypingStop, {
        'conversationWith': conversationWith,
      });
    }
  }

  /// Disconnect socket
  void disconnect() {
    if (_isConnected) {
      _socket.disconnect();
      _isConnected = false;
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
    _connectionStreamController.close();
  }
}

// Models for socket events
class TypingIndicator {
  final String userId;
  final String conversationWith;
  final bool isTyping;

  TypingIndicator({
    required this.userId,
    required this.conversationWith,
    required this.isTyping,
  });
}

class UserStatus {
  final String userId;
  final bool isOnline;
  final DateTime lastSeen;

  UserStatus({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
  });
}

// Provider for SocketService
final socketServiceProvider = Provider<SocketService>((ref) {
  final socketService = SocketService();
  
  // Listen to auth state and connect/disconnect accordingly
  ref.listen(authStateProvider, (previous, next) {
    if (next.isAuthenticated && !socketService.isConnected) {
      socketService.connect();
    } else if (!next.isAuthenticated && socketService.isConnected) {
      socketService.disconnect();
    }
  });

  ref.onDispose(() {
    socketService.dispose();
  });

  return socketService;
});

// Socket connection state provider
final socketConnectionProvider = StreamProvider<bool>((ref) {
  final socketService = ref.read(socketServiceProvider);
  return socketService.connectionStream;
});

// Message stream provider
final messageStreamProvider = StreamProvider<Message>((ref) {
  final socketService = ref.read(socketServiceProvider);
  return socketService.messageStream;
});

// Typing indicator stream provider
final typingStreamProvider = StreamProvider<TypingIndicator>((ref) {
  final socketService = ref.read(socketServiceProvider);
  return socketService.typingStream;
});

// User status stream provider
final userStatusStreamProvider = StreamProvider<UserStatus>((ref) {
  final socketService = ref.read(socketServiceProvider);
  return socketService.userStatusStream;
}); 