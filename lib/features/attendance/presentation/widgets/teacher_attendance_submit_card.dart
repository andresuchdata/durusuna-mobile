import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attendance_models.dart';
import '../../../../shared/services/attendance_service.dart';

class TeacherAttendanceSubmitCard extends StatefulWidget {
  final AttendanceRecord? attendanceRecord;
  final VoidCallback onAttendanceSubmitted;

  const TeacherAttendanceSubmitCard({
    super.key,
    this.attendanceRecord,
    required this.onAttendanceSubmitted,
  });

  @override
  State<TeacherAttendanceSubmitCard> createState() =>
      _TeacherAttendanceSubmitCardState();
}

class _TeacherAttendanceSubmitCardState
    extends State<TeacherAttendanceSubmitCard> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final hasAttendance = widget.attendanceRecord != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'My Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasAttendance) ...[
              _buildAttendanceStatus(widget.attendanceRecord!),
            ] else ...[
              _buildAttendanceSubmission(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStatus(AttendanceRecord record) {
    final statusColor = _getStatusColor(record.status);
    final statusEmoji = _getStatusEmoji(record.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            statusEmoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Submitted',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Status: ${record.status.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor.withValues(alpha: 0.8),
                  ),
                ),
                if (record.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${record.notes}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSubmission() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submit your attendance for today',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatusButton(
                'Present',
                '✅',
                AppTheme.successColor,
                AttendanceStatus.present,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusButton(
                'Late',
                '⏰',
                AppTheme.warningColor,
                AttendanceStatus.late,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusButton(
                'Absent',
                '❌',
                AppTheme.errorColor,
                AttendanceStatus.absent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusButton(
                'Excused',
                '📝',
                AppTheme.infoColor,
                AttendanceStatus.excused,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusButton(
    String label,
    String emoji,
    Color color,
    AttendanceStatus status,
  ) {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : () => _submitAttendance(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAttendance(AttendanceStatus status) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Show dialog for notes
      final notes = await _showNotesDialog();
      if (notes == null) {
        // User cancelled
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Submit attendance
      final service = AttendanceService();
      await service.submitTeacherAttendance(status, notes);

      widget.onAttendanceSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting attendance: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String?> _showNotesDialog() async {
    String notes = '';

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Notes (Optional)'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter any notes about your attendance...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) => notes = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(notes),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppTheme.successColor;
      case AttendanceStatus.late:
        return AppTheme.warningColor;
      case AttendanceStatus.absent:
        return AppTheme.errorColor;
      case AttendanceStatus.excused:
        return AppTheme.infoColor;
      case AttendanceStatus.sick:
        return AppTheme.warningColor;
    }
  }

  String _getStatusEmoji(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return '✅';
      case AttendanceStatus.late:
        return '⏰';
      case AttendanceStatus.absent:
        return '❌';
      case AttendanceStatus.excused:
        return '📝';
      case AttendanceStatus.sick:
        return '🤒';
    }
  }
}
