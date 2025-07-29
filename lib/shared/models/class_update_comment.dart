import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'class_update_comment.g.dart';

@JsonSerializable()
class ClassUpdateComment {
  final String id;
  @JsonKey(name: 'class_update_id')
  final String classUpdateId;
  @JsonKey(name: 'author_id')
  final String authorId;
  final String content;
  @JsonKey(name: 'reply_to_id')
  final String? replyToId;
  final Map<String, dynamic>? reactions;
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
  @JsonKey(name: 'reply_to')
  final ClassUpdateComment? replyTo;
  final List<ClassUpdateComment>? replies;
  @JsonKey(name: 'replies_count')
  final int? repliesCount;

  ClassUpdateComment({
    required this.id,
    required this.classUpdateId,
    required this.authorId,
    required this.content,
    this.replyToId,
    this.reactions,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.replyTo,
    this.replies,
    this.repliesCount,
  });

  factory ClassUpdateComment.fromJson(Map<String, dynamic> json) =>
      _$ClassUpdateCommentFromJson(json);
  Map<String, dynamic> toJson() => _$ClassUpdateCommentToJson(this);

  bool get isReply => replyToId != null;
  bool get hasReactions => reactions != null && reactions!.isNotEmpty;
  bool get hasReplies => repliesCount != null && repliesCount! > 0;

  int get totalReactions {
    if (reactions == null) return 0;
    int total = 0;
    for (var reaction in reactions!.values) {
      if (reaction is Map<String, dynamic>) {
        total += (reaction['count'] as int? ?? 0);
      } else if (reaction is int) {
        // Fallback for legacy format
        total += reaction;
      }
    }
    return total;
  }

  String get displayContent {
    if (isDeleted) return 'This comment was deleted';
    return content;
  }

  ClassUpdateComment copyWith({
    String? id,
    String? classUpdateId,
    String? authorId,
    String? content,
    String? replyToId,
    Map<String, dynamic>? reactions,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? author,
    ClassUpdateComment? replyTo,
    List<ClassUpdateComment>? replies,
    int? repliesCount,
  }) {
    return ClassUpdateComment(
      id: id ?? this.id,
      classUpdateId: classUpdateId ?? this.classUpdateId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author ?? this.author,
      replyTo: replyTo ?? this.replyTo,
      replies: replies ?? this.replies,
      repliesCount: repliesCount ?? this.repliesCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassUpdateComment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ClassUpdateComment(id: $id, authorId: $authorId, isReply: $isReply)';
}
