import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/global_app_scaffold.dart';
import '../widgets/student_tile.dart';
import '../widgets/teacher_tile.dart';
import '../widgets/lesson_tile.dart';

// Providers for class details data
final classStudentsProvider =
    FutureProvider.family<List<User>, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassStudents(classId);
});

final classTeachersProvider =
    FutureProvider.family<List<User>, String>((ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassTeachers(classId);
});

final classLessonsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, classId) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassLessons(classId);
});

final classManagementServiceProvider = Provider<ClassManagementService>((ref) {
  return ClassManagementService();
});

class ClassDetailsPage extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const ClassDetailsPage({
    super.key,
    required this.classModel,
  });

  @override
  ConsumerState<ClassDetailsPage> createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends ConsumerState<ClassDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final currentUser = authState.user;

    return GlobalAppScaffold(
      showNotifications: false,
      automaticallyImplyLeading: false,
      child: Container(
        color: AppTheme.backgroundColor,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                title: Text(
                  widget.classModel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.class_,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.classModel.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        widget.classModel.academicYear,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: 'Students'),
                    Tab(text: 'Teachers'),
                    Tab(text: 'Lessons'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildStudentsTab(),
              _buildTeachersTab(),
              _buildLessonsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    final studentsAsync =
        ref.watch(classStudentsProvider(widget.classModel.id));

    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          _buildErrorWidget('Failed to load students', error.toString()),
      data: (students) => _buildStudentsList(students),
    );
  }

  Widget _buildStudentsList(List<User> students) {
    if (students.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No students enrolled',
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
        return StudentTile(
          student: students[index],
          onTap: () => _showStudentDetails(students[index]),
        );
      },
    );
  }

  Widget _buildTeachersTab() {
    final teachersAsync =
        ref.watch(classTeachersProvider(widget.classModel.id));

    return teachersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          _buildErrorWidget('Failed to load teachers', error.toString()),
      data: (teachers) => _buildTeachersList(teachers),
    );
  }

  Widget _buildTeachersList(List<User> teachers) {
    if (teachers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No teachers assigned',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teachers.length,
      itemBuilder: (context, index) {
        return TeacherTile(
          teacher: teachers[index],
          onTap: () => _showTeacherDetails(teachers[index]),
        );
      },
    );
  }

  Widget _buildLessonsTab() {
    final lessonsAsync = ref.watch(classLessonsProvider(widget.classModel.id));

    return lessonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          _buildErrorWidget('Failed to load lessons', error.toString()),
      data: (lessons) => _buildLessonsList(lessons),
    );
  }

  Widget _buildLessonsList(List<Map<String, dynamic>> lessons) {
    if (lessons.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No lessons scheduled',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        return LessonTile(
          lesson: lessons[index],
          onTap: () => _showLessonDetails(lessons[index]),
        );
      },
    );
  }

  Widget _buildErrorWidget(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(User student) {
    // Navigate to student details or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${student.firstName} ${student.lastName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${student.email}'),
            if (student.phone?.isNotEmpty == true)
              Text('Phone: ${student.phone}'),
            Text('User Type: ${student.userType.name.toUpperCase()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTeacherDetails(User teacher) {
    // Navigate to teacher details or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${teacher.firstName} ${teacher.lastName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${teacher.email}'),
            if (teacher.phone?.isNotEmpty == true)
              Text('Phone: ${teacher.phone}'),
            Text('User Type: ${teacher.userType.name.toUpperCase()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLessonDetails(Map<String, dynamic> lesson) {
    // Navigate to lesson details or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson['title'] ?? 'Lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject: ${lesson['subject'] ?? 'Not specified'}'),
            if (lesson['description'] != null)
              Text('Description: ${lesson['description']}'),
            Text('Status: ${lesson['status'] ?? 'scheduled'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
