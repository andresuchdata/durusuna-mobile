import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Secure Firebase configuration using environment variables.
///
/// Usage:
/// - Development: Set environment variables in your IDE or use --dart-define
/// - Production: Use build-time environment variables
///
/// Example build command:
/// ```bash
/// flutter build apk \
///   --dart-define=FIREBASE_PROJECT_ID=your-project-id \
///   --dart-define=FIREBASE_ANDROID_API_KEY=your-android-key \
///   --dart-define=FIREBASE_ANDROID_APP_ID=your-android-app-id \
///   --dart-define=FIREBASE_IOS_API_KEY=your-ios-key \
///   --dart-define=FIREBASE_IOS_APP_ID=your-ios-app-id \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id
/// ```
class SecureFirebaseConfig {
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  // Android Configuration
  static const String _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: '',
  );

  static const String _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '',
  );

  // iOS Configuration
  static const String _iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
    defaultValue: '',
  );

  static const String _iosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '',
  );

  static const String _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.durusuna.mobile',
  );

  /// Get Firebase options for current platform
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase not configured for web platform');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidOptions;
      case TargetPlatform.iOS:
        return _iosOptions;
      default:
        throw UnsupportedError(
          'Firebase not configured for ${defaultTargetPlatform.name} platform',
        );
    }
  }

  /// Validate that all required configuration is present
  static bool get isConfigured {
    if (_projectId.isEmpty || _messagingSenderId.isEmpty) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidApiKey.isNotEmpty && _androidAppId.isNotEmpty;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosApiKey.isNotEmpty && _iosAppId.isNotEmpty;
    }

    return false;
  }

  static FirebaseOptions get _androidOptions => FirebaseOptions(
        apiKey: _androidApiKey,
        appId: _androidAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
      );

  static FirebaseOptions get _iosOptions => FirebaseOptions(
        apiKey: _iosApiKey,
        appId: _iosAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        iosBundleId: _iosBundleId,
      );

  /// Get configuration summary for debugging (without sensitive data)
  static Map<String, dynamic> get debugInfo => {
        'projectId': _projectId.isNotEmpty
            ? '${_projectId.substring(0, 8)}...'
            : 'missing',
        'messagingSenderId': _messagingSenderId.isNotEmpty
            ? '${_messagingSenderId.substring(0, 8)}...'
            : 'missing',
        'platform': defaultTargetPlatform.name,
        'isConfigured': isConfigured,
      };
}
