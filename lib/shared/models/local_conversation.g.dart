// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalConversation _$LocalConversationFromJson(Map<String, dynamic> json) =>
    LocalConversation(
      serverId: json['serverId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      otherUserId: json['otherUserId'] as String?,
      otherUserName: json['otherUserName'] as String?,
      otherUserAvatar: json['otherUserAvatar'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      isOnline: json['isOnline'] as bool? ?? false,
      participantsJson: json['participantsJson'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
      type: $enumDecode(_$LocalConversationTypeEnumMap, json['type']),
      avatarUrl: json['avatarUrl'] as String?,
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      isMuted: json['isMuted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
    );

Map<String, dynamic> _$LocalConversationToJson(LocalConversation instance) =>
    <String, dynamic>{
      'serverId': instance.serverId,
      'name': instance.name,
      'description': instance.description,
      'otherUserId': instance.otherUserId,
      'otherUserName': instance.otherUserName,
      'otherUserAvatar': instance.otherUserAvatar,
      'lastMessage': instance.lastMessage,
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'isOnline': instance.isOnline,
      'participantsJson': instance.participantsJson,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'isArchived': instance.isArchived,
      'type': _$LocalConversationTypeEnumMap[instance.type]!,
      'avatarUrl': instance.avatarUrl,
      'lastActivity': instance.lastActivity.toIso8601String(),
      'isMuted': instance.isMuted,
      'isPinned': instance.isPinned,
    };

const _$LocalConversationTypeEnumMap = {
  LocalConversationType.direct: 'direct',
  LocalConversationType.group: 'group',
  LocalConversationType.class_: 'class_',
};
