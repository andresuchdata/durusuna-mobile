import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/json_parsing_helpers.dart';

part 'assignment.g.dart';

enum AssignmentType {
  @JsonValue('assignment')
  assignment,
  @JsonValue('test')
  test,
  @JsonValue('final_exam')
  finalExam,
}

enum AssignmentStatus {
  @JsonValue('not_submitted')
  notSubmitted,
  @JsonValue('submitted')
  submitted,
  @JsonValue('graded')
  graded,
  @JsonValue('returned')
  returned,
  @JsonValue('excused')
  excused,
}

@JsonSerializable()
class Assignment {
  final String id;
  @JsonKey(name: 'class_offering_id')
  final String classOfferingId;
  final AssignmentType type;
  final String title;
  final String? description;
  @JsonKey(name: 'max_score', fromJson: intFromDynamic)
  final int maxScore;
  @JsonKey(name: 'weight_override', fromJson: doubleFromDynamicNullable)
  final double? weightOverride;
  @JsonKey(name: 'group_tag')
  final String? groupTag;
  @JsonKey(name: 'sequence_no', fromJson: intFromDynamicNullable)
  final int? sequenceNo;
  @JsonKey(name: 'assigned_date')
  final DateTime? assignedDate;
  @JsonKey(name: 'due_date')
  final DateTime? dueDate;
  final Map<String, dynamic>? rubric;
  final Map<String, dynamic>? instructions;
  @JsonKey(name: 'is_published')
  final bool isPublished;
  @JsonKey(name: 'allow_late_submission')
  final bool allowLateSubmission;
  @JsonKey(name: 'late_penalty_per_day', fromJson: doubleFromDynamicNullable)
  final double? latePenaltyPerDay;
  @JsonKey(name: 'created_by')
  final String createdBy;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Additional fields from API joins
  @JsonKey(name: 'subject_name')
  final String? subjectName;
  @JsonKey(name: 'subject_code')
  final String? subjectCode;
  @JsonKey(name: 'class_name')
  final String? className;
  @JsonKey(name: 'creator_first_name')
  final String? creatorFirstName;
  @JsonKey(name: 'creator_last_name')
  final String? creatorLastName;

  // Student-specific fields (when applicable)
  @JsonKey(name: 'submitted_count', fromJson: intFromDynamicNullable)
  final int? submittedCount;
  @JsonKey(name: 'total_students', fromJson: intFromDynamicNullable)
  final int? totalStudents;
  @JsonKey(name: 'grades_count', fromJson: intFromDynamicNullable)
  final int? gradesCount;
  @JsonKey(name: 'graded_count', fromJson: intFromDynamicNullable)
  final int? gradedCount;
  @JsonKey(name: 'average_score', fromJson: doubleFromDynamicNullable)
  final double? averageScore;

  // Student submission status (if user is a student)
  @JsonKey(name: 'submission_status')
  final AssignmentStatus? submissionStatus;
  @JsonKey(name: 'student_score', fromJson: doubleFromDynamicNullable)
  final double? studentScore;
  @JsonKey(name: 'is_late')
  final bool? isLate;
  @JsonKey(name: 'submitted_at')
  final DateTime? submittedAt;
  @JsonKey(name: 'graded_at')
  final DateTime? gradedAt;

  Assignment({
    required this.id,
    required this.classOfferingId,
    required this.type,
    required this.title,
    this.description,
    required this.maxScore,
    this.weightOverride,
    this.groupTag,
    this.sequenceNo,
    this.assignedDate,
    this.dueDate,
    this.rubric,
    this.instructions,
    required this.isPublished,
    required this.allowLateSubmission,
    this.latePenaltyPerDay,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.subjectName,
    this.subjectCode,
    this.className,
    this.creatorFirstName,
    this.creatorLastName,
    this.submittedCount,
    this.totalStudents,
    this.gradesCount,
    this.gradedCount,
    this.averageScore,
    this.submissionStatus,
    this.studentScore,
    this.isLate,
    this.submittedAt,
    this.gradedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) =>
      _$AssignmentFromJson(json);

  Map<String, dynamic> toJson() => _$AssignmentToJson(this);

  // Computed properties
  String get displayTitle {
    if (subjectName != null) {
      return '$subjectName - $title';
    }
    return title;
  }

  String get creatorName {
    if (creatorFirstName != null || creatorLastName != null) {
      return '${creatorFirstName ?? ''} ${creatorLastName ?? ''}'.trim();
    }
    return 'Unknown';
  }

  bool get isDueSoon {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    return difference >= 0 && difference <= 3;
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isSubmitted {
    return submissionStatus == AssignmentStatus.submitted ||
        submissionStatus == AssignmentStatus.graded ||
        submissionStatus == AssignmentStatus.returned;
  }

  bool get isGraded {
    return submissionStatus == AssignmentStatus.graded ||
        submissionStatus == AssignmentStatus.returned;
  }

  String get statusText {
    if (submissionStatus != null) {
      switch (submissionStatus!) {
        case AssignmentStatus.graded:
        case AssignmentStatus.returned:
          return 'Graded';
        case AssignmentStatus.submitted:
          return 'Submitted';
        case AssignmentStatus.excused:
          return 'Excused';
        case AssignmentStatus.notSubmitted:
          if (isOverdue) return 'Overdue';
          if (isDueSoon) return 'Due Soon';
          return 'Active';
      }
    }

    // Fallback for non-student users
    if (isOverdue) return 'Overdue';
    if (isDueSoon) return 'Due Soon';
    return 'Active';
  }

  Color get statusColor {
    if (submissionStatus != null) {
      switch (submissionStatus!) {
        case AssignmentStatus.graded:
        case AssignmentStatus.returned:
          return AppTheme.successColor;
        case AssignmentStatus.submitted:
          return AppTheme.infoColor;
        case AssignmentStatus.excused:
          return AppTheme.warningColor;
        case AssignmentStatus.notSubmitted:
          if (isOverdue) return AppTheme.errorColor;
          if (isDueSoon) return AppTheme.warningColor;
          return AppTheme.primaryColor;
      }
    }

    // Fallback for non-student users
    if (isOverdue) return AppTheme.errorColor;
    if (isDueSoon) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }

  String get typeDisplayName {
    switch (type) {
      case AssignmentType.assignment:
        return 'Assignment';
      case AssignmentType.test:
        return 'Test';
      case AssignmentType.finalExam:
        return 'Final Exam';
    }
  }

  Assignment copyWith({
    String? id,
    String? classOfferingId,
    AssignmentType? type,
    String? title,
    String? description,
    int? maxScore,
    double? weightOverride,
    String? groupTag,
    int? sequenceNo,
    DateTime? assignedDate,
    DateTime? dueDate,
    Map<String, dynamic>? rubric,
    Map<String, dynamic>? instructions,
    bool? isPublished,
    bool? allowLateSubmission,
    double? latePenaltyPerDay,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subjectName,
    String? subjectCode,
    String? className,
    String? creatorFirstName,
    String? creatorLastName,
    int? submittedCount,
    int? totalStudents,
    int? gradesCount,
    int? gradedCount,
    double? averageScore,
    AssignmentStatus? submissionStatus,
    double? studentScore,
    bool? isLate,
    DateTime? submittedAt,
    DateTime? gradedAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      classOfferingId: classOfferingId ?? this.classOfferingId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      maxScore: maxScore ?? this.maxScore,
      weightOverride: weightOverride ?? this.weightOverride,
      groupTag: groupTag ?? this.groupTag,
      sequenceNo: sequenceNo ?? this.sequenceNo,
      assignedDate: assignedDate ?? this.assignedDate,
      dueDate: dueDate ?? this.dueDate,
      rubric: rubric ?? this.rubric,
      instructions: instructions ?? this.instructions,
      isPublished: isPublished ?? this.isPublished,
      allowLateSubmission: allowLateSubmission ?? this.allowLateSubmission,
      latePenaltyPerDay: latePenaltyPerDay ?? this.latePenaltyPerDay,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subjectName: subjectName ?? this.subjectName,
      subjectCode: subjectCode ?? this.subjectCode,
      className: className ?? this.className,
      creatorFirstName: creatorFirstName ?? this.creatorFirstName,
      creatorLastName: creatorLastName ?? this.creatorLastName,
      submittedCount: submittedCount ?? this.submittedCount,
      totalStudents: totalStudents ?? this.totalStudents,
      gradesCount: gradesCount ?? this.gradesCount,
      gradedCount: gradedCount ?? this.gradedCount,
      averageScore: averageScore ?? this.averageScore,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      studentScore: studentScore ?? this.studentScore,
      isLate: isLate ?? this.isLate,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
    );
  }
}
