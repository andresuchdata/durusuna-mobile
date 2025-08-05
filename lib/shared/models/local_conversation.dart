import 'package:isar/isar.dart';

part 'local_conversation.g.dart';

@collection
class LocalConversation {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String serverId; // Server conversation ID

  @Enumerated(EnumType.name)
  LocalConversationType type;

  String? name; // Group name or null for direct chats
  String? description; // Group description
  String? avatarUrl;

  // For direct conversations - other user info
  String? otherUserId;
  String? otherUserName;
  String? otherUserAvatar;

  // Last message info (denormalized for speed)
  String? lastMessage;
  DateTime? lastMessageAt;

  @Index()
  DateTime lastActivity;

  @Index()
  int unreadCount;

  bool isOnline; // For direct chats
  bool isMuted;
  bool isPinned;
  bool isArchived;

  // Participants (JSON string for groups)
  String? participantsJson;

  DateTime createdAt;
  DateTime? updatedAt;

  LocalConversation({
    required this.serverId,
    required this.type,
    this.name,
    this.description,
    this.avatarUrl,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
    this.lastMessageAt,
    required this.lastActivity,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.participantsJson,
    required this.createdAt,
    this.updatedAt,
  });

  LocalConversation copyWith({
    String? serverId,
    LocalConversationType? type,
    String? name,
    String? description,
    String? avatarUrl,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? lastActivity,
    int? unreadCount,
    bool? isOnline,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
    String? participantsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalConversation(
      serverId: serverId ?? this.serverId,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      participantsJson: participantsJson ?? this.participantsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  String get displayName {
    if (type == LocalConversationType.group) {
      return name ?? 'Group Chat';
    }
    return otherUserName ?? 'Unknown User';
  }

  String get displayAvatar {
    if (type == LocalConversationType.group) {
      return avatarUrl ?? '';
    }
    return otherUserAvatar ?? '';
  }
}

enum LocalConversationType {
  direct,
  group,
}

// Extension for API conversion
extension LocalConversationExtension on LocalConversation {
  static LocalConversation fromApiJson(
      Map<String, dynamic> json, String currentUserId) {
    final type = json['type'] == 'group'
        ? LocalConversationType.group
        : LocalConversationType.direct;

    // For direct conversations, find the other user
    String? otherUserId;
    String? otherUserName;
    String? otherUserAvatar;

    if (type == LocalConversationType.direct && json['participants'] != null) {
      final participants = json['participants'] as List;
      final otherUser = participants.firstWhere(
        (p) => p['id'] != currentUserId,
        orElse: () => null,
      );

      if (otherUser != null) {
        otherUserId = otherUser['id'];
        otherUserName =
            '${otherUser['first_name'] ?? ''} ${otherUser['last_name'] ?? ''}'
                .trim();
        otherUserAvatar = otherUser['avatar_url'];
      }
    }

    return LocalConversation(
      serverId: json['id'],
      type: type,
      name: json['name'],
      description: json['description'],
      avatarUrl: json['avatar_url'],
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      lastMessage: json['last_message']?['content'],
      lastMessageAt: json['last_message']?['created_at'] != null
          ? DateTime.parse(json['last_message']['created_at'])
          : null,
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'])
          : DateTime.now(),
      unreadCount: json['unread_count'] ?? 0,
      isOnline: json['is_online'] ?? false,
      participantsJson:
          json['participants'] != null ? json['participants'].toString() : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
