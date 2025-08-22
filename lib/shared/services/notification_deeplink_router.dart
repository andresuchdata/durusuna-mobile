import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/presentation/pages/local_chat_page.dart';
import '../../features/class_updates/presentation/pages/class_updates_page.dart';
import '../../features/assignments/presentation/pages/assignments_main_page.dart';
import '../../features/assignments/presentation/pages/assignment_detail_page.dart';
import '../../features/attendance/presentation/pages/student_attendance_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../main.dart';
import '../models/conversation.dart';
import 'chat_service.dart';

/// Centralized router for handling navigation from FCM payloads
class NotificationDeepLinkRouter {
  /// Entry point: handle FCM data payload to navigate accordingly
  static Future<void> handleFCMNavigation(Map<String, dynamic> data) async {
    final context = DurusunaMobileApp.navigatorKey.currentContext;
    if (context == null) return;

    try {
      final String? type = _readString(data, ['notificationType', 'type']);
      final String? actionUrl = _readString(data, ['actionUrl', 'action_url']);
      final Map<String, dynamic>? actionData = _readActionData(data);

      debugPrint('🔔 FCM Navigation: type=$type, actionUrl=$actionUrl');
      debugPrint('🔔 FCM Navigation: actionData=$actionData');

      // Route based on notification type
      if (type != null) {
        await _routeByNotificationType(context, type, actionUrl, actionData);
      } else if (actionUrl != null) {
        // Fallback: route by URL pattern
        await _routeByActionUrl(context, actionUrl, actionData);
      } else {
        // Last resort: go to notifications page
        await _navigateToNotifications(context);
      }
    } catch (e) {
      debugPrint('❌ FCM Navigation error: $e');
      // Last resort: go home
      await _navigateToHome(context);
    }
  }

  /// Route based on notification type (BE standard)
  static Future<void> _routeByNotificationType(
    BuildContext context,
    String type,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    switch (type.toLowerCase()) {
      // Class Update Related
      case 'class_update_announcement':
      case 'class_update_homework':
      case 'class_update_reminder':
      case 'class_update_event':
      case 'class_update_comment':
      case 'class_update_reply':
        await _navigateToClassUpdate(context, actionUrl, actionData);
        break;

      // Assignment Related
      case 'assignment_created':
      case 'assignment_updated':
      case 'assignment_due_soon':
      case 'assignment_submitted':
      case 'assignment_graded':
        await _navigateToAssignment(context, actionUrl, actionData);
        break;

      // Attendance Related
      case 'attendance_marked':
      case 'attendance_late':
      case 'attendance_absent':
        await _navigateToAttendance(context, actionUrl, actionData);
        break;

      // Grade Related
      case 'grade_posted':
      case 'grade_updated':
        await _navigateToGrades(context, actionUrl, actionData);
        break;

      // Message Related
      case 'message_received':
      case 'conversation_created':
      case 'message': // Legacy
        await _navigateToMessage(context, actionUrl, actionData);
        break;

      // System Related
      case 'system_announcement':
      case 'system_maintenance':
      case 'system_update':
      case 'system': // Legacy
        await _navigateToNotifications(context);
        break;

      // General notifications
      case 'announcement':
      case 'event':
      case 'reminder':
        await _navigateToClassUpdate(context, actionUrl, actionData);
        break;

      // Legacy assignment type
      case 'assignment':
        await _navigateToAssignment(context, actionUrl, actionData);
        break;

      default:
        debugPrint(
            '⚠️ Unknown notification type: $type, falling back to notifications');
        await _navigateToNotifications(context);
    }
  }

  /// Fallback routing by action URL pattern
  static Future<void> _routeByActionUrl(
    BuildContext context,
    String actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    if (actionUrl.contains('/chat/') || actionUrl.contains('/conversation/')) {
      await _navigateToMessage(context, actionUrl, actionData);
    } else if (actionUrl.contains('/classes/') &&
        actionUrl.contains('/updates/')) {
      await _navigateToClassUpdate(context, actionUrl, actionData);
    } else if (actionUrl.contains('/assignment/')) {
      await _navigateToAssignment(context, actionUrl, actionData);
    } else if (actionUrl.contains('/attendance/')) {
      await _navigateToAttendance(context, actionUrl, actionData);
    } else {
      await _navigateToNotifications(context);
    }
  }

  static Future<void> _navigateToMessage(
    BuildContext context,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);

    // Resolve conversationId from actionData or URL
    String? conversationId = actionData?['conversation_id'] as String?;
    if (conversationId == null && actionUrl != null) {
      final uri = Uri.tryParse(actionUrl);
      final segments = uri?.pathSegments ?? actionUrl.split('/');
      if (segments.isNotEmpty) {
        // Supports formats: chat/{id} or just 'chat/{id}' string
        final idx = segments.first == 'chat' ? 1 : 0;
        if (segments.length > idx) conversationId = segments[idx];
      }
    }

    if (conversationId == null) {
      await _navigateToHome(context);
      return;
    }

    // Try resolve conversation from providers/cache; refresh if needed
    Conversation? conversation;
    try {
      final conversationsState = container.read(conversationsProvider);
      conversation = conversationsState.conversations
          .cast<Conversation?>()
          .firstWhere((c) => c?.id == conversationId, orElse: () => null);

      if (conversation == null) {
        // Refresh from service
        await container
            .read(conversationsProvider.notifier)
            .loadConversations();
        final updated = container.read(conversationsProvider);
        conversation = updated.conversations
            .cast<Conversation?>()
            .firstWhere((c) => c?.id == conversationId, orElse: () => null);
      }
    } catch (_) {}

    if (conversation == null) {
      // As a fallback, try to fetch conversation from service by id if supported
      try {
        await container
            .read(conversationsProvider.notifier)
            .loadConversations();
        final updated = container.read(conversationsProvider);
        conversation = updated.conversations
            .cast<Conversation?>()
            .firstWhere((c) => c?.id == conversationId, orElse: () => null);
      } catch (_) {}
    }

    if (conversation == null) {
      await _navigateToHome(context);
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LocalChatPage(
          conversation: conversation!,
          highlightMessageId: actionData?['message_id'] as String?,
          scrollToMessage: (actionData?['message_id'] as String?) != null,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigate to class update (renamed and enhanced)
  static Future<void> _navigateToClassUpdate(
    BuildContext context,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    // Resolve class id and update id
    String? classId = actionData?['class_id'] as String?;
    String? updateId = actionData?['update_id'] as String?;
    String? className = actionData?['class_name'] as String?;

    if (classId == null && actionUrl != null) {
      final uri = Uri.tryParse(actionUrl);
      final segments = uri?.pathSegments ?? actionUrl.split('/');
      if (segments.isNotEmpty) {
        final idx = segments.indexWhere((s) => s == 'classes');
        if (idx >= 0 && segments.length > idx + 1) {
          classId = segments[idx + 1];
          // Try to extract update ID from URL like /classes/{id}/updates/{updateId}
          final updateIdx = segments.indexWhere((s) => s == 'updates');
          if (updateIdx >= 0 && segments.length > updateIdx + 1) {
            updateId = segments[updateIdx + 1];
          }
        }
      }
    }

    if (classId == null) {
      await _navigateToHome(context);
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ClassUpdatesPage(
          classId: classId!,
          className: className ?? 'Class Updates',
          highlightUpdateId: updateId,
          scrollToUpdate: updateId != null,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigate to assignment page
  static Future<void> _navigateToAssignment(
    BuildContext context,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    String? assignmentId = actionData?['assignment_id'] as String?;
    String? assignmentTitle = actionData?['assignment_title'] as String?;

    // Try to extract assignment ID from URL
    if (assignmentId == null && actionUrl != null) {
      final uri = Uri.tryParse(actionUrl);
      final segments = uri?.pathSegments ?? actionUrl.split('/');
      final assignmentIdx =
          segments.indexWhere((s) => s == 'assignment' || s == 'assignments');
      if (assignmentIdx >= 0 && segments.length > assignmentIdx + 1) {
        assignmentId = segments[assignmentIdx + 1];
      }
    }

    // Navigate to specific assignment or assignments page
    if (assignmentId != null) {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AssignmentDetailPage(
            assignmentId: assignmentId!,
            title: assignmentTitle,
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AssignmentsMainPage(),
        ),
        (route) => route.isFirst,
      );
    }
  }

  /// Navigate to attendance page
  static Future<void> _navigateToAttendance(
    BuildContext context,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    // Note: Currently navigates to general attendance page
    // Future enhancement: could navigate to specific class/date if StudentAttendancePage supports it

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const StudentAttendancePage(),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigate to grades (assignments page for now, could be specialized later)
  static Future<void> _navigateToGrades(
    BuildContext context,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    // For now, grades are part of assignments
    await _navigateToAssignment(context, actionUrl, actionData);
  }

  /// Navigate to notifications page
  static Future<void> _navigateToNotifications(BuildContext context) async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
      (route) => route.isFirst,
    );
  }

  static Future<void> _navigateToHome(BuildContext context) async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EnhancedHomePage()),
      (route) => false,
    );
  }

  static Map<String, dynamic>? _readActionData(Map<String, dynamic> data) {
    final dynamic raw = data['actionData'] ?? data['action_data'];
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }
}
