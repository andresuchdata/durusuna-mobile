// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassModel _$ClassModelFromJson(Map<String, dynamic> json) => ClassModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      gradeLevel: json['grade_level'] as String?,
      section: json['section'] as String?,
      academicYear: json['academic_year'] as String,
      settings: json['settings'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      teachers: (json['teachers'] as List<dynamic>?)
          ?.map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
      students: (json['students'] as List<dynamic>?)
          ?.map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
      studentsCount: (json['students_count'] as num?)?.toInt(),
      teachersCount: (json['teachers_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ClassModelToJson(ClassModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'school_id': instance.schoolId,
      'name': instance.name,
      'description': instance.description,
      'grade_level': instance.gradeLevel,
      'section': instance.section,
      'academic_year': instance.academicYear,
      'settings': instance.settings,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'teachers': instance.teachers,
      'students': instance.students,
      'students_count': instance.studentsCount,
      'teachers_count': instance.teachersCount,
    };
