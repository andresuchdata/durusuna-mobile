import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../../shared/models/assignment.dart';
import '../../../../shared/models/assignment_detail.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/assignments_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/attachment_list.dart';
import '../widgets/student_submission_list.dart';

final assignmentDetailProvider =
    FutureProvider.family<AssignmentDetail, String>((ref, assignmentId) {
  final assignmentsService = ref.read(assignmentsServiceProvider);
  return assignmentsService.getAssignmentDetails(assignmentId);
});

class AssignmentDetailPage extends ConsumerWidget {
  final String assignmentId;
  final String? title;

  const AssignmentDetailPage({
    super.key,
    required this.assignmentId,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentDetailAsync =
        ref.watch(assignmentDetailProvider(assignmentId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          title ?? 'Assignment Details',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit Assignment'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Grades'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'analytics',
                child: ListTile(
                  leading: Icon(Icons.analytics),
                  title: Text('View Analytics'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: assignmentDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error.toString()),
        data: (assignmentDetail) =>
            _buildContent(context, assignmentDetail, ref),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load assignment details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, AssignmentDetail assignmentDetail, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => Future.value(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment Header
            _buildAssignmentHeader(assignmentDetail.assignment),
            const SizedBox(height: 16),

            // Assignment Description
            if (assignmentDetail.assignment.description?.isNotEmpty ==
                true) ...[
              _buildDescriptionSection(
                  assignmentDetail.assignment.description!),
              const SizedBox(height: 16),
            ],

            // Assignment Attachments
            if (assignmentDetail.attachments.isNotEmpty) ...[
              _buildAttachmentsSection(assignmentDetail.attachments),
              const SizedBox(height: 16),
            ],

            // Instructions/Rubric
            if (assignmentDetail.assignment.instructions != null ||
                assignmentDetail.assignment.rubric != null) ...[
              _buildInstructionsSection(assignmentDetail.assignment),
              const SizedBox(height: 16),
            ],

            // Submission Stats (only for teachers)
            if (_shouldShowStats(ref)) ...[
              _buildStatsSection(assignmentDetail.stats),
              const SizedBox(height: 16),
            ],

            // Student Submissions
            _buildStudentSubmissionsSection(
                assignmentDetail.studentSubmissions, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentHeader(Assignment assignment) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  assignment.type.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.book,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${assignment.subjectName} • ${assignment.className}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                assignment.dueDate != null
                    ? 'Due: ${app_date_utils.DateUtils.formatReadableDate(assignment.dueDate!)}'
                    : 'No due date',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.grade,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${assignment.maxScore} points',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(List<Map<String, dynamic>> attachments) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: AttachmentList(
        attachments: attachments,
        mode: AttachmentListMode.horizontal,
        headerTitle: 'Assignment Files',
        maxItems: 4,
        onMoreTap: () => _showAllAttachments(attachments),
      ),
    );
  }

  Widget _buildInstructionsSection(dynamic assignment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Instructions & Rubric',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (assignment.instructions != null) ...[
            Text(
              'Instructions: ${assignment.instructions.toString()}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (assignment.rubric != null) ...[
            Text(
              'Rubric: ${assignment.rubric.toString()}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(AssignmentStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submission Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Students',
                  stats.totalStudents.toString(),
                  AppTheme.primaryColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Submitted',
                  '${stats.submittedCount}/${stats.totalStudents}',
                  AppTheme.infoColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Graded',
                  '${stats.gradedCount}/${stats.submittedCount}',
                  AppTheme.successColor,
                ),
              ),
              if (stats.averageScore != null)
                Expanded(
                  child: _buildStatItem(
                    'Average',
                    '${stats.averageScore!.toStringAsFixed(1)}%',
                    AppTheme.warningColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStudentSubmissionsSection(
      List<StudentSubmission> submissions, WidgetRef ref) {
    // Filter submissions based on user role
    final filteredSubmissions = _filterSubmissionsByUserRole(submissions, ref);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            filteredSubmissions.isEmpty
                ? 'Student Submissions'
                : 'Student Submissions (${filteredSubmissions.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          filteredSubmissions.isEmpty
              ? _buildNoSubmissionsWidget(ref)
              : StudentSubmissionList(submissions: filteredSubmissions),
        ],
      ),
    );
  }

  Widget _buildNoSubmissionsWidget(WidgetRef ref) {
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    String message = 'No submissions available';
    if (user?.userType == UserType.student) {
      message = 'You have not submitted this assignment yet';
    } else if (user?.userType == UserType.parent) {
      message = 'Your child has not submitted this assignment yet';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _shouldShowStats(WidgetRef ref) {
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    if (user == null) return false;

    // Only show stats for teachers and admins
    return user.userType == UserType.teacher || user.role == UserRole.admin;
  }

  List<StudentSubmission> _filterSubmissionsByUserRole(
      List<StudentSubmission> submissions, WidgetRef ref) {
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    if (user == null) return submissions;

    switch (user.userType) {
      case UserType.student:
        // Students only see their own submission
        return submissions
            .where((submission) => submission.studentId == user.id)
            .toList();

      case UserType.parent:
        // For parents, we need to show their child's submission
        // Note: This assumes the parent-child relationship is handled by the backend
        // and only returns submissions for their child in the API response.
        // If backend doesn't filter, we would need additional parent-child relationship data
        return submissions;

      case UserType.teacher:
        // Teachers and admins see all submissions
        return submissions;
    }
  }

  void _showAllAttachments(List<Map<String, dynamic>> attachments) {
    // TODO: Navigate to full attachment view
    debugPrint('Show all attachments: ${attachments.length}');
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit Assignment - Under Development')),
        );
        break;
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export Grades - Under Development')),
        );
        break;
      case 'analytics':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('View Analytics - Under Development')),
        );
        break;
    }
  }
}
