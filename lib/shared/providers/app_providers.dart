import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/storage_service.dart';

// Export notification providers for easy access
export '../services/notification_service.dart' show 
    notificationServiceProvider, 
    notificationsProvider, 
    unreadNotificationsCountProvider;

// Theme Mode Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_getInitialThemeMode());
  
  static ThemeMode _getInitialThemeMode() {
    final savedTheme = StorageService.getThemeMode();
    switch (savedTheme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
  
  void setThemeMode(ThemeMode themeMode) {
    state = themeMode;
    String themeName;
    switch (themeMode) {
      case ThemeMode.light:
        themeName = 'light';
        break;
      case ThemeMode.dark:
        themeName = 'dark';
        break;
      case ThemeMode.system:
        themeName = 'system';
        break;
    }
    StorageService.setThemeMode(themeName);
  }
}

// Language Provider
final languageProvider = StateNotifierProvider<LanguageNotifier, String>(
  (ref) => LanguageNotifier(),
);

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super(StorageService.getLanguage());
  
  void setLanguage(String language) {
    state = language;
    StorageService.setLanguage(language);
  }
}

// Notifications Provider
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, bool>(
  (ref) => NotificationsNotifier(),
);

class NotificationsNotifier extends StateNotifier<bool> {
  NotificationsNotifier() : super(StorageService.getNotificationsEnabled());
  
  void setNotificationsEnabled(bool enabled) {
    state = enabled;
    StorageService.setNotificationsEnabled(enabled);
  }
} 