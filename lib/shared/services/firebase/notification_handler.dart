import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../notification_deeplink_router.dart';

/// Handles local notifications for foreground messages
class NotificationHandler {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'durusuna_channel';
  static const String _channelName = 'Durusuna Notifications';
  static const String _channelDescription = 'Notifications from Durusuna app';

  /// Initialize local notifications
  static Future<void> initialize() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      if (!kIsWeb) {
        await _createNotificationChannel();
      }

      debugPrint('🔔 Local notifications initialized');
    } catch (error) {
      debugPrint('🔔 Failed to initialize local notifications: $error');
    }
  }

  /// Show local notification for foreground messages
  static Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF1E3A8A),
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        details,
        payload: message.data['actionUrl'] ?? '',
      );

      debugPrint('🔔 Local notification shown: ${notification.title}');
    } catch (error) {
      debugPrint('🔔 Failed to show local notification: $error');
    }
  }

  /// Handle navigation from notification data
  static void handleNotificationNavigation(Map<String, dynamic> data) {
    NotificationDeepLinkRouter.handleFCMNavigation(data);
  }

  /// Handle local notification tap
  static void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped: ${response.payload}');
    if (response.payload?.isNotEmpty == true) {
      handleNotificationNavigation({'actionUrl': response.payload});
    }
  }

  /// Create notification channel for mobile platforms
  static Future<void> _createNotificationChannel() async {
    if (kIsWeb) {
      // Web doesn't need notification channels
      return;
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('🔔 Mobile notification channel created');
  }
}
