import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

/// Handles local notifications and navigation from Firebase messages
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'durusuna_notifications';
  static const String _channelName = 'Durusuna Notifications';
  static const String _channelDescription = 'Notifications for Durusuna app';

  /// Initialize local notifications
  Future<void> initialize() async {
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

      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      debugPrint('🔔 Local notifications initialized');
    } catch (error) {
      debugPrint('🔔 Failed to initialize local notifications: $error');
    }
  }

  /// Show local notification for foreground messages
  Future<void> showLocalNotification(RemoteMessage message) async {
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
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final actionUrl = data['actionUrl'] as String?;
    if (actionUrl?.isNotEmpty == true) {
      debugPrint('🔔 Should navigate to: $actionUrl');
      // TODO: Implement navigation logic
      // NavigationService.navigateFromNotification(actionUrl);
    }
  }

  /// Handle local notification tap
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped: ${response.payload}');
    if (response.payload?.isNotEmpty == true) {
      handleNotificationNavigation({'actionUrl': response.payload});
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
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

    debugPrint('🔔 Android notification channel created');
  }
}
