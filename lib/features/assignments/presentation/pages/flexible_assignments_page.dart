import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_theme.dart';
import '../widgets/assignment_list_view.dart';
import '../widgets/assignment_stats_card.dart';
import '../widgets/create_assignment_fab.dart';
import 'assignments_main_page.dart'; // For enums
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/assignment_providers.dart';
import '../../../../shared/services/subjects_service.dart' show SubjectOffering;
import '../../../../shared/services/assignments_service.dart';
import '../../../class_management/presentation/pages/class_management_page.dart'
    show userClassesProvider;

/// Navigation context for assignments
enum AssignmentNavigationContext {
  fromHome,
  fromClass,
  fromSubject,
  standalone,
}

/// Parameters for flexible assignment list navigation
class AssignmentListParams {
  final AssignmentNavigationContext context;
  final String? preSelectedClassId;
  final String? preSelectedSubjectId;
  final String? title;
  final bool showClassFilter;
  final bool showSubjectFilter;
  final bool showStats;

  const AssignmentListParams({
    required this.context,
    this.preSelectedClassId,
    this.preSelectedSubjectId,
    this.title,
    this.showClassFilter = true,
    this.showSubjectFilter = true,
    this.showStats = false,
  });
}

class FlexibleAssignmentsPage extends ConsumerStatefulWidget {
  final AssignmentListParams params;

  const FlexibleAssignmentsPage({
    super.key,
    required this.params,
  });

  @override
  ConsumerState<FlexibleAssignmentsPage> createState() =>
      _FlexibleAssignmentsPageState();
}

class _FlexibleAssignmentsPageState
    extends ConsumerState<FlexibleAssignmentsPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  String? _selectedClassId;
  String? _selectedSubjectId;
  String _selectedClassFilter = 'all';
  String _selectedSubjectFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.params.preSelectedClassId;
    _selectedSubjectId = widget.params.preSelectedSubjectId;

    // Set filter values based on pre-selected IDs
    if (_selectedClassId != null) {
      _selectedClassFilter = _selectedClassId!;
    }
    if (_selectedSubjectId != null) {
      _selectedSubjectFilter = _selectedSubjectId!;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
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
    final showTabs = isTeacher || isAdmin;

    // Initialize tab controller if needed for teachers/admins
    if (showTabs && _tabController == null) {
      _tabController = TabController(length: 4, vsync: this);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          _getPageTitle(widget.params, user),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
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
        bottom: showTabs
            ? TabBar(
                controller: _tabController!,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: isTeacher || isAdmin
                        ? 'All Assignments'
                        : 'My Assignments',
                  ),
                  const Tab(text: 'Due Soon'),
                  const Tab(text: 'Submitted'),
                  const Tab(text: 'Graded'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // Filter Section
          if (_shouldShowFilters()) _buildFilterSection(),

          // Search Section
          _buildSearchSection(),

          // Stats Cards Section
          if (widget.params.showStats && (isTeacher || isAdmin))
            _buildStatsSection(),

          // Tab Content or Simple Assignment List
          Expanded(
            child: showTabs
                ? TabBarView(
                    controller: _tabController!,
                    children: [
                      AssignmentListView(
                        filterType: AssignmentFilterType.all,
                        userRole: _getUserRole(user),
                        classId: _selectedClassId,
                        subjectId: _selectedSubjectId,
                        searchQuery: _searchQuery,
                      ),
                      AssignmentListView(
                        filterType: AssignmentFilterType.dueSoon,
                        userRole: _getUserRole(user),
                        classId: _selectedClassId,
                        subjectId: _selectedSubjectId,
                        searchQuery: _searchQuery,
                      ),
                      AssignmentListView(
                        filterType: AssignmentFilterType.submitted,
                        userRole: _getUserRole(user),
                        classId: _selectedClassId,
                        subjectId: _selectedSubjectId,
                        searchQuery: _searchQuery,
                      ),
                      AssignmentListView(
                        filterType: AssignmentFilterType.graded,
                        userRole: _getUserRole(user),
                        classId: _selectedClassId,
                        subjectId: _selectedSubjectId,
                        searchQuery: _searchQuery,
                      ),
                    ],
                  )
                : AssignmentListView(
                    filterType: AssignmentFilterType.all,
                    userRole: _getUserRole(user),
                    classId: _selectedClassId,
                    subjectId: _selectedSubjectId,
                    searchQuery: _searchQuery,
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

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search assignments by title...',
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Class Filter
              if (widget.params.showClassFilter) ...[
                Expanded(
                  child: _buildClassFilter(),
                ),
                const SizedBox(width: 12),
              ],
              // Subject Filter
              if (widget.params.showSubjectFilter) ...[
                Expanded(
                  child: _buildSubjectFilter(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassFilter() {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    // Use teacher-specific API for teachers, general API for others
    final userClassesAsync = user?.userType == UserType.teacher
        ? ref.watch(teacherAccessibleClassesProvider)
        : ref.watch(userClassesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Class',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: userClassesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Loading...',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Error loading classes',
                  style: TextStyle(color: AppTheme.errorColor)),
            ),
            data: (dynamic classes) {
              List<DropdownMenuItem<String>> classItems = [];
              List<String> availableValues = ['all'];

              if (user?.userType == UserType.teacher) {
                // Handle TeacherAccessibleClass list
                final teacherClasses = classes as List<TeacherAccessibleClass>;
                for (final classItem in teacherClasses) {
                  availableValues.add(classItem.classId);
                  classItems.add(
                    DropdownMenuItem(
                      value: classItem.classId,
                      child: Text(
                        classItem.className,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }
              } else {
                // Handle ClassModel list (students, parents, admins)
                final regularClasses = classes as List<dynamic>;
                for (final classModel in regularClasses) {
                  final classId = classModel.id;
                  final className = classModel.name;
                  availableValues.add(classId);
                  classItems.add(
                    DropdownMenuItem(
                      value: classId,
                      child: Text(
                        className,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }
              }

              // Ensure selected value exists in available options
              final validSelectedValue =
                  availableValues.contains(_selectedClassFilter)
                      ? _selectedClassFilter
                      : 'all';

              return DropdownButtonFormField<String>(
                value: validSelectedValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'All Classes',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...classItems,
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedClassFilter = value ?? 'all';
                    if (value == 'all') {
                      _selectedClassId = null;
                    } else {
                      _selectedClassId = value;
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectFilter() {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    // Use teacher-specific API for teachers, general API for others
    final userSubjectsAsync = user?.userType == UserType.teacher
        ? ref.watch(teacherAccessibleSubjectsProvider)
        : ref.watch(roleBasedSubjectOfferingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subject',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: userSubjectsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Loading...',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Error loading subjects',
                  style: TextStyle(color: AppTheme.errorColor)),
            ),
            data: (dynamic subjects) {
              List<DropdownMenuItem<String>> subjectItems = [];
              List<String> availableValues = ['all'];

              if (user?.userType == UserType.teacher) {
                // Handle TeacherAccessibleSubject list
                final teacherSubjects =
                    subjects as List<TeacherAccessibleSubject>;
                for (final subject in teacherSubjects) {
                  availableValues.add(subject.subjectId);
                  subjectItems.add(
                    DropdownMenuItem(
                      value: subject.subjectId,
                      child: Text(
                        subject.subjectName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }
              } else {
                // Handle SubjectOffering list (students, parents)
                final regularSubjects = subjects as List<SubjectOffering>;
                // Deduplicate subjects by subjectId
                final uniqueSubjects = regularSubjects
                    .fold<Map<String, SubjectOffering>>({}, (map, subject) {
                      map[subject.subjectId] = subject;
                      return map;
                    })
                    .values
                    .toList();

                for (final subject in uniqueSubjects) {
                  availableValues.add(subject.subjectId);
                  subjectItems.add(
                    DropdownMenuItem(
                      value: subject.subjectId,
                      child: Text(
                        subject.subjectName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }
              }

              // Ensure selected value exists in available options
              final validSelectedValue =
                  availableValues.contains(_selectedSubjectFilter)
                      ? _selectedSubjectFilter
                      : 'all';

              return DropdownButtonFormField<String>(
                value: validSelectedValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'All Subjects',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...subjectItems,
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSubjectFilter = value ?? 'all';
                    if (value == 'all') {
                      _selectedSubjectId = null;
                    } else {
                      _selectedSubjectId = value;
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
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

  bool _shouldShowFilters() {
    switch (widget.params.context) {
      case AssignmentNavigationContext.fromHome:
        return widget.params.showClassFilter || widget.params.showSubjectFilter;
      case AssignmentNavigationContext.fromClass:
        return widget.params.showSubjectFilter;
      case AssignmentNavigationContext.fromSubject:
        return false; // No filters needed when already filtered by subject
      case AssignmentNavigationContext.standalone:
        return widget.params.showClassFilter || widget.params.showSubjectFilter;
    }
  }

  String _getPageTitle(AssignmentListParams params, User user) {
    if (params.title != null) return params.title!;

    switch (params.context) {
      case AssignmentNavigationContext.fromHome:
        return 'My Assignments';
      case AssignmentNavigationContext.fromClass:
        return 'Class Assignments';
      case AssignmentNavigationContext.fromSubject:
        return 'Subject Assignments';
      case AssignmentNavigationContext.standalone:
        return 'Assignments';
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assignment Analytics - Under Development'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _createNewAssignment(BuildContext context, User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create Assignment - Under Development'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _navigateToAssignmentSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assignment Settings - Under Development'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _navigateToAssignmentTemplates(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assignment Templates - Under Development'),
        backgroundColor: AppTheme.infoColor,
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
