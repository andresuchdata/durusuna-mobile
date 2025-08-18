import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../../core/constants/app_theme.dart';
import '../../features/assignments/presentation/pages/assignments_main_page.dart';
import '../../features/grading/pages/formula_templates_main_page.dart';
import '../../features/grading/pages/formula_builder_page.dart';

class EnhancedAppDrawer extends ConsumerWidget {
  const EnhancedAppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Drawer(child: Center(child: CircularProgressIndicator()));
    }

    return Drawer(
      child: Container(
        color: AppTheme.backgroundColor,
        child: Column(
          children: [
            _buildDrawerHeader(user),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Core Navigation
                  _buildSectionHeader('Navigation'),
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.chat,
                    title: 'Messages',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.class_,
                    title: 'Classes',
                    onTap: () => Navigator.pop(context),
                  ),

                  // Academic Management (Teachers & Admins)
                  if (user.userType == UserType.teacher ||
                      user.role == UserRole.admin) ...[
                    const Divider(height: 32),
                    _buildSectionHeader('Academic Management'),
                    _buildDrawerItem(
                      icon: Icons.assignment,
                      title: 'Assignments',
                      subtitle: 'Manage assignments and submissions',
                      onTap: () =>
                          _navigateToPage(context, const AssignmentsMainPage()),
                    ),
                    _buildDrawerItem(
                      icon: Icons.grade,
                      title: 'Grading',
                      subtitle: 'Grade submissions and manage scores',
                      onTap: () => _showGradingSubmenu(context, user),
                    ),
                    if (user.role == UserRole.admin) ...[
                      _buildDrawerItem(
                        icon: Icons.functions,
                        title: 'Formula Templates',
                        subtitle: 'Manage grading formulas',
                        onTap: () => _navigateToPage(
                            context, const FormulaTemplatesMainPage()),
                      ),
                      _buildDrawerItem(
                        icon: Icons.analytics,
                        title: 'Analytics',
                        subtitle: 'Academic performance insights',
                        onTap: () => _showComingSoon(context, 'Analytics'),
                      ),
                    ],
                  ],

                  // Grading Tools (Teachers)
                  if (user.userType == UserType.teacher) ...[
                    const Divider(height: 32),
                    _buildSectionHeader('Grading Tools'),
                    _buildDrawerItem(
                      icon: Icons.calculate,
                      title: 'Formula Builder',
                      subtitle: 'Create custom grading formulas',
                      onTap: () => _navigateToPage(
                          context, const FormulaBuilderPage(scope: 'school')),
                    ),
                    _buildDrawerItem(
                      icon: Icons.description,
                      title: 'My Formulas',
                      subtitle: 'View and edit your formulas',
                      onTap: () => _navigateToPage(
                          context, const FormulaTemplatesMainPage()),
                    ),
                  ],

                  // Student Features
                  if (user.userType == UserType.student) ...[
                    const Divider(height: 32),
                    _buildSectionHeader('My Learning'),
                    _buildDrawerItem(
                      icon: Icons.assignment_turned_in,
                      title: 'My Assignments',
                      subtitle: 'View assignments and submissions',
                      onTap: () =>
                          _navigateToPage(context, const AssignmentsMainPage()),
                    ),
                    _buildDrawerItem(
                      icon: Icons.grade,
                      title: 'My Grades',
                      subtitle: 'View grades and progress',
                      onTap: () => _showComingSoon(context, 'Grades'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.location_on,
                      title: 'Attendance',
                      subtitle: 'Mark attendance and view history',
                      onTap: () => _showComingSoon(context, 'Attendance'),
                    ),
                  ],

                  // Common Features
                  const Divider(height: 32),
                  _buildSectionHeader('Features'),
                  _buildDrawerItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    onTap: () => _showComingSoon(context, 'Notifications'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_month,
                    title: 'Calendar',
                    onTap: () => _showComingSoon(context, 'Calendar'),
                  ),

                  // Settings & Account
                  const Divider(height: 32),
                  _buildSectionHeader('Account'),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () => _showComingSoon(context, 'Settings'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () => _showComingSoon(context, 'Help'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Sign Out',
                    textColor: AppTheme.errorColor,
                    onTap: () => _signOut(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(User user) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.firstName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                _getRoleDisplayText(user),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              if (user.school?.name != null) ...[
                const SizedBox(height: 4),
                Text(
                  user.school!.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? AppTheme.textPrimary,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor ?? AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _showGradingSubmenu(BuildContext context, User user) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grading Tools',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('Grade Submissions'),
              subtitle: const Text('Review and grade student work'),
              onTap: () => _showComingSoon(context, 'Grade Submissions'),
            ),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Formula Builder'),
              subtitle: const Text('Create custom grading formulas'),
              onTap: () => _navigateToPage(
                  context, const FormulaBuilderPage(scope: 'school')),
            ),
            if (user.role == UserRole.admin)
              ListTile(
                leading: const Icon(Icons.functions),
                title: const Text('Formula Templates'),
                subtitle: const Text('Manage school grading templates'),
                onTap: () =>
                    _navigateToPage(context, const FormulaTemplatesMainPage()),
              ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Grade Analytics'),
              subtitle: const Text('View grading insights'),
              onTap: () => _showComingSoon(context, 'Grade Analytics'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayText(User user) {
    final role = user.role == UserRole.admin ? 'Admin' : '';
    final userType = user.userType.name.replaceFirst(
      user.userType.name[0],
      user.userType.name[0].toUpperCase(),
    );

    if (role.isNotEmpty) {
      return '$userType • $role';
    }
    return userType;
  }
}
