import 'package:flutter/material.dart';

/// Animation durations and curves for Durusuna Mobile
/// Provides consistent animation timing across the app
class AppAnimations {
  AppAnimations._(); // Private constructor to prevent instantiation

  // ============ DURATION CONSTANTS ============
  /// Ultra-fast transitions (75ms) - micro interactions
  static const Duration durationUltraFast = Duration(milliseconds: 75);

  /// Fast transitions (150ms) - quick feedback
  static const Duration durationFast = Duration(milliseconds: 150);

  /// Standard transitions (300ms) - default animations
  static const Duration durationDefault = Duration(milliseconds: 300);

  /// Medium transitions (400ms) - noticeable movement
  static const Duration durationMedium = Duration(milliseconds: 400);

  /// Slow transitions (500ms) - deliberate animations
  static const Duration durationSlow = Duration(milliseconds: 500);

  /// Extra slow transitions (750ms) - emphasized animations
  static const Duration durationExtraSlow = Duration(milliseconds: 750);

  /// Very slow transitions (1000ms) - page transitions
  static const Duration durationVerySlow = Duration(milliseconds: 1000);

  // ============ COMMON DURATION ALIASES ============
  static const Duration shortestDuration = durationUltraFast;
  static const Duration shortDuration = durationFast;
  static const Duration standardDuration = durationDefault;
  static const Duration longDuration = durationSlow;
  static const Duration longestDuration = durationVerySlow;

  // ============ ANIMATION CURVES ============
  /// Standard Material easing curve
  static const Curve curveLinear = Curves.linear;

  /// Material easing - ease in
  static const Curve curveEaseIn = Curves.easeIn;

  /// Material easing - ease out
  static const Curve curveEaseOut = Curves.easeOut;

  /// Material easing - ease in and out
  static const Curve curveEaseInOut = Curves.easeInOut;

  /// Fast entrance curve
  static const Curve curveEaseOutCubic = Curves.easeOutCubic;

  /// Deceleration curve
  static const Curve curveDecelerate = Curves.decelerate;

  /// Bouncy curve for playful animations
  static const Curve curveBounceInOut = Curves.bounceInOut;

  /// Elastic curve for springy animations
  static const Curve curveElasticInOut = Curves.elasticInOut;

  /// Elastic curve in
  static const Curve curveElasticOut = Curves.elasticOut;

  // ============ RECOMMENDED ANIMATION COMBINATIONS ============
  /// Quick, snappy feedback animations
  static const AnimationConfig snappyAnimation = AnimationConfig(
    duration: durationFast,
    curve: curveEaseOutCubic,
  );

  /// Standard smooth transitions
  static const AnimationConfig smoothAnimation = AnimationConfig(
    duration: durationDefault,
    curve: curveEaseInOut,
  );

  /// Emphatic entrance animations
  static const AnimationConfig emphasticAnimation = AnimationConfig(
    duration: durationMedium,
    curve: Curves.easeOutQuint,
  );

  /// Subtle fade animations
  static const AnimationConfig subtleAnimation = AnimationConfig(
    duration: durationFast,
    curve: curveEaseOut,
  );

  /// Playful bouncy animations
  static const AnimationConfig playfulAnimation = AnimationConfig(
    duration: durationSlow,
    curve: curveElasticOut,
  );

  /// Page transition animations
  static const AnimationConfig pageTransitionAnimation = AnimationConfig(
    duration: durationMedium,
    curve: Curves.easeInOutCubic,
  );

  /// Modal entrance animations
  static const AnimationConfig modalAnimation = AnimationConfig(
    duration: durationDefault,
    curve: curveEaseOut,
  );

  // ============ HELPER METHODS ============
  /// Get duration in milliseconds
  static int getDurationInMs(Duration duration) => duration.inMilliseconds;

  /// Get duration in seconds
  static double getDurationInSeconds(Duration duration) =>
      duration.inMilliseconds / 1000;

  /// Create custom animation config
  static AnimationConfig custom({
    Duration duration = durationDefault,
    Curve curve = Curves.easeInOut,
  }) =>
      AnimationConfig(duration: duration, curve: curve);
}

/// Animation configuration model
class AnimationConfig {
  final Duration duration;
  final Curve curve;

  const AnimationConfig({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });
}
