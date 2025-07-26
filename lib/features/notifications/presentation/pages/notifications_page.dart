import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/models/notification.dart';
import '../widgets/notification_tile.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize notifications when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).initialize();
    });

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near bottom
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (notificationsState.notifications.isNotEmpty)
            TextButton(
              onPressed: notificationsState.unreadCount > 0
                  ? () {
                      ref.read(notificationsProvider.notifier).markAllAsRead();
                    }
                  : null,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: notificationsState.unreadCount > 0
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(notificationsProvider.notifier)
              .loadNotifications(refresh: true);
        },
        child: _buildBody(notificationsState),
      ),
    );
  }

  Widget _buildBody(NotificationsState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (state.unreadCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Text(
              '${state.unreadCount} unread notification${state.unreadCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.notifications.length) {
                // Loading indicator for pagination
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                );
              }

              final notification = state.notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await _showDeleteConfirmation(context, notification);
                },
                onDismissed: (direction) {
                  ref
                      .read(notificationsProvider.notifier)
                      .deleteNotification(notification.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${notification.title} dismissed'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
                child: NotificationTile(
                  notification: notification,
                  onTap: () {
                    if (!notification.isRead) {
                      ref
                          .read(notificationsProvider.notifier)
                          .markAsRead(notification.id);
                    }
                    _handleNotificationAction(notification);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'ll see important updates here',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(notificationsProvider.notifier)
                  .loadNotifications(refresh: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(
      BuildContext context, NotificationModel notification) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Notification'),
          content:
              Text('Are you sure you want to delete "${notification.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _handleNotificationAction(NotificationModel notification) {
    // Handle different notification actions based on type
    switch (notification.type) {
      case NotificationType.message:
        // Navigate to chat/conversation
        debugPrint('Navigate to chat for notification: ${notification.id}');
        break;
      case NotificationType.classUpdate:
        // Navigate to class updates
        debugPrint(
            'Navigate to class updates for notification: ${notification.id}');
        break;
      case NotificationType.assignment:
        // Navigate to assignments
        debugPrint(
            'Navigate to assignments for notification: ${notification.id}');
        break;
      case NotificationType.announcement:
        // Navigate to announcements
        debugPrint(
            'Navigate to announcements for notification: ${notification.id}');
        break;
      case NotificationType.event:
        // Navigate to events/calendar
        debugPrint('Navigate to events for notification: ${notification.id}');
        break;
      case NotificationType.system:
        // Handle system notifications
        debugPrint('Handle system notification: ${notification.id}');
        break;
    }

    // If there's an action URL, you could navigate there
    if (notification.actionUrl != null) {
      debugPrint('Navigate to: ${notification.actionUrl}');
    }
  }
}
