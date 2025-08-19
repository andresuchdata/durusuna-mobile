import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attendance_models.dart';

class StudentAttendanceTile extends StatelessWidget {
  final StudentWithAttendance studentWithAttendance;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isDisabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(AttendanceStatus) onAttendanceChanged;

  const StudentAttendanceTile({
    super.key,
    required this.studentWithAttendance,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isDisabled,
    required this.onTap,
    required this.onLongPress,
    required this.onAttendanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final attendance = studentWithAttendance.attendance;
    final hasAttendance = attendance != null;

    // Debug print to check attendance data
    debugPrint(
        '${studentWithAttendance.displayName}: hasAttendance=$hasAttendance, attendance=$attendance');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(hasAttendance),
        borderRadius: BorderRadius.circular(12),
        border: _getBorderStyle(hasAttendance),
        boxShadow: hasAttendance
            ? [
                BoxShadow(
                  color: _getAttendanceColor().withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: _getAttendanceColor().withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          onLongPress: isDisabled ? null : onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Selection checkbox (if in selection mode)
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: isDisabled ? null : (_) => onTap(),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              studentWithAttendance.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (hasAttendance) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _getAttendanceColor(),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _getAttendanceColor()
                                        .withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getAttendanceIcon(),
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          // Debug indicator for development
                          if (_showDebugIndicator()) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              studentWithAttendance.email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (hasAttendance) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getAttendanceColor()
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getAttendanceColor()
                                      .withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'MARKED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getAttendanceColor(),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                      if ((attendance?.notes ?? '').isNotEmpty) ...[
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
    final hasAttendance = studentWithAttendance.attendance != null;

    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
            border: hasAttendance
                ? Border.all(
                    color: _getAttendanceColor().withValues(alpha: 0.8),
                    width: 3)
                : null,
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
        ),
        // Attendance status indicator on avatar
        if (hasAttendance)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _getAttendanceColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                _getAttendanceIcon(),
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
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
            enabled: !isDisabled,
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            icon: Icons.close,
            color: AppTheme.errorColor,
            status: AttendanceStatus.absent,
            tooltip: 'Absent',
            enabled: !isDisabled,
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            icon: Icons.access_time,
            color: AppTheme.warningColor,
            status: AttendanceStatus.late,
            tooltip: 'Late',
            enabled: !isDisabled,
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
    required bool enabled,
  }) {
    final button = Container(
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
    );
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: IgnorePointer(
          ignoring: !enabled,
          child: GestureDetector(
            onTap: () => onAttendanceChanged(status),
            child: button,
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
      case AttendanceStatus.sick:
        backgroundColor = Colors.purple;
        textColor = Colors.white;
        text = 'Sick';
        icon = Icons.sick;
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

  Color _getBackgroundColor(bool hasAttendance) {
    if (isSelected) {
      return AppTheme.primaryColor.withValues(alpha: 0.1);
    }

    // Debug highlighting for development
    if (_showDebugIndicator()) {
      return Colors.orange.withValues(alpha: 0.2);
    }

    if (hasAttendance) {
      return _getAttendanceColor().withValues(alpha: 0.25);
    }

    return Colors.white;
  }

  Border _getBorderStyle(bool hasAttendance) {
    if (isSelected) {
      return Border.all(color: AppTheme.primaryColor, width: 2);
    }

    if (hasAttendance) {
      return Border.all(
          color: _getAttendanceColor().withValues(alpha: 0.6), width: 2);
    }

    return Border.all(color: Colors.grey[200]!, width: 1);
  }

  Color _getAttendanceColor() {
    final attendance = studentWithAttendance.attendance;
    if (attendance == null) return Colors.grey;

    switch (attendance.status) {
      case AttendanceStatus.present:
        return AppTheme.successColor;
      case AttendanceStatus.absent:
        return AppTheme.errorColor;
      case AttendanceStatus.late:
        return AppTheme.warningColor;
      case AttendanceStatus.excused:
        return AppTheme.infoColor;
      case AttendanceStatus.sick:
        return Colors.purple;
    }
  }

  IconData _getAttendanceIcon() {
    final attendance = studentWithAttendance.attendance;
    if (attendance == null) return Icons.help;

    switch (attendance.status) {
      case AttendanceStatus.present:
        return Icons.check;
      case AttendanceStatus.absent:
        return Icons.close;
      case AttendanceStatus.late:
        return Icons.access_time;
      case AttendanceStatus.excused:
        return Icons.event_note;
      case AttendanceStatus.sick:
        return Icons.sick;
    }
  }

  /// Show debug indicator for development purposes
  /// Can be customized based on specific student ID, name, or other criteria
  bool _showDebugIndicator() {
    // In development, you can customize this condition:
    // - Check for specific student IDs
    // - Check for test data patterns
    // - Use environment variables
    // - Check for specific names for testing

    // Example: Show for students with specific pattern in name or ID
    const debugStudentIds = ['student1@asdf.com', 'student2@asdf.com'];
    if (debugStudentIds.contains(studentWithAttendance.email)) {
      return true;
    }

    // Example: Show for test students (adjust as needed)
    if (studentWithAttendance.displayName.toLowerCase().contains('test')) {
      return true;
    }

    return false; // Set to true to show for all students during debugging
  }
}
