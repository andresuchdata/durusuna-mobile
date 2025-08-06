import 'package:flutter/material.dart';

/// Performance optimization constants for high refresh rate and smooth animations
class PerformanceConstants {
  // Animation durations optimized for high refresh rates
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 250);
  static const Duration slowAnimation = Duration(milliseconds: 350);

  // Scroll physics constants
  static const double scrollPhysicsSpring = 0.8;
  static const double scrollPhysicsDamping = 0.9;

  // List performance settings
  static const int itemCacheExtent = 250; // Cache items outside viewport
  static const int maxCacheExtent = 1000; // Maximum cache size

  // Refresh rates and frame targets
  static const int targetRefreshRate = 120; // Target 120Hz
  static const int fallbackRefreshRate = 60; // Fallback to 60Hz
  static const Duration frameTarget = Duration(microseconds: 8333); // ~120FPS

  // Performance thresholds
  static const int maxItemsPerFrame = 10; // Limit concurrent animations
  static const Duration debounceDelay =
      Duration(milliseconds: 16); // ~60FPS debounce

  // Memory management
  static const int maxCachedPages = 5;
  static const int maxCachedImages = 50;

  // Network performance
  static const Duration apiTimeout = Duration(seconds: 10);
  static const int maxConcurrentRequests = 6;

  // UI update batching
  static const Duration uiBatchDelay = Duration(milliseconds: 16);
  static const int maxBatchedUpdates = 20;
}

/// Animation curves optimized for high refresh rate displays
class PerformanceCurves {
  static const Curve fastOut = Curves.easeOutQuart;
  static const Curve fastIn = Curves.easeInQuart;
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = Curves.elasticInOut;
}

/// High-performance scroll physics
class HighRefreshScrollPhysics extends BouncingScrollPhysics {
  const HighRefreshScrollPhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  HighRefreshScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HighRefreshScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.8,
        stiffness: 300.0,
        ratio: PerformanceConstants.scrollPhysicsDamping,
      );

  @override
  double get minFlingVelocity => 100.0;

  @override
  double get maxFlingVelocity => 5000.0;
}
