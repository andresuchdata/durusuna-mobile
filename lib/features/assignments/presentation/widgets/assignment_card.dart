import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../pages/assignments_main_page.dart';
import 'assignment_list_view.dart';

class AssignmentCard extends StatelessWidget {
  final MockAssignment assignment;
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
            // Header with status and type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: assignment.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    assignment.statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: assignment.statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    assignment.type,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              assignment.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Subject and Class
            Row(
              children: [
                Icon(
                  Icons.subject,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  assignment.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.class_,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  assignment.className,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Due date and points
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: assignment.isOverdue
                      ? AppTheme.errorColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDueDate(assignment.dueDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: assignment.isOverdue
                        ? AppTheme.errorColor
                        : AppTheme.textSecondary,
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
                  '${assignment.totalPoints} pts',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            // Progress bar for teachers/admins
            if (userRole != UserRoleType.student) ...[
              const SizedBox(height: 12),
              _buildProgressSection(),
            ],

            // Grade for students (if graded)
            if (userRole == UserRoleType.student && assignment.isGraded) ...[
              const SizedBox(height: 12),
              _buildGradeSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final progress = assignment.submissionCount / assignment.totalStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Submissions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '${assignment.submissionCount}/${assignment.totalStudents}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            progress < 0.5
                ? AppTheme.errorColor
                : progress < 0.8
                    ? AppTheme.warningColor
                    : AppTheme.successColor,
          ),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildGradeSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Your Grade',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            '${assignment.grade?.toStringAsFixed(0) ?? 'N/A'}/${assignment.totalPoints}',
            style: const TextStyle(
              fontSize: 16,
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
