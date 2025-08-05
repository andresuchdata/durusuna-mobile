import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/global_auth_handler.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/notification.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/widgets/global_app_drawer.dart';
import '../../../../shared/widgets/global_bottom_navigation.dart';

import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../chat/presentation/pages/conversations_page.dart';
import '../../../class_management/presentation/pages/class_management_page.dart';
import '../../../class_management/presentation/pages/class_details_page.dart';
import '../../../class_management/presentation/widgets/class_card.dart';
import '../../../class_management/presentation/widgets/create_class_dialog.dart';

// Import the existing provider to avoid conflicts
import '../../../class_management/presentation/pages/class_management_page.dart'
    show userClassesProvider;

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
      debugPrint('🏠 EnhancedHomePage: PostFrame callback triggered');
      final authState = ref.read(authStateProvider);
      debugPrint(
          '🔐 Auth State - isAuthenticated: ${authState.isAuthenticated}');
      debugPrint('👤 Auth State - user: ${authState.user?.email ?? 'null'}');
      debugPrint('🔄 Auth State - isLoading: ${authState.isLoading}');
      debugPrint('❌ Auth State - error: ${authState.error ?? 'null'}');

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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final currentIndex = ref.watch(globalBottomNavigationProvider);

    debugPrint(
        '🏠 EnhancedHomePage: Building with user: ${user?.email ?? 'null'}');
    debugPrint(
        '🔐 EnhancedHomePage: isAuthenticated: ${authState.isAuthenticated}');

    if (user == null) {
      debugPrint('⚠️ EnhancedHomePage: User is null, showing loading');
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

    debugPrint(
        '✅ EnhancedHomePage: Rendering main content for user: ${user.email}');

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

          // Quick Actions Section
          SliverToBoxAdapter(
            child: _buildQuickActionsSection(),
          ),
        ],
      ),
    );
  }

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
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(
                      '${user.firstName[0]}${user.lastName[0]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
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

    // Show maximum 3 classes in home tab as full-width cards
    final displayClasses = classes.take(3).toList();

    return Column(
      children: displayClasses
          .map(
            (classModel) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEnhancedClassCard(classModel),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEnhancedClassCard(ClassModel classModel) {
    return Card(
      key: ValueKey('class_card_${classModel.id}'),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToClassDetails(classModel, context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class name
                Text(
                  classModel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Class details
                Text(
                  '${classModel.academicYear} • ${classModel.studentsCount ?? 0} students',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                // Teacher info
                if (classModel.teachers != null &&
                    classModel.teachers!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.person,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${classModel.teachers!.first.firstName} ${classModel.teachers!.first.lastName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Class Teacher',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
          '${notification.content} • ${_formatNotificationTime(notification.createdAt)}',
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
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  title: 'New Message',
                  icon: Icons.add_comment,
                  color: AppTheme.successColor,
                  onTap: () => ref
                      .read(globalBottomNavigationProvider.notifier)
                      .setCurrentIndex(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  title: 'View Schedule',
                  icon: Icons.schedule,
                  color: AppTheme.infoColor,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Schedule feature coming soon')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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
    return Container(
      color: AppTheme.backgroundColor,
      child: CustomScrollView(
        slivers: [
          // Profile header with action buttons
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'settings':
                          // TODO: Navigate to settings
                          break;
                        case 'test_401':
                          // Test 401 handling and navigation
                          GlobalAuthHandler.test401Handler();
                          break;
                        case 'force_logout':
                          // Test force immediate logout
                          GlobalAuthHandler.forceImmediateLogout();
                          break;
                        case 'logout':
                          _showLogoutDialog();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 20),
                            SizedBox(width: 8),
                            Text('Settings'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout,
                                size: 20, color: AppTheme.errorColor),
                            SizedBox(width: 8),
                            Text('Logout',
                                style: TextStyle(color: AppTheme.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Profile content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryColor,
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  '${user.firstName[0]}${user.lastName[0]}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getUserTypeColor(user.userType)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getUserTypeLabel(user.userType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getUserTypeColor(user.userType),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Info
                  _buildInfoSection('Personal Information', [
                    _buildInfoTile('Phone', user.phone ?? 'Not provided'),
                    _buildInfoTile('Role',
                        user.role?.name.toUpperCase() ?? 'Not assigned'),
                    _buildInfoTile(
                        'School', user.school?.name ?? 'Not assigned'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // This method is no longer needed as we're using GlobalBottomNavigation
  // Widget _buildBottomNavigation() {
  //   return BottomNavigationBar(
  //     type: BottomNavigationBarType.fixed,
  //     currentIndex: _currentIndex,
  //     onTap: (index) => setState(() => _currentIndex = index),
  //     selectedItemColor: AppTheme.primaryColor,
  //     unselectedItemColor: AppTheme.textSecondary,
  //     items: const [
  //       BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
  //       BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
  //       BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Classes'),
  //       BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  //     ],
  //   );
  // }

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

  void _handleNotificationTap(NotificationModel notification) {
    // Mark notification as read when tapped
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    }

    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.message:
        ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(1);
        break;
      case NotificationType.assignment:
        ref.read(globalBottomNavigationProvider.notifier).setCurrentIndex(2);
        break;
      case NotificationType.announcement:
      case NotificationType.event:
      case NotificationType.system:
        // Stay on current page
        break;
    }
  }

  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return AppTheme.successColor;
      case NotificationType.assignment:
        return AppTheme.warningColor;
      case NotificationType.announcement:
        return AppTheme.primaryColor;
      case NotificationType.event:
        return AppTheme.infoColor;
      case NotificationType.system:
        return AppTheme.textSecondary;
    }
  }

  IconData _getNotificationTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.message;
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.system:
        return Icons.settings;
    }
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

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
