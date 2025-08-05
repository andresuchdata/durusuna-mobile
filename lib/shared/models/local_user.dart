import 'package:isar/isar.dart';

part 'local_user.g.dart';

@collection
class LocalUser {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String serverId; // Server user ID

  @Index(caseSensitive: false)
  String firstName;

  @Index(caseSensitive: false)
  String lastName;

  @Index(unique: true, caseSensitive: false)
  String email;

  String? avatarUrl;
  String? phone;

  @Enumerated(EnumType.name)
  LocalUserType userType;

  String? schoolId;
  String? schoolName;

  // Contact info
  bool isContact;
  bool isBlocked;

  // Status
  bool isOnline;
  DateTime? lastSeen;

  DateTime createdAt;
  DateTime? updatedAt;

  LocalUser({
    required this.serverId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
    this.phone,
    required this.userType,
    this.schoolId,
    this.schoolName,
    this.isContact = false,
    this.isBlocked = false,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
    this.updatedAt,
  });

  // Helper getters
  String get displayName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  LocalUser copyWith({
    String? serverId,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarUrl,
    String? phone,
    LocalUserType? userType,
    String? schoolId,
    String? schoolName,
    bool? isContact,
    bool? isBlocked,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalUser(
      serverId: serverId ?? this.serverId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      isContact: isContact ?? this.isContact,
      isBlocked: isBlocked ?? this.isBlocked,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum LocalUserType {
  student,
  teacher,
  parent,
}

// Extension for API conversion
extension LocalUserExtension on LocalUser {
  static LocalUser fromApiJson(Map<String, dynamic> json) {
    return LocalUser(
      serverId: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      phone: json['phone'],
      userType: _parseUserType(json['user_type']),
      schoolId: json['school_id'],
      schoolName: json['school_name'],
      isContact: json['is_contact'] ?? false,
      isBlocked: json['is_blocked'] ?? false,
      isOnline: json['is_online'] ?? false,
      lastSeen:
          json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  static LocalUserType _parseUserType(dynamic type) {
    switch (type.toString().toLowerCase()) {
      case 'teacher':
        return LocalUserType.teacher;
      case 'parent':
        return LocalUserType.parent;
      default:
        return LocalUserType.student;
    }
  }
}
