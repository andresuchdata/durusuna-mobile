import 'chat_repository.dart';
import 'sqlite_chat_repository.dart';
import 'isar_chat_repository.dart';

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
        print('✅ [RepositoryFactory] Using SQLite repository');
      } else {
        // Try Isar first
        final isarRepo = IsarChatRepository();
        await isarRepo.initialize();
        _currentRepository = isarRepo;
        print('✅ [RepositoryFactory] Using Isar repository');
      }

      _initialized = true;
    } catch (e) {
      print(
          '⚠️ [RepositoryFactory] Primary repository failed, trying fallback: $e');

      try {
        if (preferSQLite) {
          // Fallback to Isar
          final isarRepo = IsarChatRepository();
          await isarRepo.initialize();
          _currentRepository = isarRepo;
          print('✅ [RepositoryFactory] Fallback to Isar repository successful');
        } else {
          // Fallback to SQLite
          final sqliteRepo = SQLiteChatRepository();
          await sqliteRepo.initialize();
          _currentRepository = sqliteRepo;
          print(
              '✅ [RepositoryFactory] Fallback to SQLite repository successful');
        }

        _initialized = true;
      } catch (fallbackError) {
        print('❌ [RepositoryFactory] Both repositories failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Get the current repository instance
  static ChatRepository get repository {
    if (!_initialized || _currentRepository == null) {
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
          print('✅ [RepositoryFactory] Switched to SQLite repository');
          break;
        case RepositoryType.isar:
          final isarRepo = IsarChatRepository();
          await isarRepo.initialize();
          _currentRepository = isarRepo;
          print('✅ [RepositoryFactory] Switched to Isar repository');
          break;
        case RepositoryType.unknown:
          throw ArgumentError('Cannot switch to unknown repository type');
      }
    } catch (e) {
      print('❌ [RepositoryFactory] Error switching repository: $e');
      rethrow;
    }
  }

  /// Get the current repository type
  static RepositoryType get currentType {
    if (_currentRepository is SQLiteChatRepository) {
      return RepositoryType.sqlite;
    } else if (_currentRepository is IsarChatRepository) {
      return RepositoryType.isar;
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
      print('✅ [RepositoryFactory] Repository closed');
    }
  }

  /// Check if repository is initialized
  static bool get isInitialized => _initialized;

  /// Get repository type as string
  static String get repositoryTypeName {
    switch (currentType) {
      case RepositoryType.sqlite:
        return 'SQLite';
      case RepositoryType.isar:
        return 'Isar';
      case RepositoryType.unknown:
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
