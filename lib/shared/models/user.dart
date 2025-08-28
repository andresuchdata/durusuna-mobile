import 'package:json_annotation/json_annotation.dart';
import 'school.dart';

part 'user.g.dart';

enum UserType {
  @JsonValue('teacher')
  teacher,
  @JsonValue('student')
  student,
  @JsonValue('parent')
  parent,
}

enum UserRole {
  @JsonValue('admin')
  admin,
  @JsonValue('user')
  user,
}

@JsonSerializable()
class User {
  final String id;
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  final String email;
  final String? phone;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'user_type')
  final UserType userType;
  final UserRole? role;
  @JsonKey(name: 'school_id')
  final String? schoolId;
  @JsonKey(includeToJson: false, includeFromJson: true)
  final School? school;
  @JsonKey(name: 'is_active')
  final bool? isActive;
  @JsonKey(name: 'email_verified')
  final bool? emailVerified;
  @JsonKey(name: 'email_verified_at')
  final DateTime? emailVerifiedAt;
  @JsonKey(name: 'last_active_at')
  final DateTime? lastActiveAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.userType,
    this.role,
    this.schoolId,
    this.school,
    this.isActive,
    this.emailVerified,
    this.emailVerifiedAt,
    this.lastActiveAt,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  String get displayName => '$firstName $lastName';

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatarUrl,
    UserType? userType,
    UserRole? role,
    String? schoolId,
    School? school,
    bool? isActive,
    bool? emailVerified,
    DateTime? emailVerifiedAt,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userType: userType ?? this.userType,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      school: school ?? this.school,
      isActive: isActive ?? this.isActive,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
