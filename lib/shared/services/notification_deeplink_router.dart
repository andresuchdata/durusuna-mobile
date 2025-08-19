import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/presentation/pages/local_chat_page.dart';
import '../../features/class_updates/presentation/pages/class_updates_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../main.dart';
import '../models/conversation.dart';
import 'chat_service.dart';

/// Centralized router for handling navigation from FCM payloads
class NotificationDeepLinkRouter {
  /// Entry point: handle FCM data payload to navigate accordingly
  static Future<void> handleFCMNavigation(Map<String, dynamic> data) async {
    final context = DurusunaMobileApp.navigatorKey.currentContext;
    if (context == null) return;

    try {
      final String? type = _readString(data, ['notificationType', 'type']);
      final String? actionUrl = _readString(data, ['actionUrl', 'action_url']);
      final Map<String, dynamic>? actionData = _readActionData(data);

      if (type == 'message' || (actionUrl?.startsWith('chat/') ?? false)) {
        await _navigateToMessage(context, actionUrl, actionData);
        return;
      }

      // Default all other types to class updates page
      await _navigateToClassUpdates(context, actionUrl, actionData);
    } catch (e) {
      // Last resort: go home
      await _navigateToHome(context);
    }
  }

  static Future<void> _navigateToMessage(
    BuildContext context,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);

    // Resolve conversationId from actionData or URL
    String? conversationId = actionData?['conversation_id'] as String?;
    if (conversationId == null && actionUrl != null) {
      final uri = Uri.tryParse(actionUrl);
      final segments = uri?.pathSegments ?? actionUrl.split('/');
      if (segments.isNotEmpty) {
        // Supports formats: chat/{id} or just 'chat/{id}' string
        final idx = segments.first == 'chat' ? 1 : 0;
        if (segments.length > idx) conversationId = segments[idx];
      }
    }

    if (conversationId == null) {
      await _navigateToHome(context);
      return;
    }

    // Try resolve conversation from providers/cache; refresh if needed
    Conversation? conversation;
    try {
      final conversationsState = container.read(conversationsProvider);
      conversation = conversationsState.conversations
          .cast<Conversation?>()
          .firstWhere((c) => c?.id == conversationId, orElse: () => null);

      if (conversation == null) {
        // Refresh from service
        await container
            .read(conversationsProvider.notifier)
            .loadConversations();
        final updated = container.read(conversationsProvider);
        conversation = updated.conversations
            .cast<Conversation?>()
            .firstWhere((c) => c?.id == conversationId, orElse: () => null);
      }
    } catch (_) {}

    if (conversation == null) {
      // As a fallback, try to fetch conversation from service by id if supported
      try {
        await container
            .read(conversationsProvider.notifier)
            .loadConversations();
        final updated = container.read(conversationsProvider);
        conversation = updated.conversations
            .cast<Conversation?>()
            .firstWhere((c) => c?.id == conversationId, orElse: () => null);
      } catch (_) {}
    }

    if (conversation == null) {
      await _navigateToHome(context);
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LocalChatPage(
          conversation: conversation!,
          highlightMessageId: actionData?['message_id'] as String?,
          scrollToMessage: (actionData?['message_id'] as String?) != null,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  static Future<void> _navigateToClassUpdates(
    BuildContext context,
    String? actionUrl,
    Map<String, dynamic>? actionData,
  ) async {
    // Resolve class id and update id
    String? classId = actionData?['class_id'] as String?;
    String? updateId = actionData?['update_id'] as String?;
    String? className = actionData?['class_name'] as String?;

    if (classId == null && actionUrl != null) {
      final uri = Uri.tryParse(actionUrl);
      final segments = uri?.pathSegments ?? actionUrl.split('/');
      if (segments.isNotEmpty) {
        final idx = segments.first == 'class' ? 1 : 0;
        if (segments.length > idx) classId = segments[idx];
      }
    }

    if (classId == null) {
      await _navigateToHome(context);
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ClassUpdatesPage(
          classId: classId!,
          className: className ?? 'Class Updates',
          highlightUpdateId: updateId,
          scrollToUpdate: updateId != null,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  static Future<void> _navigateToHome(BuildContext context) async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EnhancedHomePage()),
      (route) => false,
    );
  }

  static Map<String, dynamic>? _readActionData(Map<String, dynamic> data) {
    final dynamic raw = data['actionData'] ?? data['action_data'];
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }
}
