import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';

class ClassAttendanceSummaryCard extends StatelessWidget {
  final Map<String, dynamic> classInfo;
  final VoidCallback onTap;

  const ClassAttendanceSummaryCard({
    super.key,
    required this.classInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAttendanceSession = classInfo['has_attendance_session'] ?? false;
    final isFinalized = classInfo['is_finalized'] ?? false;
    final studentCount = classInfo['student_count'] ?? 0;
    final presentCount = classInfo['present_count'] ?? 0;
    final absentCount = classInfo['absent_count'] ?? 0;
    final lateCount = classInfo['late_count'] ?? 0;
    final excusedCount = classInfo['excused_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classInfo['class_name'] ?? 'Unknown Class',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${classInfo['class_grade_level'] ?? ''} ${classInfo['class_section'] ?? ''}'
                              .trim(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusIndicator(hasAttendanceSession, isFinalized),
                ],
              ),
              const SizedBox(height: 12),

              // Student count
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$studentCount students',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              if (hasAttendanceSession) ...[
                const SizedBox(height: 8),
                _buildAttendanceStats(
                    presentCount, absentCount, lateCount, excusedCount),
              ] else ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'No attendance session',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool hasSession, bool isFinalized) {
    if (!hasSession) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Not Started',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (isFinalized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Finalized',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.successColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Active',
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAttendanceStats(int present, int absent, int late, int excused) {
    final total = present + absent + late + excused;
    final attendanceRate =
        total > 0 ? ((present + late + excused) / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attendance Rate: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '$attendanceRate%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getAttendanceRateColor(attendanceRate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStatChip('Present', present, AppTheme.successColor),
            const SizedBox(width: 4),
            _buildStatChip('Absent', absent, AppTheme.errorColor),
            const SizedBox(width: 4),
            _buildStatChip('Late', late, AppTheme.warningColor),
            const SizedBox(width: 4),
            _buildStatChip('Excused', excused, AppTheme.infoColor),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getAttendanceRateColor(int rate) {
    if (rate >= 90) return AppTheme.successColor;
    if (rate >= 75) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
