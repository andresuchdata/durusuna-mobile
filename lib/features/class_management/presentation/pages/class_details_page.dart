import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/global_app_scaffold.dart';
import '../widgets/lesson_tile.dart';
import 'subject_details_page.dart';

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
                    padding: EdgeInsets.zero, // Remove default ListView padding
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return _buildSubjectCard(subject);
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
      height: 100, // Reduced height since we removed class name
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
            // Removed redundant class name - it's already in the navbar
            Text(
              '${widget.classModel.academicYear} • ${subjects.length} subjects',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16, // Slightly larger since it's now the main text
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16), // Reduced bottom spacing
          ],
        ),
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
                  color: AppTheme.primaryColor.withOpacity(0.08),
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
                        color: AppTheme.textSecondary.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Clean arrow indicator
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
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
        ),
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
