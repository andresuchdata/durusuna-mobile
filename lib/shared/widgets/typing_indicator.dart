import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/app_theme.dart';

class TypingIndicator extends StatefulWidget {
  final Color? bubbleColor;
  final Color? dotsColor;
  final double? bubbleRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? dotsSize;
  final int dotCount;
  final Duration rippleDuration;
  final Duration dotAnimationDuration;
  final bool isTyping;

  const TypingIndicator({
    super.key,
    this.bubbleColor,
    this.dotsColor,
    this.bubbleRadius,
    this.padding,
    this.margin,
    this.dotsSize,
    this.dotCount = 3,
    this.rippleDuration = const Duration(milliseconds: 2000),
    this.dotAnimationDuration = const Duration(milliseconds: 600),
    this.isTyping = true,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.rippleDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_animationController);

    // Start continuous animation
    _startAnimation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _animationController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.bubbleColor ?? Colors.grey[200],
            borderRadius: BorderRadius.circular(widget.bubbleRadius ?? 20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated typing dots with wave-like ripple movement
              SizedBox(
                width: 32,
                height: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    widget.dotCount,
                    (index) => _buildRippleDot(index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRippleDot(int index) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Create a wave-like ripple effect with phase shift for each dot
        final phaseShift =
            (index * math.pi / 2); // Delay each dot by π/2 radians
        final adjustedValue = _animation.value + phaseShift;
        final sineValue = math.sin(adjustedValue);

        // Convert sine wave to vertical movement (up and down)
        final verticalOffset = sineValue * 4.0; // Move up and down by 4px

        // Scale and opacity based on the wave position
        final normalizedValue = (sineValue + 1) / 2; // Convert to 0-1 range
        final scale = 0.6 + (normalizedValue * 0.4); // Scale from 0.6 to 1.0
        final opacity =
            0.4 + (normalizedValue * 0.6); // Opacity from 0.4 to 1.0

        return Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.dotsSize ?? 6,
              height: widget.dotsSize ?? 6,
              decoration: BoxDecoration(
                color: (widget.dotsColor ?? AppTheme.textSecondary)
                    .withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
