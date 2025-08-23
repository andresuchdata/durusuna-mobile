import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../assignments/presentation/pages/flexible_assignments_page.dart';
import '../../../grading/pages/formula_templates_main_page.dart';
import '../../../grading/pages/formula_builder_page.dart';
import '../../../subjects/presentation/pages/subjects_main_page.dart';
import '../../../offerings/presentation/pages/teacher_offerings_page.dart';

class AcademicQuickActions extends ConsumerWidget {
  const AcademicQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _getRoleText(user),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionGrid(context, user),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, User user) {
    final actions = _getActionsForUser(user, context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildActionCard(
          context: context,
          title: action.title,
          subtitle: action.subtitle,
          icon: action.icon,
          color: action.color,
          badge: action.badge,
          onTap: action.onTap,
        );
      },
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<QuickAction> _getActionsForUser(User user, BuildContext context) {
    final actions = <QuickAction>[];

    // Common actions for all users
    if (user.userType == UserType.teacher || user.role == UserRole.admin) {
      actions.add(
        QuickAction(
          title: user.role == UserRole.admin ? 'All Subjects' : 'My Subjects',
          subtitle: user.role == UserRole.admin
              ? 'Manage school subjects'
              : 'View assigned subjects',
          icon: Icons.book,
          color: AppTheme.primaryColor,
          onTap: () => _navigateToPage(context, const SubjectsMainPage()),
        ),
      );
    }

    actions.add(
      QuickAction(
        title: 'Assignments',
        subtitle: user.userType == UserType.student
            ? 'View my assignments'
            : 'Manage assignments',
        icon: Icons.assignment,
        color: user.userType == UserType.student
            ? AppTheme.primaryColor
            : AppTheme.successColor,
        badge: user.userType == UserType.student ? '3' : null,
        onTap: () => _navigateToPage(
            context,
            const FlexibleAssignmentsPage(
              params: AssignmentListParams(
                context: AssignmentNavigationContext.standalone,
                title: 'My Assignments',
                showClassFilter: true,
                showSubjectFilter: true,
                showStats: false,
              ),
            )),
      ),
    );

    // Teacher-specific offerings action
    if (user.userType == UserType.teacher) {
      actions.add(
        QuickAction(
          title: 'My Offerings',
          subtitle: 'Teaching schedule & classes',
          icon: Icons.schedule,
          color: AppTheme.accentColor,
          onTap: () => _navigateToPage(context, const TeacherOfferingsPage()),
        ),
      );
    }

    // Teacher and Admin specific actions
    if (user.userType == UserType.teacher || user.role == UserRole.admin) {
      actions.add(
        QuickAction(
          title: 'Grade Center',
          subtitle: 'Review submissions',
          icon: Icons.grade,
          color: AppTheme.successColor,
          badge: '8',
          onTap: () => _showComingSoon(context, 'Grade Center'),
        ),
      );

      actions.add(
        QuickAction(
          title: 'Formula Builder',
          subtitle: 'Create grading formula',
          icon: Icons.calculate,
          color: AppTheme.warningColor,
          onTap: () => _navigateToPage(
              context, const FormulaBuilderPage(scope: 'school')),
        ),
      );

      if (user.role == UserRole.admin) {
        actions.add(
          QuickAction(
            title: 'Formula Templates',
            subtitle: 'Manage templates',
            icon: Icons.functions,
            color: AppTheme.infoColor,
            onTap: () =>
                _navigateToPage(context, const FormulaTemplatesMainPage()),
          ),
        );
      } else {
        actions.add(
          QuickAction(
            title: 'Analytics',
            subtitle: 'Class performance',
            icon: Icons.analytics,
            color: AppTheme.infoColor,
            onTap: () => _showComingSoon(context, 'Analytics'),
          ),
        );
      }
    }

    // Student specific actions
    if (user.userType == UserType.student) {
      actions.add(
        QuickAction(
          title: 'My Grades',
          subtitle: 'View my grades',
          icon: Icons.grade,
          color: AppTheme.successColor,
          onTap: () => _showComingSoon(context, 'My Grades'),
        ),
      );

      actions.add(
        QuickAction(
          title: 'Attendance',
          subtitle: 'Mark attendance',
          icon: Icons.location_on,
          color: AppTheme.warningColor,
          onTap: () => _showComingSoon(context, 'Attendance'),
        ),
      );

      actions.add(
        QuickAction(
          title: 'Schedule',
          subtitle: 'View class schedule',
          icon: Icons.schedule,
          color: AppTheme.infoColor,
          onTap: () => _showComingSoon(context, 'Schedule'),
        ),
      );
    }

    return actions;
  }

  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  String _getRoleText(User user) {
    if (user.role == UserRole.admin) {
      return 'Administrator';
    }
    return user.userType.name.replaceFirst(
      user.userType.name[0],
      user.userType.name[0].toUpperCase(),
    );
  }
}

class QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    required this.onTap,
  });
}
