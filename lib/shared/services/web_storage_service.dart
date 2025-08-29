import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web storage service that provides localStorage-like functionality
/// This is used as a fallback when SQLite is not available on web
class WebStorageService {
  static const String _prefix = 'durusuna_';
  static SharedPreferences? _prefs;

  /// Initialize the web storage service
  static Future<void> initialize() async {
    if (kIsWeb) {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('✅ [WebStorage] Initialized for web platform');
    }
  }

  /// Check if web storage is available
  static bool get isAvailable => kIsWeb && _prefs != null;

  /// Store a value in web storage
  static Future<bool> setString(String key, String value) async {
    if (!isAvailable) return false;
    return await _prefs!.setString('$_prefix$key', value);
  }

  /// Get a string value from web storage
  static String? getString(String key) {
    if (!isAvailable) return null;
    return _prefs!.getString('$_prefix$key');
  }

  /// Store a map in web storage
  static Future<bool> setMap(String key, Map<String, dynamic> value) async {
    if (!isAvailable) return false;
    final jsonString = jsonEncode(value);
    return await _prefs!.setString('$_prefix$key', jsonString);
  }

  /// Get a map from web storage
  static Map<String, dynamic>? getMap(String key) {
    if (!isAvailable) return null;
    final jsonString = _prefs!.getString('$_prefix$key');
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [WebStorage] Failed to decode JSON for key $key: $e');
      return null;
    }
  }

  /// Store a list in web storage
  static Future<bool> setList(String key, List<dynamic> value) async {
    if (!isAvailable) return false;
    final jsonString = jsonEncode(value);
    return await _prefs!.setString('$_prefix$key', jsonString);
  }

  /// Get a list from web storage
  static List<dynamic>? getList(String key) {
    if (!isAvailable) return null;
    final jsonString = _prefs!.getString('$_prefix$key');
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      debugPrint('❌ [WebStorage] Failed to decode JSON for key $key: $e');
      return null;
    }
  }

  /// Remove a value from web storage
  static Future<bool> remove(String key) async {
    if (!isAvailable) return false;
    return await _prefs!.remove('$_prefix$key');
  }

  /// Clear all web storage
  static Future<bool> clear() async {
    if (!isAvailable) return false;
    return await _prefs!.clear();
  }

  /// Get all keys with the prefix
  static Set<String> getKeys() {
    if (!isAvailable) return {};
    return _prefs!.getKeys().where((key) => key.startsWith(_prefix)).toSet();
  }

  /// Check if a key exists
  static bool containsKey(String key) {
    if (!isAvailable) return false;
    return _prefs!.containsKey('$_prefix$key');
  }

  /// Get storage size (approximate)
  static int getStorageSize() {
    if (!isAvailable) return 0;
    int size = 0;
    for (final key in getKeys()) {
      final value = _prefs!.getString(key);
      if (value != null) {
        size += key.length + value.length;
      }
    }
    return size;
  }
}
