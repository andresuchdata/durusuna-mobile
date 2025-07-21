import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/storage_service.dart';
import '../../shared/services/auth_service.dart';

class GlobalAuthHandler {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static WidgetRef? _ref;

  // Initialize with navigator key and ref
  static void initialize(
      GlobalKey<NavigatorState> navigatorKey, WidgetRef ref) {
    _navigatorKey = navigatorKey;
    _ref = ref;
  }

  // Handle unauthorized response (401)
  static Future<void> handleUnauthorized({
    String? customMessage,
    bool showSnackBar = true,
  }) async {
    try {
      // Clear all stored authentication data
      await StorageService.clearUser();

      // Update auth state through provider
      if (_ref != null) {
        _ref!.read(authStateProvider.notifier).logout();
      }

      // Show user feedback if requested
      if (showSnackBar && _navigatorKey?.currentContext != null) {
        _showLogoutMessage(_navigatorKey!.currentContext!, customMessage);
      }

      // Navigate to login page
      await _navigateToLogin();
    } catch (e) {
      debugPrint('Error in GlobalAuthHandler.handleUnauthorized: $e');
      // Still try to navigate to login even if other operations fail
      await _navigateToLogin();
    }
  }

  // Navigate to login page
  static Future<void> _navigateToLogin() async {
    if (_navigatorKey?.currentContext != null) {
      // Clear the entire navigation stack and go to login
      _navigatorKey!.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false, // Remove all previous routes
      );
    }
  }

  // Show logout message to user
  static void _showLogoutMessage(BuildContext context, String? customMessage) {
    final message = customMessage ?? 'Session expired. Please log in again.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Check if handler is properly initialized
  static bool get isInitialized => _navigatorKey != null && _ref != null;

  // Manual logout (called by user action)
  static Future<void> logout({String? message}) async {
    await handleUnauthorized(
      customMessage: message ?? 'You have been logged out.',
      showSnackBar: true,
    );
  }

  // Session timeout logout
  static Future<void> sessionTimeout() async {
    await handleUnauthorized(
      customMessage: 'Your session has expired. Please log in again.',
      showSnackBar: true,
    );
  }

  // Token refresh failed logout
  static Future<void> tokenRefreshFailed() async {
    await handleUnauthorized(
      customMessage: 'Unable to refresh your session. Please log in again.',
      showSnackBar: true,
    );
  }

  // Force logout for testing purposes (can be called from UI)
  static Future<void> forceLogout() async {
    await handleUnauthorized(
      customMessage: 'Logged out successfully.',
      showSnackBar: true,
    );
  }

  // Test 401 handling (for development/testing)
  static Future<void> test401Handler() async {
    await handleUnauthorized(
      customMessage: '401 Test: Session expired. Please log in again.',
      showSnackBar: true,
    );
  }
}
