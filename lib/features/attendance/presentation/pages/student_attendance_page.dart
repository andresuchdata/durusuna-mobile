import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/attendance_models.dart';
import '../../../../shared/services/attendance_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../widgets/class_selection_card.dart';
import '../widgets/attendance_success_animation.dart';

// Provider for attendance service
final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

// Provider for student classes (for attendance)
final studentClassesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final service = ref.read(attendanceServiceProvider);
  return await service.getStudentClassesForAttendance();
});

class StudentAttendancePage extends ConsumerStatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  ConsumerState<StudentAttendancePage> createState() =>
      _StudentAttendancePageState();
}

class _StudentAttendancePageState extends ConsumerState<StudentAttendancePage>
    with TickerProviderStateMixin {
  bool _isMarkingAttendance = false;
  AttendanceRecord? _markedAttendance;
  late AnimationController _locationAnimationController;
  late AnimationController _successAnimationController;

  @override
  void initState() {
    super.initState();
    _locationAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _locationAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    // Check if user is a student
    if (currentUser?.userType != UserType.student) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mark Attendance')),
        body: const Center(
          child: Text(
            'This feature is only available for students',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final classesAsync = ref.watch(studentClassesProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _markedAttendance != null
          ? _buildSuccessView()
          : _buildClassSelectionView(classesAsync),
    );
  }

  Widget _buildClassSelectionView(AsyncValue<List<ClassModel>> classesAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'GPS Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select your class to mark attendance using your current location.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You must be within the school premises to mark attendance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Classes List
          classesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => _buildErrorState(error.toString()),
            data: (classes) => _buildClassesList(classes),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList(List<ClassModel> classes) {
    if (classes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.class_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'No Classes Found',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are not enrolled in any classes yet.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Class',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ...classes
            .map((classModel) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClassSelectionCard(
                    classModel: classModel,
                    onTap: () => _markAttendanceForClass(classModel),
                    isLoading: _isMarkingAttendance,
                  ),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Classes',
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
              onPressed: () => ref.invalidate(studentClassesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AttendanceSuccessAnimation(
              controller: _successAnimationController,
              status: _markedAttendance!.status,
            ),
            const SizedBox(height: 32),
            const Text(
              'Attendance Marked!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(_markedAttendance!.status)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Marked as ${_getStatusDisplayName(_markedAttendance!.status)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(_markedAttendance!.status),
                ),
              ),
            ),
            if (_markedAttendance!.checkInTime != null) ...[
              const SizedBox(height: 16),
              Text(
                'Check-in time: ${_formatTime(_markedAttendance!.checkInTime!)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            if (_markedAttendance!.markedVia == AttendanceMarkedVia.gps) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: _markedAttendance!.locationVerified
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _markedAttendance!.locationVerified
                        ? 'Location verified'
                        : 'Location not verified',
                    style: TextStyle(
                      fontSize: 12,
                      color: _markedAttendance!.locationVerified
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAttendanceForClass(ClassModel classModel) async {
    if (_isMarkingAttendance) return;

    setState(() {
      _isMarkingAttendance = true;
    });

    try {
      // Show loading dialog
      _showLocationDialog();

      final service = ref.read(attendanceServiceProvider);
      final attendance = await service.markStudentAttendanceGPS(classModel.id);

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _markedAttendance = attendance;
        _isMarkingAttendance = false;
      });

      // Start success animation
      _successAnimationController.forward();
    } catch (e) {
      setState(() {
        _isMarkingAttendance = false;
      });

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error dialog
      _showErrorDialog(e.toString());
    }
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _locationAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_locationAnimationController.value * 0.1),
                  child: Icon(
                    Icons.location_searching,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Getting your location...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please wait while we verify your location',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
            ),
            const SizedBox(width: 8),
            const Text('Attendance Failed'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (error.contains('Location')) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ],
      ),
    );
  }

  void _openLocationSettings() async {
    await Geolocator.openLocationSettings();
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
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
