import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attendance_models.dart';

class AttendanceStatsCard extends StatelessWidget {
  final AttendanceStats stats;

  const AttendanceStatsCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Attendance Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getAttendanceRateColor(stats.attendanceRate)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${stats.attendanceRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getAttendanceRateColor(stats.attendanceRate),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Total',
                  value: stats.totalStudents.toString(),
                  color: AppTheme.textSecondary,
                  icon: Icons.people,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Present',
                  value: stats.present.toString(),
                  color: AppTheme.successColor,
                  icon: Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Absent',
                  value: stats.absent.toString(),
                  color: AppTheme.errorColor,
                  icon: Icons.cancel,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Late',
                  value: stats.late.toString(),
                  color: AppTheme.warningColor,
                  icon: Icons.access_time,
                ),
              ),
            ],
          ),

          if (stats.excused > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'Excused',
                    value: stats.excused.toString(),
                    color: AppTheme.infoColor,
                    icon: Icons.event_note,
                  ),
                ),
                // Add empty expanded widgets to maintain spacing
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attendance Rate',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${stats.totalMarked} of ${stats.totalStudents} marked',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: stats.totalStudents > 0
                      ? stats.totalMarked / stats.totalStudents
                      : 0,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getAttendanceRateColor(stats.attendanceRate),
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getAttendanceRateColor(double rate) {
    if (rate >= 90) {
      return AppTheme.successColor;
    } else if (rate >= 75) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.errorColor;
    }
  }
}
