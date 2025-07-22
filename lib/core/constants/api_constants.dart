import 'dart:io';

class ApiConstants {
  /// 🌐 BACKEND CONNECTION CONFIGURATION
  ///
  /// Update these settings based on where you're testing:
  ///
  /// 1. 📱 Physical Device: Set _usePhysicalDevice = true
  /// 2. 📱 Android Emulator: Set _usePhysicalDevice = false
  /// 3. 📱 iOS Simulator: Set _usePhysicalDevice = false
  /// 4. 🌐 Flutter Web: Set _usePhysicalDevice = false
  ///
  /// To find your IP: Run `ifconfig | grep inet` in terminal

  // Development machine IP (update this with your machine's IP)
  static const String _developmentIP = '192.168.1.8';

  // Set this to true when testing on physical device
  static const bool _usePhysicalDevice = false;

  // Base URL - platform-aware configuration
  static final String baseUrl = _getBaseUrl();

  // Socket URL (without /api suffix)
  static final String socketUrl = _getSocketUrl();

  static String _getBaseUrl() {
    if (_usePhysicalDevice) {
      return 'http://$_developmentIP:3001/api'; // Physical device
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001/api'; // Android emulator
    } else {
      return 'http://localhost:3001/api'; // iOS simulator and others
    }
  }

  static String _getSocketUrl() {
    if (_usePhysicalDevice) {
      return 'http://$_developmentIP:3001'; // Physical device
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001'; // Android emulator
    } else {
      return 'http://localhost:3001'; // iOS simulator and others
    }
  }

  // Development/Production configuration
  static const bool enableLogging = true; // Set to false in production

  // Timeout configurations
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // File upload limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];
  static const List<String> allowedVideoTypes = ['mp4', 'mov', 'avi'];
  static const List<String> allowedAudioTypes = ['mp3', 'wav', 'aac'];
  static const List<String> allowedDocumentTypes = [
    'pdf',
    'doc',
    'docx',
    'txt'
  ];

  // API Endpoints
  static const String auth = '/auth';
  static const String users = '/users';
  static const String schools = '/schools';
  static const String classes = '/classes';
  static const String lessons = '/lessons';
  static const String messages = '/messages';
  static const String uploads = '/uploads';

  // Auth endpoints
  static const String login = '$auth/login';
  static const String register = '$auth/register';
  static const String refresh = '$auth/refresh';
  static const String logout = '$auth/logout';
  static const String profile = '$auth/me';
  static const String changePassword = '$auth/change-password';

  // Message endpoints
  static const String sendMessage = '$messages/send';
  static const String getConversations = '$messages/conversations';
  static const String getConversationMessages = '$messages/conversation';
  static const String markAsRead = '$messages/mark-read';
  static const String markConversationAsRead = '$messages/conversation';
  static const String deleteMessage = '$messages/delete';

  // Class update endpoints
  static const String classUpdates = '/class-updates';
  static const String createClassUpdate = '$classUpdates/create';
  static const String getClassUpdates = classUpdates;
  static const String addComment = '$classUpdates/comment';
  static const String addReaction = '$classUpdates/reaction';

  // WebSocket events
  static const String wsConnect = 'connect';
  static const String wsDisconnect = 'disconnect';
  static const String wsJoinRoom = 'join_room';
  static const String wsLeaveRoom = 'leave_room';
  static const String wsNewMessage = 'new_message';
  static const String wsMessageReceived = 'message_received';
  static const String wsTypingStart = 'typing_start';
  static const String wsTypingStop = 'typing_stop';
  static const String wsUserOnline = 'user_online';
  static const String wsUserOffline = 'user_offline';

  // Cache keys
  static const String cacheUser = 'current_user';
  static const String cacheToken = 'auth_token';
  static const String cacheRefreshToken = 'refresh_token';
  static const String cacheClasses = 'user_classes';
  static const String cacheConversations = 'conversations';
}
