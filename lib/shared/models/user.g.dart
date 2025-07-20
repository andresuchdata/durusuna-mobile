// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      userType: $enumDecode(_$UserTypeEnumMap, json['user_type']),
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      schoolId: json['school_id'] as String?,
      school: json['school'] == null
          ? null
          : School.fromJson(json['school'] as Map<String, dynamic>),
      isActive: json['is_active'] as bool,
      lastActiveAt: json['last_active_at'] == null
          ? null
          : DateTime.parse(json['last_active_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'email': instance.email,
      'phone': instance.phone,
      'avatar_url': instance.avatarUrl,
      'user_type': _$UserTypeEnumMap[instance.userType]!,
      'role': _$UserRoleEnumMap[instance.role]!,
      'school_id': instance.schoolId,
      'school': instance.school,
      'is_active': instance.isActive,
      'last_active_at': instance.lastActiveAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$UserTypeEnumMap = {
  UserType.teacher: 'teacher',
  UserType.student: 'student',
  UserType.parent: 'parent',
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.user: 'user',
};
