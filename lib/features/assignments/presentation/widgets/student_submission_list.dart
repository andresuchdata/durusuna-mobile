import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../../shared/models/assignment_detail.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';

class StudentSubmissionList extends ConsumerWidget {
  final List<StudentSubmission> submissions;
  final bool showSearch;

  const StudentSubmissionList({
    super.key,
    required this.submissions,
    this.showSearch = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (submissions.isEmpty) {
      return _buildEmptyState();
    }

    // Sort submissions: graded first, then submitted, then not submitted
    final sortedSubmissions = List<StudentSubmission>.from(submissions)
      ..sort((a, b) {
        // Primary sort by status priority
        final statusPriority = {
          'graded': 0,
          'returned': 0,
          'submitted': 1,
          'not_submitted': 2,
          'excused': 3,
        };

        final aPriority = statusPriority[a.status] ?? 4;
        final bPriority = statusPriority[b.status] ?? 4;

        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }

        // Secondary sort by student name
        return a.studentName.compareTo(b.studentName);
      });

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedSubmissions.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: AppTheme.textSecondary.withValues(alpha: 0.2),
          ),
          itemBuilder: (context, index) {
            final submission = sortedSubmissions[index];
            return _buildSubmissionItem(context, submission, ref);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No students enrolled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Students will appear here once they are enrolled in this class.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionItem(
      BuildContext context, StudentSubmission submission, WidgetRef ref) {
    return InkWell(
      onTap: () => _showSubmissionDetails(context, submission, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Avatar and student info
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _buildAvatar(submission),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.studentName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (submission.studentNumber?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            submission.studentNumber!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Status and score
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildStatusIcon(submission.status),
                      const SizedBox(width: 4),
                      if (submission.hasScore) ...[
                        Text(
                          submission.scoreDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getScoreColor(submission),
                          ),
                        ),
                      ] else ...[
                        Text(
                          submission.statusDisplayText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(submission.status),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  _buildSubmissionDate(submission),
                ],
              ),
            ),

            // Expand arrow
            Icon(
              Icons.chevron_right,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(StudentSubmission submission) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      backgroundImage: submission.avatarUrl?.isNotEmpty == true
          ? NetworkImage(submission.avatarUrl!)
          : null,
      child: submission.avatarUrl?.isEmpty != false
          ? Text(
              _getInitials(submission.studentName),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            )
          : null,
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'graded':
      case 'returned':
        icon = Icons.check_circle;
        color = AppTheme.successColor;
        break;
      case 'submitted':
        icon = Icons.schedule;
        color = AppTheme.infoColor;
        break;
      case 'excused':
        icon = Icons.remove_circle_outline;
        color = AppTheme.warningColor;
        break;
      case 'not_submitted':
      default:
        icon = Icons.radio_button_unchecked;
        color = AppTheme.errorColor;
        break;
    }

    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }

  Widget _buildSubmissionDate(StudentSubmission submission) {
    String dateText = '';
    String prefix = '';

    if (submission.isGraded && submission.gradedAt != null) {
      prefix = 'Graded';
      dateText =
          app_date_utils.DateUtils.formatRelativeTime(submission.gradedAt!);
    } else if (submission.isSubmitted && submission.submittedAt != null) {
      prefix = submission.isLate ? 'Late' : 'Submitted';
      dateText =
          app_date_utils.DateUtils.formatRelativeTime(submission.submittedAt!);
    } else if (submission.status == 'not_submitted') {
      prefix = 'Missing';
      dateText = '';
    }

    if (dateText.isEmpty && prefix.isNotEmpty) {
      return Text(
        prefix,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textTertiary,
        ),
      );
    }

    if (prefix.isNotEmpty && dateText.isNotEmpty) {
      return Text(
        '$prefix • $dateText',
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textTertiary,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'graded':
      case 'returned':
        return AppTheme.successColor;
      case 'submitted':
        return AppTheme.infoColor;
      case 'excused':
        return AppTheme.warningColor;
      case 'not_submitted':
      default:
        return AppTheme.errorColor;
    }
  }

  Color _getScoreColor(StudentSubmission submission) {
    if (!submission.hasScore) return AppTheme.textSecondary;

    final percentage = (submission.score! / submission.maxScore) * 100;

    if (percentage >= 85) return AppTheme.successColor;
    if (percentage >= 75) return AppTheme.infoColor;
    if (percentage >= 60) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  void _showSubmissionDetails(
      BuildContext context, StudentSubmission submission, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _buildSubmissionDetailsModal(context, submission, ref),
    );
  }

  Widget _buildSubmissionDetailsModal(
      BuildContext context, StudentSubmission submission, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student info
                  Row(
                    children: [
                      _buildAvatar(submission),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              submission.studentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (submission.studentNumber?.isNotEmpty == true)
                              Text(
                                submission.studentNumber!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildStatusIcon(submission.status),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Submission details
                  if (submission.hasScore) ...[
                    _buildDetailRow('Score', submission.scoreDisplay),
                    const SizedBox(height: 12),
                  ],

                  _buildDetailRow('Status', submission.statusDisplayText),

                  if (submission.submittedAt != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Submitted',
                      '${app_date_utils.DateUtils.formatFullDateTime(submission.submittedAt!)}${submission.isLate ? ' (Late)' : ''}',
                    ),
                  ],

                  if (submission.gradedAt != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                        'Graded',
                        app_date_utils.DateUtils.formatFullDateTime(
                            submission.gradedAt!)),
                  ],

                  if (submission.graderName != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('Graded By', submission.graderName!),
                  ],

                  if (submission.feedback?.isNotEmpty == true) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Feedback',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        submission.feedback!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action buttons
                  _buildActionButtons(context, submission, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, StudentSubmission submission, WidgetRef ref) {
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    // Only teachers and admins can edit grades
    final canEditGrades =
        user?.userType == UserType.teacher || user?.role == UserRole.admin;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
        if (canEditGrades) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editGrade(submission);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Edit Grade'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _editGrade(StudentSubmission submission) {
    // TODO: Navigate to grade editing screen
    debugPrint('Edit grade for ${submission.studentName}');
  }
}
