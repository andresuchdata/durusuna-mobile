import 'package:json_annotation/json_annotation.dart';
import 'assignment.dart';

part 'assignment_detail.g.dart';

@JsonSerializable()
class StudentSubmission {
  @JsonKey(name: 'student_id')
  final String studentId;

  @JsonKey(name: 'student_name')
  final String studentName;

  @JsonKey(name: 'student_number')
  final String? studentNumber;

  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  final String status;
  final double? score;

  @JsonKey(name: 'max_score')
  final double maxScore;

  @JsonKey(name: 'submitted_at')
  final DateTime? submittedAt;

  @JsonKey(name: 'graded_at')
  final DateTime? gradedAt;

  @JsonKey(name: 'grader_name')
  final String? graderName;

  @JsonKey(name: 'is_late')
  final bool isLate;

  @JsonKey(name: 'days_late')
  final int? daysLate;

  final String? feedback;

  @JsonKey(name: 'submission_attachments')
  final List<Map<String, dynamic>> submissionAttachments;

  StudentSubmission({
    required this.studentId,
    required this.studentName,
    this.studentNumber,
    this.avatarUrl,
    required this.status,
    this.score,
    required this.maxScore,
    this.submittedAt,
    this.gradedAt,
    this.graderName,
    required this.isLate,
    this.daysLate,
    this.feedback,
    required this.submissionAttachments,
  });

  factory StudentSubmission.fromJson(Map<String, dynamic> json) =>
      _$StudentSubmissionFromJson(json);

  Map<String, dynamic> toJson() => _$StudentSubmissionToJson(this);

  String get statusDisplayText {
    switch (status) {
      case 'graded':
        return 'Graded';
      case 'submitted':
        return 'Submitted';
      case 'not_submitted':
        return 'Not Submitted';
      case 'returned':
        return 'Returned';
      case 'excused':
        return 'Excused';
      default:
        return 'Unknown';
    }
  }

  String get scoreDisplay {
    if (score != null) {
      return '${score!.toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}';
    }
    return '-';
  }

  bool get hasScore => score != null;
  bool get isSubmitted => ['submitted', 'graded', 'returned'].contains(status);
  bool get isGraded => ['graded', 'returned'].contains(status);
}

@JsonSerializable()
class AssignmentStats {
  @JsonKey(name: 'total_students')
  final int totalStudents;

  @JsonKey(name: 'submitted_count')
  final int submittedCount;

  @JsonKey(name: 'graded_count')
  final int gradedCount;

  @JsonKey(name: 'average_score')
  final double? averageScore;

  AssignmentStats({
    required this.totalStudents,
    required this.submittedCount,
    required this.gradedCount,
    this.averageScore,
  });

  factory AssignmentStats.fromJson(Map<String, dynamic> json) =>
      _$AssignmentStatsFromJson(json);

  Map<String, dynamic> toJson() => _$AssignmentStatsToJson(this);

  double get submissionRate =>
      totalStudents > 0 ? submittedCount / totalStudents : 0.0;
  double get gradingRate =>
      submittedCount > 0 ? gradedCount / submittedCount : 0.0;
}

@JsonSerializable()
class AssignmentDetail {
  final Assignment assignment;
  final List<Map<String, dynamic>> attachments;

  @JsonKey(name: 'student_submissions')
  final List<StudentSubmission> studentSubmissions;

  final AssignmentStats stats;

  AssignmentDetail({
    required this.assignment,
    required this.attachments,
    required this.studentSubmissions,
    required this.stats,
  });

  factory AssignmentDetail.fromJson(Map<String, dynamic> json) =>
      _$AssignmentDetailFromJson(json);

  Map<String, dynamic> toJson() => _$AssignmentDetailToJson(this);
}
