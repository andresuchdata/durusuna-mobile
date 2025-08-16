import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import 'package:flutter/foundation.dart';
import 'notification_handler.dart';
import 'permission_manager.dart';

/// Service responsible for Firebase Cloud Messaging operations
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationHandler _notificationHandler = NotificationHandler();
  final PermissionManager _permissionManager = PermissionManager();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      debugPrint('🔥 Initializing FCM Service...');

      // Request permissions
      final hasPermission = await _permissionManager.requestPermissions();
      if (!hasPermission) {
        debugPrint('🔥 FCM: No notification permissions granted');
        return;
      }

      // Ensure iOS foreground notifications present as system alerts
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize local notifications
      await _notificationHandler.initialize();

      // Get and store FCM token
      await _refreshToken();

      // Set up message handlers
      _setupMessageHandlers();

      debugPrint('🔥 FCM Service initialized successfully');
    } catch (error) {
      debugPrint('🔥 FCM Service initialization failed: $error');
    }
  }

  /// Refresh FCM token and sync with backend
  Future<void> _refreshToken() async {
    try {
      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        debugPrint('🔥 FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        await _syncTokenWithBackend(_fcmToken!);
        await _saveTokenLocally(_fcmToken!);
      }
    } catch (error) {
      debugPrint('🔥 Failed to refresh FCM token: $error');
    }
  }

  /// Set up FCM message handlers
  void _setupMessageHandlers() {
    // Handle token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔥 FCM Token refreshed');
      _fcmToken = newToken;
      _syncTokenWithBackend(newToken);
      _saveTokenLocally(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle app launch from notification
    _handleAppLaunchFromNotification();
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔥 Foreground message received: ${message.messageId}');
    await _notificationHandler.showLocalNotification(message);
  }

  /// Handle notification tap (background)
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('🔥 Notification tapped: ${message.messageId}');
    _notificationHandler.handleNotificationNavigation(message.data);
  }

  /// Handle app launch from notification
  Future<void> _handleAppLaunchFromNotification() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          '🔥 App launched from notification: ${initialMessage.messageId}');
      _notificationHandler.handleNotificationNavigation(initialMessage.data);
    }
  }

  /// Sync token with backend
  Future<void> _syncTokenWithBackend(String token) async {
    try {
      final apiService = ApiService();
      await apiService.updateFCMToken(token);
      debugPrint('✅ FCM token synced with backend');
    } catch (error) {
      debugPrint('🔥 Failed to sync FCM token with backend: $error');
    }
  }

  /// Save token locally for offline access
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (error) {
      debugPrint('🔥 Failed to save FCM token locally: $error');
    }
  }

  /// Clear token (for logout)
  Future<void> clearToken() async {
    try {
      await _messaging.deleteToken();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');

      _fcmToken = null;
      debugPrint('🔥 FCM token cleared');
    } catch (error) {
      debugPrint('🔥 Failed to clear FCM token: $error');
    }
  }

  /// Force token refresh
  Future<void> refreshToken() async {
    await _refreshToken();
  }
}
