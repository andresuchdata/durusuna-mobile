// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Assignment _$AssignmentFromJson(Map<String, dynamic> json) => Assignment(
      id: json['id'] as String,
      classOfferingId: json['class_offering_id'] as String,
      type: $enumDecode(_$AssignmentTypeEnumMap, json['type']),
      title: json['title'] as String,
      description: json['description'] as String?,
      maxScore: _intFromDynamic(json['max_score']),
      weightOverride: _doubleFromDynamicNullable(json['weight_override']),
      groupTag: json['group_tag'] as String?,
      sequenceNo: _intFromDynamicNullable(json['sequence_no']),
      assignedDate: json['assigned_date'] == null
          ? null
          : DateTime.parse(json['assigned_date'] as String),
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      rubric: json['rubric'] as Map<String, dynamic>?,
      instructions: json['instructions'] as Map<String, dynamic>?,
      isPublished: json['is_published'] as bool,
      allowLateSubmission: json['allow_late_submission'] as bool,
      latePenaltyPerDay:
          _doubleFromDynamicNullable(json['late_penalty_per_day']),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      subjectName: json['subject_name'] as String?,
      subjectCode: json['subject_code'] as String?,
      className: json['class_name'] as String?,
      creatorFirstName: json['creator_first_name'] as String?,
      creatorLastName: json['creator_last_name'] as String?,
      submittedCount: _intFromDynamicNullable(json['submitted_count']),
      totalStudents: _intFromDynamicNullable(json['total_students']),
      gradesCount: _intFromDynamicNullable(json['grades_count']),
      gradedCount: _intFromDynamicNullable(json['graded_count']),
      averageScore: _doubleFromDynamicNullable(json['average_score']),
      submissionStatus: $enumDecodeNullable(
          _$AssignmentStatusEnumMap, json['submission_status']),
      studentScore: _doubleFromDynamicNullable(json['student_score']),
      isLate: json['is_late'] as bool?,
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String),
      gradedAt: json['graded_at'] == null
          ? null
          : DateTime.parse(json['graded_at'] as String),
    );

Map<String, dynamic> _$AssignmentToJson(Assignment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'class_offering_id': instance.classOfferingId,
      'type': _$AssignmentTypeEnumMap[instance.type]!,
      'title': instance.title,
      'description': instance.description,
      'max_score': instance.maxScore,
      'weight_override': instance.weightOverride,
      'group_tag': instance.groupTag,
      'sequence_no': instance.sequenceNo,
      'assigned_date': instance.assignedDate?.toIso8601String(),
      'due_date': instance.dueDate?.toIso8601String(),
      'rubric': instance.rubric,
      'instructions': instance.instructions,
      'is_published': instance.isPublished,
      'allow_late_submission': instance.allowLateSubmission,
      'late_penalty_per_day': instance.latePenaltyPerDay,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'subject_name': instance.subjectName,
      'subject_code': instance.subjectCode,
      'class_name': instance.className,
      'creator_first_name': instance.creatorFirstName,
      'creator_last_name': instance.creatorLastName,
      'submitted_count': instance.submittedCount,
      'total_students': instance.totalStudents,
      'grades_count': instance.gradesCount,
      'graded_count': instance.gradedCount,
      'average_score': instance.averageScore,
      'submission_status': _$AssignmentStatusEnumMap[instance.submissionStatus],
      'student_score': instance.studentScore,
      'is_late': instance.isLate,
      'submitted_at': instance.submittedAt?.toIso8601String(),
      'graded_at': instance.gradedAt?.toIso8601String(),
    };

const _$AssignmentTypeEnumMap = {
  AssignmentType.assignment: 'assignment',
  AssignmentType.test: 'test',
  AssignmentType.finalExam: 'final_exam',
};

const _$AssignmentStatusEnumMap = {
  AssignmentStatus.notSubmitted: 'not_submitted',
  AssignmentStatus.submitted: 'submitted',
  AssignmentStatus.graded: 'graded',
  AssignmentStatus.returned: 'returned',
  AssignmentStatus.excused: 'excused',
};
