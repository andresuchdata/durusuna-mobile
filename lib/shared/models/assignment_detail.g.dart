// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assignment_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentSubmission _$StudentSubmissionFromJson(Map<String, dynamic> json) =>
    StudentSubmission(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      studentNumber: json['student_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String,
      score: (json['score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num).toDouble(),
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String),
      gradedAt: json['graded_at'] == null
          ? null
          : DateTime.parse(json['graded_at'] as String),
      graderName: json['grader_name'] as String?,
      isLate: json['is_late'] as bool,
      daysLate: (json['days_late'] as num?)?.toInt(),
      feedback: json['feedback'] as String?,
      submissionAttachments: (json['submission_attachments'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );

Map<String, dynamic> _$StudentSubmissionToJson(StudentSubmission instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'student_name': instance.studentName,
      'student_number': instance.studentNumber,
      'avatar_url': instance.avatarUrl,
      'status': instance.status,
      'score': instance.score,
      'max_score': instance.maxScore,
      'submitted_at': instance.submittedAt?.toIso8601String(),
      'graded_at': instance.gradedAt?.toIso8601String(),
      'grader_name': instance.graderName,
      'is_late': instance.isLate,
      'days_late': instance.daysLate,
      'feedback': instance.feedback,
      'submission_attachments': instance.submissionAttachments,
    };

AssignmentStats _$AssignmentStatsFromJson(Map<String, dynamic> json) =>
    AssignmentStats(
      totalStudents: (json['total_students'] as num).toInt(),
      submittedCount: (json['submitted_count'] as num).toInt(),
      gradedCount: (json['graded_count'] as num).toInt(),
      averageScore: (json['average_score'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$AssignmentStatsToJson(AssignmentStats instance) =>
    <String, dynamic>{
      'total_students': instance.totalStudents,
      'submitted_count': instance.submittedCount,
      'graded_count': instance.gradedCount,
      'average_score': instance.averageScore,
    };

AssignmentDetail _$AssignmentDetailFromJson(Map<String, dynamic> json) =>
    AssignmentDetail(
      assignment:
          Assignment.fromJson(json['assignment'] as Map<String, dynamic>),
      attachments: (json['attachments'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      studentSubmissions: (json['student_submissions'] as List<dynamic>)
          .map((e) => StudentSubmission.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: AssignmentStats.fromJson(json['stats'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AssignmentDetailToJson(AssignmentDetail instance) =>
    <String, dynamic>{
      'assignment': instance.assignment,
      'attachments': instance.attachments,
      'student_submissions': instance.studentSubmissions,
      'stats': instance.stats,
    };
