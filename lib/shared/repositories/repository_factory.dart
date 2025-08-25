import 'chat_repository.dart';
import 'sqlite_chat_repository.dart';
import 'package:flutter/foundation.dart';

/// Factory for creating and managing chat repositories
/// This allows easy switching between different database implementations
class RepositoryFactory {
  static ChatRepository? _currentRepository;
  static bool _initialized = false;

  /// Initialize the repository factory with the preferred database type
  /// [preferSQLite] - If true, tries SQLite first, then falls back to Isar
  static Future<void> initialize({bool preferSQLite = true}) async {
    if (_initialized) return;

    try {
      if (preferSQLite) {
        // Try SQLite first
        final sqliteRepo = SQLiteChatRepository();
        await sqliteRepo.initialize();
        _currentRepository = sqliteRepo;
        _initialized = true;
        debugPrint('✅ [RepositoryFactory] Using SQLite repository');
      } else {
        debugPrint('✅ [RepositoryFactory] Please try again with SQLite');
      }
    } catch (e) {
      debugPrint('⚠️ [RepositoryFactory] Primary repository failed: $e');
      rethrow;
    }
  }

  /// Get the current repository instance
  static ChatRepository get repository {
    if (!_initialized || _currentRepository == null) {
      // Try to initialize automatically if not already done
      debugPrint(
          '⚠️ [RepositoryFactory] Repository not initialized, attempting auto-initialization...');
      throw StateError('Repository not initialized. Call initialize() first.');
    }
    return _currentRepository!;
  }

  /// Switch to a different repository type
  static Future<void> switchRepository(RepositoryType type) async {
    if (!_initialized) {
      throw StateError('Repository not initialized. Call initialize() first.');
    }

    try {
      // Close current repository
      if (_currentRepository != null) {
        await _currentRepository!.close();
      }

      // Initialize new repository
      switch (type) {
        case RepositoryType.sqlite:
          final sqliteRepo = SQLiteChatRepository();
          await sqliteRepo.initialize();
          _currentRepository = sqliteRepo;
          debugPrint('✅ [RepositoryFactory] Switched to SQLite repository');
          break;
        default:
          throw ArgumentError('Cannot switch to unknown repository type');
      }
    } catch (e) {
      debugPrint('❌ [RepositoryFactory] Error switching repository: $e');
      rethrow;
    }
  }

  /// Get the current repository type
  static RepositoryType get currentType {
    if (_currentRepository is SQLiteChatRepository) {
      return RepositoryType.sqlite;
    }

    return RepositoryType.unknown;
  }

  /// Get repository health status
  static Future<Map<String, dynamic>> getHealthStatus() async {
    if (!_initialized || _currentRepository == null) {
      return {
        'isHealthy': false,
        'error': 'Repository not initialized',
        'type': 'unknown',
      };
    }

    try {
      final health = await _currentRepository!.getHealthStatus();
      health['factoryInitialized'] = _initialized;
      health['currentType'] = currentType.name;
      return health;
    } catch (e) {
      return {
        'isHealthy': false,
        'error': e.toString(),
        'type': currentType.name,
        'factoryInitialized': _initialized,
      };
    }
  }

  /// Close the current repository
  static Future<void> close() async {
    if (_currentRepository != null) {
      await _currentRepository!.close();
      _currentRepository = null;
      _initialized = false;
      debugPrint('✅ [RepositoryFactory] Repository closed');
    }
  }

  /// Check if repository is initialized
  static bool get isInitialized => _initialized;

  /// Get repository type as string
  static String get repositoryTypeName {
    switch (currentType) {
      case RepositoryType.sqlite:
        return 'SQLite';
      default:
        return 'Unknown';
    }
  }
}

/// Enum for repository types
enum RepositoryType {
  sqlite,
  isar,
  unknown,
}
