import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/services/subjects_service.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../assignments/presentation/pages/assignments_main_page.dart';
import '../../../grading/pages/formula_templates_main_page.dart';
import '../widgets/subject_card.dart';
import '../widgets/subject_stats_card.dart';
import 'subject_offering_details_page.dart';

class SubjectsMainPage extends ConsumerStatefulWidget {
  const SubjectsMainPage({super.key});

  @override
  ConsumerState<SubjectsMainPage> createState() => _SubjectsMainPageState();
}

class _SubjectsMainPageState extends ConsumerState<SubjectsMainPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  // int _selectedIndex = 0; // Future use for navigation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: Text(
          isAdmin ? 'All Subjects' : 'My Subjects',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSubjectSearch(context),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _createNewSubject(context),
            ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value, user),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter',
                child: ListTile(
                  leading: Icon(Icons.filter_list),
                  title: Text('Filter Subjects'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'manage_teachers',
                  child: ListTile(
                    leading: Icon(Icons.person_add),
                    title: Text('Manage Teachers'),
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
            Tab(text: isAdmin ? 'All Subjects' : 'Teaching'),
            Tab(text: isAdmin ? 'By Grade' : 'Collaborating'),
            const Tab(text: 'Archive'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats Cards Section
          if (isTeacher || isAdmin) _buildStatsSection(user),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubjectsList(SubjectFilterType.active, user),
                _buildSubjectsList(SubjectFilterType.grade, user),
                _buildSubjectsList(SubjectFilterType.archived, user),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _createNewSubject(context),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildStatsSection(User user) {
    return Consumer(
      builder: (context, ref, child) {
        final statsAsync = ref.watch(userSubjectStatsProvider);

        return Container(
          padding: const EdgeInsets.all(16),
          child: statsAsync.when(
            loading: () => Row(
              children: [
                Expanded(child: _buildLoadingStatsCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildLoadingStatsCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildLoadingStatsCard()),
              ],
            ),
            error: (error, stack) => const Row(
              children: [
                Expanded(
                  child: SubjectStatsCard(
                    title: 'Active Subjects',
                    count: '--',
                    subtitle: 'Error loading',
                    icon: Icons.book,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SubjectStatsCard(
                    title: 'Total Students',
                    count: '--',
                    subtitle: 'Error loading',
                    icon: Icons.people,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SubjectStatsCard(
                    title: 'Pending Tasks',
                    count: '--',
                    subtitle: 'Error loading',
                    icon: Icons.assignment_late,
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            data: (stats) => Row(
              children: [
                Expanded(
                  child: SubjectStatsCard(
                    title: 'Active Subjects',
                    count: '${stats.activeSubjects}',
                    subtitle: 'Currently teaching',
                    icon: Icons.book,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SubjectStatsCard(
                    title: 'Total Students',
                    count: '${stats.totalStudents}',
                    subtitle: 'Across all subjects',
                    icon: Icons.people,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SubjectStatsCard(
                    title: 'Pending Tasks',
                    count: '${stats.pendingTasks}',
                    subtitle: 'Assignments to grade',
                    icon: Icons.assignment_late,
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingStatsCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildSubjectsList(SubjectFilterType filterType, User user) {
    return Consumer(
      builder: (context, ref, child) {
        final subjectsAsync = ref.watch(userSubjectsProvider);

        return subjectsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load subjects',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(userSubjectsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (allSubjects) {
            final filteredSubjects =
                _filterSubjects(allSubjects, filterType, user);

            if (filteredSubjects.isEmpty) {
              return _buildEmptyState(filterType, user);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredSubjects.length,
              itemBuilder: (context, index) {
                final subjectOffering = filteredSubjects[index];
                // Convert SubjectOffering to MockSubject for compatibility
                final mockSubject = _convertToMockSubject(subjectOffering);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SubjectCard(
                    subject: mockSubject,
                    onTap: () => _navigateToOfferingDetails(subjectOffering),
                    onAssignmentsPressed: () =>
                        _navigateToSubjectAssignments(mockSubject),
                    onGradingPressed: () =>
                        _navigateToSubjectGrading(mockSubject),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<SubjectOffering> _filterSubjects(
      List<SubjectOffering> subjects, SubjectFilterType filterType, User user) {
    switch (filterType) {
      case SubjectFilterType.active:
        return subjects; // All subjects are considered active
      case SubjectFilterType.grade:
        // Group by grade level or show collaborative subjects
        return subjects.where((s) => s.gradeLevel.isNotEmpty).toList();
      case SubjectFilterType.archived:
        return []; // No archived subjects for now
    }
  }

  MockSubject _convertToMockSubject(SubjectOffering offering) {
    return MockSubject(
      id: offering.id,
      name: offering.subjectName,
      code: offering.subjectCode,
      grade: offering.gradeLevel,
      studentCount: offering.studentCount,
      assignmentsCount: offering.assignmentsCount,
      pendingGrades: offering.pendingGrades,
      teacher: offering.teacherName,
      color: Color(offering.color['primary'] ?? 0xFF757575),
      schedule: _formatSchedule(offering.schedule),
    );
  }

  String _formatSchedule(Map<String, dynamic> schedule) {
    // Format schedule from backend JSON to display string
    if (schedule.isEmpty) return 'TBD';

    // You can expand this based on your schedule format
    return 'See schedule'; // Placeholder
  }

  Widget _buildEmptyState(SubjectFilterType filterType, User user) {
    String message;
    String actionText;
    IconData icon;

    switch (filterType) {
      case SubjectFilterType.active:
        if (user.role == UserRole.admin) {
          message = 'No subjects found';
          actionText = 'Create Subject';
          icon = Icons.book;
        } else {
          message = 'No subjects assigned yet';
          actionText = 'Contact Admin';
          icon = Icons.school;
        }
        break;
      case SubjectFilterType.grade:
        message = 'No collaborative subjects';
        actionText = 'Browse Available';
        icon = Icons.group;
        break;
      case SubjectFilterType.archived:
        message = 'No archived subjects';
        actionText = 'View Active';
        icon = Icons.archive;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _handleEmptyStateAction(filterType, user),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  void _showSubjectSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: SubjectSearchDelegate(),
    );
  }

  void _createNewSubject(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create Subject - Under Development')),
    );
  }

  void _handleMenuAction(BuildContext context, String action, User user) {
    switch (action) {
      case 'filter':
        _showFilterDialog(context);
        break;
      case 'manage_teachers':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manage Teachers - Under Development')),
        );
        break;
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export Data - Under Development')),
        );
        break;
    }
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Subjects'),
        content: const Text('Filter options will be available soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleEmptyStateAction(SubjectFilterType filterType, User user) {
    switch (filterType) {
      case SubjectFilterType.active:
        if (user.role == UserRole.admin) {
          _createNewSubject(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Contact administrator for subject assignment')),
          );
        }
        break;
      case SubjectFilterType.grade:
        _tabController.animateTo(0);
        break;
      case SubjectFilterType.archived:
        _tabController.animateTo(0);
        break;
    }
  }

  void _navigateToOfferingDetails(SubjectOffering offering) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubjectOfferingDetailsPage(offering: offering),
      ),
    );
  }

  void _navigateToSubjectAssignments(MockSubject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssignmentsMainPage(),
      ),
    );
  }

  void _navigateToSubjectGrading(MockSubject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FormulaTemplatesMainPage(),
      ),
    );
  }
}

// Enums and Models
enum SubjectFilterType { active, grade, archived }

class MockSubject {
  final String id;
  final String name;
  final String code;
  final String grade;
  final int studentCount;
  final int assignmentsCount;
  final int pendingGrades;
  final String teacher;
  final Color color;
  final String schedule;

  MockSubject({
    required this.id,
    required this.name,
    required this.code,
    required this.grade,
    required this.studentCount,
    required this.assignmentsCount,
    required this.pendingGrades,
    required this.teacher,
    required this.color,
    required this.schedule,
  });
}

// Search Delegate
class SubjectSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, ''),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return const Center(
      child: Text('Search results will be implemented'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Search functionality will be implemented'),
    );
  }
}
