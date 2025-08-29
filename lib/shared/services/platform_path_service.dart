import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Platform-specific path service that handles web and mobile platforms
class PlatformPathService {
  static Directory? _documentsDirectory;
  static Directory? _temporaryDirectory;

  /// Get the application documents directory
  /// On web, this returns a mock directory path
  /// On mobile, this returns the actual documents directory
  static Future<Directory> getApplicationDocumentsDirectory() async {
    if (_documentsDirectory != null) {
      return _documentsDirectory!;
    }

    if (kIsWeb) {
      // Web platform - return a mock directory
      // In a real web app, you might use IndexedDB or localStorage instead
      _documentsDirectory = Directory('/tmp/durusuna_documents');
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
  static Future<Directory> getTemporaryDirectory() async {
    if (_temporaryDirectory != null) {
      return _temporaryDirectory!;
    }

    if (kIsWeb) {
      // Web platform - return a mock directory
      _temporaryDirectory = Directory('/tmp/durusuna_temp');
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
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Get a platform-appropriate database path
  static Future<String> getDatabasePath(String dbName) async {
    if (kIsWeb) {
      // For web, we'll use a simple path
      // In a real implementation, you might want to use IndexedDB
      return '/tmp/$dbName';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$dbName';
    }
  }

  /// Ensure directory exists
  static Future<void> ensureDirectoryExists(Directory directory) async {
    if (!kIsWeb) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
    // On web, we don't need to create directories
  }
}
