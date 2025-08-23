import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/subjects_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../assignments/presentation/pages/flexible_assignments_page.dart';

import '../../../assignments/presentation/widgets/assignment_list_view.dart';
import '../../../assignments/presentation/pages/assignments_main_page.dart';
import '../../../grading/pages/formula_templates_main_page.dart';
import '../../../class_management/presentation/pages/student_detail_page.dart';
import '../../../../shared/models/class_model.dart';

// Import the provider for students list
final studentsListWithSearchProvider =
    FutureProvider.family<List<User>, (String, String?)>((ref, params) async {
  final (classId, search) = params;
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassStudents(classId, search: search);
});

class SubjectOfferingDetailsPage extends ConsumerStatefulWidget {
  final SubjectOffering offering;

  const SubjectOfferingDetailsPage({
    super.key,
    required this.offering,
  });

  @override
  ConsumerState<SubjectOfferingDetailsPage> createState() =>
      _SubjectOfferingDetailsPageState();
}

class _SubjectOfferingDetailsPageState
    extends ConsumerState<SubjectOfferingDetailsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildTabBar(),
          _buildTabContent(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Color(widget.offering.color['primary'] ?? 0xFF757575),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.offering.subjectName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(widget.offering.color['primary'] ?? 0xFF757575),
                Color(widget.offering.color['primary'] ?? 0xFF757575)
                    .withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 40), // Account for app bar
                  Text(
                    widget.offering.subjectCode,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.offering.className,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.offering.gradeLevel.isNotEmpty)
                    Text(
                      widget.offering.gradeLevel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () => _shareOffering(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Export Data'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'analytics',
              child: ListTile(
                leading: Icon(Icons.analytics),
                title: Text('View Analytics'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subject Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SizedBox(
                  width: 120,
                  child: _buildStatCard(
                    'Students',
                    '${widget.offering.studentCount}',
                    Icons.people,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: _buildStatCard(
                    'Assignments',
                    '${widget.offering.assignmentsCount}',
                    Icons.assignment,
                    AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: _buildStatCard(
                    'Pending',
                    '${widget.offering.pendingGrades}',
                    Icons.assignment_late,
                    AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: _buildStatCard(
                    'Hours/Week',
                    '${widget.offering.hoursPerWeek}',
                    Icons.schedule,
                    AppTheme.infoColor,
                  ),
                ),
                const SizedBox(width: 16), // Extra padding at the end
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Assignments'),
            Tab(text: 'Students'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAssignmentsTab(),
          _buildStudentsTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatisticsCard(),
          const SizedBox(height: 16),
          _buildTeacherInfoCard(),
          const SizedBox(height: 16),
          _buildScheduleCard(),
          const SizedBox(height: 16),
          _buildDescriptionCard(),
          const SizedBox(height: 16),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildTeacherInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teacher Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                backgroundImage: widget.offering.teacherAvatarUrl != null
                    ? NetworkImage(widget.offering.teacherAvatarUrl!)
                    : null,
                child: widget.offering.teacherAvatarUrl == null
                    ? Text(
                        _getInitials(widget.offering.teacherName),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.offering.teacherName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (widget.offering.teacherEmail != null)
                      Text(
                        widget.offering.teacherEmail!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _contactTeacher(),
                icon: const Icon(Icons.message),
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final authState = ref.read(authStateProvider);
    final currentUser = authState.user;
    final canEdit = currentUser?.userType == UserType.teacher ||
        currentUser?.role == UserRole.admin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                'Schedule & Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (canEdit)
                TextButton(
                  onPressed: () => _editSchedule(),
                  child: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildScheduleItem(
              'Room',
              widget.offering.room.isNotEmpty
                  ? widget.offering.room
                  : 'Not assigned'),
          _buildScheduleItem(
              'Hours per Week', '${widget.offering.hoursPerWeek}'),
          _buildScheduleItem(
              'Schedule',
              widget.offering.schedule.isNotEmpty
                  ? _formatScheduleDisplay(widget.offering.schedule)
                  : 'Not set'),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subject Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.offering.subjectDescription.isNotEmpty
                ? widget.offering.subjectDescription
                : 'No description available for this subject offering.',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final authState = ref.read(authStateProvider);
    final currentUser = authState.user;
    final canManage = currentUser?.userType == UserType.teacher ||
        currentUser?.role == UserRole.admin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'View Assignments',
                  Icons.assignment,
                  AppTheme.primaryColor,
                  () => _navigateToAssignments(),
                ),
              ),
              const SizedBox(width: 12),
              if (canManage)
                Expanded(
                  child: _buildActionButton(
                    'Grading',
                    Icons.grade,
                    AppTheme.successColor,
                    () => _navigateToGrading(),
                  ),
                ),
              if (!canManage)
                Expanded(
                  child: _buildActionButton(
                    'Class Chat',
                    Icons.chat,
                    AppTheme.infoColor,
                    () => _openClassChat(),
                  ),
                ),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Create Assignment',
                    Icons.add_task,
                    AppTheme.warningColor,
                    () => _createAssignment(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Class Chat',
                    Icons.chat,
                    AppTheme.infoColor,
                    () => _openClassChat(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    final authState = ref.read(authStateProvider);
    final currentUser = authState.user;
    final userRole = currentUser?.userType == UserType.teacher ||
            currentUser?.role == UserRole.admin
        ? UserRoleType.teacher
        : UserRoleType.student;

    return AssignmentListView(
      filterType: AssignmentFilterType.all,
      userRole: userRole,
      classId: widget.offering.classId,
      subjectId: widget.offering.subjectId,
      searchQuery: null,
    );
  }

  Widget _buildStudentsTab() {
    final studentsAsync = ref
        .watch(studentsListWithSearchProvider((widget.offering.classId, null)));

    return studentsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Error loading students: ${error.toString()}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(studentsListWithSearchProvider(
                  (widget.offering.classId, null))),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (students) {
        if (students.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No students enrolled in this class yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: student.avatarUrl != null
                      ? NetworkImage(student.avatarUrl!)
                      : null,
                  child: student.avatarUrl == null
                      ? Text(
                          _getInitials(student.displayName),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  student.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(student.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Create a minimal ClassModel for the student detail page
                  final classModel = ClassModel(
                    id: widget.offering.classId,
                    schoolId: '', // Not available from offering
                    name: widget.offering.className,
                    gradeLevel: widget.offering.gradeLevel.isNotEmpty
                        ? widget.offering.gradeLevel
                        : null,
                    academicYear: DateTime.now()
                        .year
                        .toString(), // Default to current year
                    isActive: true,
                    createdAt: DateTime.now(), // Placeholder
                    updatedAt: DateTime.now(), // Placeholder
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDetailPage(
                        student: student,
                        classModel: classModel,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Analytics will be implemented',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return 'U';
  }

  String _formatScheduleDisplay(Map<String, dynamic> schedule) {
    // Implement schedule formatting based on your schedule structure
    if (schedule.isEmpty) return 'Not set';
    // For now, return a placeholder
    return 'See detailed schedule';
  }

  // Action methods
  void _shareOffering() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share offering - Under Development')),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportData();
        break;
      case 'analytics':
        _viewAnalytics();
        break;
    }
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export data - Under Development')),
    );
  }

  void _viewAnalytics() {
    _tabController.animateTo(3); // Switch to analytics tab
  }

  void _contactTeacher() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact teacher - Under Development')),
    );
  }

  void _editSchedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit schedule - Under Development')),
    );
  }

  void _navigateToAssignments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlexibleAssignmentsPage(
          params: AssignmentListParams(
            context: AssignmentNavigationContext.fromSubject,
            preSelectedClassId: widget.offering.classId,
            preSelectedSubjectId: widget.offering.subjectId,
            title: '${widget.offering.subjectName} Assignments',
            showClassFilter: false,
            showSubjectFilter: false,
            showStats: false,
          ),
        ),
      ),
    );
  }

  void _navigateToGrading() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FormulaTemplatesMainPage(),
      ),
    );
  }

  void _openClassChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class chat - Under Development')),
    );
  }

  void _createAssignment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create assignment - Under Development')),
    );
  }
}
