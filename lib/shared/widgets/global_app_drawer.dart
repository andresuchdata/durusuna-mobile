import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/global_auth_handler.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/class_management/presentation/pages/class_management_page.dart';
import '../../features/home/presentation/pages/enhanced_home_page_concept.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/subjects/presentation/pages/subjects_main_page.dart';
import '../../features/offerings/presentation/pages/teacher_offerings_page.dart';

class GlobalAppDrawer extends ConsumerWidget {
  const GlobalAppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) return const SizedBox.shrink();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(context, user),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard,
                    title: 'Home / Dashboard',
                    onTap: () => _navigateToHome(context),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.message,
                    title: 'Messages',
                    onTap: () => _navigateToMessages(context),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.class_,
                    title: 'Classes',
                    onTap: () => _navigateToClasses(context),
                  ),
                  if (user.userType == UserType.teacher ||
                      user.role == UserRole.admin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.book,
                      title: user.role == UserRole.admin
                          ? 'All Subjects'
                          : 'My Subjects',
                      onTap: () => _navigateToSubjects(context),
                    ),
                  if (user.userType == UserType.teacher)
                    _buildDrawerItem(
                      context,
                      icon: Icons.schedule,
                      title: 'My Offerings',
                      onTap: () => _navigateToOfferings(context),
                    ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.assignment,
                    title: 'Assignments',
                    onTap: () => _navigateToAssignments(context),
                  ),
                  const Divider(height: 32),
                  _buildDrawerItem(
                    context,
                    icon: Icons.info_outline,
                    title: 'About this app',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.logout,
                    title: 'Log out',
                    onTap: () => _showLogoutDialog(context, ref),
                    textColor: AppTheme.errorColor,
                    iconColor: AppTheme.errorColor,
                  ),
                ],
              ),
            ),
            _buildDrawerFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, User user) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          '${user.firstName[0]}${user.lastName[0]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              user.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getUserTypeLabel(user.userType),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppTheme.textSecondary,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Durusuna App',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _navigateToClasses(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ClassManagementPage(),
      ),
    );
  }

  void _navigateToClassUpdates(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    // Navigate to class updates - for now show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Please select a class from Classes page to view updates'),
      ),
    );
  }

  void _navigateToSubjects(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubjectsMainPage(),
      ),
    );
  }

  void _navigateToOfferings(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TeacherOfferingsPage(),
      ),
    );
  }

  void _navigateToAssignments(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assignments feature coming soon')),
    );
  }

  void _navigateToMessages(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ConversationsPage(),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    Navigator.of(context).pop(); // Close drawer
    showAboutDialog(
      context: context,
      applicationName: 'Durusuna',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.school,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text(
          'Durusuna is a comprehensive school management system that connects teachers, students, and parents in one unified platform.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Features:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('• Class management and updates'),
        const Text('• Real-time messaging'),
        const Text('• Assignment tracking'),
        const Text('• Grade management'),
        const Text('• Parent-teacher communication'),
        const SizedBox(height: 16),
        Text(
          '© 2024 Durusuna. All rights reserved.',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop(); // Close drawer
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // Use GlobalAuthHandler for consistent logout behavior
                if (GlobalAuthHandler.isInitialized) {
                  await GlobalAuthHandler.logout(
                    message: 'You have been logged out successfully.',
                  );
                } else {
                  // Fallback: manual logout + navigation
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                }
              } catch (e) {
                // Fallback in case of any error
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _getUserTypeLabel(UserType userType) {
    switch (userType) {
      case UserType.teacher:
        return 'Teacher';
      case UserType.student:
        return 'Student';
      case UserType.parent:
        return 'Parent';
    }
  }
}
