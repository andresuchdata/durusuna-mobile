import 'package:json_annotation/json_annotation.dart';
import 'user.dart';
import 'class_update_comment.dart';

part 'class_update.g.dart';

enum UpdateType {
  @JsonValue('announcement')
  announcement,
  @JsonValue('homework')
  homework,
  @JsonValue('reminder')
  reminder,
  @JsonValue('event')
  event,
}

@JsonSerializable()
class ClassUpdate {
  final String id;
  @JsonKey(name: 'class_id')
  final String classId;
  @JsonKey(name: 'author_id')
  final String authorId;
  final String? title;
  final String content;
  @JsonKey(name: 'update_type')
  final UpdateType updateType;
  final List<Map<String, dynamic>>? attachments;
  final Map<String, int>? reactions;
  @JsonKey(name: 'is_pinned')
  final bool isPinned;
  @JsonKey(name: 'is_edited')
  final bool isEdited;
  @JsonKey(name: 'edited_at')
  final DateTime? editedAt;
  @JsonKey(name: 'is_deleted')
  final bool isDeleted;
  @JsonKey(name: 'deleted_at')
  final DateTime? deletedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  
  // Related data
  final User? author;
  final List<ClassUpdateComment>? comments;
  @JsonKey(name: 'comments_count')
  final int? commentsCount;

  ClassUpdate({
    required this.id,
    required this.classId,
    required this.authorId,
    this.title,
    required this.content,
    required this.updateType,
    this.attachments,
    this.reactions,
    required this.isPinned,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.comments,
    this.commentsCount,
  });

  factory ClassUpdate.fromJson(Map<String, dynamic> json) => 
      _$ClassUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$ClassUpdateToJson(this);

  bool get hasAttachments => attachments != null && attachments!.isNotEmpty;
  bool get hasReactions => reactions != null && reactions!.isNotEmpty;
  bool get hasComments => commentsCount != null && commentsCount! > 0;

  int get totalReactions {
    if (reactions == null) return 0;
    return reactions!.values.fold(0, (sum, count) => sum + count);
  }

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    switch (updateType) {
      case UpdateType.announcement:
        return 'Announcement';
      case UpdateType.homework:
        return 'Homework';
      case UpdateType.reminder:
        return 'Reminder';
      case UpdateType.event:
        return 'Event';
    }
  }

  String get updateTypeIcon {
    switch (updateType) {
      case UpdateType.announcement:
        return '📢';
      case UpdateType.homework:
        return '📚';
      case UpdateType.reminder:
        return '⏰';
      case UpdateType.event:
        return '📅';
    }
  }

  ClassUpdate copyWith({
    String? id,
    String? classId,
    String? authorId,
    String? title,
    String? content,
    UpdateType? updateType,
    List<Map<String, dynamic>>? attachments,
    Map<String, int>? reactions,
    bool? isPinned,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? author,
    List<ClassUpdateComment>? comments,
    int? commentsCount,
  }) {
    return ClassUpdate(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      content: content ?? this.content,
      updateType: updateType ?? this.updateType,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      isPinned: isPinned ?? this.isPinned,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author ?? this.author,
      comments: comments ?? this.comments,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassUpdate && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ClassUpdate(id: $id, title: $displayTitle, updateType: $updateType)';
} 