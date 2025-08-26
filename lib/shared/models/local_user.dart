import 'package:json_annotation/json_annotation.dart';

part 'local_user.g.dart';

/// Enum for user types
enum LocalUserType {
  student,
  teacher,
  admin,
  parent,
}

/// Extension to convert enum to string
extension LocalUserTypeExtension on LocalUserType {
  String get value {
    switch (this) {
      case LocalUserType.student:
        return 'student';
      case LocalUserType.teacher:
        return 'teacher';
      case LocalUserType.admin:
        return 'admin';
      case LocalUserType.parent:
        return 'parent';
    }
  }

  static LocalUserType fromString(String value) {
    switch (value) {
      case 'student':
        return LocalUserType.student;
      case 'teacher':
        return LocalUserType.teacher;
      case 'admin':
        return LocalUserType.admin;
      case 'parent':
        return LocalUserType.parent;
      default:
        return LocalUserType.student;
    }
  }
}

/// Local user model for SQLite storage
@JsonSerializable()
class LocalUser {
  final String serverId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final LocalUserType userType;
  final bool isOnline;
  final bool isVerified;
  final bool isBlocked;
  final DateTime? lastSeen;
  final String? status;
  final String? bio;
  final String? schoolName;
  final bool isContact;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? schoolId;

  const LocalUser({
    required this.serverId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.userType,
    this.isOnline = false,
    this.isVerified = false,
    this.isBlocked = false,
    this.lastSeen,
    this.status,
    this.bio,
    this.schoolName,
    this.isContact = false,
    required this.createdAt,
    this.updatedAt,
    this.schoolId,
  });

  factory LocalUser.fromJson(Map<String, dynamic> json) =>
      _$LocalUserFromJson(json);

  Map<String, dynamic> toJson() => _$LocalUserToJson(this);

  LocalUser copyWith({
    String? serverId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatarUrl,
    LocalUserType? userType,
    bool? isOnline,
    bool? isVerified,
    bool? isBlocked,
    DateTime? lastSeen,
    String? status,
    String? bio,
    String? schoolName,
    bool? isContact,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? schoolId,
  }) {
    return LocalUser(
      serverId: serverId ?? this.serverId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userType: userType ?? this.userType,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      bio: bio ?? this.bio,
      schoolName: schoolName ?? this.schoolName,
      isContact: isContact ?? this.isContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalUser &&
          runtimeType == other.runtimeType &&
          serverId == other.serverId;

  @override
  int get hashCode => serverId.hashCode;

  String get displayName => '$firstName $lastName';

  @override
  String toString() {
    return 'LocalUser{serverId: $serverId, firstName: $firstName, lastName: $lastName, userType: $userType, isOnline: $isOnline}';
  }
}

/// Extension for API JSON conversion
extension LocalUserExtension on LocalUser {
  static LocalUser fromApiJson(Map<String, dynamic> json) {
    return LocalUser(
      serverId: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      userType:
          LocalUserTypeExtension.fromString(json['user_type'] ?? 'student'),
      isOnline: json['is_online'] ?? false,
      isVerified: json['is_verified'] ?? false,
      isBlocked: json['is_blocked'] ?? false,
      lastSeen:
          json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      status: json['status'],
      bio: json['bio'],
      schoolName: json['school_name'],
      isContact: json['is_contact'] ?? false,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      schoolId: json['school_id'],
    );
  }
}
