import 'package:json_annotation/json_annotation.dart';
import 'user.dart';
import '../utils/notification_helpers.dart';

part 'notification.g.dart';

enum NotificationType {
  // Class Update Related
  @JsonValue('class_update_announcement')
  classUpdateAnnouncement,
  @JsonValue('class_update_homework')
  classUpdateHomework,
  @JsonValue('class_update_reminder')
  classUpdateReminder,
  @JsonValue('class_update_event')
  classUpdateEvent,

  // Class Update Comments
  @JsonValue('class_update_comment')
  classUpdateComment,
  @JsonValue('class_update_reply')
  classUpdateReply,

  // Assignment Related
  @JsonValue('assignment_created')
  assignmentCreated,
  @JsonValue('assignment_updated')
  assignmentUpdated,
  @JsonValue('assignment_due_soon')
  assignmentDueSoon,
  @JsonValue('assignment_submitted')
  assignmentSubmitted,
  @JsonValue('assignment_graded')
  assignmentGraded,

  // Attendance Related
  @JsonValue('attendance_marked')
  attendanceMarked,
  @JsonValue('attendance_late')
  attendanceLate,
  @JsonValue('attendance_absent')
  attendanceAbsent,

  // Grade Related
  @JsonValue('grade_posted')
  gradePosted,
  @JsonValue('grade_updated')
  gradeUpdated,

  // Message Related
  @JsonValue('message_received')
  messageReceived,
  @JsonValue('conversation_created')
  conversationCreated,

  // System Related
  @JsonValue('system_announcement')
  systemAnnouncement,
  @JsonValue('system_maintenance')
  systemMaintenance,
  @JsonValue('system_update')
  systemUpdate,

  // General
  @JsonValue('announcement')
  announcement,
  @JsonValue('event')
  event,
  @JsonValue('reminder')
  reminder,

  // Legacy types (for backward compatibility)
  @JsonValue('message')
  message,
  @JsonValue('assignment')
  assignment,
  @JsonValue('system')
  system,
}

enum NotificationPriority {
  @JsonValue('low')
  low,
  @JsonValue('normal')
  normal,
  @JsonValue('high')
  high,
  @JsonValue('urgent')
  urgent,
}

@JsonSerializable()
class NotificationModel {
  final String id;
  final String title;
  final String content;
  @JsonKey(name: 'notification_type')
  final NotificationType type;
  final NotificationPriority priority;
  @JsonKey(name: 'is_read')
  final bool isRead;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'sender_id')
  final String? senderId;
  final User? sender;
  @JsonKey(name: 'action_url')
  final String? actionUrl;
  @JsonKey(name: 'action_data')
  final Map<String, dynamic>? actionData;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'read_at')
  final DateTime? readAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.priority = NotificationPriority.normal,
    this.isRead = false,
    required this.userId,
    this.senderId,
    this.sender,
    this.actionUrl,
    this.actionData,
    this.imageUrl,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  NotificationModel copyWith({
    String? id,
    String? title,
    String? content,
    NotificationType? type,
    NotificationPriority? priority,
    bool? isRead,
    String? userId,
    String? senderId,
    User? sender,
    String? actionUrl,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      sender: sender ?? this.sender,
      actionUrl: actionUrl ?? this.actionUrl,
      actionData: actionData ?? this.actionData,
      imageUrl: imageUrl ?? this.imageUrl,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get typeDisplayName => NotificationHelpers.getDisplayName(type);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
