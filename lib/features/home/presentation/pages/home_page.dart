import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/global_auth_handler.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../../shared/models/assignment.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/notification.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/widgets/global_app_drawer.dart';
import '../../../../shared/widgets/global_bottom_navigation.dart';
import '../../../../shared/widgets/avatar_widget.dart';
import '../../../../shared/utils/notification_helpers.dart';

import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../assignments/presentation/pages/assignment_detail_page.dart';
import '../../../chat/presentation/pages/conversations_page.dart';
import '../../../chat/presentation/pages/local_chat_page.dart';
import '../../../class_management/presentation/pages/class_management_page.dart';
import '../../../class_management/presentation/pages/class_details_page.dart';
import '../../../class_management/presentation/widgets/class_card.dart';
import '../../../class_management/presentation/widgets/create_class_dialog.dart';
import '../../../../shared/services/assignments_service.dart';
import '../../../class_updates/presentation/pages/class_updates_page.dart';
import '../../../attendance/presentation/pages/student_attendance_page.dart';
import '../../../attendance/presentation/pages/teacher_attendance_page.dart';

import '../../../subjects/presentation/pages/subjects_main_page.dart';
import '../../../assignments/presentation/pages/flexible_assignments_page.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/early_participant_loader.dart';
import 'profile_page.dart';

// Import the existing provider to avoid conflicts
import '../../../class_management/presentation/pages/class_management_page.dart'
    show userClassesProvider;
import '../../../class_management/presentation/pages/class_details_page.dart'
    show classCountsProvider;

final classActivityProvider = FutureProvider.family
    .autoDispose<ClassActivitySummary, String>((ref, classId) async {
  // Keep the provider alive for 5 minutes to prevent constant refetching
  ref.keepAlive();

  // Add timeout to prevent hanging
  try {
    // This would fetch unread counts, recent updates, etc.
    // Simulate async operation with timeout
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data - in real implementation, this would fetch from your backend
    return ClassActivitySummary(
      classId: classId,
      unreadMessages: (classId.hashCode % 10),
      unreadUpdates: (classId.hashCode % 5),
      upcomingEvents: (classId.hashCode % 3),
      recentActivity: _getMockRecentActivity(classId),
    );
  } catch (e) {
    // Return empty state on error
    return ClassActivitySummary(
      classId: classId,
      unreadMessages: 0,
      unreadUpdates: 0,
      recentActivity: null,
      upcomingEvents: 0,
    );
  }
});

String _getMockRecentActivity(String classId) {
  final activities = [
    'New assignment posted',
    'Quiz scheduled for Friday',
    'Homework reminder',
    'Parent-teacher meeting',
    'Project submission due',
    'New announcement',
  ];
  return activities[classId.hashCode % activities.length];
}

// Cache the organized stats to prevent unnecessary rebuilds
final quickStatsProvider = Provider<Map<String, String>>((ref) {
  final userClassesAsync = ref.watch(userClassesProvider);

  return userClassesAsync.when(
    data: (classes) => {
      'Classes': classes.length.toString(),
      'Unread': '8', // This should come from actual data
      'Today': '3', // This should come from actual data
    },
    loading: () => {
      'Classes': '-',
      'Unread': '-',
      'Today': '-',
    },
    error: (_, __) => {
      'Classes': '-',
      'Unread': '-',
      'Today': '-',
    },
  );
});

class ClassActivitySummary {
  final String classId;
  final int unreadMessages;
  final int unreadUpdates;
  final int upcomingEvents;
  final String? recentActivity;

  ClassActivitySummary({
    required this.classId,
    required this.unreadMessages,
    required this.unreadUpdates,
    required this.upcomingEvents,
    this.recentActivity,
  });

  int get totalUnread => unreadMessages + unreadUpdates;
}

class EnhancedHomePage extends ConsumerStatefulWidget {
  const EnhancedHomePage({super.key});

  @override
  ConsumerState<EnhancedHomePage> createState() => _EnhancedHomePageState();
}

class _EnhancedHomePageState extends ConsumerState<EnhancedHomePage> {
  @override
  void initState() {
    super.initState();
    // Add debug logging to understand authentication state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authStateProvider);

      // If user is null but we might have stored data, try to reinitialize
      if (authState.user == null && !authState.isLoading) {
        debugPrint('🔄 Attempting to reinitialize auth state...');
        // Force a check of the auth status
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            final currentState = ref.read(authStateProvider);
            if (currentState.user == null) {
              debugPrint('🔄 Re-checking auth status...');
              ref.read(authStateProvider.notifier).checkAuthStatus();
            }
          }
        });
      }

      // Initialize notifications unread count and load recent notifications
      if (authState.isAuthenticated && authState.user != null) {
        debugPrint('🔔 Initializing notifications...');
        ref.read(notificationsProvider.notifier).initializeWithData();

        // Load participants for group conversations early to prevent flickering
        _loadParticipantsEarly();
      }
    });
  }

  /// Load participants for group conversations early to prevent flickering
  /// This ensures participant names are available immediately when opening group chats
  Future<void> _loadParticipantsEarly() async {
    try {
      debugPrint('🔍 [HomePage] Starting early participant loading...');

      // Get conversations to find group conversations
      final conversationsState = ref.read(conversationsProvider);
      List<String> groupConversationIds = [];

      if (conversationsState.conversations.isNotEmpty) {
        // Extract group conversation IDs
        groupConversationIds = conversationsState.conversations
            .where((conv) => conv.type == 'group')
            .map((conv) => conv.id)
            .toList();

        debugPrint(
            '🔍 [HomePage] Found ${groupConversationIds.length} group conversations');
      } else {
        // If no conversations loaded yet, try to load them first
        debugPrint(
            '🔍 [HomePage] No conversations loaded yet, loading conversations first...');
        await ref.read(conversationsProvider.notifier).loadConversations();

        final updatedState = ref.read(conversationsProvider);
        groupConversationIds = updatedState.conversations
            .where((conv) => conv.type == 'group')
            .map((conv) => conv.id)
            .toList();

        debugPrint(
            '🔍 [HomePage] Loaded ${groupConversationIds.length} group conversations');
      }

      if (groupConversationIds.isNotEmpty) {
        // Load participants for all group conversations
        await EarlyParticipantLoader.loadAllParticipants(groupConversationIds);
        debugPrint('🔍 [HomePage] Early participant loading completed');
      } else {
        debugPrint(
            '🔍 [HomePage] No group conversations found, skipping participant loading');
      }
    } catch (e) {
      debugPrint('❌ [HomePage] Failed to load participants early: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final currentIndex = ref.watch(globalBottomNavigationProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Loading user data...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  debugPrint('🔄 Manual refresh authentication state');
                  ref.read(authStateProvider.notifier).checkAuthStatus();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: const GlobalAppDrawer(),
      body: SafeArea(
        child: IndexedStack(
          index: currentIndex,
          children: [
            _buildEnhancedHomeTab(user),
            _buildConversationsTab(),
            _buildAllClassesTab(user),
            user.userType == UserType.teacher
                ? const TeacherAttendancePage()
                : const StudentAttendancePage(),
            _buildProfileTab(user),
          ],
        ),
      ),
      bottomNavigationBar: GlobalBottomNavigation(
        currentIndex: currentIndex,
        onTap: (index) {
          ref
              .read(globalBottomNavigationProvider.notifier)
              .setCurrentIndex(index);
        },
      ),
    );
  }

  Widget _buildEnhancedHomeTab(User user) {
    final userClassesAsync = ref.watch(userClassesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh classes data
        ref.invalidate(userClassesProvider);
        // Refresh notifications
        ref
            .read(notificationsProvider.notifier)
            .loadNotifications(refresh: true);
        // Wait for the refresh to complete
        await ref.read(userClassesProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          // Enhanced Header with User Info
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryColor,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              _buildNotificationButton(),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: _buildHeaderBackground(user),
            ),
          ),

          // Quick Stats Bar (Pinned)
          SliverPersistentHeader(
            pinned: true,
            delegate: _QuickStatsDelegate(ref.watch(quickStatsProvider)),
          ),

          // My Classes Section
          SliverToBoxAdapter(
            child: _buildMyClassesSection(userClassesAsync),
          ),

          // Recent Activity Feed
          SliverToBoxAdapter(
            child: _buildRecentActivitySection(),
          ),

          // Recent Assignments (Teacher)
          SliverToBoxAdapter(
            child: _buildRecentAssignmentsSection(),
          ),

          // Quick Actions Section
          SliverToBoxAdapter(
            child: _buildQuickActionsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAssignmentsSection() {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final assignmentsFuture = ref.watch(_recentAssignmentsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FlexibleAssignmentsPage(
                        params: AssignmentListParams(
                          context: AssignmentNavigationContext.fromHome,
                          title: 'My Assignments',
                          showClassFilter: true,
                          showSubjectFilter: true,
                          showStats: false,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          assignmentsFuture.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (e, st) {
              debugPrint('⚠️ Recent assignments error: $e');
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No recent assignments',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              );
            },
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No recent assignments',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }

              return Column(
                children:
                    items.take(3).map((a) => _buildAssignmentRow(a)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentRow(Assignment assignment) {
    final title = assignment.title;
    final type = assignment.typeDisplayName;
    final subjectName = assignment.subjectName ?? '';
    final dueDateStr = assignment.dueDate?.toIso8601String();

    return InkWell(
      onTap: () => _navigateToAssignmentDetail(assignment),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              type == 'test'
                  ? Icons.quiz
                  : type == 'final_exam'
                      ? Icons.fact_check
                      : Icons.assignment,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (subjectName.isNotEmpty)
                        Text(
                          subjectName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      if (subjectName.isNotEmpty && dueDateStr != null)
                        const Text(' • '),
                      if (dueDateStr != null)
                        Text(
                          dueDateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _navigateToAssignmentDetail(Assignment assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentDetailPage(
          assignmentId: assignment.id,
          title: assignment.title,
        ),
      ),
    );
  }

  static final _recentAssignmentsProvider =
      FutureProvider<List<Assignment>>((ref) async {
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    final service = ref.read(assignmentsServiceProvider);

    if (user == null) return <Assignment>[];

    if (user.userType == UserType.teacher) {
      // Teachers get recent assignments from subjects they teach
      return await service.getUserAssignments(
        limit: 3,
        status: 'all', // Teachers see both published and draft assignments
      );
    } else {
      // Students/parents get their recent assignments (due soon)
      return await service.getUserAssignments(
        limit: 3,
        status: 'published',
      );
    }
  });

  Widget _buildHeaderBackground(User user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
            left: 72, right: 16, bottom: 50), // Added space for hamburger menu
        child: Row(
          children: [
            AvatarWidget(
              avatarUrl: user.avatarUrl,
              initials: '${user.firstName[0]}${user.lastName[0]}',
              radius: 25,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              textColor: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    user.firstName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyClassesSection(AsyncValue<List<ClassModel>> userClassesAsync) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Classes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => ref
                    .read(globalBottomNavigationProvider.notifier)
                    .setCurrentIndex(2),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          userClassesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorCard(error.toString()),
            data: (classes) => _buildClassesGrid(classes),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesGrid(List<ClassModel> classes) {
    if (classes.isEmpty) {
      return _buildEmptyClassesCard();
    }

    // Show maximum 4 classes in home tab as 2 cards per row
    final displayClasses = classes.take(4).toList();

    // Group classes into rows of 2
    final rows = <List<ClassModel>>[];
    for (int i = 0; i < displayClasses.length; i += 2) {
      final endIndex =
          (i + 2 < displayClasses.length) ? i + 2 : displayClasses.length;
      rows.add(displayClasses.sublist(i, endIndex));
    }

    return Column(
      children: rows.map((rowClasses) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildCompactClassCard(rowClasses[0]),
              ),
              if (rowClasses.length > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactClassCard(rowClasses[1]),
                ),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompactClassCard(ClassModel classModel) {
    final countsAsync = ref.watch(classCountsProvider(classModel.id));

    return Card(
      key: ValueKey('class_card_${classModel.id}'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToClassDetails(classModel, context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Class name
                Text(
                  classModel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Class details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classModel.academicYear.isNotEmpty
                          ? classModel.academicYear
                          : 'Academic Year',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        countsAsync.when(
                          loading: () => Text(
                            '${classModel.studentsCount ?? 0}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          error: (error, stack) => Text(
                            '${classModel.studentsCount ?? 0}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          data: (counts) => Text(
                            '${counts.studentCount}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final notificationsState = ref.watch(notificationsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecentNotificationsList(notificationsState),
        ],
      ),
    );
  }

  Widget _buildRecentNotificationsList(NotificationsState notificationsState) {
    if (notificationsState.isLoading &&
        notificationsState.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notificationsState.notifications.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.notifications_outlined,
                  size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text(
                'No recent notifications',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Show only the 3 most recent notifications
    final recentNotifications =
        notificationsState.notifications.take(3).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentNotifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildNotificationTile(recentNotifications[index]);
      },
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationTypeColor(notification.type)
              .withValues(alpha: 0.1),
          child: Icon(
            _getNotificationTypeIcon(notification.type),
            color: _getNotificationTypeColor(notification.type),
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${notification.content} • ${app_date_utils.DateUtils.formatRelativeTime(notification.createdAt)}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionsGrid(),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    List<Widget> quickActions = [];

    // Common actions for all users
    quickActions.add(
      _buildQuickActionCard(
        title: 'New Message',
        icon: Icons.add_comment,
        color: AppTheme.successColor,
        onTap: () => ref
            .read(globalBottomNavigationProvider.notifier)
            .setCurrentIndex(1),
      ),
    );

    // Student-specific actions
    if (currentUser?.userType == UserType.student) {
      quickActions.add(
        _buildQuickActionCard(
          title: 'Mark Attendance',
          icon: Icons.location_on,
          color: AppTheme.primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentAttendancePage(),
              ),
            );
          },
        ),
      );
    }

    // General actions for all users
    quickActions.add(
      _buildQuickActionCard(
        title: 'View Schedule',
        icon: Icons.schedule,
        color: AppTheme.infoColor,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule feature coming soon')),
          );
        },
      ),
    );

    // If teacher, add class management shortcuts
    if (currentUser?.userType == UserType.teacher) {
      quickActions.add(
        _buildQuickActionCard(
          title: 'My Subjects',
          icon: Icons.book,
          color: AppTheme.accentColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SubjectsMainPage(),
              ),
            );
          },
        ),
      );

      quickActions.add(
        _buildQuickActionCard(
          title: 'Manage Classes',
          icon: Icons.class_,
          color: AppTheme.primaryColor,
          onTap: () => ref
              .read(globalBottomNavigationProvider.notifier)
              .setCurrentIndex(2), // Assuming class management is at index 2
        ),
      );
    }

    // Build grid layout
    return Column(
      children: [
        Row(
          children: [
            if (quickActions.isNotEmpty) Expanded(child: quickActions[0]),
            if (quickActions.length > 1) ...[
              const SizedBox(width: 12),
              Expanded(child: quickActions[1]),
            ],
          ],
        ),
        if (quickActions.length > 2) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: quickActions[2]),
              if (quickActions.length > 3) ...[
                const SizedBox(width: 12),
                Expanded(child: quickActions[3]),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods and remaining widgets...
  Widget _buildConversationsTab() {
    return const ConversationsPage();
  }

  Widget _buildAllClassesTab(User user) {
    return _ClassManagementTabView();
  }

  Widget _buildProfileTab(User user) {
    return const ProfilePage();
  }

  Widget _buildNotificationButton() {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationsPage(),
              ),
            );
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyClassesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.class_, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            const Text('No classes assigned yet'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 8),
            Text('Error loading classes: $error'),
          ],
        ),
      ),
    );
  }

  // Navigation and utility methods
  void _navigateToClassDetails(ClassModel classModel, BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassDetailsPage(
          classModel: classModel,
          bottomNavigationBar: const GlobalBottomNavigation(
            currentIndex: 2, // Classes tab
            isDetailPage: true,
          ),
          showBackButton: true,
        ),
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) async {
    // Mark notification as read when tapped
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    }

    // Navigate based on notification type and action data
    try {
      switch (notification.type) {
        // Message Related
        case NotificationType.message:
        case NotificationType.messageReceived:
        case NotificationType.conversationCreated:
          await _navigateToConversation(notification);
          break;

        // Class Update Related
        case NotificationType.classUpdateAnnouncement:
        case NotificationType.classUpdateHomework:
        case NotificationType.classUpdateReminder:
        case NotificationType.classUpdateEvent:
        case NotificationType.classUpdateComment:
        case NotificationType.classUpdateReply:
        case NotificationType.announcement:
        case NotificationType.event:
        case NotificationType.reminder:
          await _navigateToClassUpdates(notification);
          break;

        // Assignment Related
        case NotificationType.assignment:
        case NotificationType.assignmentCreated:
        case NotificationType.assignmentUpdated:
        case NotificationType.assignmentDueSoon:
        case NotificationType.assignmentSubmitted:
        case NotificationType.assignmentGraded:
          await _navigateToClassUpdates(notification);
          break;

        // All other types navigate to notifications page
        case NotificationType.attendanceMarked:
        case NotificationType.attendanceLate:
        case NotificationType.attendanceAbsent:
        case NotificationType.gradePosted:
        case NotificationType.gradeUpdated:
        case NotificationType.system:
        case NotificationType.systemAnnouncement:
        case NotificationType.systemMaintenance:
        case NotificationType.systemUpdate:
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NotificationsPage(),
            ),
          );
          break;
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      // Fallback: navigate to notifications page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const NotificationsPage(),
        ),
      );
    }
  }

  Future<void> _navigateToConversation(NotificationModel notification) async {
    final actionData = notification.actionData;
    if (actionData == null) {
      // Fallback: navigate to conversations tab
      ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(1);
      return;
    }

    final conversationId = actionData['conversation_id'] as String?;
    final messageId = actionData['message_id'] as String?;

    if (conversationId == null) {
      // Fallback: navigate to conversations tab
      ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(1);
      return;
    }

    try {
      // Load the specific conversation
      final conversation = await _loadConversation(conversationId);
      if (conversation == null) {
        // Fallback: navigate to conversations tab
        ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(1);
        return;
      }

      // Navigate to chat page with message highlighting support
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LocalChatPage(
            conversation: conversation,
            highlightMessageId: messageId,
            scrollToMessage: messageId != null,
          ),
        ),
      );

      debugPrint(
          'Navigating to conversation: $conversationId, message: $messageId');
    } catch (e) {
      debugPrint('Error navigating to conversation: $e');
      // Fallback: navigate to conversations tab
      ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(1);
    }
  }

  Future<void> _navigateToClassUpdates(NotificationModel notification) async {
    final actionData = notification.actionData;
    if (actionData == null) {
      // Fallback: navigate to classes tab
      ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(2);
      return;
    }

    final classId = actionData['class_id'] as String?;
    final updateId = actionData['update_id'] as String?;
    final className = actionData['class_name'] as String?;

    if (classId == null) {
      // Fallback: navigate to classes tab
      ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(2);
      return;
    }

    try {
      // Navigate to class updates page with update highlighting
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ClassUpdatesPage(
            classId: classId,
            className: className ?? 'Class Updates',
            highlightUpdateId: updateId,
            scrollToUpdate: updateId != null,
          ),
        ),
      );

      debugPrint('Navigating to class updates: $classId, update: $updateId');
    } catch (e) {
      debugPrint('Error navigating to class updates: $e');
      // Fallback: navigate to classes tab
      ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(2);
    }
  }

  Future<Conversation?> _loadConversation(String conversationId) async {
    try {
      // First check if conversation is already in cache
      final conversationsState = ref.read(conversationsProvider);
      final cachedConversation =
          conversationsState.conversations.cast<Conversation?>().firstWhere(
                (conv) => conv?.id == conversationId,
                orElse: () => null,
              );

      if (cachedConversation != null) {
        return cachedConversation;
      }

      // If not in cache, load from service
      await ref.read(conversationsProvider.notifier).loadConversations();

      // Try to find it again after refresh
      final updatedState = ref.read(conversationsProvider);
      return updatedState.conversations.cast<Conversation?>().firstWhere(
            (conv) => conv?.id == conversationId,
            orElse: () => null,
          );
    } catch (e) {
      debugPrint('Error loading conversation: $e');
      return null;
    }
  }

  Color _getNotificationTypeColor(NotificationType type) =>
      NotificationHelpers.getColor(type);

  IconData _getNotificationTypeIcon(NotificationType type) =>
      NotificationHelpers.getIcon(type);

  Color _getUserTypeColor(UserType userType) {
    switch (userType) {
      case UserType.teacher:
        return AppTheme.primaryColor;
      case UserType.student:
        return AppTheme.successColor;
      case UserType.parent:
        return AppTheme.infoColor;
    }
  }

  String _getUserTypeLabel(UserType userType) {
    switch (userType) {
      case UserType.teacher:
        return 'Teacher';
      case UserType.student:
        return 'Student';
      case UserType.parent:
        return 'Parent';
    }
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // Use GlobalAuthHandler for consistent logout behavior with navigation
                if (GlobalAuthHandler.isInitialized) {
                  await GlobalAuthHandler.logout(
                    message: 'You have been logged out successfully.',
                  );
                } else {
                  // Fallback: manual logout + navigation
                  await ref.read(authStateProvider.notifier).logout();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                }
              } catch (e) {
                // Fallback in case of any error
                await ref.read(authStateProvider.notifier).logout();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// Custom tab view for class management without scaffold

class _ClassManagementTabView extends ConsumerWidget {
  const _ClassManagementTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userClassesAsync = ref.watch(userClassesProvider);
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.user;

    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          // Custom app bar for tab view
          Container(
            color: AppTheme.primaryColor,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Class Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (currentUser?.userType == UserType.teacher)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => _showCreateClassDialog(context, ref),
                        tooltip: 'Create Class',
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userClassesProvider);
              },
              child: userClassesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) =>
                    _buildErrorState(error.toString(), ref),
                data: (classes) =>
                    _buildClassList(classes, currentUser, context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassList(List<ClassModel> classes, User? currentUser,
      BuildContext context, WidgetRef ref) {
    if (classes.isEmpty) {
      return _buildEmptyState(currentUser, context, ref);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classModel = classes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClassCard(
            classModel: classModel,
            onTap: () => _navigateToClassDetails(classModel, context),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
      User? currentUser, BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            currentUser?.userType == UserType.teacher
                ? 'No classes assigned yet'
                : 'You are not enrolled in any classes',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser?.userType == UserType.teacher
                ? 'Create a new class or contact your administrator'
                : 'Contact your teacher for class enrollment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (currentUser?.userType == UserType.teacher) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateClassDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(userClassesProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToClassDetails(ClassModel classModel, BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassDetailsPage(
          classModel: classModel,
          bottomNavigationBar: const GlobalBottomNavigation(
            currentIndex: 2, // Classes tab
            isDetailPage: true,
          ),
          showBackButton: false,
        ),
      ),
    );
  }

  // Removed _buildBottomNavigationForDetails method - now using GlobalBottomNavigation

  void _showCreateClassDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => CreateClassDialog(
        onClassCreated: () {
          ref.invalidate(userClassesProvider);
        },
      ),
    );
  }

  // (Duplicate Quick Actions section removed; use the grid-based one earlier in file)
}

// Quick Stats Delegate for pinned header
class _QuickStatsDelegate extends SliverPersistentHeaderDelegate {
  final Map<String, String> stats;

  _QuickStatsDelegate(this.stats);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 80, // Explicit height to match extent
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            _buildQuickStat('Total Classes', stats['Classes'] ?? '-'),
            const SizedBox(width: 24),
            _buildQuickStat('Unread', stats['Unread'] ?? '-'),
            const SizedBox(width: 24),
            _buildQuickStat('Today', stats['Today'] ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant _QuickStatsDelegate oldDelegate) {
    // Only rebuild if the stats have actually changed
    return stats != oldDelegate.stats;
  }
}

// Supporting data classes
class RecentActivity {
  final String title;
  final String subtitle;
  final String time;
  final ActivityType type;
  final String classId;

  RecentActivity({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.classId,
  });
}

enum ActivityType {
  message,
  assignment,
  update,
}
