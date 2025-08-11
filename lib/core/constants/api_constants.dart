import 'dart:io';

class ApiConstants {
  /// 🌐 BACKEND CONNECTION CONFIGURATION
  ///
  /// SECURITY: Uses environment variables and build-time configuration
  /// to avoid hardcoding sensitive data in source code.
  ///
  /// Usage:
  /// - Development: Uses local configuration
  /// - Staging: Uses staging environment
  /// - Production: Uses production environment

  // Environment detection from build-time arguments
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // Backend URLs per environment (can be overridden via environment)
  static const String _stagingBackendUrl = String.fromEnvironment(
    'STAGING_BACKEND_URL',
    defaultValue: 'https://durusuna-backend-staging.sevalla.app',
  );

  static const String _productionBackendUrl = String.fromEnvironment(
    'PRODUCTION_BACKEND_URL',
    defaultValue: '',
  );

  // Development configuration - SECURE: No hardcoded IPs in source code
  static const String _developmentIP = String.fromEnvironment(
    'DEV_SERVER_IP',
    defaultValue: 'localhost', // Safe fallback
  );

  static const String _developmentPort = String.fromEnvironment(
    'DEV_SERVER_PORT',
    defaultValue: '3001',
  );

  // Configuration flags
  static const bool _usePhysicalDevice = bool.fromEnvironment(
    'USE_PHYSICAL_DEVICE',
    defaultValue: false, // Default to emulator for security
  );

  // Development mode detection
  static const bool _isDebugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: true,
  );

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
    // For physical device testing
    if (_usePhysicalDevice) {
      return 'http://$_developmentIP:$_developmentPort';
    }

    // Platform-specific defaults for simulators/emulators
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_developmentPort'; // Android emulator
    } else {
      return 'http://localhost:$_developmentPort'; // iOS simulator
    }
  }

  // Public API - clean and secure
  static String get baseUrl => '$_backendUrl/api';
  static String get socketUrl => _backendUrl;

  // Development/Production configuration
  static bool get enableLogging => _environment != 'production' && _isDebugMode;
  static bool get isProduction => _environment == 'production';
  static bool get isDevelopment => _environment == 'development';

  // Current configuration info (for debugging only)
  static Map<String, dynamic> get configInfo => {
        'environment': _environment,
        'usePhysicalDevice': _usePhysicalDevice,
        'isProduction': isProduction,
        'enableLogging': enableLogging,
        // DO NOT expose actual URLs/IPs in production logs
        if (!isProduction) ...{
          'baseUrl': baseUrl,
          'socketUrl': socketUrl,
        }
      };

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

  // User endpoints
  static const String searchUsers = '$users/search';
  static const String getContacts = '$users/contacts';

  // Conversation endpoints
  static String getConversations = conversations;
  static String createConversation = conversations;
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
  static String addCommentReaction(String commentId) =>
      '$classUpdates/comments/$commentId/reactions';

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
