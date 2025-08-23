import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../../shared/models/assignment.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/providers/assignment_providers.dart';
import '../../../../shared/services/auth_service.dart';
import '../pages/assignments_main_page.dart';

/// Standardized presenter for assignment list data
/// Provides consistent data handling across different contexts
class AssignmentListPresenter {
  final WidgetRef ref;
  final AssignmentListContext context;
  final AssignmentListFilters filters;

  AssignmentListPresenter({
    required this.ref,
    required this.context,
    required this.filters,
  });

  /// Get assignments with applied filters
  AsyncValue<List<AssignmentPresenterItem>> getFilteredAssignments() {
    final params = _buildQueryParams();
    final assignmentsAsync = ref.watch(userAssignmentsProvider(params));

    return assignmentsAsync.when(
      data: (assignments) {
        final filtered = _applyLocalFilters(assignments);
        final presentedItems = filtered
            .map((assignment) => AssignmentPresenterItem.fromAssignment(
                  assignment,
                  context: context,
                ))
            .toList();
        return AsyncValue.data(presentedItems);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    );
  }

  /// Build query parameters based on context and filters
  AssignmentQueryParams _buildQueryParams() {
    return AssignmentQueryParams(
      classId: context.classId,
      subjectId: context.subjectId,
      limit: 100,
      status: _getStatusForUserRole(),
      filterType: _getFilterTypeString(filters.filterType),
      searchQuery: filters.searchQuery,
    );
  }

  /// Get appropriate status filter based on user role
  String _getStatusForUserRole() {
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    if (user == null) return 'published';

    // Students and parents only see published assignments
    if (user.userType == UserType.student || user.userType == UserType.parent) {
      return 'published';
    }

    // Teachers and admins can see all based on context
    return filters.statusFilter ?? 'all';
  }

  /// Convert filter type enum to string
  String? _getFilterTypeString(AssignmentFilterType filterType) {
    switch (filterType) {
      case AssignmentFilterType.all:
        return null;
      case AssignmentFilterType.dueSoon:
        return 'due_soon';
      case AssignmentFilterType.submitted:
        return 'submitted';
      case AssignmentFilterType.graded:
        return 'graded';
    }
  }

  /// Apply additional local filters (client-side)
  List<Assignment> _applyLocalFilters(List<Assignment> assignments) {
    var filtered = assignments;

    // Additional filtering can be added here
    // For example, custom date ranges, priority levels, etc.

    return filtered;
  }

  /// Get empty state message based on context
  String getEmptyStateMessage() {
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    if (filters.searchQuery?.isNotEmpty == true) {
      return 'No assignments found for "${filters.searchQuery}"';
    }

    switch (filters.filterType) {
      case AssignmentFilterType.all:
        if (context.isFromClassDetails) {
          return 'No assignments found for this class';
        } else if (context.isFromSubjectDetails) {
          return 'No assignments found for this subject';
        } else {
          return user?.userType == UserType.student
              ? 'No assignments found'
              : 'No assignments created yet';
        }
      case AssignmentFilterType.dueSoon:
        return 'No assignments due soon';
      case AssignmentFilterType.submitted:
        return 'No submitted assignments';
      case AssignmentFilterType.graded:
        return 'No graded assignments';
    }
  }

  /// Get error message based on context
  String getErrorMessage(String error) {
    if (error.contains('Authentication')) {
      return 'Please log in to view assignments';
    } else if (error.contains('Access denied')) {
      return 'You don\'t have permission to view these assignments';
    } else {
      return 'Failed to load assignments. Please try again.';
    }
  }
}

/// Context information for assignment list
class AssignmentListContext {
  final String? classId;
  final String? subjectId;
  final AssignmentNavigationSource source;
  final String? title;

  const AssignmentListContext({
    this.classId,
    this.subjectId,
    required this.source,
    this.title,
  });

  bool get isFromClassDetails =>
      source == AssignmentNavigationSource.classDetails;
  bool get isFromSubjectDetails =>
      source == AssignmentNavigationSource.subjectDetails;
  bool get isFromHome => source == AssignmentNavigationSource.home;
  bool get isStandalone => source == AssignmentNavigationSource.standalone;

  /// Create context for global assignment list (from home)
  factory AssignmentListContext.global({String? title}) {
    return AssignmentListContext(
      source: AssignmentNavigationSource.home,
      title: title ?? 'My Assignments',
    );
  }

  /// Create context for class-specific assignment list
  factory AssignmentListContext.forClass({
    required String classId,
    String? title,
  }) {
    return AssignmentListContext(
      classId: classId,
      source: AssignmentNavigationSource.classDetails,
      title: title ?? 'Class Assignments',
    );
  }

  /// Create context for subject-specific assignment list
  factory AssignmentListContext.forSubject({
    required String classId,
    required String subjectId,
    String? title,
  }) {
    return AssignmentListContext(
      classId: classId,
      subjectId: subjectId,
      source: AssignmentNavigationSource.subjectDetails,
      title: title ?? 'Subject Assignments',
    );
  }
}

/// Filter configuration for assignment list
class AssignmentListFilters {
  final AssignmentFilterType filterType;
  final String? searchQuery;
  final String? statusFilter;
  final String? typeFilter;

  const AssignmentListFilters({
    required this.filterType,
    this.searchQuery,
    this.statusFilter,
    this.typeFilter,
  });

  AssignmentListFilters copyWith({
    AssignmentFilterType? filterType,
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
  }) {
    return AssignmentListFilters(
      filterType: filterType ?? this.filterType,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

/// Navigation source for assignment list
enum AssignmentNavigationSource {
  home,
  classDetails,
  subjectDetails,
  standalone,
}

/// Presenter item that wraps assignment with additional presentation data
class AssignmentPresenterItem {
  final Assignment assignment;
  final String displayTitle;
  final String displaySubtitle;
  final String displayClassInfo;
  final String displaySubjectInfo;
  final bool showClassInfo;
  final bool showSubjectInfo;

  const AssignmentPresenterItem({
    required this.assignment,
    required this.displayTitle,
    required this.displaySubtitle,
    required this.displayClassInfo,
    required this.displaySubjectInfo,
    required this.showClassInfo,
    required this.showSubjectInfo,
  });

  factory AssignmentPresenterItem.fromAssignment(
    Assignment assignment, {
    required AssignmentListContext context,
  }) {
    final displayTitle = assignment.title;

    // Build subtitle based on context
    String displaySubtitle = '';
    if (assignment.dueDate != null) {
      displaySubtitle =
          app_date_utils.DateUtils.formatAssignmentDueDate(assignment.dueDate!);
    }

    // Determine what class/subject info to show
    final showClassInfo = !context.isFromClassDetails;
    final showSubjectInfo = !context.isFromSubjectDetails;

    final displayClassInfo = assignment.className ?? 'Unknown Class';
    final displaySubjectInfo = assignment.subjectName ?? 'Unknown Subject';

    return AssignmentPresenterItem(
      assignment: assignment,
      displayTitle: displayTitle,
      displaySubtitle: displaySubtitle,
      displayClassInfo: displayClassInfo,
      displaySubjectInfo: displaySubjectInfo,
      showClassInfo: showClassInfo,
      showSubjectInfo: showSubjectInfo,
    );
  }
}
