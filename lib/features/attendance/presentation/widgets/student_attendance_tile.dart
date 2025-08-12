import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attendance_models.dart';

class StudentAttendanceTile extends StatelessWidget {
  final StudentWithAttendance studentWithAttendance;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(AttendanceStatus) onAttendanceChanged;

  const StudentAttendanceTile({
    super.key,
    required this.studentWithAttendance,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onAttendanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final attendance = studentWithAttendance.attendance;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Selection checkbox (if in selection mode)
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                ],

                // Student avatar
                _buildAvatar(),
                const SizedBox(width: 16),

                // Student info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentWithAttendance.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        studentWithAttendance.email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (attendance?.checkInTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Check-in: ${DateFormat('HH:mm').format(attendance!.checkInTime!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      if (attendance?.notes != null &&
                          attendance!.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: ${attendance!.notes}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Attendance status and quick actions
                if (!isSelectionMode) _buildAttendanceActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
      ),
      child: studentWithAttendance.avatarUrl != null &&
              studentWithAttendance.avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                studentWithAttendance.avatarUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitialsAvatar();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            )
          : _buildInitialsAvatar(),
    );
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.8),
            AppTheme.accentColor,
          ],
        ),
      ),
      child: Center(
        child: Text(
          studentWithAttendance.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceActions() {
    final attendance = studentWithAttendance.attendance;

    if (attendance == null) {
      // No attendance marked - show quick action buttons
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuickActionButton(
            icon: Icons.check,
            color: AppTheme.successColor,
            status: AttendanceStatus.present,
            tooltip: 'Present',
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            icon: Icons.close,
            color: AppTheme.errorColor,
            status: AttendanceStatus.absent,
            tooltip: 'Absent',
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            icon: Icons.access_time,
            color: AppTheme.warningColor,
            status: AttendanceStatus.late,
            tooltip: 'Late',
          ),
        ],
      );
    } else {
      // Attendance already marked - show status badge
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBadge(attendance.status),
          if (attendance.markedVia == AttendanceMarkedVia.gps) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 12,
                  color: attendance.locationVerified
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
                const SizedBox(width: 2),
                Text(
                  'GPS',
                  style: TextStyle(
                    fontSize: 10,
                    color: attendance.locationVerified
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required AttendanceStatus status,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => onAttendanceChanged(status),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case AttendanceStatus.present:
        backgroundColor = AppTheme.successColor;
        textColor = Colors.white;
        text = 'Present';
        icon = Icons.check;
        break;
      case AttendanceStatus.absent:
        backgroundColor = AppTheme.errorColor;
        textColor = Colors.white;
        text = 'Absent';
        icon = Icons.close;
        break;
      case AttendanceStatus.late:
        backgroundColor = AppTheme.warningColor;
        textColor = Colors.white;
        text = 'Late';
        icon = Icons.access_time;
        break;
      case AttendanceStatus.excused:
        backgroundColor = AppTheme.infoColor;
        textColor = Colors.white;
        text = 'Excused';
        icon = Icons.event_note;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
