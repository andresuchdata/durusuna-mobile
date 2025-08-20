import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/assignment.dart';
import '../../../../shared/providers/assignment_providers.dart';
import '../../../../shared/services/auth_service.dart';
import '../pages/assignments_main_page.dart';
import 'assignment_card.dart';

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
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AssignmentCard(
                  assignment: assignment,
                  userRole: userRole,
                  onTap: () => _navigateToAssignmentDetail(context, assignment),
                ),
              );
            },
          ),
        );
      },
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
        builder: (context) => AssignmentDetailPage(assignment: assignment),
      ),
    );
  }
}

// Placeholder for assignment detail page
class AssignmentDetailPage extends StatelessWidget {
  final Assignment assignment;

  const AssignmentDetailPage({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(assignment.title),
      ),
      body: Center(
        child: Text('Assignment Detail - ${assignment.title}'),
      ),
    );
  }
}
