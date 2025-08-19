import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../pages/teacher_offerings_page.dart';

class OfferingCard extends StatelessWidget {
  final MockOffering offering;
  final VoidCallback? onTap;
  final VoidCallback? onAssignmentsPressed;
  final VoidCallback? onStudentsPressed;

  const OfferingCard({
    super.key,
    required this.offering,
    this.onTap,
    this.onAssignmentsPressed,
    this.onStudentsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: offering.color,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Subject icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: offering.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSubjectIcon(offering.subjectName),
                        color: offering.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Subject and class info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  offering.subjectName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: offering.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  offering.subjectCode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: offering.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            offering.className,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Schedule and room info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              offering.schedule,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${offering.hoursPerWeek}h/week',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              offering.room,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${offering.studentCount} students',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Next class and status
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: _getNextClassColor(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getNextClassText(),
                        style: TextStyle(
                          fontSize: 13,
                          color: _getNextClassColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (offering.pendingGrades > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${offering.pendingGrades} pending',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onAssignmentsPressed,
                        icon: Icon(
                          Icons.assignment,
                          size: 16,
                          color: offering.color,
                        ),
                        label: const Text('Assignments'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: offering.color,
                          side: BorderSide(color: offering.color),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onStudentsPressed,
                        icon: const Icon(
                          Icons.people,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        label: const Text('Students'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.textSecondary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getSubjectIcon(String subjectName) {
    final subject = subjectName.toLowerCase();
    if (subject.contains('math')) {
      return Icons.calculate;
    } else if (subject.contains('physics') || subject.contains('science')) {
      return Icons.science;
    } else if (subject.contains('english') || subject.contains('language')) {
      return Icons.translate;
    } else if (subject.contains('history')) {
      return Icons.history_edu;
    } else if (subject.contains('art')) {
      return Icons.palette;
    } else if (subject.contains('music')) {
      return Icons.music_note;
    } else if (subject.contains('physical') || subject.contains('pe')) {
      return Icons.sports;
    } else if (subject.contains('islamic') || subject.contains('religion')) {
      return Icons.mosque;
    } else {
      return Icons.book;
    }
  }

  Color _getNextClassColor() {
    final now = DateTime.now();
    final timeDiff = offering.nextClass.difference(now);

    if (timeDiff.inHours < 2) {
      return AppTheme.errorColor; // Soon
    } else if (timeDiff.inHours < 24) {
      return AppTheme.warningColor; // Today
    } else {
      return AppTheme.textSecondary; // Later
    }
  }

  String _getNextClassText() {
    final now = DateTime.now();
    final timeDiff = offering.nextClass.difference(now);

    if (timeDiff.isNegative) {
      return 'Class ended';
    } else if (timeDiff.inMinutes < 60) {
      return 'Next class in ${timeDiff.inMinutes}m';
    } else if (timeDiff.inHours < 24) {
      return 'Next class in ${timeDiff.inHours}h';
    } else if (timeDiff.inDays == 1) {
      return 'Next class tomorrow';
    } else {
      return 'Next class in ${timeDiff.inDays} days';
    }
  }
}
