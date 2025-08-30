import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Platform-specific path service that handles web and mobile platforms
class PlatformPathService {
  static dynamic _documentsDirectory;
  static dynamic _temporaryDirectory;

  /// Get the application documents directory
  /// On web, this returns a mock directory path
  /// On mobile, this returns the actual documents directory
  static Future<dynamic> getAppDocumentsDirectory() async {
    if (_documentsDirectory != null) {
      return _documentsDirectory!;
    }

    if (kIsWeb) {
      // Web platform - return a mock directory path string
      // In a real web app, you might use IndexedDB or localStorage instead
      _documentsDirectory = '/tmp/durusuna_documents';
      return _documentsDirectory!;
    } else {
      // Mobile platform - use the actual path provider
      _documentsDirectory = await getApplicationDocumentsDirectory();
      return _documentsDirectory!;
    }
  }

  /// Get the temporary directory
  /// On web, this returns a mock directory path
  /// On mobile, this returns the actual temporary directory
  static Future<dynamic> getAppTemporaryDirectory() async {
    if (_temporaryDirectory != null) {
      return _temporaryDirectory!;
    }

    if (kIsWeb) {
      // Web platform - return a mock directory path string
      _temporaryDirectory = '/tmp/durusuna_temp';
      return _temporaryDirectory!;
    } else {
      // Mobile platform - use the actual path provider
      _temporaryDirectory = await getTemporaryDirectory();
      return _temporaryDirectory!;
    }
  }

  /// Check if the current platform is web
  static bool get isWeb => kIsWeb;

  /// Check if the current platform is mobile
  /// Note: This method is not available on web platform
  static bool get isMobile {
    if (kIsWeb) {
      return false;
    }
    // For mobile platforms, we'll use a different approach
    // This will be handled by conditional imports or platform-specific code
    return true; // Assume mobile if not web
  }

  /// Get a platform-appropriate database path
  static Future<String> getDatabasePath(String dbName) async {
    if (kIsWeb) {
      // For web, we'll use a simple path
      // In a real implementation, you might want to use IndexedDB
      return '/tmp/$dbName';
    } else {
      final dir = await getAppDocumentsDirectory();
      return '${dir.path}/$dbName';
    }
  }

  /// Ensure directory exists
  static Future<void> ensureDirectoryExists(dynamic directory) async {
    if (!kIsWeb) {
      // Only try to create directories on mobile platforms
      // This would need to be implemented with proper dart:io imports
      // For now, we'll skip this on web
    }
    // On web, we don't need to create directories
  }
}
