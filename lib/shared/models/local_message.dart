import 'dart:convert';
import 'package:isar/isar.dart';

part 'local_message.g.dart';

@collection
class LocalMessage {
  Id id = Isar.autoIncrement; // Local auto-increment ID

  @Index(unique: true)
  String? serverId; // Server-side UUID

  @Index()
  String conversationId;

  @Index()
  String senderId;

  @Index(caseSensitive: false)
  String? content;

  @Enumerated(EnumType.name)
  LocalMessageType messageType;

  String? replyToId;
  String? replyToContent; // Denormalized for quick display

  @Index()
  DateTime createdAt;

  DateTime? updatedAt;
  DateTime? readAt;
  DateTime? deliveredAt;

  bool isFromMe;

  @Index()
  String? readStatus; // 'sent', 'delivered', 'read'

  // Sync status
  @Index()
  bool isSynced;

  bool needsUpload; // For media files

  // Media/attachment info
  String? attachmentUrl;
  String? attachmentType;
  int? attachmentSize;
  String? thumbnailPath; // Local thumbnail for media

  // Metadata (stored as JSON string)
  String? metadataJson;

  // Reactions (JSON string for simplicity)
  String? reactions;

  LocalMessage({
    this.serverId,
    required this.conversationId,
    required this.senderId,
    this.content,
    required this.messageType,
    this.replyToId,
    this.replyToContent,
    required this.createdAt,
    this.updatedAt,
    this.readAt,
    this.deliveredAt,
    required this.isFromMe,
    this.readStatus = 'sent',
    this.isSynced = false,
    this.needsUpload = false,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentSize,
    this.thumbnailPath,
    this.metadataJson,
    this.reactions,
  });

  LocalMessage copyWith({
    String? serverId,
    String? conversationId,
    String? senderId,
    String? content,
    LocalMessageType? messageType,
    String? replyToId,
    String? replyToContent,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
    DateTime? deliveredAt,
    bool? isFromMe,
    String? readStatus,
    bool? isSynced,
    bool? needsUpload,
    String? attachmentUrl,
    String? attachmentType,
    int? attachmentSize,
    String? thumbnailPath,
    String? metadataJson,
    String? reactions,
  }) {
    return LocalMessage(
      serverId: serverId ?? this.serverId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      isFromMe: isFromMe ?? this.isFromMe,
      readStatus: readStatus ?? this.readStatus,
      isSynced: isSynced ?? this.isSynced,
      needsUpload: needsUpload ?? this.needsUpload,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      metadataJson: metadataJson ?? this.metadataJson,
      reactions: reactions ?? this.reactions,
    );
  }
}

enum LocalMessageType {
  text,
  image,
  video,
  audio,
  file,
  emoji,
  location,
}

// Extension to convert to/from existing Message model
extension LocalMessageExtension on LocalMessage {
  // Helper to get metadata as Map
  Map<String, dynamic>? get metadata {
    if (metadataJson == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(metadataJson!));
    } catch (e) {
      return null;
    }
  }

  // Convert to API Message model for sending
  Map<String, dynamic> toApiJson() {
    return {
      'id': serverId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType.name,
      'reply_to_id': replyToId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Create from API response
  static LocalMessage fromApiJson(Map<String, dynamic> json,
      {required bool isFromMe}) {
    return LocalMessage(
      serverId: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      messageType: _parseMessageType(json['message_type']),
      replyToId: json['reply_to_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isFromMe: isFromMe,
      readStatus: json['read_status'] ?? 'sent',
      isSynced: true, // Coming from server, so it's synced
      metadataJson:
          json['metadata'] != null ? jsonEncode(json['metadata']) : null,
    );
  }

  static LocalMessageType _parseMessageType(dynamic type) {
    switch (type.toString().toLowerCase()) {
      case 'image':
        return LocalMessageType.image;
      case 'video':
        return LocalMessageType.video;
      case 'audio':
        return LocalMessageType.audio;
      case 'file':
        return LocalMessageType.file;
      case 'emoji':
        return LocalMessageType.emoji;
      case 'location':
        return LocalMessageType.location;
      default:
        return LocalMessageType.text;
    }
  }
}
