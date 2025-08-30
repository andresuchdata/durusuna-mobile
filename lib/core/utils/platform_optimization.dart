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
    } else {
      await _initializeMobile();
    }

    _initialized = true;
  }

  /// Mobile-specific optimizations (iOS and Android)
  static Future<void> _initializeMobile() async {
    try {
      // Enable system UI optimizations for mobile platforms
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0x00000000),
          statusBarColor: Color(0x00000000),
          systemNavigationBarIconBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.dark,
        ),
      );

      // Set preferred frame rate for mobile platforms
      try {
        debugPrint(
            '🎯 Requesting ${PerformanceConstants.targetRefreshRate}Hz refresh rate...');
        await SystemChannels.platform
            .invokeMethod('SystemChrome.setPreferredFrameRate', {
          'frameRate': PerformanceConstants.targetRefreshRate,
        });
        debugPrint('✅ Mobile frame rate request sent successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to set mobile frame rate: $e');
        debugPrint(
            '💡 This is normal in simulator - physical device required for 120Hz');
      }

      // Request high performance mode on mobile platforms
      try {
        await SystemChannels.platform
            .invokeMethod('SystemChrome.setHighPerformanceMode', true);
      } catch (e) {
        debugPrint('High performance mode not available: $e');
      }

      debugPrint('✅ Mobile optimizations initialized');
    } catch (e) {
      debugPrint('❌ Mobile optimization error: $e');
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
    if (kIsWeb) {
      return const AlwaysScrollableScrollPhysics();
    } else {
      // For mobile platforms, use bouncing scroll physics
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
  }

  /// Get optimal animation duration for the current platform
  static Duration getOptimalAnimationDuration() {
    if (kIsWeb) {
      return PerformanceConstants.normalAnimation;
    } else {
      return PerformanceConstants.fastAnimation;
    }
  }

  /// Check if high refresh rate is likely supported
  static bool get isHighRefreshRateSupported {
    // This is a heuristic - in a real app you'd use platform channels
    // to check actual device capabilities
    if (kIsWeb) {
      return false; // Web doesn't typically support high refresh rates
    } else {
      // Mobile platforms often support 90Hz or 120Hz
      return true; // Assume supported for now
    }
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
