import 'package:flutter/material.dart';
import '../models/formula_builder_models.dart';

class FormulaNodeWidget extends StatelessWidget {
  final FormulaNode node;
  final bool isSelected;
  final bool isConnecting;
  final VoidCallback? onStartConnection;

  const FormulaNodeWidget({
    Key? key,
    required this.node,
    this.isSelected = false,
    this.isConnecting = false,
    this.onStartConnection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _getNodeWidth(),
      height: _getNodeHeight(),
      decoration: BoxDecoration(
        color: _getNodeColor(),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.shade300,
          width: isSelected ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (isSelected || !node.isValid)
            BoxShadow(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Main node content
          _buildNodeContent(),

          // Connection button
          if (onStartConnection != null && !isConnecting)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onStartConnection,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(
                    Icons.link,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Validation error indicator
          if (!node.isValid)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNodeContent() {
    switch (node.type) {
      case NodeType.component:
        return _buildComponentNode();
      case NodeType.operator:
        return _buildOperatorNode();
      case NodeType.value:
        return _buildValueNode();
      case NodeType.condition:
        return _buildConditionNode();
      case NodeType.parenthesis:
        return _buildParenthesisNode();
    }
  }

  Widget _buildComponentNode() {
    final data = node.data as ComponentNodeData;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            size: 20,
            color: Colors.white,
          ),
          const SizedBox(height: 4),
          Text(
            data.displayName,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (data.description != null)
            Tooltip(
              message: data.description!,
              child: Icon(
                Icons.info_outline,
                size: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorNode() {
    final data = node.data as OperatorNodeData;
    return Center(
      child: Text(
        data.displaySymbol,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildValueNode() {
    final data = node.data as ValueNodeData;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.isPercentage ? Icons.percent : Icons.numbers,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(height: 2),
          Text(
            data.displayValue,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (data.isWeight)
            const Text(
              'weight',
              style: TextStyle(
                fontSize: 8,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConditionNode() {
    final data = node.data as ConditionNodeData;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.help_outline,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(height: 2),
          Text(
            data.displayText,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildParenthesisNode() {
    final data = node.data as ParenthesisNodeData;
    return Center(
      child: Text(
        data.displaySymbol,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  double _getNodeWidth() {
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

  double _getNodeHeight() {
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

  Color _getNodeColor() {
    switch (node.type) {
      case NodeType.component:
        return (node.data as ComponentNodeData).color;
      case NodeType.operator:
        return (node.data as OperatorNodeData).color;
      case NodeType.value:
        return (node.data as ValueNodeData).color;
      case NodeType.condition:
        return (node.data as ConditionNodeData).color;
      case NodeType.parenthesis:
        return (node.data as ParenthesisNodeData).color;
    }
  }
}

// Predefined node themes for Islamic school context
class IslamicNodeThemes {
  static const Color tugasHarianColor = Color(0xFF4CAF50); // Green
  static const Color ulanganHarianColor = Color(0xFF2196F3); // Blue
  static const Color utsColor = Color(0xFFFF9800); // Orange
  static const Color uasColor = Color(0xFFF44336); // Red
  static const Color tahfidzColor = Color(0xFF9C27B0); // Purple
  static const Color akhlakColor = Color(0xFF607D8B); // Blue Grey

  static const Color operatorColor = Color(0xFF795548); // Brown
  static const Color valueColor = Color(0xFF009688); // Teal
  static const Color conditionColor = Color(0xFFFF5722); // Deep Orange
  static const Color parenthesisColor = Color(0xFF757575); // Grey

  static Map<String, Color> get componentColors => {
        'tugas_harian': tugasHarianColor,
        'ulangan_harian': ulanganHarianColor,
        'uts': utsColor,
        'uas': uasColor,
        'tahfidz': tahfidzColor,
        'akhlak': akhlakColor,
      };

  static Map<String, IconData> get componentIcons => {
        'tugas_harian': Icons.assignment,
        'ulangan_harian': Icons.quiz,
        'uts': Icons.school,
        'uas': Icons.bookmark,
        'tahfidz': Icons.book,
        'akhlak': Icons.favorite,
      };
}

// Drag feedback widget for dragging from component library
class DraggingNodeWidget extends StatelessWidget {
  final DraggableItem item;

  const DraggingNodeWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            Text(
              item.displayName,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
