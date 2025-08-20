import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../models/user.dart';
import '../services/assignments_service.dart';
import '../services/auth_service.dart';

// Provider for user's assignments based on their role and context
final userAssignmentsProvider =
    FutureProvider.family<List<Assignment>, AssignmentQueryParams>(
  (ref, params) async {
    final assignmentsService = ref.read(assignmentsServiceProvider);
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    if (user == null) {
      throw Exception('User not authenticated');
    }

    List<Assignment> assignments;

    // Get assignments based on context - support independent filtering
    if (params.classId != null && params.subjectId != null) {
      // Get assignments for a specific subject within a class
      assignments = await assignmentsService.getSubjectAssignments(
        params.classId!,
        params.subjectId!,
        page: params.page,
        limit: params.limit,
      );
    } else if (params.classId != null) {
      // Get assignments for a specific class (across all subjects)
      assignments = await assignmentsService.getClassAssignments(
        params.classId!,
        page: params.page,
        limit: params.limit,
        type: params.type,
        status: params.status,
      );
    } else {
      // Get all user assignments (supports subjectId-only filtering via backend)
      // This handles: no filters, subjectId-only, or search-only scenarios
      assignments = await assignmentsService.getUserAssignments(
        page: params.page,
        limit: params.limit,
        type: params.type,
        status: params.status,
        searchQuery: params.searchQuery,
        subjectId: params.subjectId,
      );
    }

    // Apply role-based filtering
    assignments =
        assignmentsService.filterAssignmentsByRole(assignments, user.userType);

    // Apply additional filter type (due soon, submitted, graded, etc.)
    if (params.filterType != null) {
      assignments = assignmentsService.filterAssignmentsByType(
          assignments, params.filterType!);
    }

    return assignments;
  },
);

// Provider for assignments in a specific class (used in class details)
final classAssignmentsProvider =
    FutureProvider.family<List<Assignment>, String>(
  (ref, classId) async {
    final params = AssignmentQueryParams(
      classId: classId,
      limit: 50,
      status: 'published', // Only show published assignments in class details
    );
    return ref.watch(userAssignmentsProvider(params).future);
  },
);

// Provider for assignments in a specific subject within a class
final subjectAssignmentsProvider =
    FutureProvider.family<List<Assignment>, SubjectAssignmentParams>(
  (ref, params) async {
    final queryParams = AssignmentQueryParams(
      classId: params.classId,
      subjectId: params.subjectId,
      limit: 50,
      status: 'published',
    );
    return ref.watch(userAssignmentsProvider(queryParams).future);
  },
);

// Provider for recent assignments (limited count for previews)
final recentAssignmentsProvider = FutureProvider.family<List<Assignment>, int>(
  (ref, limit) async {
    final assignmentsService = ref.read(assignmentsServiceProvider);
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (user.userType == UserType.teacher) {
      // Teachers get recent assignments they created
      return await assignmentsService.getRecentAssignments(limit: limit);
    } else {
      // Students/parents get their recent assignments (due soon)
      final params = AssignmentQueryParams(
        limit: limit,
        status: 'published',
        filterType: 'due_soon',
      );
      return ref.watch(userAssignmentsProvider(params).future);
    }
  },
);

// Data classes for provider parameters
class AssignmentQueryParams {
  final String? classId;
  final String? subjectId;
  final int page;
  final int limit;
  final String? type;
  final String status;
  final String? filterType;
  final String? searchQuery;

  const AssignmentQueryParams({
    this.classId,
    this.subjectId,
    this.page = 1,
    this.limit = 50,
    this.type,
    this.status = 'all',
    this.filterType,
    this.searchQuery,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentQueryParams &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          subjectId == other.subjectId &&
          page == other.page &&
          limit == other.limit &&
          type == other.type &&
          status == other.status &&
          filterType == other.filterType &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode =>
      classId.hashCode ^
      subjectId.hashCode ^
      page.hashCode ^
      limit.hashCode ^
      type.hashCode ^
      status.hashCode ^
      filterType.hashCode ^
      searchQuery.hashCode;

  AssignmentQueryParams copyWith({
    String? classId,
    String? subjectId,
    int? page,
    int? limit,
    String? type,
    String? status,
    String? filterType,
    String? searchQuery,
  }) {
    return AssignmentQueryParams(
      classId: classId ?? this.classId,
      subjectId: subjectId ?? this.subjectId,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      type: type ?? this.type,
      status: status ?? this.status,
      filterType: filterType ?? this.filterType,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class SubjectAssignmentParams {
  final String classId;
  final String subjectId;

  const SubjectAssignmentParams({
    required this.classId,
    required this.subjectId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectAssignmentParams &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          subjectId == other.subjectId;

  @override
  int get hashCode => classId.hashCode ^ subjectId.hashCode;
}

// Provider for teacher accessible subjects
final teacherAccessibleSubjectsProvider =
    FutureProvider<List<TeacherAccessibleSubject>>((ref) async {
  final assignmentsService = ref.read(assignmentsServiceProvider);
  final authState = ref.read(authStateProvider);
  final user = authState.user;

  if (user == null || user.userType != UserType.teacher) {
    throw Exception('Access denied. Teachers only.');
  }

  return await assignmentsService.getTeacherAccessibleSubjects();
});

// Provider for teacher accessible classes
final teacherAccessibleClassesProvider =
    FutureProvider<List<TeacherAccessibleClass>>((ref) async {
  final assignmentsService = ref.read(assignmentsServiceProvider);
  final authState = ref.read(authStateProvider);
  final user = authState.user;

  if (user == null || user.userType != UserType.teacher) {
    throw Exception('Access denied. Teachers only.');
  }

  return await assignmentsService.getTeacherAccessibleClasses();
});
