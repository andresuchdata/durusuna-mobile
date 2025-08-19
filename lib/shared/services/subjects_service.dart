import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';
import 'class_management_service.dart';

class SubjectsService {
  static final String _baseUrl = ApiConstants.baseUrl;
  final ClassManagementService _classService = ClassManagementService();

  Future<Map<String, String>> _getHeaders() async {
    final token = StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get all subjects/offerings for the current user across all their classes
  Future<List<SubjectOffering>> getUserSubjects() async {
    try {
      // Get user's classes
      final classes = await _classService.getUserClasses();

      List<SubjectOffering> allOfferings = [];

      // For each class, get its offerings
      for (final classModel in classes) {
        try {
          final classOfferings =
              await _classService.getClassOfferings(classModel.id);

          // Convert to SubjectOffering objects with assignments
          for (final offering in classOfferings) {
            try {
              // Get assignments for this offering
              final assignments = await _getOfferingAssignments(
                  classModel.id, offering['subject_id'] ?? '');

              final subjectOffering = SubjectOffering(
                id: offering['class_offering_id'] ?? offering['id'] ?? '',
                subjectId: offering['subject_id'] ?? '',
                subjectName: offering['subject_name'] ?? 'Unknown Subject',
                subjectCode: offering['subject_code'] ?? '',
                subjectDescription: offering['subject_description'] ?? '',
                classId: classModel.id,
                className: classModel.name,
                gradeLevel: classModel.gradeLevel ?? '',
                hoursPerWeek: offering['hours_per_week'] ?? 0,
                room: offering['room'] ?? '',
                schedule: offering['schedule'] ?? {},
                teacherId: offering['teacher_id'],
                teacherName: _getTeacherName(offering),
                teacherEmail: offering['email'],
                teacherAvatarUrl: offering['avatar_url'],
                assignments: assignments,
                studentCount: classModel.studentsCount ?? 0,
                assignmentsCount: assignments.length,
                pendingGrades: _countPendingGrades(assignments),
                color: _getSubjectColor(offering['subject_name'] ?? ''),
              );

              allOfferings.add(subjectOffering);
            } catch (e) {
              debugPrint(
                  'Error fetching assignments for offering ${offering['id']}: $e');
              // Continue with offering but without assignments
              final subjectOffering = SubjectOffering(
                id: offering['class_offering_id'] ?? offering['id'] ?? '',
                subjectId: offering['subject_id'] ?? '',
                subjectName: offering['subject_name'] ?? 'Unknown Subject',
                subjectCode: offering['subject_code'] ?? '',
                subjectDescription: offering['subject_description'] ?? '',
                classId: classModel.id,
                className: classModel.name,
                gradeLevel: classModel.gradeLevel ?? '',
                hoursPerWeek: offering['hours_per_week'] ?? 0,
                room: offering['room'] ?? '',
                schedule: offering['schedule'] ?? {},
                teacherId: offering['teacher_id'],
                teacherName: _getTeacherName(offering),
                teacherEmail: offering['email'],
                teacherAvatarUrl: offering['avatar_url'],
                assignments: [],
                studentCount: classModel.studentsCount ?? 0,
                assignmentsCount: 0,
                pendingGrades: 0,
                color: _getSubjectColor(offering['subject_name'] ?? ''),
              );

              allOfferings.add(subjectOffering);
            }
          }
        } catch (e) {
          debugPrint('Error fetching offerings for class ${classModel.id}: $e');
        }
      }

      return _sortSubjectOfferings(allOfferings);
    } catch (e) {
      throw Exception('Error fetching user subjects: $e');
    }
  }

  /// Get all subject offerings for admin users
  Future<List<SubjectOffering>> getAllSubjectOfferingsForAdmin() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/class-offerings/all'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> offeringsJson = data['offerings'] ?? [];

        List<SubjectOffering> allOfferings = [];

        for (final offering in offeringsJson) {
          try {
            // Get assignments for this offering
            final assignments = await _getOfferingAssignments(
                offering['class_id'] ?? '', offering['subject_id'] ?? '');

            final subjectOffering = SubjectOffering(
              id: offering['id'] ?? '',
              subjectId: offering['subject_id'] ?? '',
              subjectName: offering['subject_name'] ?? 'Unknown Subject',
              subjectCode: offering['subject_code'] ?? '',
              subjectDescription: offering['subject_description'] ?? '',
              classId: offering['class_id'] ?? '',
              className: offering['class_name'] ?? '',
              gradeLevel: offering['grade_level'] ?? '',
              hoursPerWeek: offering['hours_per_week'] ?? 0,
              room: offering['room'] ?? '',
              schedule: offering['schedule'] ?? {},
              teacherId: offering['primary_teacher_id'],
              teacherName: _getTeacherNameFromOffering(offering),
              teacherEmail: offering['teacher_email'],
              teacherAvatarUrl: offering['teacher_avatar_url'],
              assignments: assignments,
              studentCount: offering['enrollment_count'] ?? 0,
              assignmentsCount: assignments.length,
              pendingGrades: _countPendingGrades(assignments),
              color: _getSubjectColor(offering['subject_name'] ?? ''),
            );

            allOfferings.add(subjectOffering);
          } catch (e) {
            debugPrint('Error processing offering ${offering['id']}: $e');
            // Continue with offering but without assignments
            final subjectOffering = SubjectOffering(
              id: offering['id'] ?? '',
              subjectId: offering['subject_id'] ?? '',
              subjectName: offering['subject_name'] ?? 'Unknown Subject',
              subjectCode: offering['subject_code'] ?? '',
              subjectDescription: offering['subject_description'] ?? '',
              classId: offering['class_id'] ?? '',
              className: offering['class_name'] ?? '',
              gradeLevel: offering['grade_level'] ?? '',
              hoursPerWeek: offering['hours_per_week'] ?? 0,
              room: offering['room'] ?? '',
              schedule: offering['schedule'] ?? {},
              teacherId: offering['primary_teacher_id'],
              teacherName: _getTeacherNameFromOffering(offering),
              teacherEmail: offering['teacher_email'],
              teacherAvatarUrl: offering['teacher_avatar_url'],
              assignments: [],
              studentCount: offering['enrollment_count'] ?? 0,
              assignmentsCount: 0,
              pendingGrades: 0,
              color: _getSubjectColor(offering['subject_name'] ?? ''),
            );

            allOfferings.add(subjectOffering);
          }
        }

        return _sortSubjectOfferings(allOfferings);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        throw Exception(
            'Failed to fetch subject offerings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching all subject offerings: $e');
    }
  }

  /// Get subject offerings for student users (based on their enrollments)
  Future<List<SubjectOffering>> getStudentSubjectOfferings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/enrollments/my-offerings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> offeringsJson = data['offerings'] ?? [];

        List<SubjectOffering> allOfferings = [];

        for (final offering in offeringsJson) {
          try {
            // Get assignments for this offering
            final assignments = await _getOfferingAssignments(
                offering['class_id'] ?? '', offering['subject_id'] ?? '');

            final subjectOffering = SubjectOffering(
              id: offering['class_offering_id'] ?? offering['id'] ?? '',
              subjectId: offering['subject_id'] ?? '',
              subjectName: offering['subject_name'] ?? 'Unknown Subject',
              subjectCode: offering['subject_code'] ?? '',
              subjectDescription: offering['subject_description'] ?? '',
              classId: offering['class_id'] ?? '',
              className: offering['class_name'] ?? '',
              gradeLevel: offering['grade_level'] ?? '',
              hoursPerWeek: offering['hours_per_week'] ?? 0,
              room: offering['room'] ?? '',
              schedule: offering['schedule'] ?? {},
              teacherId: offering['primary_teacher_id'],
              teacherName: _getTeacherNameFromOffering(offering),
              teacherEmail: offering['teacher_email'],
              teacherAvatarUrl: offering['teacher_avatar_url'],
              assignments: assignments,
              studentCount: offering['enrollment_count'] ?? 0,
              assignmentsCount: assignments.length,
              pendingGrades: _countPendingGrades(assignments),
              color: _getSubjectColor(offering['subject_name'] ?? ''),
            );

            allOfferings.add(subjectOffering);
          } catch (e) {
            debugPrint(
                'Error processing student offering ${offering['id']}: $e');
            // Continue with offering but without assignments
            final subjectOffering = SubjectOffering(
              id: offering['class_offering_id'] ?? offering['id'] ?? '',
              subjectId: offering['subject_id'] ?? '',
              subjectName: offering['subject_name'] ?? 'Unknown Subject',
              subjectCode: offering['subject_code'] ?? '',
              subjectDescription: offering['subject_description'] ?? '',
              classId: offering['class_id'] ?? '',
              className: offering['class_name'] ?? '',
              gradeLevel: offering['grade_level'] ?? '',
              hoursPerWeek: offering['hours_per_week'] ?? 0,
              room: offering['room'] ?? '',
              schedule: offering['schedule'] ?? {},
              teacherId: offering['primary_teacher_id'],
              teacherName: _getTeacherNameFromOffering(offering),
              teacherEmail: offering['teacher_email'],
              teacherAvatarUrl: offering['teacher_avatar_url'],
              assignments: [],
              studentCount: offering['enrollment_count'] ?? 0,
              assignmentsCount: 0,
              pendingGrades: 0,
              color: _getSubjectColor(offering['subject_name'] ?? ''),
            );

            allOfferings.add(subjectOffering);
          }
        }

        return _sortSubjectOfferings(allOfferings);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        throw Exception(
            'Failed to fetch student subject offerings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching student subject offerings: $e');
    }
  }

  /// Get subject offerings for parent users (based on their children's enrollments)
  Future<List<SubjectOffering>> getParentSubjectOfferings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/enrollments/children-offerings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> offeringsJson = data['offerings'] ?? [];

        List<SubjectOffering> allOfferings = [];

        for (final offering in offeringsJson) {
          try {
            // Get assignments for this offering
            final assignments = await _getOfferingAssignments(
                offering['class_id'] ?? '', offering['subject_id'] ?? '');

            final subjectOffering = SubjectOffering(
              id: offering['class_offering_id'] ?? offering['id'] ?? '',
              subjectId: offering['subject_id'] ?? '',
              subjectName: offering['subject_name'] ?? 'Unknown Subject',
              subjectCode: offering['subject_code'] ?? '',
              subjectDescription: offering['subject_description'] ?? '',
              classId: offering['class_id'] ?? '',
              className: offering['class_name'] ?? '',
              gradeLevel: offering['grade_level'] ?? '',
              hoursPerWeek: offering['hours_per_week'] ?? 0,
              room: offering['room'] ?? '',
              schedule: offering['schedule'] ?? {},
              teacherId: offering['primary_teacher_id'],
              teacherName: _getTeacherNameFromOffering(offering),
              teacherEmail: offering['teacher_email'],
              teacherAvatarUrl: offering['teacher_avatar_url'],
              assignments: assignments,
              studentCount: offering['enrollment_count'] ?? 0,
              assignmentsCount: assignments.length,
              pendingGrades: _countPendingGrades(assignments),
              color: _getSubjectColor(offering['subject_name'] ?? ''),
            );

            allOfferings.add(subjectOffering);
          } catch (e) {
            debugPrint(
                'Error processing parent offering ${offering['id']}: $e');
            // Continue with offering but without assignments
            final subjectOffering = SubjectOffering(
              id: offering['class_offering_id'] ?? offering['id'] ?? '',
              subjectId: offering['subject_id'] ?? '',
              subjectName: offering['subject_name'] ?? 'Unknown Subject',
              subjectCode: offering['subject_code'] ?? '',
              subjectDescription: offering['subject_description'] ?? '',
              classId: offering['class_id'] ?? '',
              className: offering['class_name'] ?? '',
              gradeLevel: offering['grade_level'] ?? '',
              hoursPerWeek: offering['hours_per_week'] ?? 0,
              room: offering['room'] ?? '',
              schedule: offering['schedule'] ?? {},
              teacherId: offering['primary_teacher_id'],
              teacherName: _getTeacherNameFromOffering(offering),
              teacherEmail: offering['teacher_email'],
              teacherAvatarUrl: offering['teacher_avatar_url'],
              assignments: [],
              studentCount: offering['enrollment_count'] ?? 0,
              assignmentsCount: 0,
              pendingGrades: 0,
              color: _getSubjectColor(offering['subject_name'] ?? ''),
            );

            allOfferings.add(subjectOffering);
          }
        }

        return _sortSubjectOfferings(allOfferings);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        throw Exception(
            'Failed to fetch parent subject offerings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching parent subject offerings: $e');
    }
  }

  /// Get assignments for a specific class offering
  Future<List<Map<String, dynamic>>> _getOfferingAssignments(
      String classId, String subjectId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/assignments/classes/$classId/subjects/$subjectId/assignments'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignmentsJson = data['assignments'] ?? [];
        return assignmentsJson.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        // No assignments found for this offering
        return [];
      } else {
        debugPrint(
            'Failed to fetch assignments for class $classId subject $subjectId: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint(
          'Error fetching assignments for class $classId subject $subjectId: $e');
      return [];
    }
  }

  /// Get statistics for user's subjects
  Future<SubjectStats> getUserSubjectStats() async {
    try {
      final subjects = await getUserSubjects();

      final activeSubjects = subjects.length;
      final totalStudents =
          subjects.fold(0, (sum, subject) => sum + subject.studentCount);
      final pendingTasks =
          subjects.fold(0, (sum, subject) => sum + subject.pendingGrades);

      return SubjectStats(
        activeSubjects: activeSubjects,
        totalStudents: totalStudents,
        pendingTasks: pendingTasks,
      );
    } catch (e) {
      throw Exception('Error fetching subject stats: $e');
    }
  }

  String _getTeacherName(Map<String, dynamic> offering) {
    final firstName = offering['first_name'] ?? '';
    final lastName = offering['last_name'] ?? '';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return 'Unassigned';
  }

  int _countPendingGrades(List<Map<String, dynamic>> assignments) {
    // Count assignments that are published but might have ungraded submissions
    return assignments
        .where((assignment) =>
            assignment['is_published'] == true && assignment['type'] != 'draft')
        .length;
  }

  /// Generate color for subject based on name
  Map<String, dynamic> _getSubjectColor(String subjectName) {
    final colors = {
      'Mathematics': {'primary': 0xFF2196F3, 'secondary': 0xFFE3F2FD},
      'Math': {'primary': 0xFF2196F3, 'secondary': 0xFFE3F2FD},
      'English': {'primary': 0xFF4CAF50, 'secondary': 0xFFE8F5E8},
      'Literature': {'primary': 0xFF4CAF50, 'secondary': 0xFFE8F5E8},
      'Science': {'primary': 0xFF9C27B0, 'secondary': 0xFFF3E5F5},
      'Physics': {'primary': 0xFF9C27B0, 'secondary': 0xFFF3E5F5},
      'Chemistry': {'primary': 0xFF9C27B0, 'secondary': 0xFFF3E5F5},
      'Biology': {'primary': 0xFF4CAF50, 'secondary': 0xFFE8F5E8},
      'Islamic': {'primary': 0xFF009688, 'secondary': 0xFFE0F2F1},
      'Islam': {'primary': 0xFF009688, 'secondary': 0xFFE0F2F1},
      'Arabic': {'primary': 0xFFFF9800, 'secondary': 0xFFFFF3E0},
      'History': {'primary': 0xFF795548, 'secondary': 0xFFEFEBE9},
      'Geography': {'primary': 0xFF607D8B, 'secondary': 0xFFECEFF1},
    };

    for (final key in colors.keys) {
      if (subjectName.toLowerCase().contains(key.toLowerCase())) {
        return colors[key]!;
      }
    }

    // Default color
    return {'primary': 0xFF757575, 'secondary': 0xFFF5F5F5};
  }

  /// Helper method to get teacher name from offering data
  String _getTeacherNameFromOffering(Map<String, dynamic> offering) {
    final firstName =
        offering['teacher_first_name'] ?? offering['first_name'] ?? '';
    final lastName =
        offering['teacher_last_name'] ?? offering['last_name'] ?? '';
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }
    return 'Unknown Teacher';
  }

  /// Sort subject offerings by name, then by active status, then by creation date/academic year
  List<SubjectOffering> _sortSubjectOfferings(List<SubjectOffering> offerings) {
    offerings.sort((a, b) {
      // First sort by subject name
      int nameComparison =
          a.subjectName.toLowerCase().compareTo(b.subjectName.toLowerCase());
      if (nameComparison != 0) return nameComparison;

      // Then by class name (for subjects with same name in different classes)
      int classComparison =
          a.className.toLowerCase().compareTo(b.className.toLowerCase());
      if (classComparison != 0) return classComparison;

      // Finally by grade level to group by academic progression
      return a.gradeLevel.compareTo(b.gradeLevel);
    });

    return offerings;
  }
}

// Data models
class SubjectOffering {
  final String id;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String subjectDescription;
  final String classId;
  final String className;
  final String gradeLevel;
  final int hoursPerWeek;
  final String room;
  final Map<String, dynamic> schedule;
  final String? teacherId;
  final String teacherName;
  final String? teacherEmail;
  final String? teacherAvatarUrl;
  final List<Map<String, dynamic>> assignments;
  final int studentCount;
  final int assignmentsCount;
  final int pendingGrades;
  final Map<String, dynamic> color;

  SubjectOffering({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectDescription,
    required this.classId,
    required this.className,
    required this.gradeLevel,
    required this.hoursPerWeek,
    required this.room,
    required this.schedule,
    this.teacherId,
    required this.teacherName,
    this.teacherEmail,
    this.teacherAvatarUrl,
    required this.assignments,
    required this.studentCount,
    required this.assignmentsCount,
    required this.pendingGrades,
    required this.color,
  });
}

class SubjectStats {
  final int activeSubjects;
  final int totalStudents;
  final int pendingTasks;

  SubjectStats({
    required this.activeSubjects,
    required this.totalStudents,
    required this.pendingTasks,
  });
}
