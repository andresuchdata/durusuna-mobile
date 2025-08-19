import 'package:flutter/material.dart';
import '../models/formula_builder_models.dart';
import 'formula_node_widget.dart';
import 'formula_connection_painter.dart';

class FormulaCanvas extends StatefulWidget {
  final VisualFormulaStructure formula;
  final Function(FormulaNode) onNodeSelected;
  final Function(FormulaNode, Offset) onNodeMoved;
  final Function(String, String) onNodesConnected;
  final Function(String) onNodeDeleted;
  final Function(String) onConnectionDeleted;
  final bool isReadOnly;

  const FormulaCanvas({
    Key? key,
    required this.formula,
    required this.onNodeSelected,
    required this.onNodeMoved,
    required this.onNodesConnected,
    required this.onNodeDeleted,
    required this.onConnectionDeleted,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  State<FormulaCanvas> createState() => _FormulaCanvasState();
}

class _FormulaCanvasState extends State<FormulaCanvas> {
  String? selectedNodeId;
  String? connectingFromNodeId;
  Offset? connectionEndPoint;
  bool isConnecting = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedNodeId = null;
          connectingFromNodeId = null;
          connectionEndPoint = null;
          isConnecting = false;
        });
      },
      child: Container(
        width: widget.formula.canvasSettings.size.width,
        height: widget.formula.canvasSettings.size.height,
        decoration: BoxDecoration(
          color: widget.formula.canvasSettings.backgroundColor,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            // Grid background
            if (widget.formula.canvasSettings.snapToGrid)
              _buildGridBackground(),

            // Connections layer
            CustomPaint(
              painter: FormulaConnectionPainter(
                connections: widget.formula.connections,
                nodes: widget.formula.nodes,
                temporaryConnection:
                    isConnecting && connectingFromNodeId != null
                        ? TemporaryConnection(
                            fromNodeId: connectingFromNodeId!,
                            endPoint: connectionEndPoint ?? Offset.zero,
                          )
                        : null,
              ),
              size: widget.formula.canvasSettings.size,
            ),

            // Nodes layer
            ...widget.formula.nodes.map((node) => _buildNodeWidget(node)),

            // Drop zone indicators when dragging
            if (isConnecting) ..._buildDropZones(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBackground() {
    final gridSize = widget.formula.canvasSettings.gridSize ?? 20.0;
    return CustomPaint(
      painter: GridPainter(
        gridSize: gridSize,
        color: Colors.grey.shade200,
      ),
      size: widget.formula.canvasSettings.size,
    );
  }

  Widget _buildNodeWidget(FormulaNode node) {
    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: GestureDetector(
        onTap: () {
          if (isConnecting && connectingFromNodeId != null) {
            // Complete connection
            if (connectingFromNodeId != node.id) {
              widget.onNodesConnected(connectingFromNodeId!, node.id);
            }
            setState(() {
              isConnecting = false;
              connectingFromNodeId = null;
              connectionEndPoint = null;
            });
          } else {
            // Select node
            setState(() {
              selectedNodeId = node.id;
            });
            widget.onNodeSelected(node);
          }
        },
        onLongPress: widget.isReadOnly
            ? null
            : () {
                _showNodeContextMenu(node);
              },
        onPanStart: widget.isReadOnly
            ? null
            : (details) {
                setState(() {
                  selectedNodeId = node.id;
                });
              },
        onPanUpdate: widget.isReadOnly
            ? null
            : (details) {
                final newPosition = node.position + details.delta;
                widget.onNodeMoved(node, _snapToGrid(newPosition));
              },
        child: FormulaNodeWidget(
          node: node,
          isSelected: selectedNodeId == node.id,
          isConnecting: isConnecting,
          onStartConnection: widget.isReadOnly
              ? null
              : () {
                  setState(() {
                    isConnecting = true;
                    connectingFromNodeId = node.id;
                  });
                },
        ),
      ),
    );
  }

  List<Widget> _buildDropZones() {
    return widget.formula.nodes
        .where((node) => node.id != connectingFromNodeId)
        .map((node) => Positioned(
              left: node.position.dx - 10,
              top: node.position.dy - 10,
              child: Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.link,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
              ),
            ))
        .toList();
  }

  Offset _snapToGrid(Offset position) {
    if (!widget.formula.canvasSettings.snapToGrid) {
      return position;
    }

    final gridSize = widget.formula.canvasSettings.gridSize ?? 20.0;
    return Offset(
      (position.dx / gridSize).round() * gridSize,
      (position.dy / gridSize).round() * gridSize,
    );
  }

  void _showNodeContextMenu(FormulaNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Node Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(context).pop();
                _editNode(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Connect'),
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  isConnecting = true;
                  connectingFromNodeId = node.id;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                widget.onNodeDeleted(node.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editNode(FormulaNode node) {
    showDialog(
      context: context,
      builder: (context) => _buildNodeEditDialog(node),
    );
  }

  Widget _buildNodeEditDialog(FormulaNode node) {
    switch (node.type) {
      case NodeType.value:
        return _ValueEditDialog(
          node: node,
          onSave: (newData) {
            final updatedNode = node.copyWith(data: newData);
            widget.onNodeMoved(updatedNode, node.position);
          },
        );
      case NodeType.operator:
        return _OperatorEditDialog(
          node: node,
          onSave: (newData) {
            final updatedNode = node.copyWith(data: newData);
            widget.onNodeMoved(updatedNode, node.position);
          },
        );
      case NodeType.condition:
        return _ConditionEditDialog(
          node: node,
          onSave: (newData) {
            final updatedNode = node.copyWith(data: newData);
            widget.onNodeMoved(updatedNode, node.position);
          },
        );
      default:
        return AlertDialog(
          title: const Text('Edit Node'),
          content: const Text('This node type cannot be edited.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
    }
  }
}

class GridPainter extends CustomPainter {
  final double gridSize;
  final Color color;

  GridPainter({required this.gridSize, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TemporaryConnection {
  final String fromNodeId;
  final Offset endPoint;

  TemporaryConnection({
    required this.fromNodeId,
    required this.endPoint,
  });
}

// Node edit dialogs
class _ValueEditDialog extends StatefulWidget {
  final FormulaNode node;
  final Function(ValueNodeData) onSave;

  const _ValueEditDialog({required this.node, required this.onSave});

  @override
  State<_ValueEditDialog> createState() => _ValueEditDialogState();
}

class _ValueEditDialogState extends State<_ValueEditDialog> {
  late TextEditingController _valueController;
  late bool _isPercentage;
  late bool _isWeight;

  @override
  void initState() {
    super.initState();
    final data = widget.node.data as ValueNodeData;
    _valueController = TextEditingController(text: data.value.toString());
    _isPercentage = data.isPercentage;
    _isWeight = data.isWeight;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Value'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _valueController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Value',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Percentage'),
            value: _isPercentage,
            onChanged: (value) =>
                setState(() => _isPercentage = value ?? false),
          ),
          CheckboxListTile(
            title: const Text('Weight'),
            value: _isWeight,
            onChanged: (value) => setState(() => _isWeight = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(_valueController.text) ?? 0.0;
            final newData = ValueNodeData(
              value: value,
              displayValue: _valueController.text,
              isPercentage: _isPercentage,
              isWeight: _isWeight,
              color: (widget.node.data as ValueNodeData).color,
            );
            widget.onSave(newData);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }
}

class _OperatorEditDialog extends StatefulWidget {
  final FormulaNode node;
  final Function(OperatorNodeData) onSave;

  const _OperatorEditDialog({required this.node, required this.onSave});

  @override
  State<_OperatorEditDialog> createState() => _OperatorEditDialogState();
}

class _OperatorEditDialogState extends State<_OperatorEditDialog> {
  late String _selectedOperator;

  final List<Map<String, dynamic>> _operators = [
    {'symbol': '+', 'name': 'Addition', 'precedence': 1},
    {'symbol': '-', 'name': 'Subtraction', 'precedence': 1},
    {'symbol': '*', 'name': 'Multiplication', 'precedence': 2},
    {'symbol': '/', 'name': 'Division', 'precedence': 2},
    {'symbol': '^', 'name': 'Power', 'precedence': 3},
    {'symbol': '%', 'name': 'Modulus', 'precedence': 2},
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.node.data as OperatorNodeData;
    _selectedOperator = data.operator;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Operator'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _operators.map((op) {
          return RadioListTile<String>(
            title: Text('${op['symbol']} (${op['name']})'),
            value: op['symbol'],
            groupValue: _selectedOperator,
            onChanged: (value) => setState(() => _selectedOperator = value!),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final selectedOp = _operators.firstWhere(
              (op) => op['symbol'] == _selectedOperator,
            );
            final newData = OperatorNodeData(
              operator: _selectedOperator,
              displaySymbol: _selectedOperator,
              precedence: selectedOp['precedence'],
              color: (widget.node.data as OperatorNodeData).color,
            );
            widget.onSave(newData);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ConditionEditDialog extends StatefulWidget {
  final FormulaNode node;
  final Function(ConditionNodeData) onSave;

  const _ConditionEditDialog({required this.node, required this.onSave});

  @override
  State<_ConditionEditDialog> createState() => _ConditionEditDialogState();
}

class _ConditionEditDialogState extends State<_ConditionEditDialog> {
  late TextEditingController _conditionController;
  late String _conditionType;

  final List<String> _conditionTypes = ['if', 'else_if', 'else'];

  @override
  void initState() {
    super.initState();
    final data = widget.node.data as ConditionNodeData;
    _conditionController =
        TextEditingController(text: data.conditionExpression ?? '');
    _conditionType = data.conditionType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Condition'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _conditionType,
            decoration: const InputDecoration(
              labelText: 'Condition Type',
              border: OutlineInputBorder(),
            ),
            items: _conditionTypes.map((type) {
              return DropdownMenuItem(
                  value: type, child: Text(type.toUpperCase()));
            }).toList(),
            onChanged: (value) => setState(() => _conditionType = value!),
          ),
          const SizedBox(height: 16),
          if (_conditionType != 'else')
            TextField(
              controller: _conditionController,
              decoration: const InputDecoration(
                labelText: 'Condition Expression',
                hintText: 'e.g., uas < 60',
                border: OutlineInputBorder(),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final newData = ConditionNodeData(
              conditionType: _conditionType,
              conditionExpression:
                  _conditionType == 'else' ? null : _conditionController.text,
              displayText: _conditionType == 'else'
                  ? 'ELSE'
                  : '${_conditionType.toUpperCase()} ${_conditionController.text}',
              color: (widget.node.data as ConditionNodeData).color,
            );
            widget.onSave(newData);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _conditionController.dispose();
    super.dispose();
  }
}
