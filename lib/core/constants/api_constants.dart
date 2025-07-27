import 'dart:io';

class ApiConstants {
  /// 🌐 BACKEND CONNECTION CONFIGURATION
  ///
  /// Environment-based configuration for better security:
  /// - Development: Local backend
  /// - Staging: Test environment
  /// - Production: Live backend
  ///
  /// For security, consider using:
  /// 1. Environment variables
  /// 2. Separate config files
  /// 3. Build-time configuration

  // Environment detection
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // Backend URLs per environment
  static const String _stagingBackendUrl =
      'https://durusuna-backend-staging.sevalla.app';
  static const String _productionBackendUrl =
      'https://durusuna-backend-hr9m0.sevalla.app';

  // Development machine IP (for physical device testing)
  static const String _developmentIP = '192.168.1.8';

  // Configuration flags
  static const bool _usePhysicalDevice =
      false; // For local development on device

  // Get backend URL based on environment
  static String get _backendUrl {
    switch (_environment) {
      case 'production':
        return _productionBackendUrl;
      case 'staging':
        return _stagingBackendUrl;
      case 'development':
      default:
        return _getDevelopmentUrl();
    }
  }

  static String _getDevelopmentUrl() {
    if (_usePhysicalDevice) {
      return 'http://$_developmentIP:3001';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001'; // Android emulator
    } else {
      return 'http://localhost:3001'; // iOS simulator and others
    }
  }

  // Base URL - environment-aware configuration
  static String get baseUrl => '$_backendUrl/api';

  // Socket URL (without /api suffix)
  static String get socketUrl => _backendUrl;

  // Development/Production configuration
  static bool get enableLogging => _environment != 'production';

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
  static const String conversations = '/conversations';
  static const String uploads = '/uploads';
  static const String classUpdates = '/class-updates';

  // Auth endpoints
  static const String login = '$auth/login';
  static const String register = '$auth/register';
  static const String refresh = '$auth/refresh';
  static const String logout = '$auth/logout';
  static const String profile = '$auth/me';
  static const String changePassword = '$auth/change-password';

  // Message endpoints
  static const String sendMessage = messages;
  static const String searchMessages = '$messages/search';

  // Conversation endpoints
  static String getConversations = conversations;
  static String getConversationMessages(String conversationId) =>
      '$conversations/$conversationId/messages';
  static String loadMoreMessages(String conversationId) =>
      '$conversations/$conversationId/messages/load-more';
  static String sendConversationMessage(String conversationId) =>
      '$conversations/$conversationId/messages';
  static String markConversationAsRead(String conversationId) =>
      '$conversations/$conversationId/mark-read';

  // Class endpoints - for getting class updates from a specific class
  static String getClassUpdates(String classId) => '$classes/$classId/updates';
  static String createClassUpdate(String classId) =>
      '$classes/$classId/updates';

  // Class update endpoints - for individual class update operations
  static String uploadAttachments = '$classUpdates/upload-attachments';
  static String deleteAttachment(String key) =>
      '$classUpdates/attachments/$key';
  static String getClassUpdate(String updateId) => '$classUpdates/$updateId';
  static String updateClassUpdate(String updateId) => '$classUpdates/$updateId';
  static String deleteClassUpdate(String updateId) => '$classUpdates/$updateId';
  static String pinClassUpdate(String updateId) =>
      '$classUpdates/$updateId/pin';

  // Comment endpoints
  static String getComments(String updateId) =>
      '$classUpdates/$updateId/comments';
  static String addComment(String updateId) =>
      '$classUpdates/$updateId/comments';
  static String updateComment(String commentId) =>
      '$classUpdates/comments/$commentId';
  static String deleteComment(String commentId) =>
      '$classUpdates/comments/$commentId';

  // Reaction endpoints
  static String addReaction(String updateId) =>
      '$classUpdates/$updateId/reactions';

  // Notification endpoints
  static const String notifications = '/notifications';

  // WebSocket events
  static const String wsConnect = 'connect';
  static const String wsDisconnect = 'disconnect';
  static const String wsJoinRoom = 'join_room';
  static const String wsLeaveRoom = 'leave_room';
  static const String wsNewMessage = 'new_message';

  // Debug info
  static void printConfiguration() {}
}
