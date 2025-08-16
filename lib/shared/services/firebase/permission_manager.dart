import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Manages notification permissions for Firebase messaging
class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final status = settings.authorizationStatus;
      debugPrint('🔥 Notification permission status: $status');

      switch (status) {
        case AuthorizationStatus.authorized:
          debugPrint('✅ User granted notification permissions');
          return true;
        case AuthorizationStatus.provisional:
          debugPrint('⚠️ User granted provisional notification permissions');
          return true;
        case AuthorizationStatus.denied:
          debugPrint('❌ User denied notification permissions');
          return false;
        case AuthorizationStatus.notDetermined:
          debugPrint('❓ User has not decided on notification permissions');
          return false;
      }
    } catch (error) {
      debugPrint('🔥 Failed to request notification permissions: $error');
      return false;
    }
  }

  /// Check current permission status
  Future<AuthorizationStatus> getPermissionStatus() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (error) {
      debugPrint('🔥 Failed to get permission status: $error');
      return AuthorizationStatus.denied;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    final status = await getPermissionStatus();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }
}
