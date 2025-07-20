import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'class_model.g.dart';

@JsonSerializable()
class ClassModel {
  final String id;
  @JsonKey(name: 'school_id')
  final String schoolId;
  final String name;
  final String? description;
  @JsonKey(name: 'grade_level')
  final String? gradeLevel;
  final String? section;
  @JsonKey(name: 'academic_year')
  final String academicYear;
  final Map<String, dynamic>? settings;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  
  // Related data (not from database directly)
  final List<User>? teachers;
  final List<User>? students;
  @JsonKey(name: 'students_count')
  final int? studentsCount;
  @JsonKey(name: 'teachers_count')
  final int? teachersCount;

  ClassModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.description,
    this.gradeLevel,
    this.section,
    required this.academicYear,
    this.settings,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.teachers,
    this.students,
    this.studentsCount,
    this.teachersCount,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) => _$ClassModelFromJson(json);
  Map<String, dynamic> toJson() => _$ClassModelToJson(this);

  String get displayName {
    if (gradeLevel != null && section != null) {
      return '$gradeLevel - $section';
    } else if (gradeLevel != null) {
      return gradeLevel!;
    }
    return name;
  }

  String get fullDisplayName {
    if (gradeLevel != null && section != null) {
      return '$name ($gradeLevel - $section)';
    }
    return name;
  }

  ClassModel copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? description,
    String? gradeLevel,
    String? section,
    String? academicYear,
    Map<String, dynamic>? settings,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<User>? teachers,
    List<User>? students,
    int? studentsCount,
    int? teachersCount,
  }) {
    return ClassModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      description: description ?? this.description,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      academicYear: academicYear ?? this.academicYear,
      settings: settings ?? this.settings,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      teachers: teachers ?? this.teachers,
      students: students ?? this.students,
      studentsCount: studentsCount ?? this.studentsCount,
      teachersCount: teachersCount ?? this.teachersCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ClassModel(id: $id, name: $name, displayName: $displayName)';
} 