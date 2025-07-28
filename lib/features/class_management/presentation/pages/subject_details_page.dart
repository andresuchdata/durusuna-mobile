import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/widgets/global_app_scaffold.dart';
import '../widgets/lesson_tile.dart';

class SubjectDetailsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subject;
  final ClassModel classModel;

  const SubjectDetailsPage({
    super.key,
    required this.subject,
    required this.classModel,
  });

  @override
  ConsumerState<SubjectDetailsPage> createState() => _SubjectDetailsPageState();
}

class _SubjectDetailsPageState extends ConsumerState<SubjectDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final lessons = widget.subject['lessons'] as List<dynamic>? ?? [];
    final teacher = widget.subject['teacher'] as Map<String, dynamic>? ?? {};

    return GlobalAppScaffold(
      title: widget.subject['subject_name'] ?? 'Subject Details',
      child: Container(
        color: AppTheme.backgroundColor,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubjectHeader(),
              _buildTeacherInfo(teacher),
              _buildSubjectStats(lessons),
              if (widget.subject['subject_description'] != null)
                _buildDescription(),
              _buildLessonsSection(lessons),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getSubjectIcon(widget.subject['subject_name']),
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            widget.subject['subject_name'] ?? 'Subject',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.classModel.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherInfo(Map<String, dynamic> teacher) {
    return Container(
      margin: const EdgeInsets.all(16),
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
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: const Icon(
              Icons.person,
              color: AppTheme.primaryColor,
              size: 28,
            ),
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
                  '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
                      .trim(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (teacher['email'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    teacher['email'],
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
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
    );
  }

  Widget _buildSubjectStats(List<dynamic> lessons) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Hours/Week',
              '${widget.subject['hours_per_week'] ?? 0}',
              Icons.schedule,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total Lessons',
              '${lessons.length}',
              Icons.book,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Classroom',
              widget.subject['classroom'] ?? 'TBA',
              Icons.room,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
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
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'About This Subject',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.subject['subject_description'],
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsSection(List<dynamic> lessons) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Lessons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (lessons.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${lessons.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (lessons.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 48,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No lessons yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lessons will appear here once they are scheduled',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            ...lessons.map((lesson) {
              final lessonMap = lesson as Map<String, dynamic>;
              return Column(
                children: [
                  LessonTile(
                    lesson: lessonMap,
                    onTap: () => _showLessonDetails(lessonMap),
                  ),
                  if (lesson != lessons.last)
                    Divider(
                      height: 1,
                      color: AppTheme.borderColor.withOpacity(0.3),
                    ),
                ],
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

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
