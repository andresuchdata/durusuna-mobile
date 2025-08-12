import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'attendance_models.g.dart';

enum AttendanceStatus {
  @JsonValue('present')
  present,
  @JsonValue('absent')
  absent,
  @JsonValue('late')
  late,
  @JsonValue('excused')
  excused,
}

enum AttendanceMarkedVia {
  @JsonValue('manual')
  manual,
  @JsonValue('gps')
  gps,
  @JsonValue('imported')
  imported,
}

@JsonSerializable()
class AttendanceRecord {
  final String id;
  @JsonKey(name: 'class_id')
  final String classId;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'attendance_date')
  final DateTime attendanceDate;
  final AttendanceStatus status;
  @JsonKey(name: 'check_in_time')
  final DateTime? checkInTime;
  final String? notes;
  @JsonKey(name: 'marked_by')
  final String? markedBy;
  @JsonKey(name: 'marked_via')
  final AttendanceMarkedVia markedVia;
  @JsonKey(name: 'student_latitude')
  final double? studentLatitude;
  @JsonKey(name: 'student_longitude')
  final double? studentLongitude;
  @JsonKey(name: 'location_verified')
  final bool locationVerified;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  AttendanceRecord({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.attendanceDate,
    required this.status,
    this.checkInTime,
    this.notes,
    this.markedBy,
    required this.markedVia,
    this.studentLatitude,
    this.studentLongitude,
    required this.locationVerified,
    required this.createdAt,
    this.updatedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      _$AttendanceRecordFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceRecordToJson(this);

  AttendanceRecord copyWith({
    String? id,
    String? classId,
    String? studentId,
    DateTime? attendanceDate,
    AttendanceStatus? status,
    DateTime? checkInTime,
    String? notes,
    String? markedBy,
    AttendanceMarkedVia? markedVia,
    double? studentLatitude,
    double? studentLongitude,
    bool? locationVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      studentId: studentId ?? this.studentId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      notes: notes ?? this.notes,
      markedBy: markedBy ?? this.markedBy,
      markedVia: markedVia ?? this.markedVia,
      studentLatitude: studentLatitude ?? this.studentLatitude,
      studentLongitude: studentLongitude ?? this.studentLongitude,
      locationVerified: locationVerified ?? this.locationVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@JsonSerializable()
class AttendanceRecordWithStudent {
  @JsonKey(name: 'id')
  final String id;
  @JsonKey(name: 'class_id')
  final String classId;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'attendance_date')
  final DateTime attendanceDate;
  final AttendanceStatus status;
  @JsonKey(name: 'check_in_time')
  final DateTime? checkInTime;
  final String? notes;
  @JsonKey(name: 'marked_by')
  final String? markedBy;
  @JsonKey(name: 'marked_via')
  final AttendanceMarkedVia markedVia;
  @JsonKey(name: 'student_latitude')
  final double? studentLatitude;
  @JsonKey(name: 'student_longitude')
  final double? studentLongitude;
  @JsonKey(name: 'location_verified')
  final bool locationVerified;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  final User student;

  AttendanceRecordWithStudent({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.attendanceDate,
    required this.status,
    this.checkInTime,
    this.notes,
    this.markedBy,
    required this.markedVia,
    this.studentLatitude,
    this.studentLongitude,
    required this.locationVerified,
    required this.createdAt,
    this.updatedAt,
    required this.student,
  });

  factory AttendanceRecordWithStudent.fromJson(Map<String, dynamic> json) =>
      _$AttendanceRecordWithStudentFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceRecordWithStudentToJson(this);
}

@JsonSerializable()
class AttendanceSession {
  final String id;
  @JsonKey(name: 'class_id')
  final String classId;
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  @JsonKey(name: 'session_date')
  final DateTime sessionDate;
  @JsonKey(name: 'opened_at')
  final DateTime openedAt;
  @JsonKey(name: 'closed_at')
  final DateTime? closedAt;
  @JsonKey(name: 'is_finalized')
  final bool isFinalized;
  final Map<String, dynamic> settings;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  AttendanceSession({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.sessionDate,
    required this.openedAt,
    this.closedAt,
    required this.isFinalized,
    required this.settings,
    required this.createdAt,
    this.updatedAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      _$AttendanceSessionFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceSessionToJson(this);
}

@JsonSerializable()
class SchoolAttendanceSettings {
  final String id;
  @JsonKey(name: 'school_id')
  final String schoolId;
  @JsonKey(name: 'require_location')
  final bool requireLocation;
  @JsonKey(name: 'school_latitude')
  final double? schoolLatitude;
  @JsonKey(name: 'school_longitude')
  final double? schoolLongitude;
  @JsonKey(name: 'location_radius_meters')
  final int locationRadiusMeters;
  @JsonKey(name: 'attendance_hours')
  final AttendanceHours attendanceHours;
  @JsonKey(name: 'allow_late_attendance')
  final bool allowLateAttendance;
  @JsonKey(name: 'late_threshold_minutes')
  final int lateThresholdMinutes;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  SchoolAttendanceSettings({
    required this.id,
    required this.schoolId,
    required this.requireLocation,
    this.schoolLatitude,
    this.schoolLongitude,
    required this.locationRadiusMeters,
    required this.attendanceHours,
    required this.allowLateAttendance,
    required this.lateThresholdMinutes,
    required this.createdAt,
    this.updatedAt,
  });

  factory SchoolAttendanceSettings.fromJson(Map<String, dynamic> json) =>
      _$SchoolAttendanceSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SchoolAttendanceSettingsToJson(this);
}

@JsonSerializable()
class AttendanceHours {
  final String start; // HH:MM format
  final String end;   // HH:MM format

  AttendanceHours({
    required this.start,
    required this.end,
  });

  factory AttendanceHours.fromJson(Map<String, dynamic> json) =>
      _$AttendanceHoursFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceHoursToJson(this);

  // Helper methods
  DateTime getStartTime(DateTime date) {
    final parts = start.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime getEndTime(DateTime date) {
    final parts = end.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}

@JsonSerializable()
class AttendanceStats {
  @JsonKey(name: 'total_students')
  final int totalStudents;
  final int present;
  final int absent;
  final int late;
  final int excused;
  @JsonKey(name: 'attendance_rate')
  final double attendanceRate;

  AttendanceStats({
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.attendanceRate,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) =>
      _$AttendanceStatsFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceStatsToJson(this);

  int get totalMarked => present + absent + late + excused;
  int get totalPresent => present + late + excused; // All except absent
}

@JsonSerializable()
class StudentAttendanceSummary {
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'student_name')
  final String studentName;
  @JsonKey(name: 'total_days')
  final int totalDays;
  @JsonKey(name: 'present_days')
  final int presentDays;
  @JsonKey(name: 'absent_days')
  final int absentDays;
  @JsonKey(name: 'late_days')
  final int lateDays;
  @JsonKey(name: 'excused_days')
  final int excusedDays;
  @JsonKey(name: 'attendance_rate')
  final double attendanceRate;

  StudentAttendanceSummary({
    required this.studentId,
    required this.studentName,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.excusedDays,
    required this.attendanceRate,
  });

  factory StudentAttendanceSummary.fromJson(Map<String, dynamic> json) =>
      _$StudentAttendanceSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$StudentAttendanceSummaryToJson(this);

  int get attendedDays => presentDays + lateDays + excusedDays;
}

@JsonSerializable()
class AttendanceReport {
  @JsonKey(name: 'class_id')
  final String classId;
  @JsonKey(name: 'class_name')
  final String className;
  @JsonKey(name: 'date_range')
  final DateRange dateRange;
  final AttendanceStats summary;
  final List<StudentAttendanceSummary> students;

  AttendanceReport({
    required this.classId,
    required this.className,
    required this.dateRange,
    required this.summary,
    required this.students,
  });

  factory AttendanceReport.fromJson(Map<String, dynamic> json) =>
      _$AttendanceReportFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceReportToJson(this);
}

@JsonSerializable()
class DateRange {
  @JsonKey(name: 'start_date')
  final String startDate;
  @JsonKey(name: 'end_date')
  final String endDate;

  DateRange({
    required this.startDate,
    required this.endDate,
  });

  factory DateRange.fromJson(Map<String, dynamic> json) =>
      _$DateRangeFromJson(json);
  Map<String, dynamic> toJson() => _$DateRangeToJson(this);
}

// Request models for API calls
@JsonSerializable()
class CreateAttendanceRequest {
  @JsonKey(name: 'student_id')
  final String studentId;
  final AttendanceStatus status;
  @JsonKey(name: 'check_in_time')
  final DateTime? checkInTime;
  final String? notes;
  @JsonKey(name: 'marked_via')
  final AttendanceMarkedVia? markedVia;
  @JsonKey(name: 'student_latitude')
  final double? studentLatitude;
  @JsonKey(name: 'student_longitude')
  final double? studentLongitude;

  CreateAttendanceRequest({
    required this.studentId,
    required this.status,
    this.checkInTime,
    this.notes,
    this.markedVia,
    this.studentLatitude,
    this.studentLongitude,
  });

  factory CreateAttendanceRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAttendanceRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateAttendanceRequestToJson(this);
}

@JsonSerializable()
class BulkAttendanceUpdate {
  final List<BulkAttendanceRecord> records;
  @JsonKey(name: 'marked_via')
  final AttendanceMarkedVia? markedVia;

  BulkAttendanceUpdate({
    required this.records,
    this.markedVia,
  });

  factory BulkAttendanceUpdate.fromJson(Map<String, dynamic> json) =>
      _$BulkAttendanceUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$BulkAttendanceUpdateToJson(this);
}

@JsonSerializable()
class BulkAttendanceRecord {
  @JsonKey(name: 'student_id')
  final String studentId;
  final AttendanceStatus status;
  final String? notes;

  BulkAttendanceRecord({
    required this.studentId,
    required this.status,
    this.notes,
  });

  factory BulkAttendanceRecord.fromJson(Map<String, dynamic> json) =>
      _$BulkAttendanceRecordFromJson(json);
  Map<String, dynamic> toJson() => _$BulkAttendanceRecordToJson(this);
}

@JsonSerializable()
class StudentAttendanceRequest {
  @JsonKey(name: 'class_id')
  final String classId;
  final double? latitude;
  final double? longitude;

  StudentAttendanceRequest({
    required this.classId,
    this.latitude,
    this.longitude,
  });

  factory StudentAttendanceRequest.fromJson(Map<String, dynamic> json) =>
      _$StudentAttendanceRequestFromJson(json);
  Map<String, dynamic> toJson() => _$StudentAttendanceRequestToJson(this);
}

// Response models for UI display
@JsonSerializable()
class AttendanceSessionResponse {
  final AttendanceSession session;
  final List<StudentWithAttendance> students;

  AttendanceSessionResponse({
    required this.session,
    required this.students,
  });

  factory AttendanceSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$AttendanceSessionResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceSessionResponseToJson(this);
}

@JsonSerializable()
class StudentWithAttendance {
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  final String email;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'student_id')
  final String? studentId;
  final AttendanceRecord? attendance;

  StudentWithAttendance({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
    this.studentId,
    this.attendance,
  });

  factory StudentWithAttendance.fromJson(Map<String, dynamic> json) =>
      _$StudentWithAttendanceFromJson(json);
  Map<String, dynamic> toJson() => _$StudentWithAttendanceToJson(this);

  String get displayName => '$firstName $lastName';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }
}
