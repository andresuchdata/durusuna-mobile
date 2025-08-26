import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/attendance_models.dart';
import '../../../../shared/services/attendance_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../widgets/attendance_date_selector.dart';
import '../widgets/teacher_attendance_overview_card.dart';
import '../widgets/teacher_attendance_submit_card.dart';
import '../widgets/class_attendance_summary_card.dart';
import 'attendance_management_page.dart';

// Provider for teacher attendance overview
final teacherAttendanceOverviewProvider =
    FutureProvider.family<TeacherAttendanceOverview, DateTime>(
        (ref, date) async {
  final service = ref.read(attendanceServiceProvider);
  final authState = ref.read(authStateProvider);
  final user = authState.user;

  if (user == null) throw Exception('User not authenticated');

  return await service.getTeacherAttendanceOverview(date);
});

// Provider for teacher's own attendance status
final teacherAttendanceStatusProvider =
    FutureProvider.family<AttendanceRecord?, DateTime>((ref, date) async {
  final service = ref.read(attendanceServiceProvider);
  final authState = ref.read(authStateProvider);
  final user = authState.user;

  if (user == null) return null;

  try {
    return await service.getTeacherAttendanceStatus(date);
  } catch (e) {
    return null; // No attendance record found
  }
});

class TeacherAttendancePage extends ConsumerStatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  ConsumerState<TeacherAttendancePage> createState() =>
      _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends ConsumerState<TeacherAttendancePage> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    // Check if user is a teacher
    if (currentUser?.userType != UserType.teacher) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teacher Attendance')),
        body: const Center(
          child: Text(
            'Access denied - teacher access required',
            style: TextStyle(color: AppTheme.errorColor),
          ),
        ),
      );
    }

    final overviewAsync =
        ref.watch(teacherAttendanceOverviewProvider(_selectedDate));
    final teacherAttendanceAsync =
        ref.watch(teacherAttendanceStatusProvider(_selectedDate));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Teacher Attendance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherAttendanceOverviewProvider);
          ref.invalidate(teacherAttendanceStatusProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
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

              // Teacher's own attendance submission
              Container(
                margin: const EdgeInsets.all(16),
                child: teacherAttendanceAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, stack) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading attendance status: $error',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ),
                  data: (attendanceRecord) => TeacherAttendanceSubmitCard(
                    attendanceRecord: attendanceRecord,
                    onAttendanceSubmitted: _onTeacherAttendanceSubmitted,
                  ),
                ),
              ),

              // Overview of classes
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: overviewAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, stack) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading overview',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error.toString(),
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (overview) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TeacherAttendanceOverviewCard(overview: overview),
                      const SizedBox(height: 16),
                      if (overview.classes.isNotEmpty) ...[
                        const Text(
                          'My Classes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...overview.classes.map(
                          (classInfo) => ClassAttendanceSummaryCard(
                            classInfo: classInfo,
                            onTap: () => _navigateToClassAttendance(classInfo),
                          ),
                        ),
                      ] else ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.class_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No classes assigned',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You will see your classes here once they are assigned to you.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _onTeacherAttendanceSubmitted() {
    // Refresh the teacher attendance status
    ref.invalidate(teacherAttendanceStatusProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attendance submitted successfully'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _navigateToClassAttendance(Map<String, dynamic> classInfo) {
    // Navigate to the class attendance management page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AttendanceManagementPage(
          classModel: ClassModel(
            id: classInfo['class_id'],
            name: classInfo['class_name'],
            description: classInfo['class_description'] ?? '',
            gradeLevel: classInfo['class_grade_level'] ?? '',
            section: classInfo['class_section'] ?? '',
            academicYear: classInfo['class_academic_year'] ?? '',
            schoolId: '', // This will be set by the backend
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
      ),
    );
  }
}
