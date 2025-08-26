// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalUser _$LocalUserFromJson(Map<String, dynamic> json) => LocalUser(
      serverId: json['serverId'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      userType: $enumDecode(_$LocalUserTypeEnumMap, json['userType']),
      isOnline: json['isOnline'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      isBlocked: json['isBlocked'] as bool? ?? false,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      status: json['status'] as String?,
      bio: json['bio'] as String?,
      schoolName: json['schoolName'] as String?,
      isContact: json['isContact'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      schoolId: json['schoolId'] as String?,
    );

Map<String, dynamic> _$LocalUserToJson(LocalUser instance) => <String, dynamic>{
      'serverId': instance.serverId,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
      'phone': instance.phone,
      'avatarUrl': instance.avatarUrl,
      'userType': _$LocalUserTypeEnumMap[instance.userType]!,
      'isOnline': instance.isOnline,
      'isVerified': instance.isVerified,
      'isBlocked': instance.isBlocked,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'status': instance.status,
      'bio': instance.bio,
      'schoolName': instance.schoolName,
      'isContact': instance.isContact,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'schoolId': instance.schoolId,
    };

const _$LocalUserTypeEnumMap = {
  LocalUserType.student: 'student',
  LocalUserType.teacher: 'teacher',
  LocalUserType.admin: 'admin',
  LocalUserType.parent: 'parent',
};
