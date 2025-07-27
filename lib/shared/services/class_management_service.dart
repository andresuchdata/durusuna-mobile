import 'dart:convert';
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

  /// Get students in a specific class
  Future<List<User>> getClassStudents(String classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/$classId/students'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> studentsJson = data['students'] ?? [];

        return studentsJson.map((json) => User.fromJson(json)).toList();
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

  /// Get teachers in a specific class
  Future<List<User>> getClassTeachers(String classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/$classId/teachers'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> teachersJson = data['teachers'] ?? [];

        return teachersJson.map((json) => User.fromJson(json)).toList();
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
