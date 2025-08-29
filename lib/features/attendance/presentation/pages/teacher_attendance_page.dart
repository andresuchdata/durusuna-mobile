import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
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

// Provider for teacher classes (for attendance)
final teacherClassesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final service = ref.read(attendanceServiceProvider);
  return await service.getTeacherClassesForAttendance();
});

class TeacherAttendancePage extends ConsumerStatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  ConsumerState<TeacherAttendancePage> createState() =>
      _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends ConsumerState<TeacherAttendancePage>
    with TickerProviderStateMixin {
  bool _isMarkingAttendance = false;
  AttendanceRecord? _markedAttendance;
  late AnimationController _locationAnimationController;
  late AnimationController _successAnimationController;
  Position? _currentPosition;
  SchoolAttendanceSettings? _schoolSettings;
  MapController? _mapController;
  Map<String, bool> _attendanceStatus =
      {}; // Track which classes have attendance submitted
  bool _isCheckingAttendanceStatus =
      false; // Prevent multiple concurrent checks

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

    _mapController = MapController();

    // Preload current position and school settings for map/header display
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authStateProvider);
      final user = auth.user;
      if (user?.schoolId != null) {
        try {
          final settings = await ref
              .read(attendanceServiceProvider)
              .getSchoolAttendanceSettings(user!.schoolId!);
          setState(() => _schoolSettings = settings);
        } catch (_) {}
      }
      try {
        final pos =
            await ref.read(attendanceServiceProvider).getCurrentLocation();
        setState(() => _currentPosition = pos);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _locationAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  Widget _buildInlineMapPreview() {
    final schoolLat = _schoolSettings!.schoolLatitude ?? -0.900831;
    final schoolLng = _schoolSettings!.schoolLongitude ?? 100.375814;
    final userLat = _currentPosition!.latitude;
    final userLng = _currentPosition!.longitude;

    final distanceMeters =
        Geolocator.distanceBetween(userLat, userLng, schoolLat, schoolLng);

    final markers = [
      Marker(
        width: 40,
        height: 40,
        point: latlng.LatLng(schoolLat, schoolLng),
        alignment: Alignment.center,
        child: const Icon(Icons.school, color: Colors.blueAccent, size: 26),
      ),
      Marker(
        width: 40,
        height: 40,
        point: latlng.LatLng(userLat, userLng),
        alignment: Alignment.center,
        child: const Icon(Icons.my_location, color: Colors.red, size: 26),
      ),
    ];
    final geofence = [
      CircleMarker(
        point: latlng.LatLng(schoolLat, schoolLng),
        radius: (_schoolSettings!.locationRadiusMeters).toDouble(),
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderStrokeWidth: 2,
        borderColor: AppTheme.primaryColor.withValues(alpha: 0.6),
      )
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: latlng.LatLng(userLat, userLng),
                initialZoom: 16,
                onMapReady: () {
                  final bounds = LatLngBounds.fromPoints([
                    latlng.LatLng(userLat, userLng),
                    latlng.LatLng(schoolLat, schoolLng),
                  ]);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    _mapController?.fitCamera(
                      CameraFit.bounds(
                          bounds: bounds, padding: const EdgeInsets.all(60)),
                    );
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'durusuna_mobile',
                ),
                CircleLayer(circles: geofence),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Distance to school: ${distanceMeters.toStringAsFixed(0)} m',
          style: TextStyle(
            fontSize: 12,
            color: distanceMeters <= (_schoolSettings!.locationRadiusMeters)
                ? AppTheme.successColor
                : AppTheme.warningColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

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

    final classesAsync = ref.watch(teacherClassesProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Teacher Attendance',
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
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Teacher GPS Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currentPosition != null
                      ? 'Your location: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'
                      : 'Select your class to mark teacher attendance using your current location.',
                  style: const TextStyle(
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
                        _schoolSettings?.attendanceHours != null
                            ? 'You must be within the school premises to mark attendance'
                            : 'Fetching school location settings...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_schoolSettings != null && _currentPosition != null) ...[
                  const SizedBox(height: 12),
                  _buildInlineMapPreview(),
                ],
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
    // Only check attendance status once when classes are first loaded
    if (_attendanceStatus.isEmpty && classes.isNotEmpty) {
      _checkAttendanceStatusOnce(classes);
    }

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
                'You are not assigned to any classes yet.',
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
        ...classes.map((classModel) {
          final geofenceDisabled = _computeGeofenceDisabled();
          final hasSubmittedAttendance =
              _attendanceStatus[classModel.id] ?? false;

          // Combine geofence and attendance status
          final isDisabled =
              geofenceDisabled.isDisabled || hasSubmittedAttendance;
          final disabledReason = hasSubmittedAttendance
              ? 'Attendance already submitted for today'
              : geofenceDisabled.reason;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClassSelectionCard(
              classModel: classModel,
              onTap: () => _markAttendanceForClass(classModel),
              isLoading: _isMarkingAttendance,
              isDisabled: isDisabled,
              disabledReason: disabledReason,
            ),
          );
        }).toList(),
      ],
    );
  }

  void _checkAttendanceStatusOnce(List<ClassModel> classes) {
    // Avoid calling if we're already checking or have results
    if (_isCheckingAttendanceStatus || _attendanceStatus.isNotEmpty) {
      return;
    }

    _isCheckingAttendanceStatus = true;
    _checkAttendanceStatus(classes).whenComplete(() {
      _isCheckingAttendanceStatus = false;
    });
  }

  Future<void> _checkAttendanceStatus(List<ClassModel> classes) async {
    final service = ref.read(attendanceServiceProvider);

    // Rate limiting: Add delay between requests to avoid hitting rate limits
    for (int i = 0; i < classes.length; i++) {
      final classModel = classes[i];
      try {
        final status = await service.getTeacherAttendanceStatus(DateTime.now());
        if (mounted) {
          setState(() {
            _attendanceStatus[classModel.id] = status != null;
          });
        }

        // Add delay between requests to prevent rate limiting (except for last request)
        if (i < classes.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('Error checking attendance status for ${classModel.id}: $e');
        // Default to false if we can't check - allows user to proceed
        if (mounted) {
          setState(() {
            _attendanceStatus[classModel.id] = false;
          });
        }

        // If we get a rate limit error, increase delay for subsequent requests
        if (e.toString().contains('429') ||
            e.toString().contains('Too many requests')) {
          debugPrint(
              'Rate limit detected, increasing delay for subsequent requests');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  DisabledState _computeGeofenceDisabled() {
    // If school requires location verification, disable when user is outside radius
    if (_schoolSettings == null || _currentPosition == null) {
      return const DisabledState(false, null);
    }
    final requireLocation = _schoolSettings!.requireLocation;
    if (!requireLocation) {
      return const DisabledState(false, null);
    }
    final schoolLat = _schoolSettings!.schoolLatitude ?? -0.900831;
    final schoolLng = _schoolSettings!.schoolLongitude ?? 100.375814;
    final userLat = _currentPosition!.latitude;
    final userLng = _currentPosition!.longitude;
    final distanceMeters =
        Geolocator.distanceBetween(userLat, userLng, schoolLat, schoolLng);
    final maxMeters = _schoolSettings!.locationRadiusMeters.toDouble();
    final outside = distanceMeters > maxMeters;
    return outside
        ? DisabledState(true,
            'You are outside the allowed radius (${maxMeters.toStringAsFixed(0)} m). Move closer to the school to mark attendance.')
        : const DisabledState(false, null);
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
              onPressed: () => ref.invalidate(teacherClassesProvider),
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
              'Teacher Attendance Marked!',
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

      // Show attendance status selection dialog
      final attendanceData = await _showAttendanceStatusDialog();
      if (attendanceData == null) {
        // User cancelled
        if (mounted) {
          Navigator.of(context).pop();
        }
        setState(() {
          _isMarkingAttendance = false;
        });
        return;
      }

      final attendance = await service.submitTeacherAttendanceGPS(
        attendanceData.status,
        attendanceData.notes,
      );

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

  Future<AttendanceData?> _showAttendanceStatusDialog() async {
    return showDialog<AttendanceData>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Attendance Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(context, 'Present', '✅', AppTheme.successColor,
                AttendanceStatus.present),
            _buildStatusOption(context, 'Late', '⏰', AppTheme.warningColor,
                AttendanceStatus.late),
            _buildStatusOption(context, 'Absent', '❌', AppTheme.errorColor,
                AttendanceStatus.absent),
            _buildStatusOption(context, 'Excused', '📝', AppTheme.infoColor,
                AttendanceStatus.excused),
          ],
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

  Widget _buildStatusOption(BuildContext context, String label, String emoji,
      Color color, AttendanceStatus status) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
      title: Text(label),
      onTap: () => Navigator.of(context)
          .pop(AttendanceData(status: status, notes: null)),
    );
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
                  child: const Icon(
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
      case AttendanceStatus.sick:
        return Colors.purple;
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// Lightweight immutable holder for disabled state
class DisabledState {
  final bool isDisabled;
  final String? reason;
  const DisabledState(this.isDisabled, this.reason);
}

// Data class for attendance submission
class AttendanceData {
  final AttendanceStatus status;
  final String? notes;

  AttendanceData({required this.status, this.notes});
}
