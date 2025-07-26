import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../models/user.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';
import 'auth_service.dart';

class NotificationService {
  final ApiService _apiService;

  NotificationService(this._apiService);

  /// Get notifications for current user
  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (isRead != null) 'is_read': isRead.toString(),
      };

      final response = await _apiService.get(
        ApiConstants.notifications,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> notificationsJson =
            response.data['notifications'] ?? [];
        return notificationsJson
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      } else {
        throw ApiException(
          message: 'Failed to fetch notifications',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to fetch notifications: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Mark notification as read
  Future<NotificationModel> markAsRead(String notificationId) async {
    try {
      final response = await _apiService.patch(
        '${ApiConstants.notifications}/$notificationId/read',
        data: {}, // Some backends expect an empty body for PATCH requests
      );

      if (response.statusCode == 200) {
        // Backend might return the notification directly or wrapped in a data object
        final notificationData = response.data is Map<String, dynamic>
            ? (response.data['notification'] ?? response.data)
            : response.data;
        return NotificationModel.fromJson(notificationData);
      } else {
        throw ApiException(
          message: 'Failed to mark notification as read',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to mark notification as read: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Mark all notifications as read
  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final response = await _apiService.patch(
        '${ApiConstants.notifications}/read-all',
        data: {}, // Some backends expect an empty body for PATCH requests
      );

      if (response.statusCode == 200) {
        return response.data ??
            {'success': true, 'message': 'All notifications marked as read'};
      } else {
        throw ApiException(
          message: 'Failed to mark all notifications as read',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to mark all notifications as read: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await _apiService.delete(
        '${ApiConstants.notifications}/$notificationId',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ApiException(
          message: 'Failed to delete notification',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to delete notification: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.notifications}/unread-count',
      );

      if (response.statusCode == 200) {
        return response.data['unread_count'] ?? 0;
      } else {
        throw ApiException(
          message: 'Failed to fetch unread count',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to fetch unread count: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Create a local notification (for testing purposes)
  static NotificationModel createLocalNotification({
    required String title,
    required String content,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.normal,
    User? sender,
    String? actionUrl,
    Map<String, dynamic>? actionData,
    String? imageUrl,
  }) {
    final now = DateTime.now();
    return NotificationModel(
      id: 'local_${now.millisecondsSinceEpoch}',
      title: title,
      content: content,
      type: type,
      priority: priority,
      isRead: false,
      userId: 'current_user',
      senderId: sender?.id,
      sender: sender,
      actionUrl: actionUrl,
      actionData: actionData,
      imageUrl: imageUrl,
      createdAt: now,
      updatedAt: now,
    );
  }
}

// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return NotificationService(apiService);
});

// State class for notifications
class NotificationsState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;
  final bool hasMore;
  final int currentPage;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
    this.hasMore = true,
    this.currentPage = 1,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
    bool? hasMore,
    int? currentPage,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Notifications State Notifier
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationService _notificationService;
  final Ref _ref;

  NotificationsNotifier(this._notificationService, this._ref)
      : super(const NotificationsState());

  /// Load notifications
  Future<void> loadNotifications({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(
        isLoading: true,
        error: null,
        currentPage: 1,
        hasMore: true,
      );
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final notifications = await _notificationService.getNotifications(
        page: refresh ? 1 : state.currentPage,
        limit: 20,
      );

      final updatedNotifications =
          refresh ? notifications : [...state.notifications, ...notifications];

      state = state.copyWith(
        notifications: updatedNotifications,
        isLoading: false,
        hasMore: notifications.length >= 20,
        currentPage: refresh ? 2 : state.currentPage + 1,
      );

      // Also update unread count
      await _updateUnreadCount();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more notifications
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadNotifications();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final updatedNotification =
          await _notificationService.markAsRead(notificationId);

      final updatedNotifications = state.notifications.map((notification) {
        if (notification.id == notificationId) {
          return updatedNotification;
        }
        return notification;
      }).toList();

      state = state.copyWith(notifications: updatedNotifications);
      await _updateUnreadCount();
    } catch (e) {
      // Handle error silently or show a snackbar
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final result = await _notificationService.markAllAsRead();
      debugPrint('Mark all as read result: $result');

      final updatedNotifications = state.notifications.map((notification) {
        return notification.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);

      final updatedNotifications = state.notifications
          .where((notification) => notification.id != notificationId)
          .toList();

      state = state.copyWith(notifications: updatedNotifications);
      await _updateUnreadCount();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Add a new notification (for real-time updates)
  void addNotification(NotificationModel notification) {
    final updatedNotifications = [notification, ...state.notifications];
    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: state.unreadCount + (notification.isRead ? 0 : 1),
    );
  }

  /// Update unread count
  Future<void> _updateUnreadCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      debugPrint('🔔 Unread count fetched: $count');
      state = state.copyWith(unreadCount: count);
    } catch (e) {
      // Handle error silently
      debugPrint('❌ Error updating unread count: $e');
    }
  }

  /// Load only unread count (for app startup)
  Future<void> loadUnreadCount() async {
    await _updateUnreadCount();
  }

  /// Initialize notifications (for app startup - only load unread count)
  Future<void> initialize() async {
    await _updateUnreadCount();
  }

  /// Initialize notifications with full data (for notification page)
  Future<void> initializeWithData() async {
    await loadNotifications(refresh: true);
  }
}

// Provider for notifications state
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final notificationService = ref.read(notificationServiceProvider);
  return NotificationsNotifier(notificationService, ref);
});

// Provider for unread count only
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
