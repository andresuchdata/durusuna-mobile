import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_theme.dart';
import '../widgets/assignment_list_view.dart';
import '../widgets/assignment_stats_card.dart';
import '../widgets/create_assignment_fab.dart';

class AssignmentsMainPage extends ConsumerStatefulWidget {
  const AssignmentsMainPage({super.key});

  @override
  ConsumerState<AssignmentsMainPage> createState() =>
      _AssignmentsMainPageState();
}

class _AssignmentsMainPageState extends ConsumerState<AssignmentsMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTeacher = user.userType == UserType.teacher;
    final isAdmin = user.role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Assignments',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          if (isTeacher || isAdmin)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              onPressed: () => _showAssignmentAnalytics(context),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value, user),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Assignment Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'templates',
                  child: ListTile(
                    leading: Icon(Icons.description),
                    title: Text('Assignment Templates'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: isTeacher || isAdmin ? 'All Assignments' : 'My Assignments',
            ),
            const Tab(text: 'Due Soon'),
            const Tab(text: 'Submitted'),
            const Tab(text: 'Graded'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats Cards Section
          if (isTeacher || isAdmin) _buildStatsSection(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AssignmentListView(
                  filterType: AssignmentFilterType.all,
                  userRole: _getUserRole(user),
                ),
                AssignmentListView(
                  filterType: AssignmentFilterType.dueSoon,
                  userRole: _getUserRole(user),
                ),
                AssignmentListView(
                  filterType: AssignmentFilterType.submitted,
                  userRole: _getUserRole(user),
                ),
                AssignmentListView(
                  filterType: AssignmentFilterType.graded,
                  userRole: _getUserRole(user),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (isTeacher || isAdmin)
          ? CreateAssignmentFab(
              onPressed: () => _createNewAssignment(context, user),
            )
          : null,
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Expanded(
            child: AssignmentStatsCard(
              title: 'Total',
              count: '24',
              subtitle: 'Assignments',
              color: AppTheme.primaryColor,
              icon: Icons.assignment,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: AssignmentStatsCard(
              title: 'Pending',
              count: '8',
              subtitle: 'To Grade',
              color: AppTheme.warningColor,
              icon: Icons.pending_actions,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: AssignmentStatsCard(
              title: 'Completed',
              count: '16',
              subtitle: 'This Month',
              color: AppTheme.successColor,
              icon: Icons.done_all,
            ),
          ),
        ],
      ),
    );
  }

  UserRoleType _getUserRole(User user) {
    if (user.role == UserRole.admin) return UserRoleType.admin;
    if (user.userType == UserType.teacher) return UserRoleType.teacher;
    return UserRoleType.student;
  }

  void _handleMenuAction(BuildContext context, String action, User user) {
    switch (action) {
      case 'settings':
        _navigateToAssignmentSettings(context);
        break;
      case 'templates':
        _navigateToAssignmentTemplates(context);
        break;
      case 'export':
        _exportAssignmentData(context);
        break;
    }
  }

  void _showAssignmentAnalytics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssignmentAnalyticsPage(),
      ),
    );
  }

  void _createNewAssignment(BuildContext context, User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateAssignmentPage(),
      ),
    );
  }

  void _navigateToAssignmentSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssignmentSettingsPage(),
      ),
    );
  }

  void _navigateToAssignmentTemplates(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssignmentTemplatesPage(),
      ),
    );
  }

  void _exportAssignmentData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality will be implemented'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }
}

enum AssignmentFilterType { all, dueSoon, submitted, graded }

enum UserRoleType { admin, teacher, student }

// Placeholder pages - these will be implemented separately
class AssignmentAnalyticsPage extends StatelessWidget {
  const AssignmentAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment Analytics')),
      body: const Center(child: Text('Analytics Page - To be implemented')),
    );
  }
}

class CreateAssignmentPage extends StatelessWidget {
  const CreateAssignmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Assignment')),
      body: const Center(
          child: Text('Create Assignment Page - To be implemented')),
    );
  }
}

class AssignmentSettingsPage extends StatelessWidget {
  const AssignmentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment Settings')),
      body: const Center(child: Text('Settings Page - To be implemented')),
    );
  }
}

class AssignmentTemplatesPage extends StatelessWidget {
  const AssignmentTemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment Templates')),
      body: const Center(child: Text('Templates Page - To be implemented')),
    );
  }
}
