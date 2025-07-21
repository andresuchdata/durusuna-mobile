// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String?,
      messageType: $enumDecode(_$MessageTypeEnumMap, json['message_type']),
      metadata: json['metadata'] as Map<String, dynamic>?,
      replyToId: json['reply_to_id'] as String?,
      isEdited: json['is_edited'] as bool,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      isDeleted: json['is_deleted'] as bool,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      deliveredAt: json['delivered_at'] == null
          ? null
          : DateTime.parse(json['delivered_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      readStatus:
          $enumDecodeNullable(_$ReadStatusEnumMap, json['read_status']) ??
              ReadStatus.sent,
      reactions: json['reactions'] as Map<String, dynamic>? ?? const {},
      isFromMe: json['is_from_me'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sender: json['sender'] == null
          ? null
          : User.fromJson(json['sender'] as Map<String, dynamic>),
      receiver: json['receiver'] == null
          ? null
          : User.fromJson(json['receiver'] as Map<String, dynamic>),
      replyTo: json['reply_to'] == null
          ? null
          : Message.fromJson(json['reply_to'] as Map<String, dynamic>),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'id': instance.id,
      'sender_id': instance.senderId,
      'receiver_id': instance.receiverId,
      'content': instance.content,
      'message_type': _$MessageTypeEnumMap[instance.messageType]!,
      'metadata': instance.metadata,
      'reply_to_id': instance.replyToId,
      'is_edited': instance.isEdited,
      'edited_at': instance.editedAt?.toIso8601String(),
      'is_deleted': instance.isDeleted,
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'delivered_at': instance.deliveredAt?.toIso8601String(),
      'read_at': instance.readAt?.toIso8601String(),
      'read_status': _$ReadStatusEnumMap[instance.readStatus]!,
      'reactions': instance.reactions,
      'is_from_me': instance.isFromMe,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'sender': instance.sender,
      'receiver': instance.receiver,
      'reply_to': instance.replyTo,
      'attachments': instance.attachments,
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.video: 'video',
  MessageType.audio: 'audio',
  MessageType.file: 'file',
  MessageType.emoji: 'emoji',
};

const _$ReadStatusEnumMap = {
  ReadStatus.sent: 'sent',
  ReadStatus.delivered: 'delivered',
  ReadStatus.read: 'read',
};
