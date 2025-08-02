import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _userBox = 'user_box';
  static const String _settingsBox = 'settings_box';
  static const String _cacheBox = 'cache_box';

  static late Box _userStorage;
  static late Box _settingsStorage;
  static late Box _cacheStorage;

  static Future<void> init() async {
    _userStorage = await Hive.openBox(_userBox);
    _settingsStorage = await Hive.openBox(_settingsBox);
    _cacheStorage = await Hive.openBox(_cacheBox);
  }

  // User Storage Methods
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    await _userStorage.put('current_user', userData);
  }

  static Map<String, dynamic>? getUser() {
    final userData = _userStorage.get('current_user');
    return userData != null ? Map<String, dynamic>.from(userData) : null;
  }

  static Future<void> saveToken(String token) async {
    await _userStorage.put('auth_token', token);
  }

  static String? getToken() {
    return _userStorage.get('auth_token');
  }

  static Future<void> saveRefreshToken(String refreshToken) async {
    await _userStorage.put('refresh_token', refreshToken);
  }

  static String? getRefreshToken() {
    return _userStorage.get('refresh_token');
  }

  static Future<void> clearUser() async {
    await _userStorage.delete('current_user');
    await _userStorage.delete('auth_token');
    await _userStorage.delete('refresh_token');
  }

  // Settings Storage Methods
  static Future<void> setThemeMode(String themeMode) async {
    await _settingsStorage.put('theme_mode', themeMode);
  }

  static String getThemeMode() {
    return _settingsStorage.get('theme_mode', defaultValue: 'system');
  }

  static Future<void> setLanguage(String language) async {
    await _settingsStorage.put('language', language);
  }

  static String getLanguage() {
    return _settingsStorage.get('language', defaultValue: 'en');
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _settingsStorage.put('notifications_enabled', enabled);
  }

  static bool getNotificationsEnabled() {
    return _settingsStorage.get('notifications_enabled', defaultValue: true);
  }

  // Cache Storage Methods
  static Future<void> cacheData(String key, dynamic data) async {
    await _cacheStorage.put(key, data);
  }

  static T? getCachedData<T>(String key) {
    return _cacheStorage.get(key);
  }

  static Future<void> clearCache() async {
    await _cacheStorage.clear();
  }

  static Future<void> clearAll() async {
    await _userStorage.clear();
    await _settingsStorage.clear();
    await _cacheStorage.clear();
  }
}
