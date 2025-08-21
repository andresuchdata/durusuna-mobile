import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/assignment_detail.dart';
import '../../../../shared/services/assignments_service.dart';
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
        data: (assignmentDetail) => _buildContent(context, assignmentDetail),
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
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
              style: TextStyle(
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
      BuildContext context, AssignmentDetail assignmentDetail) {
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

            // Submission Stats
            _buildStatsSection(assignmentDetail.stats),
            const SizedBox(height: 16),

            // Student Submissions
            _buildStudentSubmissionsSection(
                assignmentDetail.studentSubmissions),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentHeader(dynamic assignment) {
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
              Icon(
                Icons.book,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${assignment.subject_name} • ${assignment.class_name}',
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
              Icon(
                Icons.calendar_today,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                assignment.due_date != null
                    ? 'Due: ${_formatDate(assignment.due_date)}'
                    : 'No due date',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.grade,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${assignment.max_score} points',
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

  Widget _buildStudentSubmissionsSection(List<StudentSubmission> submissions) {
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
            'Student Submissions (${submissions.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          StudentSubmissionList(submissions: submissions),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
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
