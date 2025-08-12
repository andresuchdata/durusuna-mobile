import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/attendance_models.dart';
import '../../../../shared/services/attendance_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../widgets/location_settings_card.dart';
import '../widgets/time_settings_card.dart';
import '../widgets/general_settings_card.dart';

// Provider for attendance service
final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

// Provider for school attendance settings
final schoolAttendanceSettingsProvider =
    FutureProvider.family<SchoolAttendanceSettings?, String>(
  (ref, schoolId) async {
    final service = ref.read(attendanceServiceProvider);
    return await service.getSchoolAttendanceSettings(schoolId);
  },
);

class AttendanceSettingsPage extends ConsumerStatefulWidget {
  const AttendanceSettingsPage({super.key});

  @override
  ConsumerState<AttendanceSettingsPage> createState() =>
      _AttendanceSettingsPageState();
}

class _AttendanceSettingsPageState
    extends ConsumerState<AttendanceSettingsPage> {
  bool _isSaving = false;
  SchoolAttendanceSettings? _currentSettings;

  // Form controllers
  final _schoolLatController = TextEditingController();
  final _schoolLonController = TextEditingController();
  final _radiusController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _lateThresholdController = TextEditingController();

  // Form state
  bool _requireLocation = false;
  bool _allowLateAttendance = true;

  @override
  void dispose() {
    _schoolLatController.dispose();
    _schoolLonController.dispose();
    _radiusController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _lateThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    // Check if user is admin
    if (currentUser?.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Settings')),
        body: const Center(
          child: Text(
            'Access denied - admin access required',
            style: TextStyle(color: AppTheme.errorColor),
          ),
        ),
      );
    }

    final settingsAsync =
        ref.watch(schoolAttendanceSettingsProvider(currentUser!.schoolId!));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Attendance Settings',
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
        actions: [
          if (_currentSettings != null)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
        data: (settings) {
          _initializeSettings(settings);
          return _buildSettingsForm();
        },
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
              'Unable to load settings',
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
              onPressed: () => ref.invalidate(schoolAttendanceSettingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'School Attendance Configuration',
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
                  'Configure how attendance works for your school, including location requirements and time settings.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Location Settings
          LocationSettingsCard(
            requireLocation: _requireLocation,
            schoolLatController: _schoolLatController,
            schoolLonController: _schoolLonController,
            radiusController: _radiusController,
            onRequireLocationChanged: (value) {
              setState(() {
                _requireLocation = value;
              });
            },
            onGetCurrentLocation: _getCurrentLocation,
          ),

          const SizedBox(height: 16),

          // Time Settings
          TimeSettingsCard(
            startTimeController: _startTimeController,
            endTimeController: _endTimeController,
            allowLateAttendance: _allowLateAttendance,
            lateThresholdController: _lateThresholdController,
            onAllowLateChanged: (value) {
              setState(() {
                _allowLateAttendance = value;
              });
            },
            onTimeSelected: _selectTime,
          ),

          const SizedBox(height: 16),

          // General Settings
          GeneralSettingsCard(
            allowLateAttendance: _allowLateAttendance,
            lateThresholdController: _lateThresholdController,
            onAllowLateChanged: (value) {
              setState(() {
                _allowLateAttendance = value;
              });
            },
          ),

          const SizedBox(height: 32),

          // Save Button (for mobile view)
          if (_currentSettings != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Settings',
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
    );
  }

  void _initializeSettings(SchoolAttendanceSettings? settings) {
    if (settings != null && _currentSettings == null) {
      _currentSettings = settings;

      setState(() {
        _requireLocation = settings.requireLocation;
        _allowLateAttendance = settings.allowLateAttendance;

        _schoolLatController.text = settings.schoolLatitude?.toString() ?? '';
        _schoolLonController.text = settings.schoolLongitude?.toString() ?? '';
        _radiusController.text = settings.locationRadiusMeters.toString();
        _startTimeController.text = settings.attendanceHours.start;
        _endTimeController.text = settings.attendanceHours.end;
        _lateThresholdController.text =
            settings.lateThresholdMinutes.toString();
      });
    } else if (settings == null && _currentSettings == null) {
      // Set default values for new settings
      setState(() {
        _requireLocation = false;
        _allowLateAttendance = true;
        _radiusController.text = '100';
        _startTimeController.text = '08:00';
        _endTimeController.text = '15:00';
        _lateThresholdController.text = '15';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final service = ref.read(attendanceServiceProvider);
      final position = await service.getCurrentLocation();

      setState(() {
        _schoolLatController.text = position.latitude.toString();
        _schoolLonController.text = position.longitude.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location set successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final currentTime = _parseTime(controller.text);

    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      final timeString =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      controller.text = timeString;
    }
  }

  TimeOfDay _parseTime(String timeString) {
    if (timeString.isEmpty) return const TimeOfDay(hour: 8, minute: 0);

    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _saveSettings() async {
    final authState = ref.read(authStateProvider);
    final currentUser = authState.user;

    if (currentUser?.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: School ID not found'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Validate required fields
      if (_requireLocation) {
        if (_schoolLatController.text.isEmpty ||
            _schoolLonController.text.isEmpty) {
          throw Exception(
              'School location coordinates are required when location verification is enabled');
        }
      }

      if (_startTimeController.text.isEmpty ||
          _endTimeController.text.isEmpty) {
        throw Exception('Attendance start and end times are required');
      }

      // Create settings object
      final settings = SchoolAttendanceSettings(
        id: _currentSettings?.id ?? '',
        schoolId: currentUser!.schoolId!,
        requireLocation: _requireLocation,
        schoolLatitude: _schoolLatController.text.isNotEmpty
            ? double.tryParse(_schoolLatController.text)
            : null,
        schoolLongitude: _schoolLonController.text.isNotEmpty
            ? double.tryParse(_schoolLonController.text)
            : null,
        locationRadiusMeters: int.tryParse(_radiusController.text) ?? 100,
        attendanceHours: AttendanceHours(
          start: _startTimeController.text,
          end: _endTimeController.text,
        ),
        allowLateAttendance: _allowLateAttendance,
        lateThresholdMinutes: int.tryParse(_lateThresholdController.text) ?? 15,
        createdAt: _currentSettings?.createdAt ?? DateTime.now(),
      );

      final service = ref.read(attendanceServiceProvider);
      final updatedSettings = await service.updateSchoolAttendanceSettings(
        currentUser.schoolId!,
        settings,
      );

      setState(() {
        _currentSettings = updatedSettings;
      });

      // Refresh the provider
      ref.invalidate(schoolAttendanceSettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance settings saved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
}
