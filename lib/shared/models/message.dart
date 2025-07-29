import 'package:json_annotation/json_annotation.dart';
import 'user.dart';
import 'message_attachment.dart';

part 'message.g.dart';

enum MessageType {
  @JsonValue('text')
  text,
  @JsonValue('image')
  image,
  @JsonValue('video')
  video,
  @JsonValue('audio')
  audio,
  @JsonValue('file')
  file,
  @JsonValue('emoji')
  emoji,
}

enum ReadStatus {
  @JsonValue('sent')
  sent,
  @JsonValue('delivered')
  delivered,
  @JsonValue('read')
  read,
}

@JsonSerializable()
class Message {
  final String id;
  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'sender_id')
  final String senderId;
  @JsonKey(name: 'receiver_id')
  final String? receiverId;
  final String? content;
  @JsonKey(name: 'message_type')
  final MessageType messageType;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'reply_to_id')
  final String? replyToId;
  @JsonKey(name: 'is_read')
  final bool isRead;
  @JsonKey(name: 'is_edited')
  final bool isEdited;
  @JsonKey(name: 'is_deleted')
  final bool isDeleted;
  @JsonKey(name: 'edited_at')
  final DateTime? editedAt;
  @JsonKey(name: 'deleted_at')
  final DateTime? deletedAt;
  @JsonKey(name: 'delivered_at')
  final DateTime? deliveredAt;
  @JsonKey(name: 'read_at')
  final DateTime? readAt;
  @JsonKey(name: 'read_status')
  final ReadStatus readStatus;
  final Map<String, dynamic> reactions;
  @JsonKey(name: 'is_from_me')
  final bool isFromMe;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Related data
  final User? sender;
  final User? receiver;
  @JsonKey(name: 'reply_to')
  final Message? replyTo;
  final List<MessageAttachment>? attachments;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    this.content,
    required this.messageType,
    this.metadata,
    this.replyToId,
    this.isRead = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.editedAt,
    this.deletedAt,
    this.deliveredAt,
    this.readAt,
    this.readStatus = ReadStatus.sent,
    this.reactions = const {},
    this.isFromMe = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sender,
    this.receiver,
    this.replyTo,
    this.attachments,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  bool get hasAttachments => attachments != null && attachments!.isNotEmpty;
  bool get isReply => replyToId != null;
  bool get wasRead => readAt != null;
  bool get hasReactions => reactions.isNotEmpty;

  int get totalReactions {
    if (reactions.isEmpty) return 0;
    int total = 0;
    for (var reaction in reactions.values) {
      if (reaction is int) {
        total += reaction;
      } else if (reaction is Map<String, dynamic>) {
        final users = reaction['users'] as List<dynamic>? ?? [];
        total += users.length;
      } else if (reaction is List) {
        total += reaction.length;
      }
    }
    return total;
  }

  String get displayContent {
    if (isDeleted) return 'This message was deleted';
    if (content != null && content!.isNotEmpty) return content!;

    switch (messageType) {
      case MessageType.image:
        return '📷 Image';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return '📄 File';
      case MessageType.emoji:
        return metadata?['emoji'] ?? '😊';
      default:
        return '';
    }
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? messageType,
    Map<String, dynamic>? metadata,
    String? replyToId,
    bool? isRead,
    bool? isEdited,
    bool? isDeleted,
    DateTime? editedAt,
    DateTime? deletedAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    ReadStatus? readStatus,
    Map<String, dynamic>? reactions,
    bool? isFromMe,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? sender,
    User? receiver,
    Message? replyTo,
    List<MessageAttachment>? attachments,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      replyToId: replyToId ?? this.replyToId,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      readStatus: readStatus ?? this.readStatus,
      reactions: reactions ?? this.reactions,
      isFromMe: isFromMe ?? this.isFromMe,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      replyTo: replyTo ?? this.replyTo,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Message(id: $id, senderId: $senderId, content: $displayContent)';
}
