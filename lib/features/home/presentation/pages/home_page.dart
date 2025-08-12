import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/global_auth_handler.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/services/chat_service.dart';
import '../../../../shared/services/class_updates_service.dart';
import '../../../../shared/services/class_management_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/class_update.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;

import '../../../class_updates/presentation/pages/class_updates_page.dart';
import '../../../chat/presentation/pages/conversations_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../class_management/presentation/pages/class_management_page.dart';

// Class to hold update with class context
class ClassUpdateWithClass {
  final ClassUpdate update;
  final String className;
  final String classId;

  ClassUpdateWithClass({
    required this.update,
    required this.className,
    required this.classId,
  });
}

// Enhanced providers for multi-class support
final classManagementServiceProvider = Provider<ClassManagementService>((ref) {
  return ClassManagementService();
});

final userClassesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final service = ref.read(classManagementServiceProvider);
  return await service.getUserClasses();
});

// Provider for recent class updates across all user's classes
final recentUpdatesProvider =
    FutureProvider<List<ClassUpdateWithClass>>((ref) async {
  final classes = await ref.read(userClassesProvider.future);
  final updateService = ref.read(classUpdatesServiceProvider);

  List<ClassUpdateWithClass> allUpdates = [];

  for (final classModel in classes) {
    try {
      final updates =
          await updateService.getClassUpdates(classModel.id, limit: 3);
      allUpdates.addAll(updates.map((update) => ClassUpdateWithClass(
            update: update,
            className: classModel.name,
            classId: classModel.id,
          )));
    } catch (e) {
      // Skip if error fetching updates for this class
      continue;
    }
  }

  // Sort by creation time and take most recent 5
  allUpdates.sort((a, b) => b.update.createdAt.compareTo(a.update.createdAt));
  return allUpdates.take(5).toList();
});

// Provider for class activity summary (mock data for now)
final classActivityProvider =
    FutureProvider.family<ClassActivitySummary, String>((ref, classId) async {
  // Simulate API call delay
  await Future.delayed(const Duration(milliseconds: 500));

  // Mock data - in real implementation, this would fetch from your backend
  return ClassActivitySummary(
    classId: classId,
    unreadMessages: (classId.hashCode % 10),
    unreadUpdates: (classId.hashCode % 5),
    upcomingEvents: (classId.hashCode % 3),
    recentActivity: _getMockRecentActivity(classId),
  );
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

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize data when home page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🏠 Home page loaded - initializing data...');

      // Initialize notifications
      ref.read(notificationsProvider.notifier).initialize();

      // Preload conversations data
      ref.read(conversationsProvider.notifier).loadConversations();

      // Load user classes
      ref.read(userClassesProvider);

      debugPrint('✅ Data preloading initiated');
    });
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildEnhancedHomeTab(user),
          const ConversationsPage(),
          _buildAllClassesTab(user),
          _buildProfileTab(user),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHomeTab(User user) {
    final userClassesAsync = ref.watch(userClassesProvider);

    return CustomScrollView(
      slivers: [
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
            Consumer(
              builder: (context, ref, child) {
                final unreadCount = ref.watch(unreadNotificationsCountProvider);
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
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
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
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
              },
            ),
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

        // Quick Stats Bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _QuickStatsDelegate(userClassesAsync),
        ),

        // My Classes Section
        SliverToBoxAdapter(
          child: _buildMyClassesSection(userClassesAsync),
        ),

        // Recent Activity Section
        SliverToBoxAdapter(
          child: _buildRecentActivitySection(),
        ),

        // Quick Actions Section
        SliverToBoxAdapter(
          child: _buildQuickActionsSection(),
        ),
      ],
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
        padding: const EdgeInsets.only(left: 16, bottom: 50),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(
                      '${user.firstName[0]}${user.lastName[0]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getUserTypeLabel(user.userType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                onPressed: () => setState(() => _currentIndex = 2),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          userClassesAsync.when(
            loading: () => _buildClassesLoadingSkeleton(),
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

    // Show maximum 4 classes in home tab
    final displayClasses = classes.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: displayClasses.length,
      itemBuilder: (context, index) {
        return _buildEnhancedClassCard(displayClasses[index]);
      },
    );
  }

  Widget _buildEnhancedClassCard(ClassModel classModel) {
    final activityAsync = ref.watch(classActivityProvider(classModel.id));

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToClassDetails(classModel),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.08),
                AppTheme.primaryColor.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.class_,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  activityAsync.when(
                    data: (activity) => activity.totalUnread > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              activity.totalUnread > 99
                                  ? '99+'
                                  : activity.totalUnread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                classModel.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (classModel.displayName != classModel.name) ...[
                const SizedBox(height: 2),
                Text(
                  classModel.displayName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const Spacer(),
              activityAsync.when(
                data: (activity) => activity.recentActivity != null
                    ? Text(
                        activity.recentActivity!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        '${classModel.studentsCount ?? 0} students',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentActivityList(),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList() {
    final recentUpdatesAsync = ref.watch(recentUpdatesProvider);

    return recentUpdatesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Unable to load recent activities',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ),
      data: (updates) {
        if (updates.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.announcement_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No recent activities',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: updates.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _buildUpdateActivityTile(updates[index]);
          },
        );
      },
    );
  }

  Widget _buildUpdateActivityTile(ClassUpdateWithClass updateWithClass) {
    final update = updateWithClass.update;

    IconData icon;
    Color color;

    switch (update.updateType) {
      case UpdateType.homework:
        icon = Icons.book;
        color = AppTheme.errorColor;
        break;
      case UpdateType.announcement:
        icon = Icons.announcement;
        color = AppTheme.infoColor;
        break;
      case UpdateType.event:
        icon = Icons.event;
        color = AppTheme.successColor;
        break;
      case UpdateType.reminder:
        icon = Icons.schedule;
        color = AppTheme.warningColor;
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToSpecificUpdate(updateWithClass),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            update.title ?? 'Class Update',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                updateWithClass.className,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                app_date_utils.DateUtils.formatRelativeTime(update.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.textSecondary,
          ),
        ),
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
                  onTap: () => setState(() => _currentIndex = 1),
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

  // Helper widgets
  Widget _buildClassesLoadingSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyClassesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.class_, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No classes assigned yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contact your administrator to get enrolled in classes',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Error loading classes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(userClassesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToClassDetails(ClassModel classModel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassUpdatesPage(
          classId: classModel.id,
          className: classModel.name,
        ),
      ),
    );
  }

  // Other tabs (keeping existing implementation)
  Widget _buildAllClassesTab(User user) {
    return const ClassManagementPage();
  }

  Widget _buildProfileTab(User user) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
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
                value: 'test_401',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Test 401 Handler',
                        style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'force_logout',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Force Logout (Test)',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppTheme.errorColor),
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
      body: SingleChildScrollView(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              _buildInfoTile(
                  'Role', user.role?.name.toUpperCase() ?? 'Not assigned'),
              _buildInfoTile('School', user.school?.name ?? 'Not assigned'),
            ]),
          ],
        ),
      ),
    );
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

  void _navigateToSpecificUpdate(ClassUpdateWithClass updateWithClass) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassUpdatesPage(
          classId: updateWithClass.classId,
          className: updateWithClass.className,
          highlightUpdateId: updateWithClass.update.id,
          scrollToUpdate: true,
        ),
      ),
    );
  }
}

// Quick Stats Delegate for pinned header
class _QuickStatsDelegate extends SliverPersistentHeaderDelegate {
  final AsyncValue<List<ClassModel>> userClassesAsync;

  _QuickStatsDelegate(this.userClassesAsync);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildQuickStat(
                'Classes',
                userClassesAsync.hasValue
                    ? userClassesAsync.value!.length.toString()
                    : '-'),
            const SizedBox(width: 24),
            _buildQuickStat('Unread', '8'),
            const SizedBox(width: 24),
            _buildQuickStat('Today', '3'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  double get maxExtent => 70;

  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// Supporting data classes
