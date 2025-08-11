import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';

// Providers for student details
final studentParentsProvider =
    FutureProvider.family<List<User>, String>((ref, studentId) async {
  // Mock data - replace with actual API call
  await Future.delayed(const Duration(milliseconds: 500));

  // For now, return mock parent data
  // In real implementation, this would call the backend API
  return [
    User(
      id: 'parent1',
      firstName: 'John',
      lastName: 'Smith',
      email: 'john.smith@email.com',
      phone: '+1-555-0123',
      userType: UserType.parent,
      avatarUrl: null,
    ),
    User(
      id: 'parent2',
      firstName: 'Sarah',
      lastName: 'Smith',
      email: 'sarah.smith@email.com',
      phone: '+1-555-0124',
      userType: UserType.parent,
      avatarUrl: null,
    ),
  ];
});

final studentAssignmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, studentId) async {
  // Mock data - replace with actual API call
  await Future.delayed(const Duration(milliseconds: 700));

  return [
    {
      'id': 'assign1',
      'title': 'Math Homework - Chapter 5',
      'subject': 'Mathematics',
      'type': 'homework',
      'dueDate': DateTime.now().add(const Duration(days: 2)),
      'status': 'pending',
      'score': null,
      'maxScore': 100.0,
    },
    {
      'id': 'assign2',
      'title': 'Science Lab Report',
      'subject': 'Science',
      'type': 'project',
      'dueDate': DateTime.now().subtract(const Duration(days: 1)),
      'status': 'submitted',
      'score': 85.5,
      'maxScore': 100.0,
    },
    {
      'id': 'assign3',
      'title': 'English Essay - My Family',
      'subject': 'English',
      'type': 'essay',
      'dueDate': DateTime.now().add(const Duration(days: 5)),
      'status': 'graded',
      'score': 92.0,
      'maxScore': 100.0,
    },
  ];
});

class StudentDetailPage extends ConsumerStatefulWidget {
  final User student;
  final ClassModel classModel;

  const StudentDetailPage({
    super.key,
    required this.student,
    required this.classModel,
  });

  @override
  ConsumerState<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends ConsumerState<StudentDetailPage>
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.student.displayName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Column(
        children: [
          // Student Header Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar and Basic Info
                Row(
                  children: [
                    // Large Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                      child: widget.student.avatarUrl != null &&
                              widget.student.avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.student.avatarUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildLargeInitialsAvatar();
                                },
                              ),
                            )
                          : _buildLargeInitialsAvatar(),
                    ),

                    const SizedBox(width: 20),

                    // Student Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.student.displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.classModel.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Student ID: ${widget.student.id.substring(0, 8)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Personal'),
                      Tab(text: 'Parents'),
                      Tab(text: 'Assignments'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalTab(),
                _buildParentsTab(),
                _buildAssignmentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeInitialsAvatar() {
    final initials = widget.student.displayName
        .split(' ')
        .take(2)
        .map((name) => name.isNotEmpty ? name[0].toUpperCase() : '')
        .join('');

    return Container(
      width: 80,
      height: 80,
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
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Contact Information',
            [
              _buildInfoRow(
                  'Email', widget.student.email, Icons.email_outlined),
              if (widget.student.phone != null &&
                  widget.student.phone!.isNotEmpty)
                _buildInfoRow(
                    'Phone', widget.student.phone!, Icons.phone_outlined),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            'Account Details',
            [
              _buildInfoRow(
                  'User Type',
                  widget.student.userType.name.toUpperCase(),
                  Icons.person_outline),
              _buildInfoRow(
                  'Status',
                  widget.student.isActive == true ? 'Active' : 'Inactive',
                  Icons.circle,
                  statusColor: widget.student.isActive == true
                      ? Colors.green
                      : Colors.red),
              if (widget.student.createdAt != null)
                _buildInfoRow(
                    'Member Since',
                    _formatDate(widget.student.createdAt!),
                    Icons.calendar_today_outlined),
              if (widget.student.lastActiveAt != null)
                _buildInfoRow(
                    'Last Active',
                    _formatDate(widget.student.lastActiveAt!),
                    Icons.access_time),
            ],
          ),

          const SizedBox(height: 16),

          // Attendance Recognition Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.blue[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Recognition',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Student avatar is configured for future attendance tracking using image recognition.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentsTab() {
    final parentsAsync = ref.watch(studentParentsProvider(widget.student.id));

    return parentsAsync.when(
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
                'Unable to load parent information',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (parents) {
        if (parents.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.family_restroom_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No parent information available',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: parents.length,
          itemBuilder: (context, index) {
            final parent = parents[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.orange.withOpacity(0.8),
                              Colors.orange[300]!,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            parent.displayName
                                .split(' ')
                                .take(2)
                                .map((name) => name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '')
                                .join(''),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Parent/Guardian',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Email', parent.email, Icons.email_outlined),
                  if (parent.phone != null && parent.phone!.isNotEmpty)
                    _buildInfoRow('Phone', parent.phone!, Icons.phone_outlined),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAssignmentsTab() {
    final assignmentsAsync =
        ref.watch(studentAssignmentsProvider(widget.student.id));

    return assignmentsAsync.when(
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
                'Unable to load assignments',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (assignments) {
        if (assignments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No assignments found',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            return _buildAssignmentCard(assignment);
          },
        );
      },
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: statusColor ?? AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: statusColor ?? AppTheme.textPrimary,
                fontWeight:
                    statusColor != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final status = assignment['status'] as String;
    final score = assignment['score'] != null
        ? (assignment['score'] as num).toDouble()
        : null;
    final maxScore = (assignment['maxScore'] as num).toDouble();
    final dueDate = assignment['dueDate'] as DateTime;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case 'submitted':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Submitted';
        break;
      case 'graded':
        statusColor = Colors.green;
        statusIcon = Icons.grade;
        statusText = 'Graded';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            assignment['subject'],
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                'Due: ${_formatDate(dueDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (score != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${score.toStringAsFixed(1)}/${maxScore.toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else if (difference.inDays > 0) {
      return 'In ${difference.inDays} days';
    } else {
      return '${-difference.inDays} days ago';
    }
  }
}
