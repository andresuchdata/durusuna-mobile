import 'package:flutter/material.dart';
import '../../core/constants/performance_constants.dart';

/// High-performance ListView optimized for smooth scrolling at high refresh rates
class PerformanceOptimizedList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final double? cacheExtent;

  const PerformanceOptimizedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Wrap each item in RepaintBoundary for better performance
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const HighRefreshScrollPhysics(),
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
      cacheExtent:
          cacheExtent ?? PerformanceConstants.itemCacheExtent.toDouble(),
      // Optimize for high refresh rates
      clipBehavior: Clip.hardEdge,
    );
  }
}

/// High-performance AnimatedContainer with optimized animations
class PerformanceAnimatedContainer extends StatelessWidget {
  final Widget child;
  final Duration? duration;
  final Curve curve;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Decoration? decoration;
  final AlignmentGeometry? alignment;
  final Matrix4? transform;

  const PerformanceAnimatedContainer({
    super.key,
    required this.child,
    this.duration,
    this.curve = PerformanceCurves.smooth,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.alignment,
    this.transform,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: duration ?? PerformanceConstants.normalAnimation,
        curve: curve,
        width: width,
        height: height,
        padding: padding,
        margin: margin,
        color: color,
        decoration: decoration,
        alignment: alignment,
        transform: transform,
        child: child,
      ),
    );
  }
}

/// Optimized page transition for high refresh rates
class HighRefreshPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration transitionDuration;
  final Duration reverseTransitionDuration;

  HighRefreshPageRoute({
    required this.child,
    this.transitionDuration = PerformanceConstants.normalAnimation,
    this.reverseTransitionDuration = PerformanceConstants.fastAnimation,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
          pageBuilder: (context, animation, _) => child,
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: PerformanceCurves.smooth,
      )),
      child: child,
    );
  }
}

/// Performance monitoring widget
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PerformanceMonitor({
    super.key,
    required this.child,
    this.enabled = false,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _fps = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    if (widget.enabled) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _controller.addListener(() {
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

      if (elapsed >= 1000) {
        setState(() {
          _fps = _frameCount * 1000 / elapsed;
          _frameCount = 0;
          _lastFrameTime = now;
        });
      }
    });

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter, // Fix Directionality issue
      children: [
        widget.child,
        if (widget.enabled)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'FPS: ${_fps.toStringAsFixed(1)}',
                textDirection: TextDirection.ltr, // Fix Directionality issue
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
