import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../pages/assignments_main_page.dart';
import 'assignment_card.dart';

class AssignmentListView extends ConsumerWidget {
  final AssignmentFilterType filterType;
  final UserRoleType userRole;

  const AssignmentListView({
    super.key,
    required this.filterType,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This would normally use a provider to fetch assignments
    final assignments = _getMockAssignments();
    final filteredAssignments = _filterAssignments(assignments);

    if (filteredAssignments.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Implement refresh logic
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAssignments.length,
        itemBuilder: (context, index) {
          final assignment = filteredAssignments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AssignmentCard(
              assignment: assignment,
              userRole: userRole,
              onTap: () => _navigateToAssignmentDetail(context, assignment),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (filterType) {
      case AssignmentFilterType.all:
        message = userRole == UserRoleType.student
            ? 'No assignments found'
            : 'No assignments created yet';
        icon = Icons.assignment_outlined;
        break;
      case AssignmentFilterType.dueSoon:
        message = 'No assignments due soon';
        icon = Icons.schedule_outlined;
        break;
      case AssignmentFilterType.submitted:
        message = 'No submitted assignments';
        icon = Icons.upload_outlined;
        break;
      case AssignmentFilterType.graded:
        message = 'No graded assignments';
        icon = Icons.grade_outlined;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (userRole != UserRoleType.student &&
              filterType == AssignmentFilterType.all)
            TextButton.icon(
              onPressed: () {
                // TODO: Navigate to create assignment
              },
              icon: const Icon(Icons.add),
              label: const Text('Create First Assignment'),
            ),
        ],
      ),
    );
  }

  List<MockAssignment> _filterAssignments(List<MockAssignment> assignments) {
    switch (filterType) {
      case AssignmentFilterType.all:
        return assignments;
      case AssignmentFilterType.dueSoon:
        return assignments.where((a) => a.isDueSoon).toList();
      case AssignmentFilterType.submitted:
        return assignments.where((a) => a.isSubmitted).toList();
      case AssignmentFilterType.graded:
        return assignments.where((a) => a.isGraded).toList();
    }
  }

  void _navigateToAssignmentDetail(
      BuildContext context, MockAssignment assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentDetailPage(assignment: assignment),
      ),
    );
  }

  // Mock data - replace with actual API calls
  List<MockAssignment> _getMockAssignments() {
    return [
      MockAssignment(
        id: '1',
        title: 'Matematika - Latihan Aljabar',
        subject: 'Matematika',
        className: '8 Makkah 1',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        totalPoints: 100,
        submissionCount: 15,
        totalStudents: 25,
        type: 'Tugas Harian',
        isSubmitted: false,
        isGraded: false,
      ),
      MockAssignment(
        id: '2',
        title: 'Bahasa Indonesia - Esai Argumentatif',
        subject: 'Bahasa Indonesia',
        className: '8 Makkah 1',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        totalPoints: 80,
        submissionCount: 12,
        totalStudents: 25,
        type: 'Tugas Harian',
        isSubmitted: true,
        isGraded: false,
      ),
      MockAssignment(
        id: '3',
        title: 'IPA - Laporan Praktikum',
        subject: 'IPA',
        className: '8 Madinah 1',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        totalPoints: 120,
        submissionCount: 20,
        totalStudents: 22,
        type: 'Ulangan Harian',
        isSubmitted: true,
        isGraded: true,
        grade: 85,
      ),
    ];
  }
}

// Mock data model - replace with actual assignment model
class MockAssignment {
  final String id;
  final String title;
  final String subject;
  final String className;
  final DateTime dueDate;
  final int totalPoints;
  final int submissionCount;
  final int totalStudents;
  final String type;
  final bool isSubmitted;
  final bool isGraded;
  final double? grade;

  MockAssignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.className,
    required this.dueDate,
    required this.totalPoints,
    required this.submissionCount,
    required this.totalStudents,
    required this.type,
    required this.isSubmitted,
    required this.isGraded,
    this.grade,
  });

  bool get isDueSoon {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    return difference >= 0 && difference <= 3;
  }

  bool get isOverdue => DateTime.now().isAfter(dueDate);

  String get statusText {
    if (isGraded) return 'Graded';
    if (isSubmitted) return 'Submitted';
    if (isOverdue) return 'Overdue';
    if (isDueSoon) return 'Due Soon';
    return 'Active';
  }

  Color get statusColor {
    if (isGraded) return AppTheme.successColor;
    if (isSubmitted) return AppTheme.infoColor;
    if (isOverdue) return AppTheme.errorColor;
    if (isDueSoon) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }
}

// Placeholder for assignment detail page
class AssignmentDetailPage extends StatelessWidget {
  final MockAssignment assignment;

  const AssignmentDetailPage({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(assignment.title),
      ),
      body: Center(
        child: Text('Assignment Detail - ${assignment.title}'),
      ),
    );
  }
}
