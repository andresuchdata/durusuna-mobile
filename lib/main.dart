import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_theme.dart';

import 'core/storage/storage_service.dart';
import 'core/utils/global_auth_handler.dart';
import 'core/utils/platform_optimization.dart';
import 'shared/providers/app_providers.dart';
import 'shared/providers/local_chat_providers.dart';
import 'shared/services/realtime_service.dart';

import 'shared/services/chat_service.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/notification_service.dart' as notification_service
    show unreadNotificationsCountProvider;
import 'shared/database/chat_database.dart';
import 'shared/widgets/performance_optimized_list.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/class_management/presentation/pages/class_management_page.dart'
    show userClassesProvider;
import 'shared/services/firebase/firebase_service.dart';
import 'shared/services/firebase/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  final firebaseInitialized = await FirebaseService().initialize();
  if (!firebaseInitialized) {
    debugPrint(
        '🔥 Firebase initialization skipped due to missing configuration');
  }

  // Initialize Hive
  await Hive.initFlutter();
  await StorageService.init();

  // Initialize Isar database for local-first chat
  await ChatDatabase.initialize();

  // Initialize platform-specific optimizations
  await PlatformOptimization.initialize();

  // Initialize Firebase Cloud Messaging
  if (firebaseInitialized) {
    await FCMService().initialize();
  }

  // Enable high refresh rate displays (120Hz, 90Hz, etc.)
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Set preferred orientations for better performance
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('SystemChrome configuration error: $e');
  }

  runApp(
    const ProviderScope(
      child: DurusunaMobileApp(),
    ),
  );
}

class DurusunaMobileApp extends ConsumerWidget {
  const DurusunaMobileApp({super.key});

  // Global navigator key for navigation from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Listen for auth state changes to clear cached data on logout
    ref.listen(authStateProvider, (previous, next) {
      // If user was authenticated but is now not authenticated (logout)
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        debugPrint('🗑️ User logged out - clearing cached providers');

        // Invalidate all user-specific providers to prevent data leakage
        try {
          ref.invalidate(userClassesProvider);
          ref.invalidate(notification_service.unreadNotificationsCountProvider);

          // Clear local chat database on logout for security
          ChatDatabase.clearAllData();

          debugPrint('✅ User providers and local data cleared on logout');
        } catch (e) {
          debugPrint('❌ Error clearing providers: $e');
        }
      }
    });

    // Listen for presence updates to keep conversations list in sync
    ref.listen(realtimePresenceProvider, (previous, next) {
      next.when(
        data: (presence) {
          // Update conversation list with latest presence
          ref
              .read(conversationsProvider.notifier)
              .updateUserStatus(presence.userId, presence.isOnline);
        },
        loading: () {},
        error: (error, stack) {
          // Error in global presence listener
        },
      );
    });

    // Initialize centralized real-time dispatcher (handles all real-time events)
    ref.read(realtimeDispatcherProvider);

    // Initialize GlobalAuthHandler with navigator key and ref
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalAuthHandler.initialize(navigatorKey, ref);

      // Initialize RealtimeService for app-wide socket connection
      debugPrint('🏗️ Main: Initializing RealtimeService provider...');
      ref.read(realtimeServiceProvider);
      debugPrint('✅ Main: RealtimeService provider initialized');
    });

    return PerformanceMonitor(
      enabled: false, // Disable performance monitor frame info panel
      child: MaterialApp(
        title: 'Durusuna Mobile',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const SplashPage(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/splash': (context) => const SplashPage(),
          '/home': (context) => const EnhancedHomePage(),
        },
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}
