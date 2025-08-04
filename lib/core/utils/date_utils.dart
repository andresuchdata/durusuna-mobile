/// Date utility functions for the Durusuna app
///
/// Usage examples:
/// ```dart
/// import 'package:durusuna_mobile/core/utils/date_utils.dart' as app_date_utils;
///
/// // Format due dates
/// final dueText = app_date_utils.DateUtils.formatDueDate(DateTime.now().add(Duration(days: 3)));
/// // Result: "Due in 3 days"
///
/// // Format relative time
/// final timeText = app_date_utils.DateUtils.formatRelativeTime(DateTime.now().subtract(Duration(hours: 2)));
/// // Result: "2 hours ago"
///
/// // Check overdue status
/// final isLate = app_date_utils.DateUtils.isOverdue(DateTime.now().subtract(Duration(days: 1)));
/// // Result: true
/// ```
class DateUtils {
  /// Format a due date relative to the current time
  /// Returns user-friendly strings like "Due tomorrow", "Due in 3 days", "Overdue"
  static String formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      final daysPast = difference.inDays.abs();
      if (daysPast == 0) {
        return 'Due today';
      } else if (daysPast == 1) {
        return 'Due yesterday';
      } else {
        return 'Due $daysPast days ago';
      }
    } else {
      if (difference.inDays == 0) {
        return 'Due today';
      } else if (difference.inDays == 1) {
        return 'Due tomorrow';
      } else {
        return 'Due in ${difference.inDays} days';
      }
    }
  }

  /// Format a relative time difference (e.g., "2 hours ago", "3 days ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if a date is overdue (past current time)
  static bool isOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now());
  }

  /// Check if a date is due today
  static bool isDueToday(DateTime dueDate) {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  /// Check if a date is due tomorrow
  static bool isDueTomorrow(DateTime dueDate) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return dueDate.year == tomorrow.year &&
        dueDate.month == tomorrow.month &&
        dueDate.day == tomorrow.day;
  }

  /// Format a date in a standard readable format (e.g., "Jan 15, 2024")
  static String formatReadableDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Format time in 12-hour format (e.g., "2:30 PM")
  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Get days until a specific date
  static int daysUntil(DateTime futureDate) {
    final now = DateTime.now();
    final difference = futureDate.difference(now);
    return difference.inDays;
  }
}
