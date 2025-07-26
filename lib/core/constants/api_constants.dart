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

  // Debug info
  static void printConfiguration() {}
}
