import 'package:json_annotation/json_annotation.dart';
import 'user.dart';
import 'message.dart';

part 'conversation.g.dart';

@JsonSerializable()
class LastMessage {
  final String? content;
  @JsonKey(name: 'message_type')
  final MessageType messageType;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'is_from_me')
  final bool? isFromMe;

  LastMessage({
    this.content,
    required this.messageType,
    required this.createdAt,
    this.isFromMe,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) =>
      _$LastMessageFromJson(json);
  Map<String, dynamic> toJson() => _$LastMessageToJson(this);

  String get displayContent {
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
        return '😊';
      default:
        return '';
    }
  }
}

@JsonSerializable()
class Conversation {
  final String id;
  final String type; // 'direct' or 'group'
  final String? name; // For group chats
  final String? description; // For group chats
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl; // For group chats
  @JsonKey(name: 'created_by')
  final String createdBy; // Who created the conversation
  @JsonKey(name: 'last_message_id')
  final String? lastMessageId;
  @JsonKey(name: 'last_message_at')
  final DateTime? lastMessageAt;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Extended fields (previously in ConversationWithDetails)
  final List<User> participants;
  @JsonKey(name: 'other_user')
  final User? otherUser; // For direct chats
  @JsonKey(name: 'last_message')
  final LastMessage? lastMessage; // Changed from Message to LastMessage
  @JsonKey(name: 'unread_count')
  final int unreadCount;
  @JsonKey(name: 'last_activity')
  final DateTime? lastActivity;
  @JsonKey(name: 'user_role')
  final String? userRole; // Current user's role in the conversation
  @JsonKey(name: 'is_online')
  final bool isOnline; // For direct chats - other user's online status

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.avatarUrl,
    required this.createdBy,
    this.lastMessageId,
    this.lastMessageAt,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.participants = const [],
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastActivity,
    this.userRole,
    this.isOnline = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  Conversation copyWith({
    String? id,
    String? type,
    String? name,
    String? description,
    String? avatarUrl,
    String? createdBy,
    String? lastMessageId,
    DateTime? lastMessageAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<User>? participants,
    User? otherUser,
    LastMessage? lastMessage,
    int? unreadCount,
    DateTime? lastActivity,
    String? userRole,
    bool? isOnline,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy ?? this.createdBy,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participants: participants ?? this.participants,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastActivity: lastActivity ?? this.lastActivity,
      userRole: userRole ?? this.userRole,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Conversation(id: $id, type: $type, name: $name)';
}

@JsonSerializable()
class ConversationParticipant {
  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'user_id')
  final String userId;
  final String role; // 'member' or 'admin'
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @JsonKey(name: 'left_at')
  final DateTime? leftAt;
  @JsonKey(name: 'last_read_at')
  final DateTime? lastReadAt;
  @JsonKey(name: 'unread_count')
  final int unreadCount;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'can_add_participants')
  final bool canAddParticipants;
  @JsonKey(name: 'can_remove_participants')
  final bool canRemoveParticipants;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  ConversationParticipant({
    required this.conversationId,
    required this.userId,
    this.role = 'member',
    DateTime? joinedAt,
    this.leftAt,
    this.lastReadAt,
    this.unreadCount = 0,
    this.isActive = true,
    this.canAddParticipants = false,
    this.canRemoveParticipants = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : joinedAt = joinedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      _$ConversationParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationParticipantToJson(this);

  ConversationParticipant copyWith({
    String? conversationId,
    String? userId,
    String? role,
    DateTime? joinedAt,
    DateTime? leftAt,
    DateTime? lastReadAt,
    int? unreadCount,
    bool? isActive,
    bool? canAddParticipants,
    bool? canRemoveParticipants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationParticipant(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isActive: isActive ?? this.isActive,
      canAddParticipants: canAddParticipants ?? this.canAddParticipants,
      canRemoveParticipants:
          canRemoveParticipants ?? this.canRemoveParticipants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationParticipant &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId &&
          userId == other.userId;

  @override
  int get hashCode => conversationId.hashCode ^ userId.hashCode;

  @override
  String toString() =>
      'ConversationParticipant(conversationId: $conversationId, userId: $userId, role: $role)';
}
