import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/attendance_models.dart';
import '../../../../shared/services/attendance_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../widgets/attendance_date_selector.dart';
import '../widgets/student_attendance_tile.dart';
import '../widgets/attendance_stats_card.dart';
import '../widgets/bulk_actions_sheet.dart';

// Provider for attendance service
final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

// Provider for attendance session
final attendanceSessionProvider =
    FutureProvider.family<AttendanceSessionResponse, (String, DateTime)>(
  (ref, params) async {
    final (classId, date) = params;
    final service = ref.read(attendanceServiceProvider);
    return await service.openAttendanceSession(classId, date);
  },
);

// Provider for attendance stats
final attendanceStatsProvider =
    FutureProvider.family<AttendanceStats, (String, DateTime)>(
  (ref, params) async {
    final (classId, date) = params;
    final service = ref.read(attendanceServiceProvider);
    return await service.getAttendanceStats(classId, date);
  },
);

class AttendanceManagementPage extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const AttendanceManagementPage({
    super.key,
    required this.classModel,
  });

  @override
  ConsumerState<AttendanceManagementPage> createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState
    extends ConsumerState<AttendanceManagementPage> {
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedStudentIds = {};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    // Check if user is a teacher
    if (currentUser?.userType != UserType.teacher) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: const Center(
          child: Text(
            'Access denied - teacher access required',
            style: TextStyle(color: AppTheme.errorColor),
          ),
        ),
      );
    }

    final attendanceSessionAsync = ref.watch(
        attendanceSessionProvider((widget.classModel.id, _selectedDate)));
    final attendanceStatsAsync = ref
        .watch(attendanceStatsProvider((widget.classModel.id, _selectedDate)));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
              ),
            ),
            Text(
              widget.classModel.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          attendanceSessionAsync.maybeWhen(
            data: (sessionResponse) =>
                _isSelectionMode && !sessionResponse.session.isFinalized
                    ? Row(children: [
                        IconButton(
                          icon: const Icon(Icons.select_all),
                          onPressed: _selectAllStudents,
                          tooltip: 'Select All',
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSelection,
                          tooltip: 'Clear Selection',
                        ),
                      ])
                    : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context),
            tooltip: 'More options',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: AttendanceDateSelector(
              selectedDate: _selectedDate,
              onDateChanged: _onDateChanged,
            ),
          ),

          // Stats Card
          attendanceStatsAsync.when(
            loading: () => const SizedBox(
                height: 100, child: Center(child: CircularProgressIndicator())),
            error: (error, stack) => Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                'Error loading stats: $error',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
            data: (stats) => AttendanceStatsCard(stats: stats),
          ),

          // Students List
          Expanded(
            child: attendanceSessionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error.toString()),
              data: (sessionResponse) => _buildStudentsList(sessionResponse),
            ),
          ),
        ],
      ),
      floatingActionButton: attendanceSessionAsync.maybeWhen(
        data: (sessionResponse) => sessionResponse.session.isFinalized
            ? null
            : (_isSelectionMode && _selectedStudentIds.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () => _showBulkActionsSheet(context),
                    icon: const Icon(Icons.edit),
                    label: Text('Edit ${_selectedStudentIds.length}'),
                    backgroundColor: AppTheme.primaryColor,
                  )
                : null),
        orElse: () => null,
      ),
      bottomNavigationBar: attendanceSessionAsync.maybeWhen(
        data: (sessionResponse) => _buildBottomActions(sessionResponse),
        orElse: () => null,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load attendance',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(attendanceSessionProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList(AttendanceSessionResponse sessionResponse) {
    if (sessionResponse.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'No students enrolled',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Students will appear here once they are enrolled in this class.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final bool isDisabled = sessionResponse.session.isFinalized;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sessionResponse.students.length,
      itemBuilder: (context, index) {
        final studentWithAttendance = sessionResponse.students[index];
        return StudentAttendanceTile(
          studentWithAttendance: studentWithAttendance,
          isSelected:
              _selectedStudentIds.contains(studentWithAttendance.userId),
          isSelectionMode: _isSelectionMode,
          isDisabled: isDisabled,
          onTap: () => _onStudentTap(studentWithAttendance),
          onLongPress: () => _onStudentLongPress(studentWithAttendance),
          onAttendanceChanged: (status) => _onAttendanceChanged(
            studentWithAttendance,
            status,
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(AttendanceSessionResponse sessionResponse) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: sessionResponse.session.isFinalized
                    ? null
                    : (_isSelectionMode ? null : () => _toggleSelectionMode()),
                icon: const Icon(Icons.checklist),
                label: const Text('Bulk Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: sessionResponse.session.isFinalized
                    ? null
                    : () => _finalizeAttendance(),
                icon: const Icon(Icons.check_circle),
                label: Text(
                  sessionResponse.session.isFinalized
                      ? 'Finalized'
                      : 'Finalize',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sessionResponse.session.isFinalized
                      ? Colors.grey
                      : AppTheme.successColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedStudentIds.clear();
      _isSelectionMode = false;
    });
  }

  void _onStudentTap(StudentWithAttendance student) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedStudentIds.contains(student.userId)) {
          _selectedStudentIds.remove(student.userId);
        } else {
          _selectedStudentIds.add(student.userId);
        }
      });
    } else {
      // Show individual attendance options
      _showAttendanceDialog(student);
    }
  }

  void _onStudentLongPress(StudentWithAttendance student) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedStudentIds.add(student.userId);
      });
    }
  }

  void _onAttendanceChanged(
      StudentWithAttendance student, AttendanceStatus status) async {
    try {
      debugPrint('Marking attendance for ${student.displayName} as $status');

      final service = ref.read(attendanceServiceProvider);
      final request = CreateAttendanceRequest(
        studentId: student.userId,
        status: status,
        checkInTime: status == AttendanceStatus.present ||
                status == AttendanceStatus.late
            ? DateTime.now()
            : null,
        markedVia: AttendanceMarkedVia.manual,
      );

      await service.markStudentAttendance(
        widget.classModel.id,
        student.userId,
        _selectedDate,
        request,
      );

      debugPrint('Attendance marked successfully, refreshing data...');

      // Refresh the attendance session
      ref.invalidate(attendanceSessionProvider);
      ref.invalidate(attendanceStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance updated for ${student.displayName}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating attendance: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedStudentIds.clear();
      }
    });
  }

  void _selectAllStudents() {
    final sessionResponse = ref
        .read(attendanceSessionProvider((widget.classModel.id, _selectedDate)));
    sessionResponse.whenData((response) {
      setState(() {
        _selectedStudentIds.addAll(
          response.students.map((s) => s.userId),
        );
      });
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStudentIds.clear();
      _isSelectionMode = false;
    });
  }

  void _showAttendanceDialog(StudentWithAttendance student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark Attendance - ${student.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AttendanceStatus.values.map((status) {
            final service = ref.read(attendanceServiceProvider);
            return ListTile(
              leading: Text(service.getAttendanceStatusEmoji(status)),
              title: Text(service.getAttendanceStatusDisplayName(status)),
              onTap: () {
                Navigator.of(context).pop();
                _onAttendanceChanged(student, status);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBulkActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => BulkActionsSheet(
        selectedStudentIds: _selectedStudentIds.toList(),
        onBulkUpdate: _onBulkUpdate,
      ),
    );
  }

  void _onBulkUpdate(AttendanceStatus status, String? notes) async {
    try {
      final service = ref.read(attendanceServiceProvider);
      final bulkUpdate = BulkAttendanceUpdate(
        records: _selectedStudentIds
            .map((studentId) => BulkAttendanceRecord(
                  studentId: studentId,
                  status: status,
                  notes: notes,
                ))
            .toList(),
        markedVia: AttendanceMarkedVia.manual,
      );

      await service.bulkUpdateAttendance(
        widget.classModel.id,
        _selectedDate,
        bulkUpdate,
      );

      // Refresh the attendance session
      ref.invalidate(attendanceSessionProvider);
      ref.invalidate(attendanceStatsProvider);

      setState(() {
        _selectedStudentIds.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Bulk attendance updated for ${_selectedStudentIds.length} students'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating bulk attendance: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _finalizeAttendance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize Attendance'),
        content: const Text(
          'Are you sure you want to finalize attendance for this date? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(attendanceServiceProvider);
        await service.finalizeAttendanceSession(
          widget.classModel.id,
          _selectedDate,
        );

        // Refresh the attendance session
        ref.invalidate(attendanceSessionProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance finalized successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error finalizing attendance: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('View Report'),
              onTap: () {
                Navigator.of(context).pop();
                _showAttendanceReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              onTap: () {
                Navigator.of(context).pop();
                _exportAttendanceData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Attendance Settings'),
              onTap: () {
                Navigator.of(context).pop();
                _showAttendanceSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceReport() {
    // Navigate to attendance report page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance report feature coming soon')),
    );
  }

  void _exportAttendanceData() {
    // Export attendance data functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  void _showAttendanceSettings() {
    // Show attendance settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance settings feature coming soon')),
    );
  }
}
