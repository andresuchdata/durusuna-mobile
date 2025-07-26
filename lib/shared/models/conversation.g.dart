// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Conversation _$ConversationFromJson(Map<String, dynamic> json) => Conversation(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdBy: json['created_by'] as String,
      lastMessageId: json['last_message_id'] as String?,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => User.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      otherUser: json['other_user'] == null
          ? null
          : User.fromJson(json['other_user'] as Map<String, dynamic>),
      lastMessage: json['last_message'] == null
          ? null
          : Message.fromJson(json['last_message'] as Map<String, dynamic>),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastActivity: json['last_activity'] == null
          ? null
          : DateTime.parse(json['last_activity'] as String),
      userRole: json['user_role'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
    );

Map<String, dynamic> _$ConversationToJson(Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'name': instance.name,
      'description': instance.description,
      'avatar_url': instance.avatarUrl,
      'created_by': instance.createdBy,
      'last_message_id': instance.lastMessageId,
      'last_message_at': instance.lastMessageAt?.toIso8601String(),
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'participants': instance.participants,
      'other_user': instance.otherUser,
      'last_message': instance.lastMessage,
      'unread_count': instance.unreadCount,
      'last_activity': instance.lastActivity?.toIso8601String(),
      'user_role': instance.userRole,
      'is_online': instance.isOnline,
    };

ConversationParticipant _$ConversationParticipantFromJson(
        Map<String, dynamic> json) =>
    ConversationParticipant(
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] == null
          ? null
          : DateTime.parse(json['left_at'] as String),
      lastReadAt: json['last_read_at'] == null
          ? null
          : DateTime.parse(json['last_read_at'] as String),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      canAddParticipants: json['can_add_participants'] as bool? ?? false,
      canRemoveParticipants: json['can_remove_participants'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ConversationParticipantToJson(
        ConversationParticipant instance) =>
    <String, dynamic>{
      'conversation_id': instance.conversationId,
      'user_id': instance.userId,
      'role': instance.role,
      'joined_at': instance.joinedAt.toIso8601String(),
      'left_at': instance.leftAt?.toIso8601String(),
      'last_read_at': instance.lastReadAt?.toIso8601String(),
      'unread_count': instance.unreadCount,
      'is_active': instance.isActive,
      'can_add_participants': instance.canAddParticipants,
      'can_remove_participants': instance.canRemoveParticipants,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
