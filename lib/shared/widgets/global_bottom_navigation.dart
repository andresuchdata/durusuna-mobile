import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_theme.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../providers/local_chat_providers.dart';
import '../../features/attendance/presentation/pages/student_attendance_page.dart';

/// Provider to manage global bottom navigation state
final globalBottomNavigationProvider =
    StateNotifierProvider<GlobalBottomNavigationNotifier, int>((ref) {
  return GlobalBottomNavigationNotifier();
});

class GlobalBottomNavigationNotifier extends StateNotifier<int> {
  GlobalBottomNavigationNotifier() : super(0); // Default to Home tab

  void setCurrentIndex(int index) {
    state = index;
  }
}

/// Reusable bottom navigation bar that can be used across different pages
/// Handles proper navigation between main sections of the app
class GlobalBottomNavigation extends ConsumerWidget {
  final int? currentIndex;
  final Function(int)? onTap;
  final bool isDetailPage;
  final bool showNotificationBadge;

  const GlobalBottomNavigation({
    super.key,
    this.currentIndex,
    this.onTap,
    this.isDetailPage = false,
    this.showNotificationBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalIndex = ref.watch(globalBottomNavigationProvider);
    final unreadCount =
        showNotificationBadge ? ref.watch(unreadMessagesCountProvider) : 0;
    final user = ref.watch(authStateProvider).user;
    final effectiveIndex = currentIndex ?? globalIndex;

    // Build navigation items based on user type
    final navItems = _buildNavigationItems(unreadCount, user);
    final maxIndex = navItems.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: effectiveIndex.clamp(0, maxIndex),
          onTap: (index) => _handleNavigation(context, ref, index),
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textSecondary,
          backgroundColor: Colors.white,
          elevation: 0,
          items: navItems,
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildNavigationItems(
      int unreadCount, User? user) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            const Icon(Icons.chat),
            if (unreadCount > 0 && showNotificationBadge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: 'Messages',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.class_),
        label: 'Classes',
      ),
    ];

    // Only add attendance tab for students and parents
    if (user?.userType == UserType.student ||
        user?.userType == UserType.parent) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.how_to_reg),
          label: 'Attendance',
        ),
      );
    }

    // Profile tab is always last
    items.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    );

    return items;
  }

  void _handleNavigation(BuildContext context, WidgetRef ref, int index) {
    final user = ref.read(authStateProvider).user;
    final hasAttendanceTab =
        user?.userType == UserType.student || user?.userType == UserType.parent;

    // If a custom onTap handler is provided, use it
    if (onTap != null) {
      onTap!(index);
      return;
    }

    // Map the navigation index to the correct tab index for IndexedStack
    int stackIndex;
    if (hasAttendanceTab) {
      // For users with attendance tab: Home(0), Messages(1), Classes(2), Attendance(3), Profile(4)
      stackIndex = index;
    } else {
      // For users without attendance tab: Home(0), Messages(1), Classes(2), Profile(3)
      // Map to: Home(0), Messages(1), Classes(2), skip Attendance(3), Profile(4)
      if (index <= 2) {
        stackIndex = index;
      } else {
        stackIndex = 4; // Profile tab in IndexedStack
      }
    }

    // Update global navigation state with the mapped index
    ref
        .read(globalBottomNavigationProvider.notifier)
        .setCurrentIndex(stackIndex);

    if (isDetailPage) {
      // If we're on a detail page, navigate back to main page with the selected tab
      _navigateToMainPageWithTab(context, stackIndex);
    } else {
      // If we're already on the main page, just update the tab
      // This should be handled by the main page's IndexedStack
    }
  }

  void _navigateToMainPageWithTab(BuildContext context, int index) {
    // Navigate back to the main page and pass the selected tab index
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => _MainPageWithTab(initialTabIndex: index),
        settings: const RouteSettings(name: '/home'),
      ),
      (route) => false,
    );
  }
}

/// Wrapper widget that opens the main page with a specific tab selected
class _MainPageWithTab extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const _MainPageWithTab({
    required this.initialTabIndex,
  });

  @override
  ConsumerState<_MainPageWithTab> createState() => _MainPageWithTabState();
}

class _MainPageWithTabState extends ConsumerState<_MainPageWithTab> {
  @override
  void initState() {
    super.initState();
    // Set the initial tab index after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(globalBottomNavigationProvider.notifier)
          .setCurrentIndex(widget.initialTabIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const EnhancedHomePage();
  }
}

/// Extension methods for easier navigation
extension GlobalBottomNavigationExtension on BuildContext {
  /// Navigate to home tab
  void navigateToHome() {
    final ref = ProviderScope.containerOf(this)
        .read(globalBottomNavigationProvider.notifier);
    ref.setCurrentIndex(0);
  }

  /// Navigate to messages tab
  void navigateToMessages() {
    final ref = ProviderScope.containerOf(this)
        .read(globalBottomNavigationProvider.notifier);
    ref.setCurrentIndex(1);
  }

  /// Navigate to classes tab
  void navigateToClasses() {
    final ref = ProviderScope.containerOf(this)
        .read(globalBottomNavigationProvider.notifier);
    ref.setCurrentIndex(2);
  }

  /// Navigate to profile tab
  void navigateToProfile() {
    final ref = ProviderScope.containerOf(this)
        .read(globalBottomNavigationProvider.notifier);
    ref.setCurrentIndex(4);
  }
}
