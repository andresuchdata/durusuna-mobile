import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../assignments/presentation/pages/assignments_main_page.dart';
import '../../../grading/pages/formula_templates_main_page.dart';
import '../widgets/subject_card.dart';
import '../widgets/subject_stats_card.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: SubjectStatsCard(
              title: 'Active Subjects',
              count: user.role == UserRole.admin ? '24' : '6',
              subtitle: 'Currently teaching',
              icon: Icons.book,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SubjectStatsCard(
              title: 'Total Students',
              count: user.role == UserRole.admin ? '156' : '89',
              subtitle: 'Across all subjects',
              icon: Icons.people,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SubjectStatsCard(
              title: 'Pending Tasks',
              count: '12',
              subtitle: 'Assignments to grade',
              icon: Icons.assignment_late,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList(SubjectFilterType filterType, User user) {
    // Mock data - replace with actual provider
    final subjects = _getMockSubjects(filterType, user);

    if (subjects.isEmpty) {
      return _buildEmptyState(filterType, user);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SubjectCard(
            subject: subject,
            onTap: () => _navigateToSubjectDetails(subject),
            onAssignmentsPressed: () => _navigateToSubjectAssignments(subject),
            onGradingPressed: () => _navigateToSubjectGrading(subject),
          ),
        );
      },
    );
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

  List<MockSubject> _getMockSubjects(SubjectFilterType filterType, User user) {
    // Mock data - replace with actual API calls
    if (filterType == SubjectFilterType.archived) return [];

    final baseSubjects = [
      MockSubject(
        id: '1',
        name: 'Mathematics',
        code: 'MATH101',
        grade: 'Grade 10',
        studentCount: 32,
        assignmentsCount: 8,
        pendingGrades: 5,
        teacher: 'Ahmad Rahman',
        color: Colors.blue,
        schedule: 'Mon, Wed, Fri - 08:00',
      ),
      MockSubject(
        id: '2',
        name: 'English Literature',
        code: 'ENG201',
        grade: 'Grade 11',
        studentCount: 28,
        assignmentsCount: 12,
        pendingGrades: 3,
        teacher: 'Sarah Johnson',
        color: Colors.green,
        schedule: 'Tue, Thu - 10:00',
      ),
      MockSubject(
        id: '3',
        name: 'Islamic Studies',
        code: 'ISL101',
        grade: 'Grade 10',
        studentCount: 30,
        assignmentsCount: 6,
        pendingGrades: 2,
        teacher: 'Ustadz Mahmoud',
        color: Colors.teal,
        schedule: 'Daily - 07:30',
      ),
      MockSubject(
        id: '4',
        name: 'Science',
        code: 'SCI101',
        grade: 'Grade 9',
        studentCount: 25,
        assignmentsCount: 10,
        pendingGrades: 7,
        teacher: 'Dr. Fatima Ali',
        color: Colors.purple,
        schedule: 'Mon, Wed, Fri - 13:00',
      ),
    ];

    if (user.role == UserRole.admin) {
      return baseSubjects;
    } else {
      // Teachers see only their subjects
      return baseSubjects.take(2).toList();
    }
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

  void _navigateToSubjectDetails(MockSubject subject) {
    // Navigate to subject details with assignments, students, etc.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Subject Details: ${subject.name} - Under Development')),
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
