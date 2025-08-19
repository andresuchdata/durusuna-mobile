import 'package:flutter/material.dart';
import '../models/formula_builder_models.dart';
// import '../widgets/formula_canvas.dart'; // Temporarily unused
import '../widgets/formula_node_widget.dart';
import '../providers/formula_builder_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FormulaBuilderPage extends ConsumerStatefulWidget {
  final String? existingFormulaId;
  final String scope;
  final String? scopeRefId;

  const FormulaBuilderPage({
    Key? key,
    this.existingFormulaId,
    required this.scope,
    this.scopeRefId,
  }) : super(key: key);

  @override
  ConsumerState<FormulaBuilderPage> createState() => _FormulaBuilderPageState();
}

class _FormulaBuilderPageState extends ConsumerState<FormulaBuilderPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showComponentLibrary = true;
  // String _selectedCategory = 'components'; // Temporarily unused

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Load existing formula or create new one
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Provider initialization will be implemented
      // final notifier = ref.read(formulaBuilderProvider.notifier);
      if (widget.existingFormulaId != null) {
        // Load existing formula functionality will be implemented
      } else {
        // Create new formula functionality will be implemented
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formula Builder'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Preview button
          IconButton(
            onPressed: _showPreview,
            icon: const Icon(Icons.preview),
            tooltip: 'Preview Formula',
          ),
          // Save button
          IconButton(
            onPressed: _saveFormula,
            icon: const Icon(Icons.save),
            tooltip: 'Save Formula',
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'templates',
                child: ListTile(
                  leading: Icon(Icons.library_books),
                  title: Text('Load Template'),
                ),
              ),
              const PopupMenuItem(
                value: 'validate',
                child: ListTile(
                  leading: Icon(Icons.check_circle),
                  title: Text('Validate Formula'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear Canvas'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Formula'),
                ),
              ),
            ],
          ),
        ],
        bottom: _showComponentLibrary
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(icon: Icon(Icons.widgets), text: 'Components'),
                  Tab(icon: Icon(Icons.calculate), text: 'Operators'),
                  Tab(icon: Icon(Icons.numbers), text: 'Values'),
                  Tab(icon: Icon(Icons.help), text: 'Conditions'),
                ],
              )
            : null,
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final formulaState = ref.watch(formulaBuilderProvider);

          // For now, just show the canvas - we'll add loading states later
          return Row(
            children: [
              // Component Library Panel
              if (_showComponentLibrary)
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border:
                        Border(right: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: _buildComponentLibrary(),
                ),

              // Main Canvas Area
              Expanded(
                child: Column(
                  children: [
                    // Toolbar
                    _buildToolbar(formulaState),

                    // Canvas
                    Expanded(
                      child: _buildCanvas(formulaState),
                    ),

                    // Status Bar
                    _buildStatusBar(formulaState),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showComponentLibrary = !_showComponentLibrary;
          });
        },
        backgroundColor: Colors.teal,
        child: Icon(_showComponentLibrary ? Icons.close : Icons.widgets),
      ),
    );
  }

  Widget _buildComponentLibrary() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search components...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              // Search functionality will be implemented
            },
          ),
        ),

        // Component tabs content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildComponentTab([]),
              _buildOperatorTab([]),
              _buildValueTab([]),
              _buildConditionTab([]),
            ],
          ),
        ),

        // Islamic school quick templates
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Islamic School Templates',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildQuickTemplateChip('Basic Weighted', () {}),
                  _buildQuickTemplateChip('UAS Dominant', () {}),
                  _buildQuickTemplateChip('Best Tests', () {}),
                  _buildQuickTemplateChip('Progressive', () {}),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComponentTab(List<DraggableItem> components) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: components.length,
      itemBuilder: (context, index) {
        final component = components[index];
        return _buildDraggableComponent(component);
      },
    );
  }

  Widget _buildOperatorTab(List<DraggableItem> operators) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: operators.length,
      itemBuilder: (context, index) {
        final operator = operators[index];
        return _buildDraggableOperator(operator);
      },
    );
  }

  Widget _buildValueTab(List<DraggableItem> values) {
    return Column(
      children: [
        // Quick value buttons
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showCustomValueDialog(),
                  child: const Text('Custom Value'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showPercentageDialog(),
                  child: const Text('Percentage'),
                ),
              ),
            ],
          ),
        ),

        // Predefined values
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: values.length,
            itemBuilder: (context, index) {
              final value = values[index];
              return _buildDraggableValue(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConditionTab(List<DraggableItem> conditions) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: conditions.length,
      itemBuilder: (context, index) {
        final condition = conditions[index];
        return _buildDraggableCondition(condition);
      },
    );
  }

  Widget _buildDraggableComponent(DraggableItem component) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Draggable<DraggableItem>(
        data: component,
        feedback: DraggingNodeWidget(item: component),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: _buildComponentCard(component),
        ),
        child: _buildComponentCard(component),
      ),
    );
  }

  Widget _buildComponentCard(DraggableItem component) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: component.color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            component.icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          component.displayName,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          component.description ?? component.category,
          style: const TextStyle(fontSize: 10),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.drag_handle, size: 16),
      ),
    );
  }

  Widget _buildDraggableOperator(DraggableItem operator) {
    return Draggable<DraggableItem>(
      data: operator,
      feedback: DraggingNodeWidget(item: operator),
      child: Container(
        decoration: BoxDecoration(
          color: operator.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              operator.icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              operator.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableValue(DraggableItem value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Draggable<DraggableItem>(
        data: value,
        feedback: DraggingNodeWidget(item: value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: value.color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(value.icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const Icon(Icons.drag_handle, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableCondition(DraggableItem condition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Draggable<DraggableItem>(
        data: condition,
        feedback: DraggingNodeWidget(item: condition),
        child: Card(
          color: condition.color,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(condition.icon, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      condition.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (condition.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    condition.description!,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTemplateChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: Colors.teal.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildToolbar(dynamic state) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Zoom controls
          IconButton(
            onPressed: () {}, // Zoom out functionality
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom Out',
          ),
          const Text('100%'), // Zoom level
          IconButton(
            onPressed: () {}, // Zoom in functionality
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom In',
          ),

          const SizedBox(width: 16),
          const VerticalDivider(),
          const SizedBox(width: 16),

          // Grid toggle
          IconButton(
            onPressed: () {}, // Toggle grid functionality
            icon: const Icon(
              Icons.grid_on,
              color: Colors.grey,
            ),
            tooltip: 'Toggle Grid',
          ),

          // Auto-layout
          IconButton(
            onPressed: () {}, // Auto layout functionality
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Auto Layout',
          ),

          const Spacer(),

          // Formula expression preview
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                'Build your formula...', // Formula expression preview
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Validation status
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildCanvas(dynamic state) {
    return Container(
      color: Colors.white,
      child: DragTarget<DraggableItem>(
        onAcceptWithDetails: (details) {
          // Handle dropping item onto canvas - functionality to be implemented
        },
        builder: (context, candidateData, rejectedData) {
          return const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Center(
                child: Text('Formula Canvas - Under Development'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(dynamic state) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: const Row(
        children: [
          Text(
            'Nodes: 0',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(width: 16),
          Text(
            'Connections: 0',
            style: TextStyle(fontSize: 12),
          ),
          Spacer(),
          Text(
            'Ready',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showPreview() {
    // Preview functionality to be implemented
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preview mode - Under Development')),
    );
  }

  void _saveFormula() async {
    // Save functionality to be implemented
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Save functionality - Under Development'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'templates':
        _showTemplateDialog();
        break;
      case 'validate':
        _showValidationErrors();
        break;
      case 'clear':
        _showClearDialog();
        break;
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Export functionality - Under Development')),
        );
        break;
    }
  }

  void _showTemplateDialog() {
    // Show template selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Template'),
        content: const Text('Template selection dialog will be implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showValidationErrors() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Results'),
        content: const Text('Formula is valid!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Canvas'),
        content: const Text(
            'Are you sure you want to clear all nodes and connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(formulaBuilderProvider.notifier).clearCanvas();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showCustomValueDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomValueDialog(
        onValueCreated: (value) {
          // Custom value functionality to be implemented
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Custom value: $value')),
          );
        },
      ),
    );
  }

  void _showPercentageDialog() {
    showDialog(
      context: context,
      builder: (context) => _PercentageDialog(
        onPercentageCreated: (percentage) {
          // Percentage functionality to be implemented
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Percentage: ${(percentage * 100).toStringAsFixed(1)}%')),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Custom dialogs for value creation
class _CustomValueDialog extends StatefulWidget {
  final Function(double) onValueCreated;

  const _CustomValueDialog({required this.onValueCreated});

  @override
  State<_CustomValueDialog> createState() => _CustomValueDialogState();
}

class _CustomValueDialogState extends State<_CustomValueDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Value'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Enter value',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(_controller.text);
            if (value != null) {
              widget.onValueCreated(value);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PercentageDialog extends StatefulWidget {
  final Function(double) onPercentageCreated;

  const _PercentageDialog({required this.onPercentageCreated});

  @override
  State<_PercentageDialog> createState() => _PercentageDialogState();
}

class _PercentageDialogState extends State<_PercentageDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Percentage Weight'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Enter percentage (0-100)',
          suffixText: '%',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final percentage = double.tryParse(_controller.text);
            if (percentage != null && percentage >= 0 && percentage <= 100) {
              widget.onPercentageCreated(percentage / 100);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
