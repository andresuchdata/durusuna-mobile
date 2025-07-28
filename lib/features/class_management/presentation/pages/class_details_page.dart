import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/global_app_scaffold.dart';
import '../widgets/lesson_tile.dart';

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

class ClassDetailsPage extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const ClassDetailsPage({
    super.key,
    required this.classModel,
  });

  @override
  ConsumerState<ClassDetailsPage> createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends ConsumerState<ClassDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;
    final subjectsAsync =
        ref.watch(classSubjectsProvider(widget.classModel.id));

    return GlobalAppScaffold(
      title: widget.classModel.name,
      child: Container(
        color: AppTheme.backgroundColor,
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

            return Column(
              children: [
                _buildClassHeader(subjects),
                Expanded(
                  child: ListView.builder(
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: _buildSubjectCard(subject),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySubjects() {
    return Center(
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

  Widget _buildClassHeader(List<Map<String, dynamic>> subjects) {
    return Container(
      height: 120,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.classModel.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.classModel.academicYear} • ${subjects.length} subjects',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final lessons = subject['lessons'] as List<dynamic>? ?? [];
    final teacher = subject['teacher'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.book,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          subject['subject_name'] ?? 'Subject',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${subject['hours_per_week'] ?? 0} hours/week • ${lessons.length} lessons',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject info
                if (subject['subject_description'] != null) ...[
                  Text(
                    subject['subject_description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Teacher: ${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (subject['classroom'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.room,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Classroom: ${subject['classroom']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Lessons section
                if (lessons.isNotEmpty) ...[
                  const Text(
                    'Recent Lessons:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...lessons.take(3).map((lesson) {
                    final lessonMap = lesson as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LessonTile(
                        lesson: lessonMap,
                        onTap: () => _showLessonDetails(lessonMap),
                      ),
                    );
                  }).toList(),
                  if (lessons.length > 3) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to full lessons list
                      },
                      child: Text('View all ${lessons.length} lessons'),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'No lessons yet for this subject',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
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

  void _showLessonDetails(Map<String, dynamic> lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson['title'] ?? 'Lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lesson['description'] != null) ...[
              Text(lesson['description']),
              const SizedBox(height: 8),
            ],
            if (lesson['lesson_objectives'] != null) ...[
              const Text('Objectives:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(lesson['lesson_objectives']),
              const SizedBox(height: 8),
            ],
            if (lesson['homework_assigned'] != null) ...[
              const Text('Homework:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(lesson['homework_assigned']),
            ],
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
