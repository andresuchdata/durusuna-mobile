import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../attendance/presentation/pages/attendance_management_page.dart';
import 'student_detail_page.dart';

// Provider for paginated students list with search
final studentsListWithSearchProvider =
    FutureProvider.family<List<User>, (String, String?)>((ref, params) async {
  final (classId, search) = params;
  final service = ref.read(classManagementServiceProvider);
  return await service.getClassStudents(classId, search: search);
});

final classManagementServiceProvider = Provider<ClassManagementService>((ref) {
  return ClassManagementService();
});

class StudentListPage extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const StudentListPage({
    super.key,
    required this.classModel,
  });

  @override
  ConsumerState<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends ConsumerState<StudentListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListWithSearchProvider(
        (widget.classModel.id, _searchQuery.isEmpty ? null : _searchQuery)));
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Students',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              widget.classModel.displayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          // Show attendance management button for homeroom teachers only
          if (_isCurrentUserHomeroomTeacher(currentUser))
            IconButton(
              icon: const Icon(Icons.check_circle_outline,
                  color: AppTheme.primaryColor),
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
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search students...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Student List
          Expanded(
            child: studentsAsync.when(
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
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load students',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              data: (students) {
                if (students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No students enrolled',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Students will appear here once they are enrolled in this class.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Check if search returned no results
                if (students.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No students found',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search terms',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _buildStudentTile(student);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(User student) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailPage(
                  student: student,
                  classModel: widget.classModel,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  child: student.avatarUrl != null &&
                          student.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            student.avatarUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildInitialsAvatar(student);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : _buildInitialsAvatar(student),
                ),

                const SizedBox(width: 16),

                // Student Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (student.phone != null && student.phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            student.phone!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Student ID Badge (if available)
                if (student.id.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ID: ${student.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),

                // Arrow Icon
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(User student) {
    final initials = student.displayName
        .split(' ')
        .take(2)
        .map((name) => name.isNotEmpty ? name[0].toUpperCase() : '')
        .join('');

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.8),
            AppTheme.accentColor,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
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
}
