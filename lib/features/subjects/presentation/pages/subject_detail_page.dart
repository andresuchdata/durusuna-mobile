import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../assignments/presentation/pages/assignments_main_page.dart';
import '../../../grading/pages/formula_templates_main_page.dart';
import '../../../grading/pages/formula_builder_page.dart';
import '../widgets/subject_stats_card.dart';
import 'subjects_main_page.dart';

class SubjectDetailPage extends ConsumerStatefulWidget {
  final MockSubject subject;

  const SubjectDetailPage({
    super.key,
    required this.subject,
  });

  @override
  ConsumerState<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends ConsumerState<SubjectDetailPage>
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
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              backgroundColor: widget.subject.color,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildSubjectHeader(user),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Assignments'),
                  Tab(text: 'Grading'),
                  Tab(text: 'Students'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editSubject(context),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(context, value, user),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Subject Settings'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share Subject'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (user.role == UserRole.admin)
                      const PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(Icons.archive),
                          title: Text('Archive Subject'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(user),
            _buildAssignmentsTab(user),
            _buildGradingTab(user),
            _buildStudentsTab(user),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectHeader(User user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.subject.color,
            widget.subject.color.withValues(alpha: 0.8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40), // Space for app bar
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.book,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.subject.code} • ${widget.subject.grade}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    widget.subject.teacher,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Spacer(),
                  const Icon(Icons.schedule, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    widget.subject.schedule,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildHeaderStat('Students', widget.subject.studentCount.toString()),
                  const SizedBox(width: 24),
                  _buildHeaderStat('Assignments', widget.subject.assignmentsCount.toString()),
                  const SizedBox(width: 24),
                  _buildHeaderStat('Pending', widget.subject.pendingGrades.toString()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          _buildQuickStats(),
          const SizedBox(height: 24),

          // Recent Activity
          _buildRecentActivity(),
          const SizedBox(height: 24),

          // Quick Actions
          _buildQuickActions(user),
          const SizedBox(height: 24),

          // Subject Information
          _buildSubjectInfo(),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab(User user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assignments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _createNewAssignment(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.subject.color,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildAssignmentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grading Management Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grading Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showGradingHelp(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grading Overview Stats
          _buildGradingStats(),
          const SizedBox(height: 24),

          // Formula Management
          _buildFormulaManagement(user),
          const SizedBox(height: 24),

          // Grade Configuration
          _buildGradeConfiguration(user),
          const SizedBox(height: 24),

          // Grading Schedule & Deadlines
          _buildGradingSchedule(),
          const SizedBox(height: 24),

          // Quick Grading Actions
          _buildQuickGradingActions(user),
        ],
      ),
    );
  }

  Widget _buildStudentsTab(User user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Students (${widget.subject.studentCount})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _searchStudents(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildStudentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: SubjectStatsCard(
            title: 'This Week',
            count: '8',
            subtitle: 'Assignments due',
            icon: Icons.assignment_late,
            color: AppTheme.warningColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SubjectStatsCard(
            title: 'To Grade',
            count: widget.subject.pendingGrades.toString(),
            subtitle: 'Submissions',
            icon: Icons.grade,
            color: AppTheme.errorColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SubjectStatsCard(
            title: 'Avg Score',
            count: '85%',
            subtitle: 'Class average',
            icon: Icons.trending_up,
            color: AppTheme.successColor,
          ),
        ),
      ],
    );
  }

  Widget _buildGradingStats() {
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
            'Grading Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGradingStat('Pending', '${widget.subject.pendingGrades}', AppTheme.warningColor),
              ),
              Expanded(
                child: _buildGradingStat('Graded', '15', AppTheme.successColor),
              ),
              Expanded(
                child: _buildGradingStat('Formula', 'Active', AppTheme.primaryColor),
              ),
              Expanded(
                child: _buildGradingStat('Avg Time', '2.5m', AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradingStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaManagement(User user) {
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
                'Formula Management',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () => _navigateToFormulaBuilder(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Current Formula
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Formula: Weighted Average',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'UTS(30%) + UAS(40%) + Tugas(20%) + Pengulangan(10%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editFormula(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Formula Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToFormulaTemplates(),
                  icon: const Icon(Icons.library_books, size: 16),
                  label: const Text('Templates'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _previewFormula(),
                  icon: const Icon(Icons.preview, size: 16),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _validateFormula(),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Validate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradeConfiguration(User user) {
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
            'Grade Configuration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Grade Scale
          _buildConfigItem(
            'Grade Scale',
            'A: 90-100, B: 80-89, C: 70-79, D: 60-69, E: <60',
            Icons.grade,
            () => _configureGradeScale(),
          ),
          
          const SizedBox(height: 12),
          
          // Rounding Rules
          _buildConfigItem(
            'Rounding Rules',
            'Round to nearest integer, 0.5 rounds up',
            Icons.functions,
            () => _configureRounding(),
          ),
          
          const SizedBox(height: 12),
          
          // Extra Credit
          _buildConfigItem(
            'Extra Credit',
            'Maximum 5% bonus, specific assignments only',
            Icons.add_circle,
            () => _configureExtraCredit(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String title, String description, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildGradingSchedule() {
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
            'Grading Schedule & Deadlines',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Upcoming Deadlines
          _buildScheduleItem(
            'UTS Grading Deadline',
            'March 15, 2024',
            Icons.calendar_today,
            AppTheme.warningColor,
            '3 days left',
          ),
          
          const SizedBox(height: 8),
          
          _buildScheduleItem(
            'Assignment #3 Due',
            'March 20, 2024',
            Icons.assignment,
            AppTheme.primaryColor,
            '8 days left',
          ),
          
          const SizedBox(height: 8),
          
          _buildScheduleItem(
            'Progress Report',
            'March 25, 2024',
            Icons.report,
            AppTheme.successColor,
            '13 days left',
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String title, String date, IconData icon, Color color, String timeLeft) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              timeLeft,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGradingActions(User user) {
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
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startBulkGrading(),
                  icon: const Icon(Icons.grading, size: 16),
                  label: const Text('Bulk Grade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _generateReport(),
                  icon: const Icon(Icons.assessment, size: 16),
                  label: const Text('Generate Report'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportGrades(),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Grades'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importGrades(),
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Import Grades'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
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
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Mock recent activities
          _buildActivityItem('Assignment #2 submitted by 5 students', '2 hours ago', Icons.assignment_turned_in),
          _buildActivityItem('Graded Quiz #3 for all students', '1 day ago', Icons.grade),
          _buildActivityItem('Updated formula for final calculation', '3 days ago', Icons.calculate),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String activity, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(User user) {
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
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToAssignments(),
                  icon: const Icon(Icons.assignment, size: 16),
                  label: const Text('Assignments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.subject.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToFormulaTemplates(),
                  icon: const Icon(Icons.grade, size: 16),
                  label: const Text('Grading'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectInfo() {
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
            'Subject Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Subject Code', widget.subject.code),
          _buildInfoRow('Grade Level', widget.subject.grade),
          _buildInfoRow('Schedule', widget.subject.schedule),
          _buildInfoRow('Teacher', widget.subject.teacher),
          _buildInfoRow('Academic Year', '2023/2024'),
          _buildInfoRow('Semester', 'Genap'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.subject.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.assignment,
                color: widget.subject.color,
                size: 20,
              ),
            ),
            title: Text('Assignment #${index + 1}'),
            subtitle: Text('Due: March ${15 + index}, 2024'),
            trailing: Chip(
              label: Text('${10 - index} pending'),
              backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
            ),
            onTap: () => _viewAssignmentDetails(index),
          ),
        );
      },
    );
  }

  Widget _buildStudentsList() {
    return ListView.builder(
      itemCount: widget.subject.studentCount,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: widget.subject.color.withValues(alpha: 0.1),
              child: Text(
                'S${index + 1}',
                style: TextStyle(
                  color: widget.subject.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('Student ${index + 1}'),
            subtitle: Text('Grade Average: ${85 + (index % 10)}%'),
            trailing: Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
            ),
            onTap: () => _viewStudentProfile(index),
          ),
        );
      },
    );
  }

  // Action Methods
  void _editSubject(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit Subject - Under Development')),
    );
  }

  void _handleMenuAction(BuildContext context, String action, User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action - Under Development')),
    );
  }

  void _createNewAssignment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssignmentsMainPage(),
      ),
    );
  }

  void _navigateToAssignments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssignmentsMainPage(),
      ),
    );
  }

  void _navigateToFormulaBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FormulaBuilderPage(scope: 'subject'),
      ),
    );
  }

  void _navigateToFormulaTemplates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FormulaTemplatesMainPage(),
      ),
    );
  }

  void _editFormula() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FormulaBuilderPage(scope: 'subject'),
      ),
    );
  }

  void _previewFormula() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formula Preview - Under Development')),
    );
  }

  void _validateFormula() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formula validation passed!')),
    );
  }

  void _configureGradeScale() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grade Scale Configuration - Under Development')),
    );
  }

  void _configureRounding() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rounding Rules Configuration - Under Development')),
    );
  }

  void _configureExtraCredit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extra Credit Configuration - Under Development')),
    );
  }

  void _startBulkGrading() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk Grading - Under Development')),
    );
  }

  void _generateReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generate Report - Under Development')),
    );
  }

  void _exportGrades() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export Grades - Under Development')),
    );
  }

  void _importGrades() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import Grades - Under Development')),
    );
  }

  void _searchStudents(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student Search - Under Development')),
    );
  }

  void _viewAssignmentDetails(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assignment ${index + 1} Details - Under Development')),
    );
  }

  void _viewStudentProfile(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Student ${index + 1} Profile - Under Development')),
    );
  }

  void _showGradingHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grading Management Help'),
        content: const Text(
          'This section helps you manage grading formulas, configure grade scales, set up deadlines, and perform bulk grading operations for this subject.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
