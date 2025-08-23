// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['notification_type']),
      priority: $enumDecodeNullable(
              _$NotificationPriorityEnumMap, json['priority']) ??
          NotificationPriority.normal,
      isRead: json['is_read'] as bool? ?? false,
      userId: json['user_id'] as String,
      senderId: json['sender_id'] as String?,
      sender: json['sender'] == null
          ? null
          : User.fromJson(json['sender'] as Map<String, dynamic>),
      actionUrl: json['action_url'] as String?,
      actionData: json['action_data'] as Map<String, dynamic>?,
      imageUrl: json['image_url'] as String?,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'notification_type': _$NotificationTypeEnumMap[instance.type]!,
      'priority': _$NotificationPriorityEnumMap[instance.priority]!,
      'is_read': instance.isRead,
      'user_id': instance.userId,
      'sender_id': instance.senderId,
      'sender': instance.sender,
      'action_url': instance.actionUrl,
      'action_data': instance.actionData,
      'image_url': instance.imageUrl,
      'read_at': instance.readAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$NotificationTypeEnumMap = {
  NotificationType.classUpdateAnnouncement: 'class_update_announcement',
  NotificationType.classUpdateHomework: 'class_update_homework',
  NotificationType.classUpdateReminder: 'class_update_reminder',
  NotificationType.classUpdateEvent: 'class_update_event',
  NotificationType.classUpdateComment: 'class_update_comment',
  NotificationType.classUpdateReply: 'class_update_reply',
  NotificationType.assignmentCreated: 'assignment_created',
  NotificationType.assignmentUpdated: 'assignment_updated',
  NotificationType.assignmentDueSoon: 'assignment_due_soon',
  NotificationType.assignmentSubmitted: 'assignment_submitted',
  NotificationType.assignmentGraded: 'assignment_graded',
  NotificationType.attendanceMarked: 'attendance_marked',
  NotificationType.attendanceLate: 'attendance_late',
  NotificationType.attendanceAbsent: 'attendance_absent',
  NotificationType.gradePosted: 'grade_posted',
  NotificationType.gradeUpdated: 'grade_updated',
  NotificationType.messageReceived: 'message_received',
  NotificationType.conversationCreated: 'conversation_created',
  NotificationType.systemAnnouncement: 'system_announcement',
  NotificationType.systemMaintenance: 'system_maintenance',
  NotificationType.systemUpdate: 'system_update',
  NotificationType.announcement: 'announcement',
  NotificationType.event: 'event',
  NotificationType.reminder: 'reminder',
  NotificationType.message: 'message',
  NotificationType.assignment: 'assignment',
  NotificationType.system: 'system',
};

const _$NotificationPriorityEnumMap = {
  NotificationPriority.low: 'low',
  NotificationPriority.normal: 'normal',
  NotificationPriority.high: 'high',
  NotificationPriority.urgent: 'urgent',
};
