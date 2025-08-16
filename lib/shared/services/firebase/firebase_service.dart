import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../../config/firebase_config.dart';

/// Service responsible for Firebase initialization and core setup
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize Firebase with secure configuration
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        debugPrint('🔥 Firebase already initialized');
        return true;
      }

      // Prefer secure dart-define config when provided; otherwise fall back to
      // native platform config from google-services.json / GoogleService-Info.plist
      if (SecureFirebaseConfig.isConfigured) {
        await Firebase.initializeApp(
          options: SecureFirebaseConfig.currentPlatform,
        );
      } else {
        debugPrint('🔥 Using native Firebase config (google-services / plist)');
        await Firebase.initializeApp();
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      _isInitialized = true;
      debugPrint('🔥 Firebase initialized successfully');
      debugPrint('🔥 Config: ${SecureFirebaseConfig.debugInfo}');

      return true;
    } catch (error) {
      debugPrint('🔥 Firebase initialization failed: $error');
      return false;
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('🔥 Background message received: ${message.messageId}');
  // Handle background message processing here
}
