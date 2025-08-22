import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../models/user.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';
import 'realtime_service.dart';

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
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await _apiService.patch(
        '${ApiConstants.notifications}/$notificationId/read',
        data: {}, // Some backends expect an empty body for PATCH requests
      );

      if (response.statusCode == 200) {
        // Backend returns simple success response: {"success":true,"notification_id":"..."}
        // No need to parse as full notification object
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
  StreamSubscription<RealtimeNotificationEvent>? _realtimeSubscription;

  NotificationsNotifier(this._notificationService, this._ref)
      : super(const NotificationsState()) {
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    // Listen to real-time notifications via the service directly
    _realtimeSubscription =
        _ref.read(realtimeServiceProvider).notificationStream.listen(
      (realtimeNotification) {
        _handleRealtimeNotification(realtimeNotification);
      },
      onError: (error) {
        debugPrint('❌ Error listening to realtime notifications: $error');
      },
    );
  }

  void _handleRealtimeNotification(RealtimeNotificationEvent realtimeEvent) {
    try {
      debugPrint(
          '🔔 NotificationsNotifier: Handling realtime notification: ${realtimeEvent.notificationId}');

      // Convert RealtimeNotificationEvent to NotificationModel
      final notification = NotificationModel(
        id: realtimeEvent.notificationId,
        title: realtimeEvent.title,
        content: realtimeEvent.content,
        type: _parseNotificationType(realtimeEvent.type),
        priority: NotificationPriority.normal,
        isRead: false,
        userId: '', // Will be filled by the current user
        createdAt: realtimeEvent.timestamp,
        updatedAt: realtimeEvent.timestamp,
      );

      // Add to the beginning of notifications list
      final updatedNotifications = [notification, ...state.notifications];

      // Increment unread count
      final newUnreadCount = state.unreadCount + 1;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      );

      debugPrint(
          '🔔 NotificationsNotifier: Added real-time notification: ${notification.title}');
      debugPrint('🔔 NotificationsNotifier: New unread count: $newUnreadCount');
      debugPrint(
          '🔔 NotificationsNotifier: Total notifications: ${updatedNotifications.length}');
    } catch (e) {
      debugPrint(
          '❌ NotificationsNotifier: Error handling realtime notification: $e');
    }
  }

  NotificationType _parseNotificationType(String type) {
    switch (type.toLowerCase()) {
      // Class Update Related
      case 'class_update_announcement':
        return NotificationType.classUpdateAnnouncement;
      case 'class_update_homework':
        return NotificationType.classUpdateHomework;
      case 'class_update_reminder':
        return NotificationType.classUpdateReminder;
      case 'class_update_event':
        return NotificationType.classUpdateEvent;

      // Class Update Comments
      case 'class_update_comment':
        return NotificationType.classUpdateComment;
      case 'class_update_reply':
        return NotificationType.classUpdateReply;

      // Assignment Related
      case 'assignment_created':
        return NotificationType.assignmentCreated;
      case 'assignment_updated':
        return NotificationType.assignmentUpdated;
      case 'assignment_due_soon':
        return NotificationType.assignmentDueSoon;
      case 'assignment_submitted':
        return NotificationType.assignmentSubmitted;
      case 'assignment_graded':
        return NotificationType.assignmentGraded;

      // Attendance Related
      case 'attendance_marked':
        return NotificationType.attendanceMarked;
      case 'attendance_late':
        return NotificationType.attendanceLate;
      case 'attendance_absent':
        return NotificationType.attendanceAbsent;

      // Grade Related
      case 'grade_posted':
        return NotificationType.gradePosted;
      case 'grade_updated':
        return NotificationType.gradeUpdated;

      // Message Related
      case 'message_received':
        return NotificationType.messageReceived;
      case 'conversation_created':
        return NotificationType.conversationCreated;

      // System Related
      case 'system_announcement':
        return NotificationType.systemAnnouncement;
      case 'system_maintenance':
        return NotificationType.systemMaintenance;
      case 'system_update':
        return NotificationType.systemUpdate;

      // General
      case 'announcement':
        return NotificationType.announcement;
      case 'event':
        return NotificationType.event;
      case 'reminder':
        return NotificationType.reminder;

      // Legacy types (for backward compatibility)
      case 'message':
        return NotificationType.message;
      case 'assignment':
        return NotificationType.assignment;
      case 'system':
        return NotificationType.system;

      default:
        return NotificationType.announcement;
    }
  }

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

  /// Mark notification as read with optimistic updates
  Future<void> markAsRead(String notificationId) async {
    // Find the notification to update
    final notificationIndex =
        state.notifications.indexWhere((n) => n.id == notificationId);
    if (notificationIndex == -1) return;

    final notification = state.notifications[notificationIndex];
    // Only proceed if notification is not already read
    if (notification.isRead) return;

    // Store original state for potential rollback
    final originalNotifications =
        List<NotificationModel>.from(state.notifications);
    final originalUnreadCount = state.unreadCount;

    // OPTIMISTIC UPDATE: Update UI immediately
    final optimisticNotification =
        notification.copyWith(isRead: true, readAt: DateTime.now());

    final optimisticNotifications =
        List<NotificationModel>.from(state.notifications);
    optimisticNotifications[notificationIndex] = optimisticNotification;

    // Update state with optimistic values
    state = state.copyWith(
      notifications: optimisticNotifications,
      unreadCount: (state.unreadCount > 0) ? state.unreadCount - 1 : 0,
    );

    try {
      // Call API to persist the change
      await _notificationService.markAsRead(notificationId);

      // Keep the optimistic update since API was successful
      // No need to update again with server response
      // Optionally sync unread count with server for consistency
      await _updateUnreadCount();
    } catch (e) {
      // ROLLBACK: API failed, revert to original state
      state = state.copyWith(
        notifications: originalNotifications,
        unreadCount: originalUnreadCount,
        error: 'Failed to mark notification as read',
      );
    }
  }

  /// Mark all notifications as read with optimistic updates
  Future<void> markAllAsRead() async {
    // Store original state for potential rollback
    final originalNotifications =
        List<NotificationModel>.from(state.notifications);
    final originalUnreadCount = state.unreadCount;

    // OPTIMISTIC UPDATE: Update UI immediately
    final optimisticNotifications = state.notifications.map((notification) {
      return notification.copyWith(isRead: true, readAt: DateTime.now());
    }).toList();

    state = state.copyWith(
      notifications: optimisticNotifications,
      unreadCount: 0,
    );

    try {
      final result = await _notificationService.markAllAsRead();
      debugPrint('✅ Mark all as read result: $result');

      // Optionally sync with server for consistency
      await _updateUnreadCount();
    } catch (e) {
      // ROLLBACK: API failed, revert to original state
      debugPrint('❌ Error marking all notifications as read: $e');
      state = state.copyWith(
        notifications: originalNotifications,
        unreadCount: originalUnreadCount,
        error: e.toString(),
      );
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

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
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
