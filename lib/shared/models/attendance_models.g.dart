// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttendanceRecord _$AttendanceRecordFromJson(Map<String, dynamic> json) =>
    AttendanceRecord(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      studentId: json['student_id'] as String,
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      status: $enumDecode(_$AttendanceStatusEnumMap, json['status']),
      checkInTime: json['check_in_time'] == null
          ? null
          : DateTime.parse(json['check_in_time'] as String),
      notes: json['notes'] as String?,
      markedBy: json['marked_by'] as String?,
      markedVia: $enumDecode(_$AttendanceMarkedViaEnumMap, json['marked_via']),
      studentLatitude: (json['student_latitude'] as num?)?.toDouble(),
      studentLongitude: (json['student_longitude'] as num?)?.toDouble(),
      locationVerified: json['location_verified'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AttendanceRecordToJson(AttendanceRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'class_id': instance.classId,
      'student_id': instance.studentId,
      'attendance_date': instance.attendanceDate.toIso8601String(),
      'status': _$AttendanceStatusEnumMap[instance.status]!,
      'check_in_time': instance.checkInTime?.toIso8601String(),
      'notes': instance.notes,
      'marked_by': instance.markedBy,
      'marked_via': _$AttendanceMarkedViaEnumMap[instance.markedVia]!,
      'student_latitude': instance.studentLatitude,
      'student_longitude': instance.studentLongitude,
      'location_verified': instance.locationVerified,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$AttendanceStatusEnumMap = {
  AttendanceStatus.present: 'present',
  AttendanceStatus.absent: 'absent',
  AttendanceStatus.late: 'late',
  AttendanceStatus.excused: 'excused',
};

const _$AttendanceMarkedViaEnumMap = {
  AttendanceMarkedVia.manual: 'manual',
  AttendanceMarkedVia.gps: 'gps',
  AttendanceMarkedVia.imported: 'imported',
};

AttendanceRecordWithStudent _$AttendanceRecordWithStudentFromJson(
        Map<String, dynamic> json) =>
    AttendanceRecordWithStudent(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      studentId: json['student_id'] as String,
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      status: $enumDecode(_$AttendanceStatusEnumMap, json['status']),
      checkInTime: json['check_in_time'] == null
          ? null
          : DateTime.parse(json['check_in_time'] as String),
      notes: json['notes'] as String?,
      markedBy: json['marked_by'] as String?,
      markedVia: $enumDecode(_$AttendanceMarkedViaEnumMap, json['marked_via']),
      studentLatitude: (json['student_latitude'] as num?)?.toDouble(),
      studentLongitude: (json['student_longitude'] as num?)?.toDouble(),
      locationVerified: json['location_verified'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      student: User.fromJson(json['student'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AttendanceRecordWithStudentToJson(
        AttendanceRecordWithStudent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'class_id': instance.classId,
      'student_id': instance.studentId,
      'attendance_date': instance.attendanceDate.toIso8601String(),
      'status': _$AttendanceStatusEnumMap[instance.status]!,
      'check_in_time': instance.checkInTime?.toIso8601String(),
      'notes': instance.notes,
      'marked_by': instance.markedBy,
      'marked_via': _$AttendanceMarkedViaEnumMap[instance.markedVia]!,
      'student_latitude': instance.studentLatitude,
      'student_longitude': instance.studentLongitude,
      'location_verified': instance.locationVerified,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'student': instance.student,
    };

AttendanceSession _$AttendanceSessionFromJson(Map<String, dynamic> json) =>
    AttendanceSession(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      teacherId: json['teacher_id'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      openedAt: DateTime.parse(json['opened_at'] as String),
      closedAt: json['closed_at'] == null
          ? null
          : DateTime.parse(json['closed_at'] as String),
      isFinalized: json['is_finalized'] as bool,
      settings: json['settings'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AttendanceSessionToJson(AttendanceSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'class_id': instance.classId,
      'teacher_id': instance.teacherId,
      'session_date': instance.sessionDate.toIso8601String(),
      'opened_at': instance.openedAt.toIso8601String(),
      'closed_at': instance.closedAt?.toIso8601String(),
      'is_finalized': instance.isFinalized,
      'settings': instance.settings,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

SchoolAttendanceSettings _$SchoolAttendanceSettingsFromJson(
        Map<String, dynamic> json) =>
    SchoolAttendanceSettings(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      requireLocation: json['require_location'] as bool,
      schoolLatitude: (json['school_latitude'] as num?)?.toDouble(),
      schoolLongitude: (json['school_longitude'] as num?)?.toDouble(),
      locationRadiusMeters: (json['location_radius_meters'] as num).toInt(),
      attendanceHours: AttendanceHours.fromJson(
          json['attendance_hours'] as Map<String, dynamic>),
      allowLateAttendance: json['allow_late_attendance'] as bool,
      lateThresholdMinutes: (json['late_threshold_minutes'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SchoolAttendanceSettingsToJson(
        SchoolAttendanceSettings instance) =>
    <String, dynamic>{
      'id': instance.id,
      'school_id': instance.schoolId,
      'require_location': instance.requireLocation,
      'school_latitude': instance.schoolLatitude,
      'school_longitude': instance.schoolLongitude,
      'location_radius_meters': instance.locationRadiusMeters,
      'attendance_hours': instance.attendanceHours,
      'allow_late_attendance': instance.allowLateAttendance,
      'late_threshold_minutes': instance.lateThresholdMinutes,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

AttendanceHours _$AttendanceHoursFromJson(Map<String, dynamic> json) =>
    AttendanceHours(
      start: json['start'] as String,
      end: json['end'] as String,
    );

Map<String, dynamic> _$AttendanceHoursToJson(AttendanceHours instance) =>
    <String, dynamic>{
      'start': instance.start,
      'end': instance.end,
    };

AttendanceStats _$AttendanceStatsFromJson(Map<String, dynamic> json) =>
    AttendanceStats(
      totalStudents: (json['total_students'] as num).toInt(),
      present: (json['present'] as num).toInt(),
      absent: (json['absent'] as num).toInt(),
      late: (json['late'] as num).toInt(),
      excused: (json['excused'] as num).toInt(),
      attendanceRate: (json['attendance_rate'] as num).toDouble(),
    );

Map<String, dynamic> _$AttendanceStatsToJson(AttendanceStats instance) =>
    <String, dynamic>{
      'total_students': instance.totalStudents,
      'present': instance.present,
      'absent': instance.absent,
      'late': instance.late,
      'excused': instance.excused,
      'attendance_rate': instance.attendanceRate,
    };

StudentAttendanceSummary _$StudentAttendanceSummaryFromJson(
        Map<String, dynamic> json) =>
    StudentAttendanceSummary(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      totalDays: (json['total_days'] as num).toInt(),
      presentDays: (json['present_days'] as num).toInt(),
      absentDays: (json['absent_days'] as num).toInt(),
      lateDays: (json['late_days'] as num).toInt(),
      excusedDays: (json['excused_days'] as num).toInt(),
      attendanceRate: (json['attendance_rate'] as num).toDouble(),
    );

Map<String, dynamic> _$StudentAttendanceSummaryToJson(
        StudentAttendanceSummary instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'student_name': instance.studentName,
      'total_days': instance.totalDays,
      'present_days': instance.presentDays,
      'absent_days': instance.absentDays,
      'late_days': instance.lateDays,
      'excused_days': instance.excusedDays,
      'attendance_rate': instance.attendanceRate,
    };

AttendanceReport _$AttendanceReportFromJson(Map<String, dynamic> json) =>
    AttendanceReport(
      classId: json['class_id'] as String,
      className: json['class_name'] as String,
      dateRange: DateRange.fromJson(json['date_range'] as Map<String, dynamic>),
      summary:
          AttendanceStats.fromJson(json['summary'] as Map<String, dynamic>),
      students: (json['students'] as List<dynamic>)
          .map((e) =>
              StudentAttendanceSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AttendanceReportToJson(AttendanceReport instance) =>
    <String, dynamic>{
      'class_id': instance.classId,
      'class_name': instance.className,
      'date_range': instance.dateRange,
      'summary': instance.summary,
      'students': instance.students,
    };

DateRange _$DateRangeFromJson(Map<String, dynamic> json) => DateRange(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
    );

Map<String, dynamic> _$DateRangeToJson(DateRange instance) => <String, dynamic>{
      'start_date': instance.startDate,
      'end_date': instance.endDate,
    };

CreateAttendanceRequest _$CreateAttendanceRequestFromJson(
        Map<String, dynamic> json) =>
    CreateAttendanceRequest(
      studentId: json['student_id'] as String,
      status: $enumDecode(_$AttendanceStatusEnumMap, json['status']),
      checkInTime: json['check_in_time'] == null
          ? null
          : DateTime.parse(json['check_in_time'] as String),
      notes: json['notes'] as String?,
      markedVia:
          $enumDecodeNullable(_$AttendanceMarkedViaEnumMap, json['marked_via']),
      studentLatitude: (json['student_latitude'] as num?)?.toDouble(),
      studentLongitude: (json['student_longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$CreateAttendanceRequestToJson(
        CreateAttendanceRequest instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'status': _$AttendanceStatusEnumMap[instance.status]!,
      'check_in_time': instance.checkInTime?.toIso8601String(),
      'notes': instance.notes,
      'marked_via': _$AttendanceMarkedViaEnumMap[instance.markedVia],
      'student_latitude': instance.studentLatitude,
      'student_longitude': instance.studentLongitude,
    };

BulkAttendanceUpdate _$BulkAttendanceUpdateFromJson(
        Map<String, dynamic> json) =>
    BulkAttendanceUpdate(
      records: (json['records'] as List<dynamic>)
          .map((e) => BulkAttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      markedVia:
          $enumDecodeNullable(_$AttendanceMarkedViaEnumMap, json['marked_via']),
    );

Map<String, dynamic> _$BulkAttendanceUpdateToJson(
        BulkAttendanceUpdate instance) =>
    <String, dynamic>{
      'records': instance.records,
      'marked_via': _$AttendanceMarkedViaEnumMap[instance.markedVia],
    };

BulkAttendanceRecord _$BulkAttendanceRecordFromJson(
        Map<String, dynamic> json) =>
    BulkAttendanceRecord(
      studentId: json['student_id'] as String,
      status: $enumDecode(_$AttendanceStatusEnumMap, json['status']),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$BulkAttendanceRecordToJson(
        BulkAttendanceRecord instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'status': _$AttendanceStatusEnumMap[instance.status]!,
      'notes': instance.notes,
    };

StudentAttendanceRequest _$StudentAttendanceRequestFromJson(
        Map<String, dynamic> json) =>
    StudentAttendanceRequest(
      classId: json['class_id'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$StudentAttendanceRequestToJson(
        StudentAttendanceRequest instance) =>
    <String, dynamic>{
      'class_id': instance.classId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

AttendanceSessionResponse _$AttendanceSessionResponseFromJson(
        Map<String, dynamic> json) =>
    AttendanceSessionResponse(
      session:
          AttendanceSession.fromJson(json['session'] as Map<String, dynamic>),
      students: (json['students'] as List<dynamic>)
          .map((e) => StudentWithAttendance.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AttendanceSessionResponseToJson(
        AttendanceSessionResponse instance) =>
    <String, dynamic>{
      'session': instance.session,
      'students': instance.students,
    };

StudentWithAttendance _$StudentWithAttendanceFromJson(
        Map<String, dynamic> json) =>
    StudentWithAttendance(
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      studentId: json['student_id'] as String?,
      attendance: json['attendance'] == null
          ? null
          : AttendanceRecord.fromJson(
              json['attendance'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StudentWithAttendanceToJson(
        StudentWithAttendance instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'email': instance.email,
      'avatar_url': instance.avatarUrl,
      'student_id': instance.studentId,
      'attendance': instance.attendance,
    };
