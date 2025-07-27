import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../models/conversation.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/class_updates/presentation/pages/class_updates_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../main.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import 'api_service.dart';

/// Service responsible for handling notification navigation and deep linking
class NotificationNavigationService {
  final WidgetRef _ref;

  NotificationNavigationService(this._ref);

  /// Main entry point for handling notification taps
  Future<void> handleNotificationAction(NotificationModel notification) async {
    try {
      // NOTE: markAsRead is handled by the UI layer (NotificationsPage) with optimistic updates
      // We don't call it here to avoid duplicate API calls and provider modification errors
      
      await _navigateBasedOnType(notification);
    } catch (e) {
      debugPrint('Error handling notification action: $e');
      _showErrorSnackBar('Failed to open notification');
    }
  }

  /// Navigate based on notification type with specific parameters
  Future<void> _navigateBasedOnType(NotificationModel notification) async {
    final context = DurusunaMobileApp.navigatorKey.currentContext;
    if (context == null) return;

    switch (notification.type) {
      case NotificationType.message:
        await _handleMessageNotification(context, notification);
        break;
      case NotificationType.assignment:
        await _handleAssignmentNotification(context, notification);
        break;
      case NotificationType.announcement:
        await _handleAnnouncementNotification(context, notification);
        break;
      case NotificationType.event:
        await _handleEventNotification(context, notification);
        break;
      case NotificationType.system:
        await _handleSystemNotification(context, notification);
        break;
    }
  }

  /// Handle message notifications - navigate to specific conversation
  Future<void> _handleMessageNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final actionData = notification.actionData;
    if (actionData == null) return;

    final conversationId = actionData['conversation_id'] as String?;
    final messageId = actionData['message_id'] as String?;

    if (conversationId == null) return;

    try {
      // Load the specific conversation
      final conversation = await _loadConversation(conversationId);
      if (conversation == null) {
        _showErrorSnackBar('Conversation not found');
        return;
      }

      // Navigate to chat page with message highlighting support
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ChatPage(
            conversation: conversation,
            highlightMessageId: messageId,
            scrollToMessage: messageId != null,
          ),
        ),
        (route) => route.isFirst, // Keep only the home page in stack
      );

      // Message highlighting is now handled automatically by ChatPage
      if (messageId != null) {
        debugPrint(
            'Navigating to conversation with highlighted message: $messageId');
      }
    } catch (e) {
      debugPrint('Error navigating to conversation: $e');
      // Fallback: navigate to conversations list
      await _navigateToConversations(context);
    }
  }

  /// Handle assignment notifications - navigate to assignment page (to be created)
  Future<void> _handleAssignmentNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    // TODO: Navigate to assignment page when created
    // For now, show a placeholder message
    _showErrorSnackBar('Assignment page not yet implemented');
    debugPrint('Assignment notification tapped: ${notification.id}');
  }

  /// Handle announcement notifications - navigate to class updates page
  Future<void> _handleAnnouncementNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final actionData = notification.actionData;
    if (actionData == null) return;

    final classId = actionData['class_id'] as String?;
    final updateId = actionData['update_id'] as String?;
    final className = actionData['class_name'] as String?;

    if (classId == null) return;

    // Navigate to class updates page with highlighting
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => ClassUpdatesPage(
          classId: classId,
          className: className ?? 'Class Updates',
          highlightUpdateId: updateId,
          scrollToUpdate: updateId != null,
        ),
      ),
      (route) => route.isFirst,
    );

    // Update highlighting is now handled automatically by ClassUpdatesPage
    if (updateId != null) {
      debugPrint(
          'Navigating to class updates with highlighted update: $updateId');
    }
  }

  /// Handle event notifications - navigate to calendar page (to be created)
  Future<void> _handleEventNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    // TODO: Navigate to calendar/events page when created
    // For now, show a placeholder message
    _showErrorSnackBar('Calendar page not yet implemented');
    debugPrint('Event notification tapped: ${notification.id}');
  }

  /// Handle system notifications - no navigation, just mark as read
  Future<void> _handleSystemNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    // System notifications don't require navigation
    // They are already marked as read in the main handler
    debugPrint('System notification processed: ${notification.id}');

    // Optionally show a toast or brief message
    final actionUrl = notification.actionUrl;
    if (actionUrl != null && actionUrl.isNotEmpty) {
      // Handle custom URLs for system notifications if needed
      debugPrint('System notification action URL: $actionUrl');
    }
  }

  /// Load conversation by ID
  Future<Conversation?> _loadConversation(String conversationId) async {
    try {
      // First check if conversation is already in cache
      final conversationsState = _ref.read(conversationsProvider);
      final cachedConversation =
          conversationsState.conversations.cast<Conversation?>().firstWhere(
                (conv) => conv?.id == conversationId,
                orElse: () => null,
              );

      if (cachedConversation != null) {
        return cachedConversation;
      }

      // If not in cache, load from service
      final chatService = _ref.read(chatServiceProvider);
      // Refresh conversations to get latest data
      await _ref.read(conversationsProvider.notifier).loadConversations();

      // Try to find it again after refresh
      final updatedState = _ref.read(conversationsProvider);
      return updatedState.conversations.cast<Conversation?>().firstWhere(
            (conv) => conv?.id == conversationId,
            orElse: () => null,
          );
    } catch (e) {
      debugPrint('Error loading conversation: $e');
      return null;
    }
  }

  /// Navigate to conversations page
  Future<void> _navigateToConversations(BuildContext context) async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const HomePage(),
      ),
      (route) => false,
    );

    // TODO: Switch to conversations tab programmatically
    // This would require updating HomePage to accept initial tab parameter
  }

  /// Navigate to home with optional initial tab
  Future<void> _navigateToHome(BuildContext context,
      {int initialTab = 0}) async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const HomePage(
            // TODO: Add initialTab parameter to HomePage
            ),
      ),
      (route) => false,
    );
  }

  /// Handle custom URLs for deep linking
  Future<void> _handleCustomUrl(
    BuildContext context,
    String url,
    Map<String, dynamic>? actionData,
  ) async {
    // Parse URL and navigate accordingly
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    switch (uri.pathSegments.first) {
      case 'chat':
        if (uri.pathSegments.length > 1) {
          final conversationId = uri.pathSegments[1];
          await _handleMessageNotification(
            context,
            NotificationModel(
              id: '',
              title: '',
              content: '',
              type: NotificationType.message,
              userId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              actionData: {
                'conversation_id': conversationId,
                ...?actionData,
              },
            ),
          );
        }
        break;
      case 'class':
        if (uri.pathSegments.length > 1) {
          final classId = uri.pathSegments[1];
          await _handleAnnouncementNotification(
            context,
            NotificationModel(
              id: '',
              title: '',
              content: '',
              type: NotificationType.announcement,
              userId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              actionData: {
                'class_id': classId,
                ...?actionData,
              },
            ),
          );
        }
        break;
      default:
        await _navigateToHome(context);
    }
  }

  /// Show error message to user
  void _showErrorSnackBar(String message) {
    final context = DurusunaMobileApp.navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Provider for notification navigation service
NotificationNavigationService getNotificationNavigationService(WidgetRef ref) {
  return NotificationNavigationService(ref);
}
