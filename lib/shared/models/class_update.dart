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
class Reaction {
  final int count;
  final List<String> users;

  Reaction({
    required this.count,
    required this.users,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) =>
      _$ReactionFromJson(json);
  Map<String, dynamic> toJson() => _$ReactionToJson(this);
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
  final Map<String, Reaction>? reactions;
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

  factory ClassUpdate.fromJson(Map<String, dynamic> json) {
    try {
      // Filter out attachments with empty IDs (corrupted seed data)
      List<Map<String, dynamic>>? filteredAttachments;
      if (json['attachments'] != null) {
        final attachmentList = json['attachments'] as List<dynamic>;
        filteredAttachments = [];

        for (final attachment in attachmentList) {
          if (attachment != null &&
              attachment is Map<String, dynamic> &&
              attachment['id'] != null &&
              attachment['id'].toString().trim().isNotEmpty) {
            filteredAttachments.add(attachment);
          }
        }
      }

      // Use manual parsing to avoid null casting errors
      return ClassUpdate(
        id: json['id']?.toString() ?? '',
        classId: json['class_id']?.toString() ?? '',
        authorId: json['author_id']?.toString() ?? '',
        title: json['title']?.toString(),
        content: json['content']?.toString() ?? '',
        updateType: UpdateType.values.firstWhere(
          (e) => e.name == json['update_type'],
          orElse: () => UpdateType.announcement,
        ),
        attachments: filteredAttachments,
        reactions: json['reactions'] != null
            ? (json['reactions'] as Map<String, dynamic>).map(
                (k, e) =>
                    MapEntry(k, Reaction.fromJson(e as Map<String, dynamic>)),
              )
            : null,
        isPinned: json['is_pinned'] == true,
        isEdited: json['is_edited'] == true,
        editedAt: json['edited_at'] != null
            ? DateTime.tryParse(json['edited_at'].toString())
            : null,
        isDeleted: json['is_deleted'] == true,
        deletedAt: json['deleted_at'] != null
            ? DateTime.tryParse(json['deleted_at'].toString())
            : null,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        author: json['author'] != null
            ? _safeParseUser(json['author'] as Map<String, dynamic>)
            : null,
        comments: json['comments'] != null
            ? (json['comments'] as List<dynamic>)
                .map((e) =>
                    ClassUpdateComment.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        commentsCount: json['comments_count'] != null
            ? int.tryParse(json['comments_count'].toString())
            : null,
      );
    } catch (e) {
      rethrow;
    }
  }

  static User? _safeParseUser(Map<String, dynamic> json) {
    try {
      return User.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => _$ClassUpdateToJson(this);

  bool get hasAttachments => attachments != null && attachments!.isNotEmpty;
  bool get hasReactions =>
      reactions != null &&
      reactions!.isNotEmpty &&
      reactions!.values.any((reaction) => reaction.count > 0);
  bool get hasComments => commentsCount != null && commentsCount! > 0;

  int get totalReactions {
    if (reactions == null) return 0;
    return reactions!.values
        .where((reaction) => reaction.count > 0)
        .fold(0, (sum, reaction) => sum + reaction.count);
  }

  // Helper method to get reaction count for a specific emoji
  int getReactionCount(String emoji) {
    return reactions?[emoji]?.count ?? 0;
  }

  // Helper method to check if a user has reacted with a specific emoji
  bool hasUserReacted(String emoji, String userId) {
    return reactions?[emoji]?.users.contains(userId) ?? false;
  }

  // Helper method to get all users who reacted with a specific emoji
  List<String> getUsersWhoReacted(String emoji) {
    return reactions?[emoji]?.users ?? [];
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
    Map<String, Reaction>? reactions,
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
      other is ClassUpdate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ClassUpdate(id: $id, title: $displayTitle, updateType: $updateType)';
}
