// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassUpdate _$ClassUpdateFromJson(Map<String, dynamic> json) => ClassUpdate(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      authorId: json['author_id'] as String,
      title: json['title'] as String?,
      content: json['content'] as String,
      updateType: $enumDecode(_$UpdateTypeEnumMap, json['update_type']),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
      isPinned: json['is_pinned'] as bool,
      isEdited: json['is_edited'] as bool,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      isDeleted: json['is_deleted'] as bool,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      author: json['author'] == null
          ? null
          : User.fromJson(json['author'] as Map<String, dynamic>),
      comments: (json['comments'] as List<dynamic>?)
          ?.map((e) => ClassUpdateComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      commentsCount: (json['comments_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ClassUpdateToJson(ClassUpdate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'class_id': instance.classId,
      'author_id': instance.authorId,
      'title': instance.title,
      'content': instance.content,
      'update_type': _$UpdateTypeEnumMap[instance.updateType]!,
      'attachments': instance.attachments,
      'reactions': instance.reactions,
      'is_pinned': instance.isPinned,
      'is_edited': instance.isEdited,
      'edited_at': instance.editedAt?.toIso8601String(),
      'is_deleted': instance.isDeleted,
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'author': instance.author,
      'comments': instance.comments,
      'comments_count': instance.commentsCount,
    };

const _$UpdateTypeEnumMap = {
  UpdateType.announcement: 'announcement',
  UpdateType.homework: 'homework',
  UpdateType.reminder: 'reminder',
  UpdateType.event: 'event',
};
