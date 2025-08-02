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
      debugPrint('🔒 GlobalAuthHandler: Handling unauthorized access (401)');

      // Clear all stored authentication data
      await StorageService.clearUser();

      // Clear any cached data that might be stale
      await StorageService.clearCache();

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

      debugPrint(
          '🔒 GlobalAuthHandler: Successfully handled 401 and navigated to login');
    } catch (e) {
      debugPrint('Error in GlobalAuthHandler.handleUnauthorized: $e');
      // Still try to navigate to login even if other operations fail
      await _navigateToLogin();
    }
  }

  // Navigate to login page
  static Future<void> _navigateToLogin() async {
    debugPrint('🔀 GlobalAuthHandler: _navigateToLogin called');
    debugPrint('🔀 GlobalAuthHandler: _navigatorKey = $_navigatorKey');
    debugPrint(
        '🔀 GlobalAuthHandler: _navigatorKey?.currentContext = ${_navigatorKey?.currentContext}');
    debugPrint(
        '🔀 GlobalAuthHandler: _navigatorKey?.currentState = ${_navigatorKey?.currentState}');

    if (_navigatorKey?.currentContext != null) {
      debugPrint(
          '🔀 GlobalAuthHandler: Navigator context available, attempting navigation');
      try {
        // Clear the entire navigation stack and go to login
        final result = _navigatorKey!.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false, // Remove all previous routes
        );
        debugPrint(
            '🔀 GlobalAuthHandler: pushNamedAndRemoveUntil result = $result');
        if (result != null) {
          debugPrint('✅ GlobalAuthHandler: Navigation to login successful');
        } else {
          debugPrint('❌ GlobalAuthHandler: Navigation to login returned null');
        }
      } catch (e) {
        debugPrint('❌ GlobalAuthHandler: Navigation error: $e');
      }
    } else {
      debugPrint(
          '❌ GlobalAuthHandler: Cannot navigate - no navigator context available');
      debugPrint(
          '❌ GlobalAuthHandler: Attempting direct navigation fallback...');

      // Try alternative navigation approach
      try {
        if (_navigatorKey?.currentState != null) {
          debugPrint(
              '🔀 GlobalAuthHandler: Trying alternative navigation with currentState');
          await _navigatorKey!.currentState!.pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
          debugPrint('✅ GlobalAuthHandler: Alternative navigation successful');
        }
      } catch (e) {
        debugPrint('❌ GlobalAuthHandler: Alternative navigation failed: $e');
      }
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
    debugPrint('🔒 GlobalAuthHandler: Token refresh failed, logging out');
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
    debugPrint('🧪 GlobalAuthHandler: Testing 401 handler');
    await handleUnauthorized(
      customMessage: '401 Test: Session expired. Please log in again.',
      showSnackBar: true,
    );
  }

  // Test navigation only (for development/testing)
  static Future<void> testNavigation() async {
    debugPrint('🧪 GlobalAuthHandler: Testing navigation to login');
    debugPrint('🧪 GlobalAuthHandler: isInitialized = $isInitialized');
    debugPrint('🧪 GlobalAuthHandler: navigatorKey = $_navigatorKey');
    debugPrint('🧪 GlobalAuthHandler: ref = $_ref');
    await _navigateToLogin();
  }

  // Force immediate logout (for critical auth failures)
  static Future<void> forceImmediateLogout() async {
    debugPrint(
        '🔥 GlobalAuthHandler: FORCE IMMEDIATE LOGOUT - Critical auth failure');

    try {
      // Clear storage first
      await StorageService.clearUser();
      await StorageService.clearCache();
      debugPrint('✅ GlobalAuthHandler: Storage cleared');

      // Update auth state if possible
      if (_ref != null) {
        try {
          _ref!.read(authStateProvider.notifier).logout();
          debugPrint('✅ GlobalAuthHandler: Auth state cleared');
        } catch (e) {
          debugPrint('❌ GlobalAuthHandler: Failed to clear auth state: $e');
        }
      }

      // Force navigation - try multiple approaches
      await _forceNavigation();
    } catch (e) {
      debugPrint('❌ GlobalAuthHandler: Error in forceImmediateLogout: $e');
      // Still try to navigate even if other operations fail
      await _forceNavigation();
    }
  }

  // Force navigation with multiple fallback approaches
  static Future<void> _forceNavigation() async {
    debugPrint('🚀 GlobalAuthHandler: Attempting force navigation');

    bool navigationSuccessful = false;

    // Approach 1: Standard navigation
    if (_navigatorKey?.currentState != null) {
      try {
        debugPrint('🚀 Attempt 1: Standard navigation');
        await _navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        navigationSuccessful = true;
        debugPrint('✅ Standard navigation successful');
      } catch (e) {
        debugPrint('❌ Standard navigation failed: $e');
      }
    }

    // Approach 2: Widget tree navigation
    if (!navigationSuccessful && _navigatorKey?.currentContext != null) {
      try {
        debugPrint('🚀 Attempt 2: Widget tree navigation');
        Navigator.of(_navigatorKey!.currentContext!).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        navigationSuccessful = true;
        debugPrint('✅ Widget tree navigation successful');
      } catch (e) {
        debugPrint('❌ Widget tree navigation failed: $e');
      }
    }

    if (!navigationSuccessful) {
      debugPrint('❌ ALL NAVIGATION ATTEMPTS FAILED');
      debugPrint('❌ User will need to restart the app');
    }
  }
}
