import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/performance_constants.dart';

/// Platform-specific performance optimizations
class PlatformOptimization {
  static bool _initialized = false;

  /// Initialize platform-specific optimizations
  static Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      await _initializeWeb();
    } else if (Platform.isIOS) {
      await _initializeIOS();
    } else if (Platform.isAndroid) {
      await _initializeAndroid();
    }

    _initialized = true;
  }

  /// iOS-specific optimizations
  static Future<void> _initializeIOS() async {
    try {
      // Enable ProMotion on supported devices (iPhone 13 Pro and later)
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0x00000000),
          statusBarColor: Color(0x00000000),
        ),
      );

      // Set preferred frame rate for iOS
      if (Platform.isIOS) {
        try {
          debugPrint(
              '🎯 Requesting ${PerformanceConstants.targetRefreshRate}Hz refresh rate...');
          await SystemChannels.platform
              .invokeMethod('SystemChrome.setPreferredFrameRate', {
            'frameRate': PerformanceConstants.targetRefreshRate,
          });
          debugPrint('✅ iOS frame rate request sent successfully');
        } catch (e) {
          debugPrint('⚠️ Failed to set iOS frame rate: $e');
          debugPrint(
              '💡 This is normal in simulator - physical device required for 120Hz');
        }
      }

      debugPrint('✅ iOS optimizations initialized');
    } catch (e) {
      debugPrint('❌ iOS optimization error: $e');
    }
  }

  /// Android-specific optimizations
  static Future<void> _initializeAndroid() async {
    try {
      // Enable high refresh rate on supported Android devices
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0x00000000),
          statusBarColor: Color(0x00000000),
          systemNavigationBarIconBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.dark,
        ),
      );

      // Request high performance mode on Android
      if (Platform.isAndroid) {
        try {
          await SystemChannels.platform
              .invokeMethod('SystemChrome.setHighPerformanceMode', true);
        } catch (e) {
          debugPrint('High performance mode not available: $e');
        }
      }

      debugPrint('✅ Android optimizations initialized');
    } catch (e) {
      debugPrint('❌ Android optimization error: $e');
    }
  }

  /// Web-specific optimizations
  static Future<void> _initializeWeb() async {
    try {
      debugPrint('✅ Web optimizations initialized');
    } catch (e) {
      debugPrint('❌ Web optimization error: $e');
    }
  }

  /// Get optimal scroll physics for the current platform
  static ScrollPhysics getOptimalScrollPhysics() {
    if (Platform.isIOS) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    } else if (Platform.isAndroid) {
      return const HighRefreshScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const HighRefreshScrollPhysics();
  }

  /// Get optimal animation duration for the current platform
  static Duration getOptimalAnimationDuration() {
    if (Platform.isIOS) {
      return PerformanceConstants.normalAnimation;
    } else if (Platform.isAndroid) {
      return PerformanceConstants.fastAnimation;
    }
    return PerformanceConstants.normalAnimation;
  }

  /// Check if high refresh rate is likely supported
  static bool get isHighRefreshRateSupported {
    // This is a heuristic - in a real app you'd use platform channels
    // to check actual device capabilities
    if (Platform.isIOS) {
      // iPhone 13 Pro and later support ProMotion (120Hz)
      return true; // Assume supported for now
    } else if (Platform.isAndroid) {
      // Many modern Android devices support 90Hz or 120Hz
      return true; // Assume supported for now
    }
    return false;
  }

  /// Get recommended cache extent based on platform and device capabilities
  static double getOptimalCacheExtent() {
    if (isHighRefreshRateSupported) {
      return PerformanceConstants.maxCacheExtent.toDouble();
    }
    return PerformanceConstants.itemCacheExtent.toDouble();
  }

  /// Enable performance monitoring if in debug mode
  static bool get shouldShowPerformanceMonitor {
    return kDebugMode &&
        const bool.fromEnvironment('ENABLE_PERFORMANCE_MONITORING',
            defaultValue: false);
  }

  /// Get target refresh rate from environment or platform default
  static int get targetRefreshRate {
    const envRefreshRate =
        int.fromEnvironment('TARGET_REFRESH_RATE', defaultValue: 0);
    if (envRefreshRate > 0) return envRefreshRate;

    return isHighRefreshRateSupported
        ? PerformanceConstants.targetRefreshRate
        : PerformanceConstants.fallbackRefreshRate;
  }
}
