import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../shared/services/class_updates_service.dart'
    show classUpdatesServiceProvider;
import '../../../../shared/providers/app_providers.dart'
    show classManagementServiceProvider, classTeachersProvider;
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/global_app_drawer.dart';
import '../../../../shared/widgets/global_bottom_navigation.dart';
import '../../../../shared/widgets/avatar_widget.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../assignments/presentation/pages/assignment_detail_page.dart';
import 'student_list_page.dart';
import '../../../class_updates/presentation/pages/class_updates_page.dart';
import '../../../attendance/presentation/pages/attendance_management_page.dart';
import '../../../subjects/presentation/pages/subjects_main_page.dart';
import '../../../subjects/presentation/pages/subject_offering_details_page.dart';
import '../../../../shared/services/subjects_service.dart';
import '../../../../shared/services/academic_service.dart';
import '../../../assignments/presentation/pages/flexible_assignments_page.dart';

// Provider for class teachers (homeroom teachers)
final classTeachersProvider =
    FutureProvider.family<List<User>, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassTeachers(classId);
});

// Provider for teachers associated with class through subject offerings
final classSubjectTeachersProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  try {
    final subjects = await service.getClassOfferings(classId);

    // Extract unique teachers from subject offerings
    final Map<String, Map<String, dynamic>> uniqueTeachers = {};
    final homeroomTeacherAsync = ref.read(classTeachersProvider(classId));
    final homeroomTeacher = homeroomTeacherAsync.when(
      data: (teachers) => teachers.isNotEmpty ? teachers.first : null,
      loading: () => null,
      error: (_, __) => null,
    );
    final homeroomTeacherId = homeroomTeacher?.id;

    debugPrint(
        '🔍 [ClassDetails] Processing ${subjects.length} subjects for teachers');
    debugPrint('🔍 [ClassDetails] Homeroom teacher ID: $homeroomTeacherId');

    for (final subject in subjects) {
      final teacher = subject['teacher'];
      final subjectName =
          subject['subject_name'] ?? subject['subject']?['name'] ?? 'Unknown';

      debugPrint('🔍 [ClassDetails] Subject: $subjectName, Teacher: $teacher');

      if (teacher != null && teacher is Map<String, dynamic>) {
        final teacherId = teacher['id'] as String?;
        final teacherName =
            teacher['first_name'] != null && teacher['last_name'] != null
                ? '${teacher['first_name']} ${teacher['last_name']}'
                : teacher['email'] as String? ?? 'Unknown';

        if (teacherId != null && teacherId.isNotEmpty) {
          // Skip if this teacher is the homeroom teacher
          if (homeroomTeacherId != null && teacherId == homeroomTeacherId) {
            debugPrint(
                '🔍 [ClassDetails] Skipping homeroom teacher: $teacherName');
            continue;
          }

          if (!uniqueTeachers.containsKey(teacherId)) {
            uniqueTeachers[teacherId] = teacher;
            debugPrint('🔍 [ClassDetails] Added subject teacher: $teacherName');
          } else {
            debugPrint(
                '🔍 [ClassDetails] Subject teacher already exists: $teacherName');
          }
        }
      }
    }

    final totalTeacherCount =
        uniqueTeachers.length + (homeroomTeacher != null ? 1 : 0);
    debugPrint(
        '🔍 [ClassDetails] Found ${uniqueTeachers.length} subject teachers, $totalTeacherCount total');

    return {
      'subjectTeachers': uniqueTeachers.values.toList(),
      'subjectTeacherCount': uniqueTeachers.length,
      'homeroomTeacher': homeroomTeacher,
      'totalTeacherCount': totalTeacherCount,
    };
  } catch (e) {
    debugPrint('🔍 [ClassDetails] Error getting subject teachers: $e');
    return {
      'subjectTeachers': [],
      'subjectTeacherCount': 0,
      'homeroomTeacher': null,
      'totalTeacherCount': 0,
    };
  }
});

// Provider for class statistics based on subject offerings
final classStatisticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  try {
    final subjects = await service.getClassOfferings(classId);
    final students = await service.getClassStudents(classId);
    final updates = await ref
        .read(classUpdatesServiceProvider)
        .getClassUpdates(classId, limit: 5);

    final teachersData =
        await ref.read(classSubjectTeachersProvider(classId).future);

    return {
      'studentCount': students.length,
      'teacherCount': teachersData['totalTeacherCount'],
      'subjectCount': subjects.length,
      'updatesCount': updates.length,
      'totalMembers': students.length + teachersData['totalTeacherCount'],
    };
  } catch (e) {
    debugPrint('🔍 [ClassDetails] Error getting statistics: $e');
    return {
      'studentCount': 0,
      'teacherCount': 0,
      'subjectCount': 0,
      'updatesCount': 0,
      'totalMembers': 0,
    };
  }
});

class ClassDetailsPageFixed extends ConsumerStatefulWidget {
  final ClassModel classModel;
  final Widget? bottomNavigationBar;
  final bool showBackButton;

  const ClassDetailsPageFixed({
    super.key,
    required this.classModel,
    this.bottomNavigationBar,
    this.showBackButton = true,
  });

  @override
  ConsumerState<ClassDetailsPageFixed> createState() =>
      _ClassDetailsPageFixedState();
}

class _ClassDetailsPageFixedState extends ConsumerState<ClassDetailsPageFixed> {
  @override
  Widget build(BuildContext context) {
    final teachersDataAsync =
        ref.watch(classSubjectTeachersProvider(widget.classModel.id));
    final statisticsAsync =
        ref.watch(classStatisticsProvider(widget.classModel.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: widget.showBackButton ? const GlobalAppDrawer() : null,
      bottomNavigationBar: widget.bottomNavigationBar ??
          const GlobalBottomNavigation(
            currentIndex: 2, // Classes tab
            isDetailPage: true,
          ),
      body: SafeArea(
        child: teachersDataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text('Failed to load class data'),
                Text(error.toString()),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(
                      classSubjectTeachersProvider(widget.classModel.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (teachersData) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(teachersData['homeroomTeacher']),
                SliverToBoxAdapter(
                  child: _buildClassStatistics(statisticsAsync, teachersData),
                ),
                // Add other sections as needed
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(User? homeroomTeacher) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      automaticallyImplyLeading: widget.showBackButton,
      title: Text(
        'Kelas - ${widget.classModel.name}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        if (homeroomTeacher != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: AvatarWidget(
              avatarUrl: homeroomTeacher.avatarUrl,
              displayName: homeroomTeacher.displayName,
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              textColor: Colors.white.withValues(alpha: 0.9),
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
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kelas - ${widget.classModel.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (homeroomTeacher != null)
                        Text(
                          'Homeroom Teacher: ${homeroomTeacher.displayName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          'No homeroom teacher assigned',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassStatistics(AsyncValue<Map<String, dynamic>> statisticsAsync,
      Map<String, dynamic> teachersData) {
    return Column(
      children: [
        // Homeroom Teacher section
        _buildHomeroomTeacherSection(teachersData['homeroomTeacher']),

        // Subject Teachers section
        _buildSubjectTeachersSection(teachersData['subjectTeachers']),

        // Statistics section
        Container(
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
                statisticsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => const Center(
                    child: Text('Error loading statistics'),
                  ),
                  data: (stats) => _buildStatisticsRow(
                    studentCount: stats['studentCount'] ?? 0,
                    teacherCount: stats['teacherCount'] ?? 0,
                    totalMembers: stats['totalMembers'] ?? 0,
                    subjectCount: stats['subjectCount'] ?? 0,
                    updatesCount: stats['updatesCount'] ?? 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeroomTeacherSection(User? teacher) {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.home,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Homeroom Teacher',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (teacher != null)
              _buildTeacherCard(teacher, isHomeroom: true)
            else
              _buildNoTeacherCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectTeachersSection(List<dynamic> subjectTeachers) {
    if (subjectTeachers.isEmpty) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Subject Teachers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_off,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No subject teachers assigned yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Subject Teachers (${subjectTeachers.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...subjectTeachers.map((teacher) => _buildTeacherCard(
                  _convertTeacherMapToUser(teacher),
                  isHomeroom: false,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard(User teacher, {required bool isHomeroom}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHomeroom
            ? AppTheme.primaryColor.withValues(alpha: 0.05)
            : AppTheme.accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHomeroom
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : AppTheme.accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AvatarWidget(
            avatarUrl: teacher.avatarUrl,
            displayName: teacher.displayName,
            radius: 20,
            backgroundColor: isHomeroom
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.accentColor.withValues(alpha: 0.1),
            textColor:
                isHomeroom ? AppTheme.primaryColor : AppTheme.accentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  teacher.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
                if (isHomeroom) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Homeroom',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chat with ${teacher.displayName} coming soon'),
                  backgroundColor:
                      isHomeroom ? AppTheme.primaryColor : AppTheme.accentColor,
                ),
              );
            },
            icon: Icon(
              Icons.message,
              color: isHomeroom ? AppTheme.primaryColor : AppTheme.accentColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTeacherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_off,
              color: Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No homeroom teacher assigned',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow({
    required int studentCount,
    required int teacherCount,
    required int totalMembers,
    required int subjectCount,
    required int updatesCount,
  }) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard(
            icon: Icons.people,
            title: 'Students',
            count: studentCount,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.person,
            title: 'Teachers',
            count: teacherCount,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.book,
            title: 'Subjects',
            count: subjectCount,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.announcement,
            title: 'Updates',
            count: updatesCount,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  User _convertTeacherMapToUser(Map<String, dynamic> teacherMap) {
    final firstName = teacherMap['first_name'] as String? ?? '';
    final lastName = teacherMap['last_name'] as String? ?? '';
    final email = teacherMap['email'] as String? ?? '';
    final avatarUrl = teacherMap['avatar_url'] as String?;

    return User(
      id: teacherMap['id'] as String? ?? '',
      firstName: firstName,
      lastName: lastName,
      email: email,
      avatarUrl: avatarUrl,
      userType: UserType.teacher,
      isActive: teacherMap['is_active'] as bool? ?? true,
      createdAt: teacherMap['created_at'] != null
          ? DateTime.parse(teacherMap['created_at'] as String)
          : DateTime.now(),
      updatedAt: teacherMap['updated_at'] != null
          ? DateTime.parse(teacherMap['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
