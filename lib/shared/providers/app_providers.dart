import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/storage_service.dart';
import '../services/subjects_service.dart';
import '../services/class_management_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';

// Export notification providers for easy access
export '../services/notification_service.dart'
    show
        notificationServiceProvider,
        notificationsProvider,
        unreadNotificationsCountProvider;

// Service Providers
final subjectsServiceProvider = Provider<SubjectsService>((ref) =>
    SubjectsService(ref.read(apiServiceProvider),
        ref.read(classManagementServiceProvider)));
final classManagementServiceProvider = Provider<ClassManagementService>(
    (ref) => ClassManagementService(ref.read(apiServiceProvider)));

// Data Providers
final userSubjectsProvider = FutureProvider<List<SubjectOffering>>((ref) async {
  final service = ref.read(subjectsServiceProvider);
  return await service.getUserSubjects();
});

final userSubjectStatsProvider = FutureProvider<SubjectStats>((ref) async {
  final service = ref.read(subjectsServiceProvider);
  return await service.getUserSubjectStats();
});

// Role-based subject offerings providers
final adminSubjectOfferingsProvider =
    FutureProvider<List<SubjectOffering>>((ref) async {
  final service = ref.read(subjectsServiceProvider);
  return await service.getAllSubjectOfferingsForAdmin();
});

final studentSubjectOfferingsProvider =
    FutureProvider<List<SubjectOffering>>((ref) async {
  final service = ref.read(subjectsServiceProvider);
  return await service.getStudentSubjectOfferings();
});

final parentSubjectOfferingsProvider =
    FutureProvider<List<SubjectOffering>>((ref) async {
  final service = ref.read(subjectsServiceProvider);
  return await service.getParentSubjectOfferings();
});

// Universal provider that switches based on user role
final roleBasedSubjectOfferingsProvider =
    FutureProvider<List<SubjectOffering>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final currentUser = authState.user;

  if (currentUser == null) {
    throw Exception('User not authenticated');
  }

  final service = ref.read(subjectsServiceProvider);

  // Determine which provider to use based on user role and type
  if (currentUser.role == UserRole.admin) {
    return await service.getAllSubjectOfferingsForAdmin();
  } else if (currentUser.userType == UserType.student) {
    return await service.getStudentSubjectOfferings();
  } else if (currentUser.userType == UserType.parent) {
    return await service.getParentSubjectOfferings();
  } else if (currentUser.userType == UserType.teacher) {
    // Teachers use the existing method
    return await service.getUserSubjects();
  } else {
    throw Exception('Unsupported user type: ${currentUser.userType}');
  }
});

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
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, bool>(
  (ref) => NotificationsNotifier(),
);

class NotificationsNotifier extends StateNotifier<bool> {
  NotificationsNotifier() : super(StorageService.getNotificationsEnabled());

  void setNotificationsEnabled(bool enabled) {
    state = enabled;
    StorageService.setNotificationsEnabled(enabled);
  }
}
