import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attendance_models.dart';

class BulkActionsSheet extends StatefulWidget {
  final List<String> selectedStudentIds;
  final Function(AttendanceStatus, String?) onBulkUpdate;

  const BulkActionsSheet({
    super.key,
    required this.selectedStudentIds,
    required this.onBulkUpdate,
  });

  @override
  State<BulkActionsSheet> createState() => _BulkActionsSheetState();
}

class _BulkActionsSheetState extends State<BulkActionsSheet> {
  AttendanceStatus? _selectedStatus;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Bulk Update Attendance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Selected count
            Text(
              '${widget.selectedStudentIds.length} students selected',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // Status Selection
            const Text(
              'Mark as:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            // Status Options
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AttendanceStatus.values.map((status) {
                final isSelected = _selectedStatus == status;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getStatusColor(status)
                          : _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: isSelected
                              ? Colors.white
                              : _getStatusColor(status),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusDisplayName(status),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : _getStatusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Notes Section
            const Text(
              'Notes (Optional):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Add a note for all selected students...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
              maxLength: 200,
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedStatus != null ? _onConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update Attendance',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  void _onConfirm() {
    if (_selectedStatus != null) {
      final notes = _notesController.text.trim();
      widget.onBulkUpdate(
        _selectedStatus!,
        notes.isEmpty ? null : notes,
      );
      Navigator.of(context).pop();
    }
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
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

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
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

  String _getStatusDisplayName(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.excused:
        return 'Excused';
      case AttendanceStatus.sick:
        return 'Sick';
    }
  }
}
