import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/attendance_models.dart';
import '../models/class_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';

class AttendanceService {
  static final String _baseUrl = ApiConstants.baseUrl;

  /// Formats a DateTime to YYYY-MM-DD string format
  String _formatDateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Location permissions and GPS methods
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
          'Location services are disabled. Please enable location services to mark attendance.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
            'Location permission denied. Location access is required for GPS attendance.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied. Please enable location access in settings.');
    }

    return true;
  }

  Future<Position> getCurrentLocation() async {
    await requestLocationPermission();

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      throw Exception('Failed to get current location: $e');
    }
  }

  // School attendance settings
  Future<SchoolAttendanceSettings?> getSchoolAttendanceSettings(
      String schoolId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/attendance/settings/$schoolId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['settings'] != null) {
          return SchoolAttendanceSettings.fromJson(data['settings']);
        }
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        throw Exception(
            'Failed to fetch attendance settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attendance settings: $e');
    }
  }

  Future<SchoolAttendanceSettings> updateSchoolAttendanceSettings(
    String schoolId,
    SchoolAttendanceSettings settings,
  ) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode(settings.toJson());

      final response = await http.put(
        Uri.parse('$_baseUrl/attendance/settings/$schoolId'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return SchoolAttendanceSettings.fromJson(data['settings']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - admin access required');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(
            errorData['error'] ?? 'Failed to update attendance settings');
      }
    } catch (e) {
      throw Exception('Error updating attendance settings: $e');
    }
  }

  // Teacher attendance management
  Future<AttendanceSessionResponse> openAttendanceSession(
    String classId,
    DateTime date,
  ) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'date': _formatDateToString(date),
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/attendance/sessions/$classId/open'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AttendanceSessionResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - teacher access required');
      } else if (response.statusCode == 404) {
        throw Exception('Class not found');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(
            errorData['error'] ?? 'Failed to open attendance session');
      }
    } catch (e) {
      throw Exception('Error opening attendance session: $e');
    }
  }

  Future<AttendanceRecord> markStudentAttendance(
    String classId,
    String studentId,
    DateTime date,
    CreateAttendanceRequest request,
  ) async {
    try {
      final headers = await _getHeaders();
      final requestData = request.toJson();
      requestData['date'] = _formatDateToString(date);

      final body = json.encode(requestData);

      final response = await http.post(
        Uri.parse('$_baseUrl/attendance/mark/$classId/$studentId'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AttendanceRecord.fromJson(data['record']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to mark attendance');
      }
    } catch (e) {
      throw Exception('Error marking attendance: $e');
    }
  }

  Future<List<AttendanceRecord>> bulkUpdateAttendance(
    String classId,
    DateTime date,
    BulkAttendanceUpdate bulkUpdate,
  ) async {
    try {
      final headers = await _getHeaders();
      final requestData = bulkUpdate.toJson();
      requestData['date'] = _formatDateToString(date);

      final body = json.encode(requestData);

      final response = await http.post(
        Uri.parse('$_baseUrl/attendance/bulk-update/$classId'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> recordsJson = data['records'] ?? [];
        return recordsJson
            .map((json) => AttendanceRecord.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update attendance');
      }
    } catch (e) {
      throw Exception('Error updating attendance: $e');
    }
  }

  Future<AttendanceSession> finalizeAttendanceSession(
    String classId,
    DateTime date,
  ) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'date': _formatDateToString(date),
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/attendance/sessions/$classId/finalize'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AttendanceSession.fromJson(data['session']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(
            errorData['error'] ?? 'Cannot finalize attendance session');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(
            errorData['error'] ?? 'Failed to finalize attendance session');
      }
    } catch (e) {
      throw Exception('Error finalizing attendance session: $e');
    }
  }

  // Student GPS attendance
  Future<AttendanceRecord> markStudentAttendanceGPS(String classId) async {
    try {
      // Get current location
      final position = await getCurrentLocation();

      final headers = await _getHeaders();
      final request = StudentAttendanceRequest(
        classId: classId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final body = json.encode(request.toJson());

      final response = await http.post(
        Uri.parse('$_baseUrl/attendance/student/mark'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AttendanceRecord.fromJson(data['record']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied - not enrolled in this class');
      } else if (response.statusCode == 409) {
        throw Exception('Attendance already marked for today');
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Location verification failed');
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to mark attendance');
      }
    } catch (e) {
      if (e.toString().contains('Location')) {
        rethrow; // Re-throw location-specific errors
      }
      throw Exception('Error marking GPS attendance: $e');
    }
  }

  // Attendance statistics and reports
  Future<AttendanceStats> getAttendanceStats(
    String classId,
    DateTime date,
  ) async {
    try {
      final headers = await _getHeaders();
      final dateString = _formatDateToString(date);

      final response = await http.get(
        Uri.parse('$_baseUrl/attendance/$classId/stats?date=$dateString'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AttendanceStats.fromJson(data['stats']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        throw Exception(
            'Failed to fetch attendance statistics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attendance statistics: $e');
    }
  }

  Future<AttendanceReport> getAttendanceReport(
    String classId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final headers = await _getHeaders();
      final startDateString = _formatDateToString(startDate);
      final endDateString = _formatDateToString(endDate);

      final response = await http.get(
        Uri.parse(
            '$_baseUrl/attendance/$classId/report?start_date=$startDateString&end_date=$endDateString'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AttendanceReport.fromJson(data['report']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        throw Exception(
            'Failed to generate attendance report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating attendance report: $e');
    }
  }

  Future<List<AttendanceRecord>> getStudentAttendanceHistory(
    String studentId,
    String classId,
  ) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(
            '$_baseUrl/attendance/student/$studentId/history?class_id=$classId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> historyJson = data['history'] ?? [];
        return historyJson
            .map((json) => AttendanceRecord.fromJson(json))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied');
      } else {
        throw Exception(
            'Failed to fetch attendance history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attendance history: $e');
    }
  }

  // Helper methods for quick actions
  Future<bool> canMarkAttendanceForClass(String classId) async {
    try {
      // This would check if the student is enrolled in the class
      // and if attendance hasn't been marked for today
      // For now, we'll implement a simple check

      final today = DateTime.now();

      // Try to get today's stats to see if attendance is open
      await getAttendanceStats(classId, today);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<ClassModel>> getStudentClassesForAttendance() async {
    try {
      // This would typically call a dedicated endpoint
      // For now, we'll reuse the existing class management service
      // In a real implementation, you might want to filter classes
      // that are currently accepting attendance

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/classes/my-classes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> classesJson = data['classes'] ?? [];
        return classesJson.map((json) => ClassModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch classes');
      }
    } catch (e) {
      throw Exception('Error fetching classes for attendance: $e');
    }
  }

  // Utility methods for UI
  String getAttendanceStatusDisplayName(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.excused:
        return 'Excused';
    }
  }

  String getAttendanceStatusEmoji(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return '✅';
      case AttendanceStatus.absent:
        return '❌';
      case AttendanceStatus.late:
        return '⏰';
      case AttendanceStatus.excused:
        return '📝';
    }
  }

  bool isAttendancePositive(AttendanceStatus status) {
    return status != AttendanceStatus.absent;
  }
}
