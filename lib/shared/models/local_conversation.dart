import 'package:json_annotation/json_annotation.dart';

part 'local_conversation.g.dart';

/// Enum for conversation types
enum LocalConversationType {
  direct,
  group,
  class_,
}

/// Extension to convert enum to string
extension LocalConversationTypeExtension on LocalConversationType {
  String get value {
    switch (this) {
      case LocalConversationType.direct:
        return 'direct';
      case LocalConversationType.group:
        return 'group';
      case LocalConversationType.class_:
        return 'class';
    }
  }

  static LocalConversationType fromString(String value) {
    switch (value) {
      case 'direct':
        return LocalConversationType.direct;
      case 'group':
        return LocalConversationType.group;
      case 'class':
        return LocalConversationType.class_;
      default:
        return LocalConversationType.direct;
    }
  }
}

/// Local conversation model for SQLite storage
@JsonSerializable()
class LocalConversation {
  final String serverId;
  final String name;
  final String? description;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isOnline;
  final String? participantsJson;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int unreadCount;
  final bool isArchived;
  final LocalConversationType type;
  final String? avatarUrl;
  final DateTime lastActivity;
  final bool isMuted;
  final bool isPinned;

  const LocalConversation({
    required this.serverId,
    required this.name,
    this.description,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.isOnline = false,
    this.participantsJson,
    required this.createdAt,
    this.updatedAt,
    this.unreadCount = 0,
    this.isArchived = false,
    required this.type,
    this.avatarUrl,
    required this.lastActivity,
    this.isMuted = false,
    this.isPinned = false,
  });

  factory LocalConversation.fromJson(Map<String, dynamic> json) =>
      _$LocalConversationFromJson(json);

  Map<String, dynamic> toJson() => _$LocalConversationToJson(this);

  LocalConversation copyWith({
    String? serverId,
    String? name,
    String? description,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? isOnline,
    String? participantsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? unreadCount,
    bool? isArchived,
    LocalConversationType? type,
    String? avatarUrl,
    DateTime? lastActivity,
    bool? isMuted,
    bool? isPinned,
  }) {
    return LocalConversation(
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      description: description ?? this.description,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isOnline: isOnline ?? this.isOnline,
      participantsJson: participantsJson ?? this.participantsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      type: type ?? this.type,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastActivity: lastActivity ?? this.lastActivity,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalConversation &&
          runtimeType == other.runtimeType &&
          serverId == other.serverId;

  @override
  int get hashCode => serverId.hashCode;

  String get displayName => name;

  @override
  String toString() {
    return 'LocalConversation{serverId: $serverId, name: $name, unreadCount: $unreadCount}';
  }
}

/// Extension for API JSON conversion
extension LocalConversationExtension on LocalConversation {
  static LocalConversation fromApiJson(
      Map<String, dynamic> json, String currentUserId) {
    return LocalConversation(
      serverId: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      otherUserId: json['other_user_id'],
      otherUserName: json['other_user_name'],
      otherUserAvatar: json['other_user_avatar'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      isOnline: json['is_online'] ?? false,
      participantsJson: json['participants_json'],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      isArchived: json['is_archived'] ?? false,
      type: LocalConversationTypeExtension.fromString(json['type'] ?? 'direct'),
      avatarUrl: json['avatar_url'],
      lastActivity: DateTime.parse(
          json['last_activity'] ?? DateTime.now().toIso8601String()),
      isMuted: json['is_muted'] ?? false,
      isPinned: json['is_pinned'] ?? false,
    );
  }
}
