import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/assignment.dart';
import '../pages/assignments_main_page.dart';

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final UserRoleType userRole;
  final VoidCallback? onTap;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.userRole,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
          border: Border(
            left: BorderSide(
              color: assignment.statusColor,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title, status and type
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Subject and Class in one line
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              assignment.subjectName ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            assignment.className ?? 'Unknown Class',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: assignment.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        assignment.statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: assignment.statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assignment.typeDisplayName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Due date and points in compact row
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: assignment.isOverdue
                      ? AppTheme.errorColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  assignment.dueDate != null
                      ? _formatDueDate(assignment.dueDate!)
                      : 'No due date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: assignment.isOverdue
                        ? AppTheme.errorColor
                        : AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.grade,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${assignment.maxScore} pts',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            // Progress bar for teachers/admins (more compact)
            if (userRole != UserRoleType.student) ...[
              const SizedBox(height: 6),
              _buildCompactProgressSection(),
            ],

            // Grade for students (if graded) (more compact)
            if (userRole == UserRoleType.student && assignment.isGraded) ...[
              const SizedBox(height: 6),
              _buildCompactGradeSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactProgressSection() {
    final submittedCount = assignment.submittedCount ?? 0;
    final totalStudents = assignment.totalStudents ?? 1;
    final progress = submittedCount / totalStudents;

    return Row(
      children: [
        Text(
          'Submissions: $submittedCount/$totalStudents',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress < 0.5
                  ? AppTheme.errorColor
                  : progress < 0.8
                      ? AppTheme.warningColor
                      : AppTheme.successColor,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactGradeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Grade:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${assignment.studentScore?.toStringAsFixed(0) ?? 'N/A'}/${assignment.maxScore}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays == 0) {
      return 'Due today';
    } else if (difference.inDays == 1) {
      return 'Due tomorrow';
    } else if (difference.inDays <= 7) {
      return 'Due in ${difference.inDays} days';
    } else {
      return 'Due ${dueDate.day}/${dueDate.month}';
    }
  }
}
