import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/models/attendance_models.dart';

class AttendanceSuccessAnimation extends StatefulWidget {
  final AnimationController controller;
  final AttendanceStatus status;

  const AttendanceSuccessAnimation({
    super.key,
    required this.controller,
    required this.status,
  });

  @override
  State<AttendanceSuccessAnimation> createState() =>
      _AttendanceSuccessAnimationState();
}

class _AttendanceSuccessAnimationState extends State<AttendanceSuccessAnimation>
    with TickerProviderStateMixin {
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: widget.controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: widget.controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: widget.controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Background circle with pulse effect
            Transform.scale(
              scale: _scaleAnimation.value,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor().withValues(alpha: 0.1),
                    border: Border.all(
                      color: _getStatusColor().withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            // Main icon circle
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 0.5,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStatusColor(),
                        _getStatusColor().withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor().withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),

            // Floating particles effect
            ...List.generate(6, (index) {
              final angle = (index * 60.0) * (3.14159 / 180.0);
              final distance = 80.0;

              return Transform.translate(
                offset: Offset(
                  distance *
                      _scaleAnimation.value *
                      0.8 *
                      (index.isEven ? 1 : -1) *
                      (angle / 6.28),
                  distance *
                      _scaleAnimation.value *
                      0.8 *
                      (index % 3 == 0 ? 1 : -1) *
                      (angle / 6.28),
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor().withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case AttendanceStatus.present:
        return AppTheme.successColor;
      case AttendanceStatus.absent:
        return AppTheme.errorColor;
      case AttendanceStatus.late:
        return AppTheme.warningColor;
      case AttendanceStatus.excused:
        return AppTheme.infoColor;
      case AttendanceStatus.sick:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case AttendanceStatus.present:
        return Icons.check;
      case AttendanceStatus.absent:
        return Icons.close;
      case AttendanceStatus.late:
        return Icons.access_time;
      case AttendanceStatus.excused:
        return Icons.event_note;
      case AttendanceStatus.sick:
        return Icons.sick;
    }
  }
}
