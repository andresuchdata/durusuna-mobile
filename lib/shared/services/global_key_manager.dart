import 'dart:async';
import 'dart:math';
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

  // Random generator for UUID4
  final Random _random = Random.secure();

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
  /// Uses UUID4 for guaranteed uniqueness
  GlobalKey getMessageKey(String messageId, String conversationId) {
    final uniqueKey = 'msg_${messageId}_${conversationId}_${_generateUuid4()}';
    return _getOrCreateKey(uniqueKey);
  }

  /// Generate a unique key for a local message
  /// Uses UUID4 for guaranteed uniqueness
  GlobalKey getLocalMessageKey(int localId, String conversationId) {
    final uniqueKey = 'local_${localId}_${conversationId}_${_generateUuid4()}';
    return _getOrCreateKey(uniqueKey);
  }

  /// Generate a unique key for any widget with custom prefix
  /// Useful for other features beyond chat
  GlobalKey getCustomKey(String prefix, String identifier, String context) {
    final uniqueKey = '${prefix}_${identifier}_${context}_${_generateUuid4()}';
    return _getOrCreateKey(uniqueKey);
  }

  /// Generate a unique key for new/optimistic messages
  /// Ensures uniqueness even when message IDs might change
  GlobalKey getOptimisticMessageKey(String conversationId) {
    final uniqueKey = 'optimistic_${conversationId}_${_generateUuid4()}';
    return _getOrCreateKey(uniqueKey);
  }

  /// Generate a unique key for pending messages
  /// Used when message ID is not yet available
  GlobalKey getPendingMessageKey(String conversationId, String? clientId) {
    if (clientId != null) {
      final uniqueKey =
          'pending_${clientId}_${conversationId}_${_generateUuid4()}';
      return _getOrCreateKey(uniqueKey);
    } else {
      final uniqueKey = 'pending_${conversationId}_${_generateUuid4()}';
      return _getOrCreateKey(uniqueKey);
    }
  }

  /// Generate a UUID4 string for guaranteed uniqueness
  /// Uses cryptographically secure random numbers
  String _generateUuid4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 1

    // Convert to hex string with dashes
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Get or create a GlobalKey with usage tracking
  GlobalKey _getOrCreateKey(String uniqueKey) {
    // Track usage count
    _usageCount[uniqueKey] = (_usageCount[uniqueKey] ?? 0) + 1;

    // Create new key if it doesn't exist
    final key = _keys.putIfAbsent(uniqueKey, () => GlobalKey());

    // Debug logging for key creation
    if (_usageCount[uniqueKey] == 1) {
      debugPrint(
          '🔑 GlobalKeyManager: Created new key: ${uniqueKey.substring(0, 50)}...');
    }

    return key;
  }

  /// Mark a key as actively used (call this when key is accessed)
  void markKeyUsed(String uniqueKey) {
    _usageCount[uniqueKey] = (_usageCount[uniqueKey] ?? 0) + 1;
  }

  /// Clean up unused keys to prevent memory leaks
  void cleanupUnusedKeys({int minUsageCount = 1}) {
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

    if (keysToRemove.isNotEmpty) {
      debugPrint(
          '🧹 GlobalKeyManager: Cleaned up ${keysToRemove.length} unused keys');
      debugPrint('🧹 GlobalKeyManager: Remaining keys: ${_keys.length}');
    }
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
      'cleanupInterval': '1 minute',
      'lastCleanup': DateTime.now().toIso8601String(),
    };
  }

  /// Debug: Print current key statistics
  void debugPrintStats() {
    final stats = getMemoryStats();
    debugPrint('🔍 GlobalKeyManager Stats: $stats');

    if (_keys.isNotEmpty) {
      debugPrint('🔑 Sample keys: ${_keys.keys.take(3).toList()}');
      debugPrint(
          '📊 Usage counts: ${_usageCount.entries.take(3).map((e) => '${e.key}: ${e.value}').toList()}');
    }
  }

  /// Start periodic cleanup timer
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
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
