import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_theme.dart';

import '../widgets/offering_card.dart';

class TeacherOfferingsPage extends ConsumerStatefulWidget {
  const TeacherOfferingsPage({super.key});

  @override
  ConsumerState<TeacherOfferingsPage> createState() =>
      _TeacherOfferingsPageState();
}

class _TeacherOfferingsPageState extends ConsumerState<TeacherOfferingsPage>
    with TickerProviderStateMixin {
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
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Teaching Schedule',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showOfferingSearch(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value, user),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view_schedule',
                child: ListTile(
                  leading: Icon(Icons.schedule),
                  title: Text('View Weekly Schedule'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_schedule',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Schedule'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'This Week'),
            Tab(text: 'Upcoming'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick Stats
          Container(
            color: AppTheme.primaryColor,
            child: _buildQuickStats(user),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOfferingsList('active', user),
                _buildOfferingsList('this_week', user),
                _buildOfferingsList('upcoming', user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(User user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Active Classes',
              value: '6',
              icon: Icons.class_,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Total Students',
              value: '180',
              icon: Icons.people,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'This Week',
              value: '24h',
              icon: Icons.access_time,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingsList(String filterType, User user) {
    // Mock data - replace with actual provider
    final offerings = _getMockOfferings(filterType, user);

    if (offerings.isEmpty) {
      return _buildEmptyState(filterType);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: offerings.length,
      itemBuilder: (context, index) {
        final offering = offerings[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OfferingCard(
            offering: offering,
            onTap: () => _navigateToOfferingDetails(offering),
            onAssignmentsPressed: () =>
                _navigateToOfferingAssignments(offering),
            onStudentsPressed: () => _navigateToOfferingStudents(offering),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String filterType) {
    String message;
    IconData icon;

    switch (filterType) {
      case 'this_week':
        message = 'No classes scheduled for this week';
        icon = Icons.event_busy;
        break;
      case 'upcoming':
        message = 'No upcoming classes';
        icon = Icons.upcoming;
        break;
      default:
        message = 'No active class offerings';
        icon = Icons.class_;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<MockOffering> _getMockOfferings(String filterType, User user) {
    // Mock data - replace with actual API calls
    final baseOfferings = [
      MockOffering(
        id: '1',
        className: 'Grade 10A',
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        studentCount: 32,
        schedule: 'Mon, Wed, Fri - 08:00',
        room: 'Room 201',
        hoursPerWeek: 4,
        color: Colors.blue,
        nextClass: DateTime.now().add(const Duration(hours: 2)),
        hasAssignments: true,
        pendingGrades: 5,
      ),
      MockOffering(
        id: '2',
        className: 'Grade 10B',
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        studentCount: 28,
        schedule: 'Mon, Wed, Fri - 10:00',
        room: 'Room 201',
        hoursPerWeek: 4,
        color: Colors.blue,
        nextClass: DateTime.now().add(const Duration(days: 1, hours: 2)),
        hasAssignments: true,
        pendingGrades: 3,
      ),
      MockOffering(
        id: '3',
        className: 'Grade 11A',
        subjectName: 'Physics',
        subjectCode: 'PHY201',
        studentCount: 30,
        schedule: 'Tue, Thu - 09:00',
        room: 'Lab 1',
        hoursPerWeek: 3,
        color: Colors.green,
        nextClass: DateTime.now().add(const Duration(days: 2)),
        hasAssignments: false,
        pendingGrades: 0,
      ),
    ];

    // Filter based on type
    if (filterType == 'this_week') {
      return baseOfferings
          .where((o) => o.nextClass.difference(DateTime.now()).inDays < 7)
          .toList();
    } else if (filterType == 'upcoming') {
      return baseOfferings
          .where((o) =>
              o.nextClass.isAfter(DateTime.now().add(const Duration(days: 7))))
          .toList();
    }

    return baseOfferings;
  }

  void _showOfferingSearch(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search feature - Under Development')),
    );
  }

  void _handleMenuAction(BuildContext context, String action, User user) {
    switch (action) {
      case 'view_schedule':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Weekly Schedule View - Under Development')),
        );
        break;
      case 'export_schedule':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export Schedule - Under Development')),
        );
        break;
    }
  }

  void _navigateToOfferingDetails(MockOffering offering) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Class Details: ${offering.className} - ${offering.subjectName} - Under Development'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _navigateToOfferingAssignments(MockOffering offering) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Assignments for ${offering.subjectName} - Under Development'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _navigateToOfferingStudents(MockOffering offering) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Students in ${offering.className} - Under Development'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }
}

// Mock model for class offerings
class MockOffering {
  final String id;
  final String className;
  final String subjectName;
  final String subjectCode;
  final int studentCount;
  final String schedule;
  final String room;
  final int hoursPerWeek;
  final Color color;
  final DateTime nextClass;
  final bool hasAssignments;
  final int pendingGrades;

  MockOffering({
    required this.id,
    required this.className,
    required this.subjectName,
    required this.subjectCode,
    required this.studentCount,
    required this.schedule,
    required this.room,
    required this.hoursPerWeek,
    required this.color,
    required this.nextClass,
    required this.hasAssignments,
    required this.pendingGrades,
  });
}
