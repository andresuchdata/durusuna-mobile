import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/message.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';
import 'auth_service.dart';

/// Comprehensive realtime service for modern chat features
class RealtimeService with WidgetsBindingObserver {
  static RealtimeService? _instance;
  static RealtimeService get instance => _instance ??= RealtimeService._();

  RealtimeService._() {
    // Add lifecycle observer for Android app state changes
    WidgetsBinding.instance.addObserver(this);
  }

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;
  Timer? _connectionCheckTimer;

  // Stream controllers for different realtime events
  final _connectionController = StreamController<bool>.broadcast();
  final _messageController = StreamController<RealtimeMessage>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _presenceController = StreamController<PresenceEvent>.broadcast();
  final _messageStatusController =
      StreamController<MessageStatusEvent>.broadcast();
  final _conversationController =
      StreamController<ConversationEvent>.broadcast();
  final _reactionController = StreamController<ReactionEvent>.broadcast();
  final _fileUploadController = StreamController<FileUploadEvent>.broadcast();
  final _voiceRecordController = StreamController<VoiceRecordEvent>.broadcast();
  final _lastSeenController = StreamController<LastSeenEvent>.broadcast();

  // Public streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<RealtimeMessage> get messageStream => _messageController.stream;
  Stream<TypingEvent> get typingStream => _typingController.stream;
  Stream<PresenceEvent> get presenceStream => _presenceController.stream;
  Stream<MessageStatusEvent> get messageStatusStream =>
      _messageStatusController.stream;
  Stream<ConversationEvent> get conversationStream =>
      _conversationController.stream;
  Stream<ReactionEvent> get reactionStream => _reactionController.stream;
  Stream<FileUploadEvent> get fileUploadStream => _fileUploadController.stream;
  Stream<VoiceRecordEvent> get voiceRecordStream =>
      _voiceRecordController.stream;
  Stream<LastSeenEvent> get lastSeenStream => _lastSeenController.stream;

  // Connection management
  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;

  /// Initialize and connect to realtime service
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final token = StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // iOS-friendly socket configuration
      final optionBuilder = io.OptionBuilder()
          .setAuth({'token': token})
          .setTimeout(15000) // Longer timeout for iOS
          .enableAutoConnect();

      // iOS needs polling fallback, Android works fine with websocket only
      if (Platform.isIOS) {
        optionBuilder.setTransports(['websocket', 'polling']);
      } else {
        optionBuilder.setTransports(['websocket']);
      }

      _socket = io.io(
        ApiConstants.socketUrl,
        optionBuilder.build(),
      );

      _setupEventListeners();
    } catch (e) {
      _connectionController.add(false);
      rethrow;
    }
  }

  /// Disconnect from realtime service
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentUserId = null;
    _connectionController.add(false);
    _stopConnectionCheck();
  }

  /// App lifecycle handling for Android
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - ensure connection is active
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        // App went to background - maintain connection but reduce activity
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleAppResumed() {
    // Check if connection is still active when app resumes
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!_isConnected && StorageService.getToken() != null) {
        reconnect();
      } else if (_isConnected) {
        // Refresh presence even if connected
        _setupUserPresence();
      }
    });
    _startConnectionCheck();
  }

  void _handleAppPaused() {
    // Keep connection but stop intensive checks
    _stopConnectionCheck();
  }

  void _startConnectionCheck() {
    _stopConnectionCheck();
    if (Platform.isAndroid) {
      // More frequent connection checks on Android
      _connectionCheckTimer =
          Timer.periodic(const Duration(seconds: 30), (timer) {
        _checkConnectionHealth();
      });
    }
  }

  void _stopConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  void _checkConnectionHealth() {
    if (!_isConnected && StorageService.getToken() != null) {
      reconnect();
    } else if (_isConnected && _socket != null) {
      // Ping the server to ensure connection is active
      _socket!
          .emit('ping', {'timestamp': DateTime.now().millisecondsSinceEpoch});
    }
  }

  /// Force reconnection with fresh token (useful after login)
  Future<void> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500)); // Brief delay
    await connect();
    if (Platform.isAndroid) {
      _startConnectionCheck(); // Start health checks on Android
    }
  }

  /// Force initialization - useful when app starts or after login
  Future<void> initialize() async {
    if (!_isConnected) {
      await connect();
      if (Platform.isAndroid) {
        _startConnectionCheck();
      }
    }
  }

  /// Check WebSocket support and connection status
  bool get canConnect {
    final token = StorageService.getToken();
    const hasNetwork = true; // Assume network is available
    return token != null && hasNetwork;
  }

  /// Get detailed connection info for debugging
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': _isConnected,
      'socketUrl': ApiConstants.socketUrl,
      'currentUserId': _currentUserId,
      'hasToken': StorageService.getToken() != null,
      'platform': Platform.operatingSystem,
    };
  }

  void _setupEventListeners() {
    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionController.add(true);
      _setupUserPresence();
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onReconnect((attempt) {
      _setupUserPresence();
    });

    _socket!.onReconnectAttempt((attempt) {});
    _socket!.onReconnectError((error) {});

    _socket!.onConnectError((error) {
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onError((error) {});

    // Additional debugging events
    _socket!.on('connect', (_) {});

    _socket!.on('disconnect', (reason) {});

    // Test event for iOS debugging
    _socket!.on('test', (data) {});

    // Engine.IO debugging events
    _socket!.on('connect_error', (error) {});

    // Message events
    _socket!.on('message:new', (data) {
      try {
        final message = RealtimeMessage.fromJson(data);
        _messageController.add(message);
      } catch (e) {
        // Error parsing message:new event
      }
    });

    _socket!.on('message:updated', (data) {
      try {
        final message = RealtimeMessage.fromJson(data);
        _messageController.add(message);
      } catch (e) {
        // Error parsing message:updated event
      }
    });

    _socket!.on('message:deleted', (data) {
      try {
        final message = RealtimeMessage.fromJson(data);
        _messageController.add(message);
      } catch (e) {
        // Error parsing message:deleted event
      }
    });

    // Typing indicators
    _socket!.on('typing:start', (data) {
      final event = TypingEvent.fromJson(data);
      _typingController.add(event);
    });

    _socket!.on('typing:stop', (data) {
      final event = TypingEvent.fromJson(data);
      _typingController.add(event);
    });

    // User presence
    _socket!.on('presence:online', (data) {
      final event = PresenceEvent.fromJson(data);
      _presenceController.add(event);
    });

    _socket!.on('presence:offline', (data) {
      final event = PresenceEvent.fromJson(data);
      _presenceController.add(event);
    });

    // Message status updates
    _socket!.on('message:delivered', (data) {
      final event = MessageStatusEvent.fromJson(data);
      _messageStatusController.add(event);
    });

    _socket!.on('message:read', (data) {
      final event = MessageStatusEvent.fromJson(data);
      _messageStatusController.add(event);
    });

    // Conversation events
    _socket!.on('conversation:created', (data) {
      final event = ConversationEvent.fromJson(data);
      _conversationController.add(event);
    });

    _socket!.on('conversation:updated', (data) {
      final event = ConversationEvent.fromJson(data);
      _conversationController.add(event);
    });

    // Reactions
    _socket!.on('reaction:added', (data) {
      final event = ReactionEvent.fromJson(data);
      _reactionController.add(event);
    });

    _socket!.on('reaction:removed', (data) {
      final event = ReactionEvent.fromJson(data);
      _reactionController.add(event);
    });

    // File upload progress
    _socket!.on('upload:progress', (data) {
      final event = FileUploadEvent.fromJson(data);
      _fileUploadController.add(event);
    });

    _socket!.on('upload:complete', (data) {
      final event = FileUploadEvent.fromJson(data);
      _fileUploadController.add(event);
    });

    // Voice recording
    _socket!.on('voice:recording', (data) {
      final event = VoiceRecordEvent.fromJson(data);
      _voiceRecordController.add(event);
    });

    _socket!.on('voice:stopped', (data) {
      final event = VoiceRecordEvent.fromJson(data);
      _voiceRecordController.add(event);
    });

    // Last seen updates
    _socket!.on('user:lastseen', (data) {
      final event = LastSeenEvent.fromJson(data);
      _lastSeenController.add(event);
    });
  }

  void _setupUserPresence() {
    final user = StorageService.getUser();
    if (user != null) {
      _currentUserId = user['id'];
      _socket!.emit('user:online', {'userId': _currentUserId});
    }
  }

  // === Public Methods for Emitting Events ===

  /// Join a conversation room for real-time updates
  void joinConversation(String conversationId) {
    if (_socket?.connected == true) {
      _socket!.emit('conversation:join', {'conversationId': conversationId});
    }
  }

  /// Leave a conversation room
  void leaveConversation(String conversationId) {
    if (!_isConnected) {
      return;
    }
    _socket!.emit('conversation:leave', {'conversationId': conversationId});
  }

  /// Start typing indicator
  void startTyping(String conversationId) {
    if (!_isConnected) return;
    _socket!.emit('typing:start', {
      'conversationId': conversationId,
      'userId': _currentUserId,
    });
  }

  /// Stop typing indicator
  void stopTyping(String conversationId) {
    if (!_isConnected) return;
    _socket!.emit('typing:stop', {
      'conversationId': conversationId,
      'userId': _currentUserId,
    });
  }

  /// Mark messages as delivered
  void markAsDelivered(List<String> messageIds) {
    if (!_isConnected) return;
    _socket!.emit('message:delivered', {
      'messageIds': messageIds,
      'userId': _currentUserId,
      'deliveredAt': DateTime.now().toIso8601String(),
    });
  }

  /// Mark messages as read
  void markAsRead(List<String> messageIds, String conversationId) {
    if (!_isConnected) return;
    _socket!.emit('message:read', {
      'messageIds': messageIds,
      'conversationId': conversationId,
      'userId': _currentUserId,
      'readAt': DateTime.now().toIso8601String(),
    });
  }

  /// Update user presence
  void updatePresence(bool isOnline) {
    if (!_isConnected) return;
    _socket!.emit(isOnline ? 'user:online' : 'user:offline', {
      'userId': _currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Add reaction to message
  void addReaction(String messageId, String emoji) {
    if (!_isConnected) return;
    _socket!.emit('reaction:add', {
      'messageId': messageId,
      'emoji': emoji,
      'userId': _currentUserId,
    });
  }

  /// Remove reaction from message
  void removeReaction(String messageId, String emoji) {
    if (!_isConnected) return;
    _socket!.emit('reaction:remove', {
      'messageId': messageId,
      'emoji': emoji,
      'userId': _currentUserId,
    });
  }

  /// Start voice recording
  void startVoiceRecording(String conversationId) {
    if (!_isConnected) return;
    _socket!.emit('voice:start', {
      'conversationId': conversationId,
      'userId': _currentUserId,
    });
  }

  /// Stop voice recording
  void stopVoiceRecording(String conversationId) {
    if (!_isConnected) return;
    _socket!.emit('voice:stop', {
      'conversationId': conversationId,
      'userId': _currentUserId,
    });
  }

  /// Update last seen timestamp
  void updateLastSeen(String conversationId) {
    if (!_isConnected) return;
    _socket!.emit('user:lastseen', {
      'conversationId': conversationId,
      'userId': _currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Report file upload progress
  void reportUploadProgress(String uploadId, int progress) {
    if (!_isConnected) return;
    _socket!.emit('upload:progress', {
      'uploadId': uploadId,
      'progress': progress,
      'userId': _currentUserId,
    });
  }

  /// Dispose of all resources
  void dispose() {
    // Clean up app lifecycle observer and timers
    WidgetsBinding.instance.removeObserver(this);
    _stopConnectionCheck();

    // Disconnect and clean up streams
    disconnect();
    _connectionController.close();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _messageStatusController.close();
    _conversationController.close();
    _reactionController.close();
    _fileUploadController.close();
    _voiceRecordController.close();
    _lastSeenController.close();
  }
}

// === Event Models ===

class RealtimeMessage {
  final Message message;
  final String action; // 'created', 'updated', 'deleted'
  final String conversationId;

  RealtimeMessage({
    required this.message,
    required this.action,
    required this.conversationId,
  });

  factory RealtimeMessage.fromJson(Map<String, dynamic> json) {
    return RealtimeMessage(
      message: Message.fromJson(json['message']),
      action: json['action'],
      conversationId: json['conversationId'],
    );
  }
}

class TypingEvent {
  final String userId;
  final String conversationId;
  final bool isTyping;
  final DateTime timestamp;

  TypingEvent({
    required this.userId,
    required this.conversationId,
    required this.isTyping,
    required this.timestamp,
  });

  factory TypingEvent.fromJson(Map<String, dynamic> json) {
    return TypingEvent(
      userId: json['userId'],
      conversationId: json['conversationId'],
      isTyping: json['isTyping'] ?? true,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class PresenceEvent {
  final String userId;
  final bool isOnline;
  final DateTime timestamp;
  final String? lastSeen;

  PresenceEvent({
    required this.userId,
    required this.isOnline,
    required this.timestamp,
    this.lastSeen,
  });

  factory PresenceEvent.fromJson(Map<String, dynamic> json) {
    return PresenceEvent(
      userId: json['userId'],
      isOnline: json['isOnline'],
      timestamp: DateTime.parse(json['timestamp']),
      lastSeen: json['lastSeen'],
    );
  }
}

class MessageStatusEvent {
  final List<String> messageIds;
  final String status; // 'delivered', 'read'
  final String userId;
  final DateTime timestamp;
  final String? conversationId;

  MessageStatusEvent({
    required this.messageIds,
    required this.status,
    required this.userId,
    required this.timestamp,
    this.conversationId,
  });

  factory MessageStatusEvent.fromJson(Map<String, dynamic> json) {
    return MessageStatusEvent(
      messageIds: List<String>.from(json['messageIds']),
      status: json['status'],
      userId: json['userId'],
      timestamp: DateTime.parse(json['timestamp']),
      conversationId: json['conversationId'],
    );
  }
}

class ConversationEvent {
  final String conversationId;
  final String action; // 'created', 'updated', 'deleted'
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ConversationEvent({
    required this.conversationId,
    required this.action,
    required this.data,
    required this.timestamp,
  });

  factory ConversationEvent.fromJson(Map<String, dynamic> json) {
    return ConversationEvent(
      conversationId: json['conversationId'],
      action: json['action'],
      data: json['data'] ?? {},
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ReactionEvent {
  final String messageId;
  final String emoji;
  final String userId;
  final String action; // 'added', 'removed'
  final DateTime timestamp;

  ReactionEvent({
    required this.messageId,
    required this.emoji,
    required this.userId,
    required this.action,
    required this.timestamp,
  });

  factory ReactionEvent.fromJson(Map<String, dynamic> json) {
    return ReactionEvent(
      messageId: json['messageId'],
      emoji: json['emoji'],
      userId: json['userId'],
      action: json['action'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class FileUploadEvent {
  final String uploadId;
  final int progress; // 0-100
  final String status; // 'progress', 'complete', 'error'
  final String? error;
  final String? fileUrl;

  FileUploadEvent({
    required this.uploadId,
    required this.progress,
    required this.status,
    this.error,
    this.fileUrl,
  });

  factory FileUploadEvent.fromJson(Map<String, dynamic> json) {
    return FileUploadEvent(
      uploadId: json['uploadId'],
      progress: json['progress'] ?? 0,
      status: json['status'],
      error: json['error'],
      fileUrl: json['fileUrl'],
    );
  }
}

class VoiceRecordEvent {
  final String userId;
  final String conversationId;
  final bool isRecording;
  final DateTime timestamp;

  VoiceRecordEvent({
    required this.userId,
    required this.conversationId,
    required this.isRecording,
    required this.timestamp,
  });

  factory VoiceRecordEvent.fromJson(Map<String, dynamic> json) {
    return VoiceRecordEvent(
      userId: json['userId'],
      conversationId: json['conversationId'],
      isRecording: json['isRecording'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class LastSeenEvent {
  final String userId;
  final String conversationId;
  final DateTime timestamp;

  LastSeenEvent({
    required this.userId,
    required this.conversationId,
    required this.timestamp,
  });

  factory LastSeenEvent.fromJson(Map<String, dynamic> json) {
    return LastSeenEvent(
      userId: json['userId'],
      conversationId: json['conversationId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// === Providers ===

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService.instance;

  // Listen to auth state changes and connect/disconnect automatically
  ref.listen(authStateProvider, (previous, next) {
    if (next.isAuthenticated == true && !service.isConnected) {
      // Immediate attempt
      service.initialize();

      // Backup attempts with increasing delays
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!service.isConnected) {
          service.initialize();
        }
      });

      Future.delayed(const Duration(milliseconds: 3000), () {
        if (!service.isConnected) {
          service.initialize();
        }
      });

      Future.delayed(const Duration(milliseconds: 5000), () {
        if (!service.isConnected) {
          service.initialize();
        }
      });
    } else if (next.isAuthenticated == false && service.isConnected) {
      service.disconnect();
    }
  });

  // Check initial auth state (with longer delay for Android)
  Future.delayed(const Duration(milliseconds: 2000), () {
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated == true && !service.isConnected) {
      service.initialize();
    }
  });

  // Additional check specifically for Android (longer delay)
  if (Platform.isAndroid) {
    Future.delayed(const Duration(milliseconds: 3000), () {
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated == true && !service.isConnected) {
        service.initialize();
      }
    });
  }

  // Auto-disconnect when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// Stream providers for different events
final realtimeConnectionProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.connectionStream;
});

final realtimeMessagesProvider = StreamProvider<RealtimeMessage>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.messageStream;
});

final realtimeTypingProvider = StreamProvider<TypingEvent>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.typingStream;
});

final realtimePresenceProvider = StreamProvider<PresenceEvent>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.presenceStream;
});

final realtimeMessageStatusProvider = StreamProvider<MessageStatusEvent>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.messageStatusStream;
});
