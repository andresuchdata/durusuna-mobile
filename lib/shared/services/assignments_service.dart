import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';
import '../models/assignment.dart';
import '../models/user.dart';

class AssignmentsService {
  static final String _baseUrl = ApiConstants.baseUrl;

  AssignmentsService();

  Future<Map<String, String>> _getHeaders() async {
    final token = StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get recent assignments across all user's classes (teachers only)
  Future<List<Assignment>> getRecentAssignments({int limit = 5}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl/assignments/recent')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignmentsJson = data['assignments'] ?? [];
        return assignmentsJson
            .map((json) => Assignment.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else {
        throw Exception(
            'Failed to fetch recent assignments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching recent assignments: $e');
      throw Exception('Error fetching recent assignments: $e');
    }
  }

  /// Get all assignments for a specific class
  Future<List<Assignment>> getClassAssignments(
    String classId, {
    int page = 1,
    int limit = 50,
    String? type,
    String status = 'all',
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'status': status,
      };
      if (type != null && type != 'all') {
        queryParams['type'] = type;
      }

      final uri =
          Uri.parse('$_baseUrl/assignments/classes/$classId/assignments')
              .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignmentsJson = data['assignments'] ?? [];
        return assignmentsJson
            .map((json) => Assignment.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class assignments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching class assignments: $e');
      throw Exception('Error fetching class assignments: $e');
    }
  }

  /// Get assignments for a specific subject within a class
  Future<List<Assignment>> getSubjectAssignments(
    String classId,
    String subjectId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse(
              '$_baseUrl/assignments/classes/$classId/subjects/$subjectId/assignments')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignmentsJson = data['assignments'] ?? [];
        return assignmentsJson
            .map((json) => Assignment.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this subject');
      } else if (response.statusCode == 404) {
        // No assignments found for this subject
        return [];
      } else {
        throw Exception(
            'Failed to fetch subject assignments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching subject assignments: $e');
      throw Exception('Error fetching subject assignments: $e');
    }
  }

  /// Get all assignments for the current user based on their role
  /// - Students: Get assignments from all their enrolled class offerings
  /// - Teachers: Get assignments from all their taught classes/subjects
  /// - Parents: Get assignments from all their children's classes
  Future<List<Assignment>> getUserAssignments({
    int page = 1,
    int limit = 50,
    String? type,
    String status = 'all',
    String? searchQuery,
    String? subjectId,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'status': status,
      };
      if (type != null && type != 'all') {
        queryParams['type'] = type;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }
      if (subjectId != null && subjectId.isNotEmpty) {
        queryParams['subject_id'] = subjectId;
      }

      final uri = Uri.parse('$_baseUrl/assignments/user/assignments')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignmentsJson = data['assignments'] ?? [];
        return assignmentsJson
            .map((json) => Assignment.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else {
        throw Exception(
            'Failed to fetch user assignments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching user assignments: $e');
      throw Exception('Error fetching user assignments: $e');
    }
  }

  /// Filter assignments by type locally
  List<Assignment> filterAssignmentsByType(
      List<Assignment> assignments, String filterType) {
    switch (filterType) {
      case 'all':
        return assignments;
      case 'due_soon':
        return assignments.where((a) => a.isDueSoon && !a.isOverdue).toList();
      case 'submitted':
        return assignments.where((a) => a.isSubmitted).toList();
      case 'graded':
        return assignments.where((a) => a.isGraded).toList();
      case 'overdue':
        return assignments.where((a) => a.isOverdue && !a.isSubmitted).toList();
      default:
        return assignments;
    }
  }

  /// Filter assignments by user role
  List<Assignment> filterAssignmentsByRole(
      List<Assignment> assignments, UserType userRole) {
    switch (userRole) {
      case UserType.student:
      case UserType.parent:
        // Students and parents only see published assignments
        return assignments.where((a) => a.isPublished).toList();
      case UserType.teacher:
        // Teachers see all assignments they have access to
        return assignments;
    }
  }

  /// Get accessible subjects for teachers
  Future<List<TeacherAccessibleSubject>> getTeacherAccessibleSubjects() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/assignments/teacher/accessible-subjects'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> subjectsJson = data['subjects'] ?? [];
        return subjectsJson
            .map((json) => TeacherAccessibleSubject.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Teachers only.');
      } else {
        throw Exception(
            'Failed to fetch accessible subjects: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching teacher accessible subjects: $e');
      throw Exception('Error fetching accessible subjects: $e');
    }
  }

  /// Get accessible classes for teachers
  Future<List<TeacherAccessibleClass>> getTeacherAccessibleClasses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/assignments/teacher/accessible-classes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> classesJson = data['classes'] ?? [];
        return classesJson
            .map((json) => TeacherAccessibleClass.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Teachers only.');
      } else {
        throw Exception(
            'Failed to fetch accessible classes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching teacher accessible classes: $e');
      throw Exception('Error fetching accessible classes: $e');
    }
  }
}

/// Model for teacher accessible subjects
class TeacherAccessibleSubject {
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final String? subjectDescription;
  final List<TeacherAccessibleClass> classes;

  const TeacherAccessibleSubject({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.subjectDescription,
    required this.classes,
  });

  factory TeacherAccessibleSubject.fromJson(Map<String, dynamic> json) {
    return TeacherAccessibleSubject(
      subjectId: json['subject_id'] ?? '',
      subjectName: json['subject_name'] ?? '',
      subjectCode: json['subject_code'],
      subjectDescription: json['subject_description'],
      classes: (json['classes'] as List<dynamic>? ?? [])
          .map((classJson) => TeacherAccessibleClass.fromJson(classJson))
          .toList(),
    );
  }
}

/// Model for teacher accessible classes
class TeacherAccessibleClass {
  final String classId;
  final String className;
  final String? gradeLevel;
  final String? classOfferingId;

  const TeacherAccessibleClass({
    required this.classId,
    required this.className,
    this.gradeLevel,
    this.classOfferingId,
  });

  factory TeacherAccessibleClass.fromJson(Map<String, dynamic> json) {
    return TeacherAccessibleClass(
      classId: json['class_id'] ?? '',
      className: json['class_name'] ?? '',
      gradeLevel: json['grade_level'],
      classOfferingId: json['class_offering_id'],
    );
  }
}

final assignmentsServiceProvider = Provider<AssignmentsService>((ref) {
  return AssignmentsService();
});
