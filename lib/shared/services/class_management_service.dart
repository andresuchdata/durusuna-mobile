import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/user.dart';
import 'firebase/fcm_service.dart';
import 'api_service.dart';

class ClassManagementService {
  final ApiService _apiService;

  ClassManagementService(this._apiService);

  // Keep legacy constructor for backwards compatibility
  factory ClassManagementService.legacy() {
    return ClassManagementService._legacy();
  }

  ClassManagementService._legacy() : _apiService = ApiService();

  /// Get classes that the current user is enrolled in
  Future<List<ClassModel>> getUserClasses() async {
    try {
      final response = await _apiService.get('/classes/my-classes');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final List<dynamic> classesJson = data['classes'] ?? [];

        final classes =
            classesJson.map((json) => ClassModel.fromJson(json)).toList();

        // Subscribe to FCM topics for all user classes
        await _subscribeToClassTopics(classes);

        return classes;
      } else {
        throw Exception('Failed to fetch user classes: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching user classes: ${e.message}');
      }

      throw Exception('Error fetching user classes: $e');
    }
  }

  /// Subscribe to FCM topics for user's classes
  Future<void> _subscribeToClassTopics(List<ClassModel> classes) async {
    try {
      final fcmService = FCMService();
      final classIds = classes.map((c) => c.id).toList();
      await fcmService.subscribeToUserClasses(classIds);
      debugPrint('✅ Subscribed to ${classIds.length} class FCM topics');
    } catch (e) {
      debugPrint('⚠️ Failed to subscribe to class FCM topics: $e');
      // Don't throw error - FCM subscription failure shouldn't break class loading
    }
  }

  /// Get detailed information about a specific class
  Future<ClassModel> getClassDetails(String classId) async {
    try {
      final response = await _apiService.get('/classes/$classId');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return ClassModel.fromJson(data['class'] ?? data);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else if (response.statusCode == 404) {
        throw Exception('Class not found');
      } else {
        throw Exception(
            'Failed to fetch class details: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching class details: ${e.message}');
      }
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
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiService.get(
        '/classes/$classId/students',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final List<dynamic> studentsJson = data['students'] ?? [];
        final Map<String, dynamic> paginationJson = data['pagination'] ?? {};

        return ClassStudentsResponse(
          students: studentsJson.map((json) => User.fromJson(json)).toList(),
          pagination: PaginationInfo.fromJson(paginationJson),
        );
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class students: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching class students: ${e.message}');
      }
      throw Exception('Error fetching class students: $e');
    }
  }

  /// Get class counts (student count, teacher count, etc.)
  Future<ClassCounts> getClassCounts(String classId) async {
    try {
      final response = await _apiService.get('/classes/$classId/counts');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return ClassCounts.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception('Failed to fetch class counts: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching class counts: ${e.message}');
      }
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
      final response = await _apiService.get(
        '/classes/$classId/teachers',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final List<dynamic> teachersJson = data['teachers'] ?? [];
        final Map<String, dynamic> paginationJson = data['pagination'] ?? {};

        return ClassTeachersResponse(
          teachers: teachersJson.map((json) => User.fromJson(json)).toList(),
          pagination: PaginationInfo.fromJson(paginationJson),
        );
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class teachers: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching class teachers: ${e.message}');
      }
      throw Exception('Error fetching class teachers: $e');
    }
  }

  /// Get lessons for a specific class
  Future<List<Map<String, dynamic>>> getClassLessons(String classId) async {
    try {
      final response = await _apiService.get('/classes/$classId/lessons');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final List<dynamic> lessonsJson = data['lessons'] ?? [];

        return _safeListCast(lessonsJson);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class lessons: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching class lessons: ${e.message}');
      }
      throw Exception('Error fetching class lessons: $e');
    }
  }

  /// Safely cast dynamic list to List<Map<String, dynamic>>
  List<Map<String, dynamic>> _safeListCast(dynamic json) {
    if (json == null) return [];
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (json is Map) {
      return [Map<String, dynamic>.from(json)];
    }
    return [];
  }

  /// Get subjects for a specific class with their lessons
  Future<List<Map<String, dynamic>>> getClassSubjects(String classId) async {
    try {
      final response = await _apiService.get('/classes/$classId/subjects');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final List<dynamic> subjectsJson = data['subjects'] ?? [];

        return _safeListCast(subjectsJson);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class subjects: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching class subjects: ${e.message}');
      }
      throw Exception('Error fetching class subjects: $e');
    }
  }

  /// Get offerings (subject-classes) for a specific class
  Future<List<Map<String, dynamic>>> getClassOfferings(String classId) async {
    try {
      final response = await _apiService.get('/classes/$classId/offerings');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final List<dynamic> offeringsJson = data['offerings'] ?? [];
        return _safeListCast(offeringsJson);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class offerings: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error fetching class offerings: ${e.message}');
      }
      throw Exception('Error fetching class offerings: $e');
    }
  }

  /// Get assignments for a specific class
  Future<List<Map<String, dynamic>>> getClassAssignments(String classId,
      {int limit = 10}) async {
    try {
      debugPrint(
          '🔍 [SERVICE DEBUG] getClassAssignments called with classId: $classId, limit: $limit');

      final response = await _apiService.get(
        '/assignments/classes/$classId/assignments',
        queryParameters: {'limit': limit.toString()},
      );

      debugPrint('🔍 [SERVICE DEBUG] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final List<dynamic> assignmentsJson = data['assignments'] ?? [];
        debugPrint(
            '🔍 [SERVICE DEBUG] Found ${assignmentsJson.length} assignments');

        return _safeListCast(assignmentsJson);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied to this class');
      } else {
        throw Exception(
            'Failed to fetch class assignments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔍 [SERVICE DEBUG] Error in getClassAssignments: $e');
      if (e is ApiException) {
        throw Exception('Error fetching class assignments: ${e.message}');
      }
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
      final data = {
        'name': name,
        'description': description,
        'grade_level': gradeLevel,
        'section': section,
        'academic_year': academicYear,
      };

      final response = await _apiService.post('/classes', data: data);

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = response.data;
        return ClassModel.fromJson(responseData['class']);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - teachers only');
      } else {
        final Map<String, dynamic> errorData = response.data;
        throw Exception(errorData['error'] ?? 'Failed to create class');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error creating class: ${e.message}');
      }
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
      final Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (gradeLevel != null) updateData['grade_level'] = gradeLevel;
      if (section != null) updateData['section'] = section;
      if (academicYear != null) updateData['academic_year'] = academicYear;
      if (isActive != null) updateData['is_active'] = isActive;

      final response =
          await _apiService.put('/classes/$classId', data: updateData);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return ClassModel.fromJson(data['class']);
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - teachers only');
      } else if (response.statusCode == 404) {
        throw Exception('Class not found');
      } else {
        final Map<String, dynamic> errorData = response.data;
        throw Exception(errorData['error'] ?? 'Failed to update class');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('Error updating class: ${e.message}');
      }
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
