import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/class_updates_service.dart'
    show classUpdatesServiceProvider;

import '../../../../shared/widgets/global_app_drawer.dart';
import '../../../../shared/widgets/global_bottom_navigation.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;

import 'subject_details_page.dart';
import '../../../class_updates/presentation/pages/class_updates_page.dart';

// Providers for class details data
final classSubjectsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassSubjects(classId);
});

final classManagementServiceProvider = Provider<ClassManagementService>((ref) {
  return ClassManagementService();
});

// Using the existing provider from the service file

// Provider for recent class updates (preview - limited to 2 most recent)
final recentClassUpdatesProvider =
    FutureProvider.family<List<ClassUpdate>, String>((ref, classId) async {
  final service = ref.read(classUpdatesServiceProvider);
  final allUpdates = await service.getClassUpdates(classId);
  // Return only the 2 most recent updates for preview
  return allUpdates.take(2).toList();
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
  // Mock assignments data - replace with actual API call
  await Future.delayed(const Duration(milliseconds: 300));
  return [
    {
      'id': '1',
      'title': 'Math Homework Chapter 5',
      'subject': 'Mathematics',
      'dueDate': DateTime.now().add(const Duration(days: 2)),
      'isSubmitted': false,
    },
    {
      'id': '2',
      'title': 'Science Lab Report',
      'subject': 'Science',
      'dueDate': DateTime.now().add(const Duration(days: 5)),
      'isSubmitted': true,
    },
    {
      'id': '3',
      'title': 'English Essay',
      'subject': 'English',
      'dueDate': DateTime.now().add(const Duration(days: 7)),
      'isSubmitted': false,
    },
  ];
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
            if (subjects.isEmpty) {
              return _buildEmptySubjects();
            }

            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(subjects),
                SliverToBoxAdapter(
                  child: _buildClassStatistics(),
                ),
                SliverToBoxAdapter(
                  child: _buildClassUpdatesPreview(),
                ),
                SliverToBoxAdapter(
                  child: _buildAssignmentsPreview(),
                ),
                SliverToBoxAdapter(
                  child: _buildStudentListPreview(),
                ),
                SliverToBoxAdapter(
                  child: _buildSubjectsPreview(subjects),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySubjects() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No subjects assigned to this class',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(List<Map<String, dynamic>> subjects) {
    final teacher = widget.classModel.teachers?.isNotEmpty == true
        ? widget.classModel.teachers!.first
        : null;

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
                  app_date_utils.DateUtils.formatRelativeTime(update.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                    // Navigate to full student list
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
                      // Show all subjects
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
                    // Navigate to assignments page
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

  Widget _buildAssignmentTile(Map<String, dynamic> assignment) {
    final dueDate = assignment['dueDate'] as DateTime;
    final isSubmitted = assignment['isSubmitted'] as bool;
    final isOverdue = dueDate.isBefore(DateTime.now()) && !isSubmitted;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: isSubmitted
                  ? AppTheme.successColor
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
                  assignment['title'] ?? 'Assignment',
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
                      assignment['subject'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
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
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSubmitted
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : isOverdue
                            ? AppTheme.errorColor.withValues(alpha: 0.1)
                            : AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isSubmitted
                        ? 'Submitted'
                        : isOverdue
                            ? 'Overdue'
                            : 'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSubmitted
                          ? AppTheme.successColor
                          : isOverdue
                              ? AppTheme.errorColor
                              : AppTheme.warningColor,
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

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final lessons = subject['lessons'] as List<dynamic>? ?? [];
    final teacher = subject['teacher'] as Map<String, dynamic>? ?? {};

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _navigateToSubjectDetails(subject),
        child: Container(
          width: double.infinity, // Full width
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
              // Subject icon - clean and minimal
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getSubjectIcon(subject['subject_name']),
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              // Subject content - expanded to take available space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject name - clean typography
                    Text(
                      subject['subject_name'] ?? 'Subject',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Stats row - hours and lessons
                    Text(
                      '${subject['hours_per_week'] ?? 0} hours/week • ${lessons.length} lessons',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Teacher name - minimal design
                    Text(
                      '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
                          .trim(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w400,
                      ),
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

  void _navigateToSubjectDetails(Map<String, dynamic> subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubjectDetailsPage(
          subject: subject,
          classModel: widget.classModel,
          bottomNavigationBar: widget.bottomNavigationBar,
          showBackButton: widget.showBackButton,
        ),
      ),
    );
  }

  // Removed _buildDefaultBottomNavigation method - now using GlobalBottomNavigation
}
