import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/class_model.dart';
import '../models/user.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';

class ClassManagementService {
  static final String _baseUrl = ApiConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get classes that the current user is enrolled in
  Future<List<ClassModel>> getUserClasses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/my-classes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> classesJson = data['classes'] ?? [];

        return classesJson.map((json) => ClassModel.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to fetch user classes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user classes: $e');
    }
  }

  /// Get detailed information about a specific class
  Future<ClassModel> getClassDetails(String classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/$classId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ClassModel.fromJson(data['class'] ?? data);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else if (response.statusCode == 404) {
        throw Exception('Class not found');
      } else {
        throw Exception(
            'Failed to fetch class details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class details: $e');
    }
  }

  /// Get students in a specific class (legacy method for backward compatibility)
  Future<List<User>> getClassStudents(String classId, {String? search}) async {
    final response = await getClassStudentsPaginated(classId,
        page: 1, limit: 100, search: search);
    return response.students;
  }

  /// Get students in a specific class with pagination
  Future<ClassStudentsResponse> getClassStudentsPaginated(String classId,
      {int page = 1, int limit = 20, String? search}) async {
    try {
      final headers = await _getHeaders();

      var url = '$_baseUrl/classes/$classId/students?page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> studentsJson = data['students'] ?? [];
        final Map<String, dynamic> paginationJson = data['pagination'] ?? {};

        return ClassStudentsResponse(
          students: studentsJson.map((json) => User.fromJson(json)).toList(),
          pagination: PaginationInfo.fromJson(paginationJson),
        );
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class students: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class students: $e');
    }
  }

  /// Get class counts (student count, teacher count, etc.)
  Future<ClassCounts> getClassCounts(String classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/$classId/counts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ClassCounts.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception('Failed to fetch class counts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class counts: $e');
    }
  }

  /// Get teachers in a specific class (legacy method for backward compatibility)
  Future<List<User>> getClassTeachers(String classId) async {
    final response =
        await getClassTeachersPaginated(classId, page: 1, limit: 100);
    return response.teachers;
  }

  /// Get teachers in a specific class with pagination
  Future<ClassTeachersResponse> getClassTeachersPaginated(String classId,
      {int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/classes/$classId/teachers?page=$page&limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> teachersJson = data['teachers'] ?? [];
        final Map<String, dynamic> paginationJson = data['pagination'] ?? {};

        return ClassTeachersResponse(
          teachers: teachersJson.map((json) => User.fromJson(json)).toList(),
          pagination: PaginationInfo.fromJson(paginationJson),
        );
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class teachers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class teachers: $e');
    }
  }

  /// Get lessons for a specific class
  Future<List<Map<String, dynamic>>> getClassLessons(String classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/$classId/lessons'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> lessonsJson = data['lessons'] ?? [];

        return lessonsJson.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class lessons: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class lessons: $e');
    }
  }

  /// Get subjects for a specific class with their lessons
  Future<List<Map<String, dynamic>>> getClassSubjects(String classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/$classId/subjects'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> subjectsJson = data['subjects'] ?? [];

        return subjectsJson.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class subjects: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class subjects: $e');
    }
  }

  /// Get offerings (subject-classes) for a specific class
  Future<List<Map<String, dynamic>>> getClassOfferings(String classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/$classId/offerings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> offeringsJson = data['offerings'] ?? [];
        return offeringsJson.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class offerings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class offerings: $e');
    }
  }

  /// Get assignments for a specific class
  Future<List<Map<String, dynamic>>> getClassAssignments(String classId,
      {int limit = 10}) async {
    try {
      debugPrint(
          '🔍 [SERVICE DEBUG] getClassAssignments called with classId: $classId, limit: $limit');
      final headers = await _getHeaders();
      final url =
          '$_baseUrl/assignments/classes/$classId/assignments?limit=$limit';
      debugPrint('🔍 [SERVICE DEBUG] Making request to: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('🔍 [SERVICE DEBUG] Response status: ${response.statusCode}');
      debugPrint('🔍 [SERVICE DEBUG] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignmentsJson = data['assignments'] ?? [];
        debugPrint(
            '🔍 [SERVICE DEBUG] Found ${assignmentsJson.length} assignments');

        return assignmentsJson.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class assignments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔍 [SERVICE DEBUG] Error in getClassAssignments: $e');
      throw Exception('Error fetching class assignments: $e');
    }
  }

  /// Create a new class (teachers only)
  Future<ClassModel> createClass({
    required String name,
    String? description,
    String? gradeLevel,
    String? section,
    required String academicYear,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'name': name,
        'description': description,
        'grade_level': gradeLevel,
        'section': section,
        'academic_year': academicYear,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/classes'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ClassModel.fromJson(data['class']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - teachers only');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to create class');
      }
    } catch (e) {
      throw Exception('Error creating class: $e');
    }
  }

  /// Update class information (teachers only)
  Future<ClassModel> updateClass({
    required String classId,
    String? name,
    String? description,
    String? gradeLevel,
    String? section,
    String? academicYear,
    bool? isActive,
  }) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (gradeLevel != null) updateData['grade_level'] = gradeLevel;
      if (section != null) updateData['section'] = section;
      if (academicYear != null) updateData['academic_year'] = academicYear;
      if (isActive != null) updateData['is_active'] = isActive;

      final body = json.encode(updateData);

      final response = await http.put(
        Uri.parse('$_baseUrl/classes/$classId'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ClassModel.fromJson(data['class']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - teachers only');
      } else if (response.statusCode == 404) {
        throw Exception('Class not found');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update class');
      }
    } catch (e) {
      throw Exception('Error updating class: $e');
    }
  }
}

// Response models for paginated data
class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      total: json['total'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

class ClassStudentsResponse {
  final List<User> students;
  final PaginationInfo pagination;

  ClassStudentsResponse({
    required this.students,
    required this.pagination,
  });
}

class ClassTeachersResponse {
  final List<User> teachers;
  final PaginationInfo pagination;

  ClassTeachersResponse({
    required this.teachers,
    required this.pagination,
  });
}

class ClassCounts {
  final int studentCount;
  final int teacherCount;
  final int totalMembers;

  ClassCounts({
    required this.studentCount,
    required this.teacherCount,
    required this.totalMembers,
  });

  factory ClassCounts.fromJson(Map<String, dynamic> json) {
    return ClassCounts(
      studentCount: json['student_count'] ?? 0,
      teacherCount: json['teacher_count'] ?? 0,
      totalMembers: json['total_members'] ?? 0,
    );
  }
}
