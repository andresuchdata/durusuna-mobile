import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/assignments_service.dart';
import '../services/class_management_service.dart';
import '../models/assignment.dart';
import 'app_providers.dart';

// Provider for live subject offering statistics
final subjectOfferingStatsProvider =
    FutureProvider.family<SubjectOfferingStats, (String, String)>(
        (ref, params) async {
  final (classId, subjectId) = params;
  final assignmentsService = ref.read(assignmentsServiceProvider);
  final classService = ref.read(classManagementServiceProvider);

  try {
    // Fetch assignments for the subject
    final assignments = await assignmentsService.getClassAssignments(
      classId,
      limit: 1000, // Get all assignments to count them
    );

    // Filter assignments by subject if needed
    final subjectAssignments = assignments
        .where((assignment) =>
            assignment.subjectCode == subjectId ||
            assignment.subjectName?.toLowerCase() == subjectId.toLowerCase())
        .toList();

    // Count pending grades (assignments that are submitted but not graded)
    final pendingGrades = subjectAssignments
        .where((assignment) =>
            assignment.submissionStatus == AssignmentStatus.submitted ||
            assignment.submissionStatus == AssignmentStatus.notSubmitted)
        .length;

    // Get student count for the class
    final studentsResponse =
        await classService.getClassStudentsPaginated(classId, limit: 1000);
    final studentCount = studentsResponse.students.length;

    return SubjectOfferingStats(
      studentCount: studentCount,
      assignmentsCount: subjectAssignments.length,
      pendingGrades: pendingGrades,
    );
  } catch (e) {
    // Return default values if there's an error
    return SubjectOfferingStats(
      studentCount: 0,
      assignmentsCount: 0,
      pendingGrades: 0,
    );
  }
});

// Provider for assignments service
final assignmentsServiceProvider =
    Provider<AssignmentsService>((ref) => AssignmentsService());

// Data class for subject offering statistics
class SubjectOfferingStats {
  final int studentCount;
  final int assignmentsCount;
  final int pendingGrades;

  SubjectOfferingStats({
    required this.studentCount,
    required this.assignmentsCount,
    required this.pendingGrades,
  });
}
