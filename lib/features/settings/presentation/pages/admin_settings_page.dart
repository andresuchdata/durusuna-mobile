import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../attendance/presentation/pages/school_attendance_settings_page.dart';

class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'School',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.location_on,
            title: 'Attendance Settings',
            subtitle: 'Geofence, hours, and location requirements',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SchoolAttendanceSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'System',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.people_alt_outlined,
            title: 'User Management',
            subtitle: 'Teachers, students, and roles (coming soon)',
            onTap: () {},
            enabled: false,
          ),
          _SettingTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Channels and defaults (coming soon)',
            onTap: () {},
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: AppTheme.primaryColor),
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: subtitle != null
              ? Text(subtitle!,
                  style: const TextStyle(color: AppTheme.textSecondary))
              : null,
          trailing:
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}
