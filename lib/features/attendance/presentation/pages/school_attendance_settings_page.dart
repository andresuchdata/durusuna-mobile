import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attendance_models.dart';
import '../../../../shared/services/attendance_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import '../../../../shared/services/auth_service.dart';

// Local provider for the service
final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

class SchoolAttendanceSettingsPage extends ConsumerStatefulWidget {
  const SchoolAttendanceSettingsPage({super.key});

  @override
  ConsumerState<SchoolAttendanceSettingsPage> createState() =>
      _SchoolAttendanceSettingsPageState();
}

class _SchoolAttendanceSettingsPageState
    extends ConsumerState<SchoolAttendanceSettingsPage> {
  SchoolAttendanceSettings? _settings;
  bool _isLoading = true;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  bool _requireLocation = true;
  bool _allowLate = true;
  int _lateThresholdMinutes = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authStateProvider);
      final schoolId = auth.user?.schoolId;
      if (schoolId == null) {
        setState(() {
          _error = 'No school assigned to this account';
          _isLoading = false;
        });
        return;
      }
      final svc = ref.read(attendanceServiceProvider);
      final s = await svc.getSchoolAttendanceSettings(schoolId);
      setState(() {
        _settings = s;
        _isLoading = false;
        if (s != null) {
          // Existing settings - populate form
          _requireLocation = s.requireLocation;
          _allowLate = s.allowLateAttendance;
          _lateThresholdMinutes = s.lateThresholdMinutes;
          _latCtrl.text = (s.schoolLatitude ?? -0.900831).toStringAsFixed(6);
          _lngCtrl.text = (s.schoolLongitude ?? 100.375814).toStringAsFixed(6);
          _radiusCtrl.text = s.locationRadiusMeters.toString();
          _startCtrl.text = s.attendanceHours.start;
          _endCtrl.text = s.attendanceHours.end;
        } else {
          // New settings - set defaults
          _requireLocation = true;
          _allowLate = true;
          _lateThresholdMinutes = 15;
          _latCtrl.text = (-0.900831).toStringAsFixed(6);
          _lngCtrl.text = (100.375814).toStringAsFixed(6);
          _radiusCtrl.text = '100';
          _startCtrl.text = '08:00';
          _endCtrl.text = '15:00';
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Attendance Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.errorColor, size: 40),
            const SizedBox(height: 12),
            Text(_error ?? 'Error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final lat = double.tryParse(_latCtrl.text) ??
        (_settings?.schoolLatitude ?? -0.900831);
    final lng = double.tryParse(_lngCtrl.text) ??
        (_settings?.schoolLongitude ?? 100.375814);
    final radius = double.tryParse(_radiusCtrl.text) ??
        (_settings?.locationRadiusMeters.toDouble() ?? 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Location & Geofence'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require location to mark attendance'),
              value: _requireLocation,
              onChanged: (v) => setState(() => _requireLocation = v),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: (v) => (double.tryParse(v ?? '') == null)
                        ? 'Invalid latitude'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: (v) => (double.tryParse(v ?? '') == null)
                        ? 'Invalid longitude'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Radius (meters)'),
              validator: (v) =>
                  (int.tryParse(v ?? '') == null) ? 'Invalid radius' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: latlng.LatLng(lat, lng),
                    initialZoom: 16,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _latCtrl.text = point.latitude.toStringAsFixed(6);
                        _lngCtrl.text = point.longitude.toStringAsFixed(6);
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'durusuna_mobile',
                    ),
                    CircleLayer(circles: [
                      CircleMarker(
                        point: latlng.LatLng(lat, lng),
                        radius: radius,
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderColor:
                            AppTheme.primaryColor.withValues(alpha: 0.6),
                        borderStrokeWidth: 2,
                      ),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: latlng.LatLng(lat, lng),
                        alignment: Alignment.center,
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 28),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Attendance Hours'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Start (HH:MM)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endCtrl,
                    decoration: const InputDecoration(labelText: 'End (HH:MM)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow late attendance'),
              value: _allowLate,
              onChanged: (v) => setState(() => _allowLate = v),
            ),
            if (_allowLate) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _lateThresholdMinutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Late threshold (minutes)'),
                validator: (v) =>
                    (int.tryParse(v ?? '') == null) ? 'Invalid minutes' : null,
                onChanged: (v) => _lateThresholdMinutes = int.tryParse(v) ?? 15,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Settings',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final auth = ref.read(authStateProvider);
      final schoolId = auth.user!.schoolId!;
      final svc = ref.read(attendanceServiceProvider);
      final updated = await svc.updateSchoolAttendanceSettings(
        schoolId,
        SchoolAttendanceSettings(
          id: _settings?.id ?? 'temp',
          schoolId: schoolId,
          requireLocation: _requireLocation,
          schoolLatitude: double.tryParse(_latCtrl.text),
          schoolLongitude: double.tryParse(_lngCtrl.text),
          locationRadiusMeters: int.parse(_radiusCtrl.text),
          attendanceHours:
              AttendanceHours(start: _startCtrl.text, end: _endCtrl.text),
          allowLateAttendance: _allowLate,
          lateThresholdMinutes: _lateThresholdMinutes,
          createdAt: _settings?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      setState(() => _settings = updated);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
