// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_update_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassUpdateComment _$ClassUpdateCommentFromJson(Map<String, dynamic> json) =>
    ClassUpdateComment(
      id: json['id'] as String,
      classUpdateId: json['class_update_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      replyToId: json['reply_to_id'] as String?,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
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
      replyTo: json['reply_to'] == null
          ? null
          : ClassUpdateComment.fromJson(
              json['reply_to'] as Map<String, dynamic>),
      replies: (json['replies'] as List<dynamic>?)
          ?.map((e) => ClassUpdateComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      repliesCount: (json['replies_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ClassUpdateCommentToJson(ClassUpdateComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'class_update_id': instance.classUpdateId,
      'author_id': instance.authorId,
      'content': instance.content,
      'reply_to_id': instance.replyToId,
      'reactions': instance.reactions,
      'is_edited': instance.isEdited,
      'edited_at': instance.editedAt?.toIso8601String(),
      'is_deleted': instance.isDeleted,
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'author': instance.author,
      'reply_to': instance.replyTo,
      'replies': instance.replies,
      'replies_count': instance.repliesCount,
    };
