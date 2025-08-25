import 'dart:async';
import 'package:flutter/material.dart';

/// Production-grade GlobalKey management service
/// Handles unique key generation, memory leak prevention, and automatic cleanup
class GlobalKeyManager {
  static GlobalKeyManager? _instance;

  // Key storage with usage tracking
  final Map<String, GlobalKey> _keys = {};
  final Map<String, int> _usageCount = {};

  // Cleanup timer
  Timer? _cleanupTimer;

  // Private constructor for singleton
  GlobalKeyManager._internal() {
    _startPeriodicCleanup();
  }

  /// Get singleton instance
  static GlobalKeyManager get instance {
    _instance ??= GlobalKeyManager._internal();
    return _instance!;
  }

  /// Generate a unique key for a message in a conversation
  /// Uses multiple identifiers to ensure uniqueness
  GlobalKey getMessageKey(String messageId, String conversationId) {
    final uniqueKey =
        'msg_${messageId}_${conversationId}_${DateTime.now().millisecondsSinceEpoch}';
    return _getOrCreateKey(uniqueKey);
  }

  /// Generate a unique key for a local message
  /// Uses bitwise operations for better distribution
  GlobalKey getLocalMessageKey(int localId, String conversationId) {
    final uniqueKey = (localId << 32) | (conversationId.hashCode & 0xFFFFFFFF);
    return _getOrCreateKey(uniqueKey.toString());
  }

  /// Generate a unique key for any widget with custom prefix
  /// Useful for other features beyond chat
  GlobalKey getCustomKey(String prefix, String identifier, String context) {
    final uniqueKey =
        '${prefix}_${identifier}_${context}_${DateTime.now().millisecondsSinceEpoch}';
    return _getOrCreateKey(uniqueKey);
  }

  /// Get or create a GlobalKey with usage tracking
  GlobalKey _getOrCreateKey(String uniqueKey) {
    // Track usage count
    _usageCount[uniqueKey] = (_usageCount[uniqueKey] ?? 0) + 1;

    // Create new key if it doesn't exist
    return _keys.putIfAbsent(uniqueKey, () => GlobalKey());
  }

  /// Mark a key as actively used (call this when key is accessed)
  void markKeyUsed(String uniqueKey) {
    _usageCount[uniqueKey] = (_usageCount[uniqueKey] ?? 0) + 1;
  }

  /// Clean up unused keys to prevent memory leaks
  void cleanupUnusedKeys({int minUsageCount = 2}) {
    final keysToRemove = <String>[];

    for (final entry in _usageCount.entries) {
      if (entry.value < minUsageCount) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _keys.remove(key);
      _usageCount.remove(key);
    }

    debugPrint(
        '🧹 GlobalKeyManager: Cleaned up ${keysToRemove.length} unused keys');
  }

  /// Force cleanup of all keys (use during app shutdown or major cleanup)
  void forceCleanup() {
    final keyCount = _keys.length;
    _keys.clear();
    _usageCount.clear();
    debugPrint('🧹 GlobalKeyManager: Force cleaned up $keyCount keys');
  }

  /// Get current memory usage statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'totalKeys': _keys.length,
      'totalUsageCount':
          _usageCount.values.fold(0, (sum, count) => sum + count),
      'averageUsage': _keys.isEmpty
          ? 0
          : _usageCount.values.fold(0, (sum, count) => sum + count) /
              _keys.length,
    };
  }

  /// Start periodic cleanup timer
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      cleanupUnusedKeys();
    });
  }

  /// Stop cleanup timer and dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    forceCleanup();
    debugPrint('🔌 GlobalKeyManager: Disposed');
  }
}
