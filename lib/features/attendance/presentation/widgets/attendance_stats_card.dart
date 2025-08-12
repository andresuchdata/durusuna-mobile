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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rate badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getAttendanceRateColor(stats.attendanceRate)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics,
                    size: 16,
                    color: _getAttendanceRateColor(stats.attendanceRate)),
                const SizedBox(width: 4),
                Text(
                  '${stats.attendanceRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _getAttendanceRateColor(stats.attendanceRate),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(
                      icon: Icons.people,
                      label: 'Total',
                      value: stats.totalStudents.toString(),
                      color: AppTheme.textSecondary),
                  _chip(
                      icon: Icons.check_circle,
                      label: 'Present',
                      value: stats.present.toString(),
                      color: AppTheme.successColor),
                  _chip(
                      icon: Icons.cancel,
                      label: 'Absent',
                      value: stats.absent.toString(),
                      color: AppTheme.errorColor),
                  _chip(
                      icon: Icons.access_time,
                      label: 'Late',
                      value: stats.late.toString(),
                      color: AppTheme.warningColor),
                  if (stats.excused > 0)
                    _chip(
                        icon: Icons.event_note,
                        label: 'Excused',
                        value: stats.excused.toString(),
                        color: AppTheme.infoColor),
                  _chip(
                      icon: Icons.assignment_turned_in,
                      label: 'Marked',
                      value: '${stats.totalMarked}/${stats.totalStudents}',
                      color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
