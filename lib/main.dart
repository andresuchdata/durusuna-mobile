import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:firebase_core/firebase_core.dart'; // TEMPORARILY DISABLED

import 'core/constants/app_theme.dart';
import 'core/storage/storage_service.dart';
import 'core/utils/global_auth_handler.dart';
import 'shared/providers/app_providers.dart';
import 'shared/services/realtime_service.dart';
import 'shared/services/chat_service.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase - TEMPORARILY DISABLED FOR TESTING
  // await Firebase.initializeApp();

  // Initialize Hive
  await Hive.initFlutter();
  await StorageService.init();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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

    // Watch realtime connection status for debugging
    ref.listen(realtimeConnectionProvider, (previous, next) {
      next?.when(
        data: (isConnected) {
          print('📱 App: Realtime connection status changed: $isConnected');
        },
        loading: () {
          print('📱 App: Realtime connection loading...');
        },
        error: (error, stack) {
          print('📱 App: Realtime connection error: $error');
        },
      );
    });

    // Listen for presence updates to keep conversations list in sync
    ref.listen(realtimePresenceProvider, (previous, next) {
      next?.when(
        data: (presence) {
          print(
              '📱 App: Global presence update - User: ${presence.userId}, Online: ${presence.isOnline}');
          print('📱 App: Updating conversations list with presence change');
          // Update conversation list with latest presence
          ref
              .read(conversationsProvider.notifier)
              .updateUserStatus(presence.userId, presence.isOnline);
          print('📱 App: Conversations list update completed');
        },
        loading: () {},
        error: (error, stack) {
          print('📱 App: Error in global presence listener: $error');
        },
      );
    });

    // Listen for new messages to update conversations list in real-time
    ref.listen(realtimeMessagesProvider, (previous, next) {
      next?.when(
        data: (realtimeMessage) {
          print(
              '📱 App: Global message update - Conversation: ${realtimeMessage.conversationId}');
          print('📱 App: Message content: ${realtimeMessage.message.content}');

          // Update conversation's last message and unread count
          ref
              .read(conversationsProvider.notifier)
              .updateConversationLastMessage(
                  realtimeMessage.conversationId, realtimeMessage.message);
          print('📱 App: Conversations list updated with new message');
        },
        loading: () {},
        error: (error, stack) {
          print('📱 App: Error in global message listener: $error');
        },
      );
    });

    // Initialize GlobalAuthHandler with navigator key and ref
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalAuthHandler.initialize(navigatorKey, ref);

      // Initialize RealtimeService for app-wide socket connection
      print('📱 App: Initializing RealtimeService...');
      ref.read(realtimeServiceProvider);
    });

    return MaterialApp(
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
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}
