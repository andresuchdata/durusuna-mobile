import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../models/notification.dart';

/// Centralized notification utilities to avoid repetitive switch statements
/// across the app. Provides colors, icons, and display names for all notification types.
class NotificationHelpers {
  // Private constructor to prevent instantiation
  NotificationHelpers._();

  /// Get the primary color for a notification type
  static Color getColor(NotificationType type) {
    switch (type) {
      // Message Related - Green (Success)
      case NotificationType.message:
      case NotificationType.messageReceived:
      case NotificationType.conversationCreated:
        return AppTheme.successColor;

      // Assignment Related - Orange (Warning)
      case NotificationType.assignment:
      case NotificationType.assignmentCreated:
      case NotificationType.assignmentUpdated:
      case NotificationType.assignmentDueSoon:
      case NotificationType.assignmentSubmitted:
      case NotificationType.assignmentGraded:
        return AppTheme.warningColor;

      // Class Update Related - Primary Blue
      case NotificationType.classUpdateAnnouncement:
      case NotificationType.classUpdateHomework:
      case NotificationType.classUpdateComment:
      case NotificationType.classUpdateReply:
      case NotificationType.announcement:
        return AppTheme.primaryColor;

      // Event/Reminder Related - Purple
      case NotificationType.classUpdateEvent:
      case NotificationType.classUpdateReminder:
      case NotificationType.event:
      case NotificationType.reminder:
        return Colors.purple;

      // Attendance Related - Context-based
      case NotificationType.attendanceMarked:
        return AppTheme.successColor;
      case NotificationType.attendanceLate:
        return AppTheme.warningColor;
      case NotificationType.attendanceAbsent:
        return Colors.red;

      // Grade Related - Green (Success)
      case NotificationType.gradePosted:
      case NotificationType.gradeUpdated:
        return AppTheme.successColor;

      // System Related - Gray (Secondary)
      case NotificationType.system:
      case NotificationType.systemAnnouncement:
      case NotificationType.systemMaintenance:
      case NotificationType.systemUpdate:
        return AppTheme.textSecondary;
    }
  }

  /// Get the icon for a notification type
  static IconData getIcon(NotificationType type) {
    switch (type) {
      // Message Related
      case NotificationType.message:
      case NotificationType.messageReceived:
      case NotificationType.conversationCreated:
        return Icons.message;

      // Assignment Related
      case NotificationType.assignment:
      case NotificationType.assignmentCreated:
      case NotificationType.assignmentUpdated:
      case NotificationType.assignmentDueSoon:
      case NotificationType.assignmentSubmitted:
      case NotificationType.assignmentGraded:
        return Icons.assignment;

      // Class Update Related - Specific icons
      case NotificationType.classUpdateAnnouncement:
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.classUpdateHomework:
        return Icons.book;
      case NotificationType.classUpdateReminder:
      case NotificationType.reminder:
        return Icons.schedule;
      case NotificationType.classUpdateEvent:
      case NotificationType.event:
        return Icons.event;
      case NotificationType.classUpdateComment:
      case NotificationType.classUpdateReply:
        return Icons.comment;

      // Attendance Related
      case NotificationType.attendanceMarked:
        return Icons.check_circle;
      case NotificationType.attendanceLate:
        return Icons.access_time;
      case NotificationType.attendanceAbsent:
        return Icons.cancel;

      // Grade Related
      case NotificationType.gradePosted:
      case NotificationType.gradeUpdated:
        return Icons.grade;

      // System Related
      case NotificationType.system:
      case NotificationType.systemAnnouncement:
      case NotificationType.systemMaintenance:
      case NotificationType.systemUpdate:
        return Icons.settings;
    }
  }

  /// Get the display name for a notification type
  static String getDisplayName(NotificationType type) {
    switch (type) {
      // Message Related
      case NotificationType.message:
      case NotificationType.messageReceived:
        return 'Message';
      case NotificationType.conversationCreated:
        return 'New Conversation';

      // Assignment Related
      case NotificationType.assignment:
      case NotificationType.assignmentCreated:
        return 'New Assignment';
      case NotificationType.assignmentUpdated:
        return 'Assignment Updated';
      case NotificationType.assignmentDueSoon:
        return 'Assignment Due Soon';
      case NotificationType.assignmentSubmitted:
        return 'Assignment Submitted';
      case NotificationType.assignmentGraded:
        return 'Assignment Graded';

      // Class Update Related
      case NotificationType.classUpdateAnnouncement:
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.classUpdateHomework:
        return 'Homework';
      case NotificationType.classUpdateReminder:
      case NotificationType.reminder:
        return 'Reminder';
      case NotificationType.classUpdateEvent:
      case NotificationType.event:
        return 'Event';
      case NotificationType.classUpdateComment:
        return 'Comment';
      case NotificationType.classUpdateReply:
        return 'Reply';

      // Attendance Related
      case NotificationType.attendanceMarked:
        return 'Attendance Marked';
      case NotificationType.attendanceLate:
        return 'Late Attendance';
      case NotificationType.attendanceAbsent:
        return 'Absent';

      // Grade Related
      case NotificationType.gradePosted:
        return 'Grade Posted';
      case NotificationType.gradeUpdated:
        return 'Grade Updated';

      // System Related
      case NotificationType.system:
      case NotificationType.systemAnnouncement:
        return 'System Announcement';
      case NotificationType.systemMaintenance:
        return 'System Maintenance';
      case NotificationType.systemUpdate:
        return 'System Update';
    }
  }

  /// Get notification category for grouping/filtering
  static NotificationCategory getCategory(NotificationType type) {
    switch (type) {
      case NotificationType.message:
      case NotificationType.messageReceived:
      case NotificationType.conversationCreated:
        return NotificationCategory.message;

      case NotificationType.assignment:
      case NotificationType.assignmentCreated:
      case NotificationType.assignmentUpdated:
      case NotificationType.assignmentDueSoon:
      case NotificationType.assignmentSubmitted:
      case NotificationType.assignmentGraded:
        return NotificationCategory.assignment;

      case NotificationType.classUpdateAnnouncement:
      case NotificationType.classUpdateHomework:
      case NotificationType.classUpdateReminder:
      case NotificationType.classUpdateEvent:
      case NotificationType.classUpdateComment:
      case NotificationType.classUpdateReply:
      case NotificationType.announcement:
      case NotificationType.event:
      case NotificationType.reminder:
        return NotificationCategory.classUpdate;

      case NotificationType.attendanceMarked:
      case NotificationType.attendanceLate:
      case NotificationType.attendanceAbsent:
        return NotificationCategory.attendance;

      case NotificationType.gradePosted:
      case NotificationType.gradeUpdated:
        return NotificationCategory.grade;

      case NotificationType.system:
      case NotificationType.systemAnnouncement:
      case NotificationType.systemMaintenance:
      case NotificationType.systemUpdate:
        return NotificationCategory.system;
    }
  }

  /// Check if notification type is urgent/high priority
  static bool isUrgent(NotificationType type) {
    switch (type) {
      case NotificationType.assignmentDueSoon:
      case NotificationType.attendanceAbsent:
      case NotificationType.systemMaintenance:
        return true;
      default:
        return false;
    }
  }

  /// Check if notification type should trigger sound/vibration
  static bool shouldAlert(NotificationType type) {
    switch (type) {
      case NotificationType.message:
      case NotificationType.messageReceived:
      case NotificationType.assignmentDueSoon:
      case NotificationType.attendanceAbsent:
      case NotificationType.systemMaintenance:
        return true;
      default:
        return false;
    }
  }

  /// Get light background color for notification tiles
  static Color getLightColor(NotificationType type) {
    return getColor(type).withOpacity(0.1);
  }

  /// Get contrast text color based on background
  static Color getTextColor(NotificationType type) {
    final color = getColor(type);
    // Simple contrast check - for dark colors use white text
    final brightness = color.computeLuminance();
    return brightness > 0.5 ? Colors.black87 : Colors.white;
  }
}

/// Notification categories for filtering and organization
enum NotificationCategory {
  message,
  assignment,
  classUpdate,
  attendance,
  grade,
  system,
}

/// Extension to get display names for categories
extension NotificationCategoryExtension on NotificationCategory {
  String get displayName {
    switch (this) {
      case NotificationCategory.message:
        return 'Messages';
      case NotificationCategory.assignment:
        return 'Assignments';
      case NotificationCategory.classUpdate:
        return 'Class Updates';
      case NotificationCategory.attendance:
        return 'Attendance';
      case NotificationCategory.grade:
        return 'Grades';
      case NotificationCategory.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationCategory.message:
        return Icons.message;
      case NotificationCategory.assignment:
        return Icons.assignment;
      case NotificationCategory.classUpdate:
        return Icons.school;
      case NotificationCategory.attendance:
        return Icons.how_to_reg;
      case NotificationCategory.grade:
        return Icons.grade;
      case NotificationCategory.system:
        return Icons.settings;
    }
  }
}
