import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../../shared/models/assignment.dart';
import '../../../../shared/providers/assignment_providers.dart';
import '../../../../shared/services/auth_service.dart';
import '../pages/assignments_main_page.dart';
import '../pages/assignment_detail_page.dart';

class AssignmentListView extends ConsumerWidget {
  final AssignmentFilterType filterType;
  final UserRoleType userRole;
  final String? classId;
  final String? subjectId;
  final String? searchQuery;

  const AssignmentListView({
    super.key,
    required this.filterType,
    required this.userRole,
    this.classId,
    this.subjectId,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Build query parameters based on filter type and context
    final params = AssignmentQueryParams(
      classId: classId,
      subjectId: subjectId,
      limit: 100,
      status: 'published', // Students/parents only see published assignments
      filterType: _getFilterTypeString(filterType),
      searchQuery: searchQuery,
    );

    final assignmentsAsync = ref.watch(userAssignmentsProvider(params));

    return assignmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString(), ref),
      data: (assignments) {
        if (assignments.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userAssignmentsProvider(params));
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: assignments.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AppTheme.textSecondary.withValues(alpha: 0.2),
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];
                    return _buildAssignmentItem(context, assignment);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentItem(BuildContext context, Assignment assignment) {
    return InkWell(
      onTap: () => _navigateToAssignmentDetail(context, assignment),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Assignment type icon and color indicator
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: assignment.statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Assignment content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          assignment.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: assignment.statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          assignment.typeDisplayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: assignment.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Subject and class info (without duplicate assignment title)
                  Text(
                    '${assignment.subjectName ?? 'Unknown Subject'}${assignment.className != null ? ' • ${assignment.className}' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Due date and status row
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        assignment.dueDate != null
                            ? app_date_utils.DateUtils.formatAssignmentDueDate(
                                assignment.dueDate!)
                            : 'No due date',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const Spacer(),

                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: assignment.statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          assignment.statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: assignment.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Show score for students if available
                  if (userRole == UserRoleType.student &&
                      assignment.studentScore != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.grade,
                          size: 14,
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Score: ${assignment.studentScore}/${assignment.maxScore}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Show stats for teachers
                  if (userRole != UserRoleType.student &&
                      assignment.totalStudents != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${assignment.submittedCount ?? 0}/${assignment.totalStudents} submitted',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        if (assignment.gradedCount != null) ...[
                          Text(
                            ' • ${assignment.gradedCount} graded',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Chevron indicator
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to convert AssignmentFilterType to string
  String? _getFilterTypeString(AssignmentFilterType filterType) {
    switch (filterType) {
      case AssignmentFilterType.all:
        return null; // No additional filtering
      case AssignmentFilterType.dueSoon:
        return 'due_soon';
      case AssignmentFilterType.submitted:
        return 'submitted';
      case AssignmentFilterType.graded:
        return 'graded';
    }
  }

  Widget _buildErrorState(String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load assignments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Trigger refresh by invalidating the provider
              final params = AssignmentQueryParams(
                classId: classId,
                subjectId: subjectId,
                limit: 100,
                status: 'published',
                filterType: _getFilterTypeString(filterType),
              );
              ref.invalidate(userAssignmentsProvider(params));
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (filterType) {
      case AssignmentFilterType.all:
        message = userRole == UserRoleType.student
            ? 'No assignments found'
            : 'No assignments created yet';
        icon = Icons.assignment_outlined;
        break;
      case AssignmentFilterType.dueSoon:
        message = 'No assignments due soon';
        icon = Icons.schedule_outlined;
        break;
      case AssignmentFilterType.submitted:
        message = 'No submitted assignments';
        icon = Icons.upload_outlined;
        break;
      case AssignmentFilterType.graded:
        message = 'No graded assignments';
        icon = Icons.grade_outlined;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (userRole != UserRoleType.student &&
              filterType == AssignmentFilterType.all)
            TextButton.icon(
              onPressed: () {
                // TODO: Navigate to create assignment
              },
              icon: const Icon(Icons.add),
              label: const Text('Create First Assignment'),
            ),
        ],
      ),
    );
  }

  void _navigateToAssignmentDetail(
      BuildContext context, Assignment assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentDetailPage(
          assignmentId: assignment.id,
          title: assignment.title,
        ),
      ),
    );
  }
}
