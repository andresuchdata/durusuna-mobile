import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_theme.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'global_app_drawer.dart';

/// Global app scaffold that provides consistent navigation and notifications
/// across all pages in the app
class GlobalAppScaffold extends ConsumerWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showNotifications;
  final bool automaticallyImplyLeading;
  final bool showDrawer;

  const GlobalAppScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showNotifications = true,
    this.automaticallyImplyLeading = true,
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final authState = ref.watch(authStateProvider);
    final isAuthenticated = authState.user != null;

    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: isAuthenticated && showDrawer
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : (automaticallyImplyLeading ? null : const SizedBox.shrink()),
        actions: [
          // Existing actions first
          ...?actions,

          // Global notifications bell (only for authenticated users)
          if (showNotifications && isAuthenticated) ...[
            Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
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
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      drawer: isAuthenticated && showDrawer ? const GlobalAppDrawer() : null,
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}
