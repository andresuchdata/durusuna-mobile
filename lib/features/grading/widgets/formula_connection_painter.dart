import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/formula_builder_models.dart';
import 'formula_canvas.dart';

class FormulaConnectionPainter extends CustomPainter {
  final List<FormulaConnection> connections;
  final List<FormulaNode> nodes;
  final TemporaryConnection? temporaryConnection;

  FormulaConnectionPainter({
    required this.connections,
    required this.nodes,
    this.temporaryConnection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw established connections
    for (final connection in connections) {
      _drawConnection(canvas, connection);
    }

    // Draw temporary connection while dragging
    if (temporaryConnection != null) {
      _drawTemporaryConnection(canvas, temporaryConnection!);
    }
  }

  void _drawConnection(Canvas canvas, FormulaConnection connection) {
    final fromNode =
        nodes.firstWhere((node) => node.id == connection.fromNodeId);
    final toNode = nodes.firstWhere((node) => node.id == connection.toNodeId);

    final fromPoint = _getNodeConnectionPoint(fromNode, isOutput: true);
    final toPoint = _getNodeConnectionPoint(toNode, isOutput: false);

    final paint = Paint()
      ..color = connection.style.color
      ..strokeWidth = connection.style.width
      ..style = PaintingStyle.stroke;

    // Set line style
    switch (connection.style.lineStyle) {
      case LineStyle.dashed:
        _drawDashedLine(canvas, fromPoint, toPoint, paint);
        break;
      case LineStyle.dotted:
        _drawDottedLine(canvas, fromPoint, toPoint, paint);
        break;
      case LineStyle.solid:
      default:
        _drawBezierConnection(canvas, fromPoint, toPoint, paint);
        break;
    }

    // Draw arrow at the end
    _drawArrow(canvas, fromPoint, toPoint, paint);

    // Draw connection label if exists
    if (connection.style.label != null) {
      _drawConnectionLabel(canvas, fromPoint, toPoint, connection.style.label!);
    }

    // Draw connection type indicator for conditions
    if (connection.connectionType != ConnectionType.flow) {
      _drawConnectionTypeIndicator(
          canvas, fromPoint, toPoint, connection.connectionType);
    }
  }

  void _drawTemporaryConnection(
      Canvas canvas, TemporaryConnection tempConnection) {
    final fromNode =
        nodes.firstWhere((node) => node.id == tempConnection.fromNodeId);
    final fromPoint = _getNodeConnectionPoint(fromNode, isOutput: true);
    final toPoint = tempConnection.endPoint;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, fromPoint, toPoint, paint);
    _drawArrow(canvas, fromPoint, toPoint, paint);
  }

  Offset _getNodeConnectionPoint(FormulaNode node, {required bool isOutput}) {
    final nodeCenter = Offset(
      node.position.dx + _getNodeWidth(node) / 2,
      node.position.dy + _getNodeHeight(node) / 2,
    );

    if (isOutput) {
      // Output point (right side of node)
      return Offset(
        node.position.dx + _getNodeWidth(node),
        nodeCenter.dy,
      );
    } else {
      // Input point (left side of node)
      return Offset(
        node.position.dx,
        nodeCenter.dy,
      );
    }
  }

  double _getNodeWidth(FormulaNode node) {
    switch (node.type) {
      case NodeType.component:
        return 80;
      case NodeType.operator:
        return 50;
      case NodeType.value:
        return 60;
      case NodeType.condition:
        return 100;
      case NodeType.parenthesis:
        return 40;
    }
  }

  double _getNodeHeight(FormulaNode node) {
    switch (node.type) {
      case NodeType.component:
        return 60;
      case NodeType.operator:
        return 50;
      case NodeType.value:
        return 50;
      case NodeType.condition:
        return 60;
      case NodeType.parenthesis:
        return 50;
    }
  }

  void _drawBezierConnection(
      Canvas canvas, Offset from, Offset to, Paint paint) {
    final path = Path();
    path.moveTo(from.dx, from.dy);

    // Create curved connection
    final controlPoint1 = Offset(from.dx + 50, from.dy);
    final controlPoint2 = Offset(to.dx - 50, to.dy);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      to.dx,
      to.dy,
    );

    canvas.drawPath(path, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final distance = (to - from).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startDistance = i * (dashWidth + dashSpace);
      final endDistance = startDistance + dashWidth;

      final startPoint = Offset.lerp(from, to, startDistance / distance)!;
      final endPoint = Offset.lerp(from, to, endDistance / distance)!;

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  void _drawDottedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dotRadius = 1.0;
    const dotSpace = 4.0;
    final distance = (to - from).distance;
    final dotCount = (distance / dotSpace).floor();

    for (int i = 0; i < dotCount; i++) {
      final t = i / dotCount;
      final point = Offset.lerp(from, to, t)!;
      canvas.drawCircle(point, dotRadius, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    const arrowSize = 8.0;
    final direction = (to - from).direction;

    final arrowP1 = Offset(
      to.dx - arrowSize * math.cos(direction - math.pi / 6),
      to.dy - arrowSize * math.sin(direction - math.pi / 6),
    );

    final arrowP2 = Offset(
      to.dx - arrowSize * math.cos(direction + math.pi / 6),
      to.dy - arrowSize * math.sin(direction + math.pi / 6),
    );

    final arrowPath = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(arrowP1.dx, arrowP1.dy)
      ..lineTo(arrowP2.dx, arrowP2.dy)
      ..close();

    canvas.drawPath(arrowPath, paint..style = PaintingStyle.fill);
  }

  void _drawConnectionLabel(
      Canvas canvas, Offset from, Offset to, String label) {
    final midPoint = Offset.lerp(from, to, 0.5)!;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw background
    final labelRect = Rect.fromCenter(
      center: midPoint,
      width: textPainter.width + 4,
      height: textPainter.height + 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(2)),
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    textPainter.paint(
      canvas,
      Offset(
        midPoint.dx - textPainter.width / 2,
        midPoint.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawConnectionTypeIndicator(
      Canvas canvas, Offset from, Offset to, ConnectionType type) {
    final midPoint = Offset.lerp(from, to, 0.3)!;

    Color indicatorColor;
    IconData indicatorIcon;

    switch (type) {
      case ConnectionType.conditionTrue:
        indicatorColor = Colors.green;
        indicatorIcon = Icons.check;
        break;
      case ConnectionType.conditionFalse:
        indicatorColor = Colors.red;
        indicatorIcon = Icons.close;
        break;
      case ConnectionType.flow:
      default:
        return; // No indicator for flow connections
    }

    // Draw indicator background
    canvas.drawCircle(
      midPoint,
      8,
      Paint()..color = indicatorColor,
    );

    // Draw indicator icon (simplified as a symbol)
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    if (type == ConnectionType.conditionTrue) {
      // Draw checkmark
      final path = Path()
        ..moveTo(midPoint.dx - 3, midPoint.dy)
        ..lineTo(midPoint.dx, midPoint.dy + 3)
        ..lineTo(midPoint.dx + 4, midPoint.dy - 3);
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    } else if (type == ConnectionType.conditionFalse) {
      // Draw X
      canvas.drawLine(
        Offset(midPoint.dx - 3, midPoint.dy - 3),
        Offset(midPoint.dx + 3, midPoint.dy + 3),
        paint,
      );
      canvas.drawLine(
        Offset(midPoint.dx + 3, midPoint.dy - 3),
        Offset(midPoint.dx - 3, midPoint.dy + 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FormulaConnectionPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        nodes != oldDelegate.nodes ||
        temporaryConnection != oldDelegate.temporaryConnection;
  }
}

// Helper extension for Offset direction calculation
extension OffsetExtension on Offset {
  double get direction => math.atan2(dy, dx);
}
