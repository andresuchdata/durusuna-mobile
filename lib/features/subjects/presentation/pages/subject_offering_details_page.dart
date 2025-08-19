import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/subjects_service.dart';
import '../../../../shared/services/class_updates_service.dart';
import '../../../../shared/models/class_update.dart';
import '../../../assignments/presentation/pages/assignments_main_page.dart';
import '../../../grading/pages/formula_templates_main_page.dart';
import '../../../class_updates/presentation/pages/class_updates_page.dart';

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
                    .withOpacity(0.8),
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
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Offering'),
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
            color: Colors.black.withOpacity(0.05),
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
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Students',
                  '${widget.offering.studentCount}',
                  Icons.people,
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Assignments',
                  '${widget.offering.assignmentsCount}',
                  Icons.assignment,
                  AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  '${widget.offering.pendingGrades}',
                  Icons.assignment_late,
                  AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Hours/Week',
                  '${widget.offering.hoursPerWeek}',
                  Icons.schedule,
                  AppTheme.infoColor,
                ),
              ),
            ],
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
        color: color.withOpacity(0.1),
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
          _buildRecentUpdatesCard(),
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
            color: Colors.black.withOpacity(0.05),
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
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            color: Colors.black.withOpacity(0.05),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Expanded(
                child: _buildActionButton(
                  'Grading',
                  Icons.grade,
                  AppTheme.successColor,
                  () => _navigateToGrading(),
                ),
              ),
            ],
          ),
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.offering.assignments.length,
      itemBuilder: (context, index) {
        final assignment = widget.offering.assignments[index];
        return _buildAssignmentCard(assignment);
      },
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Expanded(
                child: Text(
                  assignment['title'] ?? 'Untitled Assignment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _buildAssignmentStatusChip(assignment),
            ],
          ),
          const SizedBox(height: 8),
          if (assignment['description'] != null)
            Text(
              assignment['description'],
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAssignmentInfo('Type', assignment['type'] ?? 'assignment'),
              const SizedBox(width: 16),
              _buildAssignmentInfo(
                  'Max Score', '${assignment['max_score'] ?? 0}'),
              const SizedBox(width: 16),
              _buildAssignmentInfo('Due', _formatDate(assignment['due_date'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentStatusChip(Map<String, dynamic> assignment) {
    final isPublished = assignment['is_published'] ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublished
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPublished ? 'Published' : 'Draft',
        style: TextStyle(
          fontSize: 12,
          color: isPublished ? AppTheme.successColor : AppTheme.warningColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAssignmentInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Students list will be implemented',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
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

  String _formatDate(dynamic date) {
    if (date == null) return 'Not set';
    try {
      final DateTime parsedDate = DateTime.parse(date.toString());
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildRecentUpdatesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                'Recent Updates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _navigateToSubjectUpdates(),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, child) {
              final subjectParams = SubjectUpdatesParams(
                classId: widget.offering.classId,
                subjectOfferingId: widget.offering.id,
              );
              final updatesState =
                  ref.watch(subjectUpdatesProvider(subjectParams));

              if (updatesState.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (updatesState.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.grey[400], size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load updates',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final recentUpdates = updatesState.updates.take(3).toList();

              if (recentUpdates.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.update, color: Colors.grey[400], size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'No recent updates',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updates for this subject will appear here',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: recentUpdates
                    .map((update) => _buildCompactUpdateCard(update))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactUpdateCard(ClassUpdate update) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getUpdateTypeIcon(update.updateType),
                size: 16,
                color: _getUpdateTypeColor(update.updateType),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  update.title ?? _getUpdateTypeLabel(update.updateType),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _getTimeAgo(update.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            update.content,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (update.author != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    _getInitials(
                        '${update.author!.firstName} ${update.author!.lastName}'),
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${update.author!.firstName} ${update.author!.lastName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getUpdateTypeIcon(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return Icons.campaign;
      case UpdateType.homework:
        return Icons.assignment;
      case UpdateType.reminder:
        return Icons.alarm;
      case UpdateType.event:
        return Icons.event;
    }
  }

  Color _getUpdateTypeColor(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return AppTheme.primaryColor;
      case UpdateType.homework:
        return AppTheme.warningColor;
      case UpdateType.reminder:
        return AppTheme.infoColor;
      case UpdateType.event:
        return AppTheme.successColor;
    }
  }

  String _getUpdateTypeLabel(UpdateType type) {
    switch (type) {
      case UpdateType.announcement:
        return 'Announcement';
      case UpdateType.homework:
        return 'Homework';
      case UpdateType.reminder:
        return 'Reminder';
      case UpdateType.event:
        return 'Event';
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Action methods
  void _shareOffering() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share offering - Under Development')),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editOffering();
        break;
      case 'export':
        _exportData();
        break;
      case 'analytics':
        _viewAnalytics();
        break;
    }
  }

  void _editOffering() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit offering - Under Development')),
    );
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
        builder: (context) => const AssignmentsMainPage(),
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

  void _createAssignment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create assignment - Under Development')),
    );
  }

  void _openClassChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class chat - Under Development')),
    );
  }

  void _navigateToSubjectUpdates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassUpdatesPage(
          classId: widget.offering.classId,
          className:
              '${widget.offering.className} - ${widget.offering.subjectName}',
        ),
      ),
    );
  }
}
