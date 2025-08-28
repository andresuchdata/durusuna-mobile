import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/storage/storage_service.dart';

/// Service to cache participant information for faster access
/// This eliminates the need to fetch participants every time a group chat is opened
class ParticipantCacheService {
  static const String _cacheKey = 'participant_cache';
  static const String _lastUpdateKey = 'participant_cache_last_update';
  static const Duration _cacheValidity =
      Duration(hours: 24); // Cache for 24 hours

  // In-memory cache for fastest access
  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Get participant display name from cache
  static String? getParticipantName(
      String conversationId, String participantId) {
    final conversationCache = _memoryCache[conversationId];
    if (conversationCache != null &&
        conversationCache.containsKey(participantId)) {
      final participant = conversationCache[participantId];
      return _buildDisplayName(participant);
    }
    return null;
  }

  /// Get all participants for a conversation
  static List<Map<String, dynamic>> getConversationParticipants(
      String conversationId) {
    final conversationCache = _memoryCache[conversationId];
    if (conversationCache != null) {
      return conversationCache.values
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
    }
    return [];
  }

  /// Cache participants for a conversation
  static Future<void> cacheParticipants(
      String conversationId, List<Map<String, dynamic>> participants) async {
    try {
      // Update memory cache
      _memoryCache[conversationId] = {};
      for (final participant in participants) {
        final id = participant['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          _memoryCache[conversationId]![id] = participant;
        }
      }

      // Persist to local storage
      await _persistToStorage();

      debugPrint(
          '🔍 [ParticipantCache] Cached ${participants.length} participants for conversation $conversationId');
    } catch (e) {
      debugPrint('❌ [ParticipantCache] Failed to cache participants: $e');
    }
  }

  /// Cache participants for multiple conversations
  static Future<void> cacheMultipleConversations(
      Map<String, List<Map<String, dynamic>>> conversationsData) async {
    try {
      for (final entry in conversationsData.entries) {
        final conversationId = entry.key;
        final participants = entry.value;

        _memoryCache[conversationId] = {};
        for (final participant in participants) {
          final id = participant['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            _memoryCache[conversationId]![id] = participant;
          }
        }
      }

      // Persist to local storage
      await _persistToStorage();

      debugPrint(
          '🔍 [ParticipantCache] Cached participants for ${conversationsData.length} conversations');
    } catch (e) {
      debugPrint(
          '❌ [ParticipantCache] Failed to cache multiple conversations: $e');
    }
  }

  /// Check if cache is valid and not expired
  static Future<bool> isCacheValid() async {
    try {
      final lastUpdateStr =
          StorageService.getCachedData<String>(_lastUpdateKey);
      if (lastUpdateStr == null) return false;

      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();

      return now.difference(lastUpdate) < _cacheValidity;
    } catch (e) {
      return false;
    }
  }

  /// Clear expired cache
  static Future<void> clearExpiredCache() async {
    try {
      if (!await isCacheValid()) {
        _memoryCache.clear();
        await StorageService.clearCache();
        debugPrint('🔍 [ParticipantCache] Cleared expired cache');
      }
    } catch (e) {
      debugPrint('❌ [ParticipantCache] Failed to clear expired cache: $e');
    }
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    try {
      _memoryCache.clear();
      await StorageService.clearCache();
      debugPrint('🔍 [ParticipantCache] Cleared all cache');
    } catch (e) {
      debugPrint('❌ [ParticipantCache] Failed to clear all cache: $e');
    }
  }

  /// Load cache from storage on app startup
  static Future<void> loadFromStorage() async {
    try {
      final cacheData = StorageService.getCachedData<String>(_cacheKey);
      if (cacheData != null) {
        final Map<String, dynamic> parsed = jsonDecode(cacheData);

        // Convert back to proper structure
        for (final entry in parsed.entries) {
          final conversationId = entry.key;
          final participantsData = entry.value as Map<String, dynamic>;

          _memoryCache[conversationId] = {};
          for (final participantEntry in participantsData.entries) {
            final participantId = participantEntry.key;
            final participant = participantEntry.value as Map<String, dynamic>;
            _memoryCache[conversationId]![participantId] = participant;
          }
        }

        debugPrint(
            '🔍 [ParticipantCache] Loaded ${_memoryCache.length} conversations from storage');
      }
    } catch (e) {
      debugPrint('❌ [ParticipantCache] Failed to load from storage: $e');
    }
  }

  /// Build display name from participant data
  static String _buildDisplayName(Map<String, dynamic> participant) {
    final displayName = participant['display_name']?.toString() ?? '';
    final firstName = participant['first_name']?.toString() ?? '';
    final lastName = participant['last_name']?.toString() ?? '';
    final email = participant['email']?.toString() ?? '';

    if (displayName.isNotEmpty) {
      return displayName;
    } else if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    } else if (email.isNotEmpty) {
      return email.split('@')[0]; // Use part before @ as name
    }

    return 'Unknown User';
  }

  /// Persist cache to local storage
  static Future<void> _persistToStorage() async {
    try {
      // Convert memory cache to serializable format
      final Map<String, Map<String, dynamic>> serializableCache = {};
      for (final entry in _memoryCache.entries) {
        serializableCache[entry.key] = Map<String, dynamic>.from(entry.value);
      }

      final cacheJson = jsonEncode(serializableCache);
      await StorageService.cacheData(_cacheKey, cacheJson);

      // Update last update timestamp
      final now = DateTime.now().toIso8601String();
      await StorageService.cacheData(_lastUpdateKey, now);
    } catch (e) {
      debugPrint('❌ [ParticipantCache] Failed to persist to storage: $e');
    }
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    int totalParticipants = 0;
    for (final conversation in _memoryCache.values) {
      totalParticipants += conversation.length;
    }

    return {
      'conversations': _memoryCache.length,
      'totalParticipants': totalParticipants,
      'conversationIds': _memoryCache.keys.toList(),
    };
  }
}
