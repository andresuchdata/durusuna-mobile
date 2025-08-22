import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/models/notification.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/class_updates_service.dart'
    show classUpdatesServiceProvider;
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/notification_service.dart';

import '../../../../shared/widgets/global_app_drawer.dart';
import '../../../../shared/widgets/global_bottom_navigation.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../assignments/presentation/pages/assignment_detail_page.dart';

import 'student_list_page.dart';
import '../../../class_updates/presentation/pages/class_updates_page.dart';
import '../../../attendance/presentation/pages/attendance_management_page.dart';
import '../../../subjects/presentation/pages/subjects_main_page.dart';
import '../../../subjects/presentation/pages/subject_offering_details_page.dart';
import '../../../../shared/services/subjects_service.dart';
import '../../../assignments/presentation/pages/flexible_assignments_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';

// Providers for class details data
final classSubjectsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassOfferings(classId);
});

final classManagementServiceProvider = Provider<ClassManagementService>((ref) {
  return ClassManagementService();
});

// Using the existing provider from the service file

// Provider for recent class updates (preview - limited to 2 most recent, excluding pinned)
final recentClassUpdatesProvider =
    FutureProvider.family<List<ClassUpdate>, String>((ref, classId) async {
  final service = ref.read(classUpdatesServiceProvider);
  final allUpdates =
      await service.getClassUpdates(classId, limit: 2, excludePinned: true);
  // Return updates excluding pinned ones (as pinned will be shown separately on top)
  return allUpdates;
});

// Provider for class students (preview - limited to first 5)
final classStudentsProvider =
    FutureProvider.family<List<User>, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassStudents(classId);
});

// Provider for class counts (students, teachers, etc.)
final classCountsProvider =
    FutureProvider.family<ClassCounts, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassCounts(classId);
});

// Provider for class teachers (preview - limited to first 3)
final classTeachersProvider =
    FutureProvider.family<List<User>, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassTeachers(classId);
});

// Provider for class assignments (preview - limited to 3 most recent)
final classAssignmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, classId) async {
  debugPrint(
      '🔍 [FLUTTER DEBUG] Calling getClassAssignments for classId: $classId');
  final service = ref.read(classManagementServiceProvider);
  try {
    final result = await service.getClassAssignments(classId, limit: 3);
    debugPrint(
        '🔍 [FLUTTER DEBUG] getClassAssignments returned ${result.length} assignments');
    return result;
  } catch (e) {
    debugPrint('🔍 [FLUTTER DEBUG] getClassAssignments error: $e');
    rethrow;
  }
});

// Provider for class-specific notifications (preview - limited to 5 most recent)
final classNotificationsProvider =
    FutureProvider.family<List<NotificationModel>, String>(
        (ref, classId) async {
  final notificationService = ref.read(notificationServiceProvider);
  return await notificationService.getNotifications(
    classId: classId,
    limit: 5,
    page: 1, // Always get the first page for preview
  );
});

class ClassDetailsPage extends ConsumerStatefulWidget {
  final ClassModel classModel;
  final Widget? bottomNavigationBar;
  final bool showBackButton;

  const ClassDetailsPage({
    super.key,
    required this.classModel,
    this.bottomNavigationBar,
    this.showBackButton = true,
  });

  @override
  ConsumerState<ClassDetailsPage> createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends ConsumerState<ClassDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final subjectsAsync =
        ref.watch(classSubjectsProvider(widget.classModel.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: widget.showBackButton ? const GlobalAppDrawer() : null,
      bottomNavigationBar: widget.bottomNavigationBar ??
          const GlobalBottomNavigation(
            currentIndex: 2, // Classes tab
            isDetailPage: true,
          ),
      body: SafeArea(
        child: subjectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text('Failed to load subjects'),
                Text(error.toString()),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.refresh(classSubjectsProvider(widget.classModel.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (subjects) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: _buildClassStatistics(),
                ),
                SliverToBoxAdapter(
                  child: _buildQuickActions(),
                ),
                SliverToBoxAdapter(
                  child: _buildClassUpdatesPreview(),
                ),
                SliverToBoxAdapter(
                  child: _buildAssignmentsPreview(),
                ),
                SliverToBoxAdapter(
                  child: _buildNotificationsPreview(),
                ),
                SliverToBoxAdapter(
                  child: subjects.isEmpty
                      ? _buildEmptySubjectsSection()
                      : _buildSubjectsPreview(subjects),
                ),
                SliverToBoxAdapter(
                  child: _buildStudentListPreview(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySubjectsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.book, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No subjects assigned to this class',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final teacher = widget.classModel.teachers?.isNotEmpty == true
        ? widget.classModel.teachers!.first
        : null;
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    return SliverAppBar(
      expandedHeight: teacher != null ? 250 : 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      automaticallyImplyLeading: widget.showBackButton,
      title: Text(
        widget.classModel.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        // Attendance management button for homeroom teachers only
        if (_isCurrentUserHomeroomTeacher(currentUser))
          IconButton(
            icon: const Icon(Icons.fact_check, color: Colors.white),
            tooltip: 'Manage Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceManagementPage(
                    classModel: widget.classModel,
                  ),
                ),
              );
            },
          ),
        if (teacher != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              backgroundImage: teacher.avatarUrl?.isNotEmpty == true
                  ? NetworkImage(teacher.avatarUrl!)
                  : null,
              child: teacher.avatarUrl?.isEmpty != false
                  ? Icon(
                      Icons.person,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 20,
                    )
                  : null,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.person_off,
              color: Colors.white.withValues(alpha: 0.6),
              size: 24,
            ),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          // header summary info class name, teacher and academic year
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Class name and academic year section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.classModel.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (teacher != null)
                        Text(
                          'Teacher: ${teacher.displayName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          'No teacher assigned',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        widget.classModel.academicYear,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Teacher info section - integrated into header
                if (teacher != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                          backgroundImage: teacher.avatarUrl?.isNotEmpty == true
                              ? NetworkImage(teacher.avatarUrl!)
                              : null,
                          child: teacher.avatarUrl?.isEmpty != false
                              ? const Icon(
                                  Icons.person,
                                  color: AppTheme.primaryColor,
                                  size: 28,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Teacher',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                teacher.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                teacher.email,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // TODO: Implement chat with teacher
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Chat with teacher coming soon'),
                                backgroundColor: AppTheme.primaryColor,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.message,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassUpdatesPreview() {
    final updatesAsync =
        ref.watch(recentClassUpdatesProvider(widget.classModel.id));

    return Container(
      margin: const EdgeInsets.all(16),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Updates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToClassUpdates(),
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          updatesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Unable to load updates',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            data: (updates) {
              if (updates.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.announcement_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No updates yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: updates
                    .map((update) => _buildUpdatePreviewTile(update))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatePreviewTile(ClassUpdate update) {
    return InkWell(
      onTap: () => _navigateToSpecificUpdate(update),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE5E5E5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update.title ?? 'Update',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (update.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      update.content,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    app_date_utils.DateUtils.formatRelativeTime(
                        update.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToClassUpdates() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassUpdatesPage(
          classId: widget.classModel.id,
          className: widget.classModel.name,
        ),
      ),
    );
  }

  void _navigateToSpecificUpdate(ClassUpdate update) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassUpdatesPage(
          classId: widget.classModel.id,
          className: widget.classModel.name,
          highlightUpdateId: update.id,
          scrollToUpdate: true,
        ),
      ),
    );
  }

  Widget _buildStudentListPreview() {
    final studentsAsync =
        ref.watch(classStudentsProvider(widget.classModel.id));
    final countsAsync = ref.watch(classCountsProvider(widget.classModel.id));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                countsAsync.when(
                  loading: () => Text(
                    'Students (${widget.classModel.studentsCount ?? 0})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  error: (error, stack) => Text(
                    'Students (${widget.classModel.studentsCount ?? 0})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  data: (counts) => Text(
                    'Students (${counts.studentCount})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentListPage(
                          classModel: widget.classModel,
                        ),
                      ),
                    );
                  },
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          studentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Unable to load students',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            data: (students) {
              if (students.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No students enrolled yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: students
                    .take(5)
                    .map((student) => _buildStudentTile(student))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(User student) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E5E5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            backgroundImage: student.avatarUrl != null
                ? NetworkImage(student.avatarUrl!)
                : null,
            child: student.avatarUrl == null
                ? Text(
                    '${student.firstName[0]}${student.lastName[0]}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
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
                  student.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (student.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    student.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsPreview(List<Map<String, dynamic>> subjects) {
    final limitedSubjects = subjects.take(3).toList();
    final hasMore = subjects.length > 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subjects (${subjects.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final countsAsync = ref
                            .watch(classCountsProvider(widget.classModel.id));
                        return countsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stack) => const SizedBox.shrink(),
                          data: (counts) => Text(
                            '${counts.teacherCount} teachers assigned',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (hasMore)
                  TextButton(
                    onPressed: () {
                      // Navigate to subjects list page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubjectsMainPage(),
                        ),
                      );
                    },
                    child: const Text('See more'),
                  ),
              ],
            ),
          ),
          ...limitedSubjects.map((subject) => _buildSubjectCard(subject)),
        ],
      ),
    );
  }

  Widget _buildAssignmentsPreview() {
    final assignmentsAsync =
        ref.watch(classAssignmentsProvider(widget.classModel.id));

    return Container(
      margin: const EdgeInsets.all(16),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Assignments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlexibleAssignmentsPage(
                          params: AssignmentListParams(
                            context: AssignmentNavigationContext.fromClass,
                            preSelectedClassId: widget.classModel.id,
                            title: '${widget.classModel.name} Assignments',
                            showClassFilter: false,
                            showSubjectFilter: true,
                            showStats: false,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          assignmentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Unable to load assignments',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            data: (assignments) {
              if (assignments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No assignments yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: assignments
                    .map((assignment) => _buildAssignmentTile(assignment))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsPreview() {
    final notificationsAsync =
        ref.watch(classNotificationsProvider(widget.classModel.id));

    return Container(
      margin: const EdgeInsets.all(16),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToNotifications(),
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          notificationsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Unable to load notifications',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            data: (notifications) {
              if (notifications.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: notifications
                    .map((notification) => _buildNotificationTile(notification))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTile(Map<String, dynamic> assignment) {
    // Parse due date from API response
    DateTime? dueDate;
    try {
      if (assignment['due_date'] != null) {
        dueDate = DateTime.parse(assignment['due_date']);
      }
    } catch (e) {
      // Handle parsing error gracefully
    }

    final isPublished = assignment['is_published'] as bool? ?? false;
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
    final assignmentId = assignment['id'] as String?;
    final assignmentTitle = assignment['title'] as String? ?? 'Assignment';

    return InkWell(
      onTap: assignmentId != null
          ? () => _navigateToAssignmentDetail(assignmentId, assignmentTitle)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE5E5E5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: !isPublished
                    ? AppTheme.textSecondary
                    : isOverdue
                        ? AppTheme.errorColor
                        : AppTheme.warningColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignmentTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        assignment['type'] ?? 'assignment',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (dueDate != null) ...[
                        const Text(' • '),
                        Text(
                          app_date_utils.DateUtils.formatDueDate(dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? AppTheme.errorColor
                                : AppTheme.textSecondary,
                            fontWeight:
                                isOverdue ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: !isPublished
                          ? AppTheme.textSecondary.withValues(alpha: 0.1)
                          : isOverdue
                              ? AppTheme.errorColor.withValues(alpha: 0.1)
                              : AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      !isPublished
                          ? 'Draft'
                          : isOverdue
                              ? 'Overdue'
                              : 'Active',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: !isPublished
                            ? AppTheme.textSecondary
                            : isOverdue
                                ? AppTheme.errorColor
                                : AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (assignmentId != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _navigateToAssignmentDetail(String assignmentId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentDetailPage(
          assignmentId: assignmentId,
          title: title,
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    return InkWell(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE5E5E5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? AppTheme.textSecondary.withValues(alpha: 0.5)
                    : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w500,
                      color: notification.isRead
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.content,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    app_date_utils.DateUtils.formatRelativeTime(
                        notification.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToNotifications() {
    // Navigate to notifications page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read if not already read
    if (!notification.isRead) {
      ref.read(notificationServiceProvider).markAsRead(notification.id);
    }

    // Handle notification action if there's an action URL
    if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) {
      // Navigate based on action URL
      // You can implement deep linking logic here
      Navigator.pushNamed(context, notification.actionUrl!);
    }
  }

  Widget _buildSubjectCard(Map<String, dynamic> offering) {
    final String subjectName =
        offering['subject_name'] ?? offering['subject']?['name'] ?? 'Subject';
    final String subjectCode =
        offering['subject_code'] ?? offering['subject']?['code'] ?? '';
    final String teacherName = (() {
      final teacher = offering['teacher'];
      if (teacher is Map) {
        final fn = teacher['first_name'] ?? '';
        final ln = teacher['last_name'] ?? '';
        final display =
            [fn, ln].where((s) => (s as String).isNotEmpty).join(' ');
        if (display.isNotEmpty) return display;
        return (teacher['email'] as String?) ?? '—';
      }
      final fn = offering['first_name'];
      final ln = offering['last_name'];
      final display =
          [fn, ln].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      return display.isNotEmpty
          ? display
          : (offering['email'] as String? ?? '—');
    })();
    final int assignmentsCount = offering['assignments_count'] is int
        ? offering['assignments_count']
        : 0;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _navigateToOfferingDetails(offering),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: const BorderSide(
                color: Color(0xFFE5E5E5),
                width: 0.5,
              ),
              left: const BorderSide(
                color: Colors.blue,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              // Subject icon with color
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getSubjectIcon(subjectName),
                  color: Colors.blue,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              // Subject content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject name and code
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subjectName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subjectCode,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Stats row
                    Text(
                      '${widget.classModel.studentsCount ?? 0} students • $assignmentsCount assignments',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Teacher and schedule
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            teacherName,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (0 > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.warningColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'pending',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.warningColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Clean arrow indicator
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    // Only show quick actions for homeroom teachers
    if (!_isCurrentUserHomeroomTeacher(currentUser)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.fact_check,
                    title: 'Manage Attendance',
                    subtitle: 'Take daily attendance',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttendanceManagementPage(
                            classModel: widget.classModel,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.people,
                    title: 'View Students',
                    subtitle: 'Manage class roster',
                    color: AppTheme.accentColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentListPage(
                            classModel: widget.classModel,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassStatistics() {
    final countsAsync = ref.watch(classCountsProvider(widget.classModel.id));
    final subjectsAsync =
        ref.watch(classSubjectsProvider(widget.classModel.id));
    final updatesAsync =
        ref.watch(recentClassUpdatesProvider(widget.classModel.id));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            countsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildStatisticsGrid(
                studentCount: widget.classModel.studentsCount ?? 0,
                teacherCount: widget.classModel.teachersCount ?? 0,
                totalMembers: (widget.classModel.studentsCount ?? 0) +
                    (widget.classModel.teachersCount ?? 0),
                subjectCount: subjectsAsync.valueOrNull?.length ?? 0,
                updatesCount: updatesAsync.valueOrNull?.length ?? 0,
              ),
              data: (counts) => _buildStatisticsGrid(
                studentCount: counts.studentCount,
                teacherCount: counts.teacherCount,
                totalMembers: counts.totalMembers,
                subjectCount: subjectsAsync.valueOrNull?.length ?? 0,
                updatesCount: updatesAsync.valueOrNull?.length ?? 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid({
    required int studentCount,
    required int teacherCount,
    required int totalMembers,
    required int subjectCount,
    required int updatesCount,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard(
          icon: Icons.people,
          title: 'Students',
          count: studentCount,
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.person,
          title: 'Teachers',
          count: teacherCount,
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.book,
          title: 'Subjects',
          count: subjectCount,
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.announcement,
          title: 'Updates',
          count: updatesCount,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10), // Slightly reduced padding
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 22, // Slightly smaller icon
          ),
          const SizedBox(width: 6), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 14, // Further reduced for reliable fit
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 10, // Smaller for better fit
                        color: color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get appropriate icon for each subject
  IconData _getSubjectIcon(String? subjectName) {
    if (subjectName == null) return Icons.book;

    final subject = subjectName.toLowerCase();
    if (subject.contains('english') || subject.contains('language')) {
      return Icons.translate;
    } else if (subject.contains('math')) {
      return Icons.calculate;
    } else if (subject.contains('science')) {
      return Icons.science;
    } else if (subject.contains('history')) {
      return Icons.history_edu;
    } else if (subject.contains('art')) {
      return Icons.palette;
    } else if (subject.contains('music')) {
      return Icons.music_note;
    } else if (subject.contains('physical') || subject.contains('pe')) {
      return Icons.sports;
    } else {
      return Icons.book;
    }
  }

  SubjectOffering _convertOfferingToSubjectOffering(
      Map<String, dynamic> offering) {
    final String subjectName =
        offering['subject_name'] ?? offering['subject']?['name'] ?? 'Subject';
    final String subjectCode =
        offering['subject_code'] ?? offering['subject']?['code'] ?? '';
    final String teacherName = (() {
      final teacher = offering['teacher'];
      if (teacher is Map) {
        final fn = teacher['first_name'] ?? '';
        final ln = teacher['last_name'] ?? '';
        final display =
            [fn, ln].where((s) => (s as String).isNotEmpty).join(' ');
        if (display.isNotEmpty) return display;
        return (teacher['email'] as String?) ?? 'Unassigned';
      }
      final fn = offering['first_name'];
      final ln = offering['last_name'];
      final display =
          [fn, ln].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      return display.isNotEmpty
          ? display
          : (offering['email'] as String? ?? 'Unassigned');
    })();

    return SubjectOffering(
      id: offering['class_offering_id'] ?? offering['id'] ?? '',
      subjectId: offering['subject_id'] ?? '',
      subjectName: subjectName,
      subjectCode: subjectCode,
      subjectDescription: offering['subject_description'] ?? '',
      classId: widget.classModel.id,
      className: widget.classModel.name,
      gradeLevel: widget.classModel.gradeLevel ?? '',
      hoursPerWeek: offering['hours_per_week'] ?? 0,
      room: offering['room'] ?? '',
      schedule: offering['schedule'] is Map<String, dynamic>
          ? offering['schedule']
          : <String, dynamic>{},
      teacherId: offering['teacher_id'],
      teacherName: teacherName,
      teacherEmail: offering['email'],
      teacherAvatarUrl: offering['avatar_url'],
      assignments: [], // Will be loaded in details page
      studentCount: widget.classModel.studentsCount ?? 0,
      assignmentsCount: offering['assignments_count'] ?? 0,
      pendingGrades: 0, // Will be calculated in service
      color: _getSubjectColor(subjectName),
    );
  }

  Map<String, dynamic> _getSubjectColor(String subjectName) {
    final colors = {
      'Mathematics': {'primary': 0xFF2196F3, 'secondary': 0xFFE3F2FD},
      'Math': {'primary': 0xFF2196F3, 'secondary': 0xFFE3F2FD},
      'English': {'primary': 0xFF4CAF50, 'secondary': 0xFFE8F5E8},
      'Literature': {'primary': 0xFF4CAF50, 'secondary': 0xFFE8F5E8},
      'Science': {'primary': 0xFF9C27B0, 'secondary': 0xFFF3E5F5},
      'Physics': {'primary': 0xFF9C27B0, 'secondary': 0xFFF3E5F5},
      'Chemistry': {'primary': 0xFF9C27B0, 'secondary': 0xFFF3E5F5},
      'Biology': {'primary': 0xFF4CAF50, 'secondary': 0xFFE8F5E8},
      'Islamic': {'primary': 0xFF009688, 'secondary': 0xFFE0F2F1},
      'Islam': {'primary': 0xFF009688, 'secondary': 0xFFE0F2F1},
      'Arabic': {'primary': 0xFFFF9800, 'secondary': 0xFFFFF3E0},
      'History': {'primary': 0xFF795548, 'secondary': 0xFFEFEBE9},
      'Geography': {'primary': 0xFF607D8B, 'secondary': 0xFFECEFF1},
    };

    for (final key in colors.keys) {
      if (subjectName.toLowerCase().contains(key.toLowerCase())) {
        return colors[key]!;
      }
    }

    // Default color
    return {'primary': 0xFF757575, 'secondary': 0xFFF5F5F5};
  }

  void _navigateToOfferingDetails(Map<String, dynamic> offering) {
    final subjectOffering = _convertOfferingToSubjectOffering(offering);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SubjectOfferingDetailsPage(offering: subjectOffering),
      ),
    );
  }

  /// Check if current user is the homeroom teacher of this class
  bool _isCurrentUserHomeroomTeacher(User? currentUser) {
    if (currentUser?.userType != UserType.teacher) return false;

    // Check class settings for homeroom teacher info
    final settings = widget.classModel.settings;
    if (settings != null) {
      final homeroomTeacherId = settings['homeroom_teacher_id'] as String?;
      if (homeroomTeacherId != null && homeroomTeacherId == currentUser?.id) {
        return true;
      }
    }

    // Fallback: check if user is in teachers list (for backward compatibility)
    final classTeachers = widget.classModel.teachers;
    if (classTeachers != null && currentUser != null) {
      return classTeachers.any((teacher) => teacher.id == currentUser.id);
    }

    return false;
  }

  // Removed _buildDefaultBottomNavigation method - now using GlobalBottomNavigation
}
