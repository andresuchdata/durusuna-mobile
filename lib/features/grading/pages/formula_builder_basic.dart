import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Basic Formula Builder Page to demonstrate Riverpod-only state management
class FormulaBuilderBasic extends ConsumerWidget {
  const FormulaBuilderBasic({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formulaNodes = ref.watch(formulaNodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formula Builder (Basic)'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addSampleNode(ref),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => ref.read(formulaNodesProvider.notifier).clear(),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Toolbar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _addComponent(ref, 'UAS'),
                    icon: const Icon(Icons.grade),
                    label: const Text('Add UAS'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addComponent(ref, 'Tugas'),
                    icon: const Icon(Icons.assignment),
                    label: const Text('Add Tugas'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addOperator(ref, '+'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add +'),
                  ),
                  const Spacer(),
                  Text('Nodes: ${formulaNodes.length}'),
                ],
              ),
            ),

            // Canvas
            Expanded(
              child: formulaNodes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.functions, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No formula components yet.\nTap buttons above to add components.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: formulaNodes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final node = entry.value;
                          return _buildNodeWidget(node, index, ref);
                        }).toList(),
                      ),
                    ),
            ),

            // Preview
            if (formulaNodes.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Formula Preview:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formulaNodes.map((n) => n.displayText).join(' '),
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeWidget(SimpleFormulaNode node, int index, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: Chip(
        label: Text(node.displayText),
        backgroundColor: node.color.withValues(alpha: 0.2),
        side: BorderSide(color: node.color),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () =>
            ref.read(formulaNodesProvider.notifier).removeAt(index),
      ),
    );
  }

  void _addSampleNode(WidgetRef ref) {
    ref.read(formulaNodesProvider.notifier).addSample();
  }

  void _addComponent(WidgetRef ref, String name) {
    final color = name == 'UAS' ? Colors.red : Colors.green;
    final node = SimpleFormulaNode(
      displayText: name,
      type: 'component',
      color: color,
    );
    ref.read(formulaNodesProvider.notifier).add(node);
  }

  void _addOperator(WidgetRef ref, String operator) {
    final node = SimpleFormulaNode(
      displayText: operator,
      type: 'operator',
      color: Colors.blue,
    );
    ref.read(formulaNodesProvider.notifier).add(node);
  }
}

// Simple data model
class SimpleFormulaNode {
  final String displayText;
  final String type;
  final Color color;

  SimpleFormulaNode({
    required this.displayText,
    required this.type,
    required this.color,
  });
}

// Simple Riverpod state provider
class FormulaNodesNotifier extends StateNotifier<List<SimpleFormulaNode>> {
  FormulaNodesNotifier() : super([]);

  void add(SimpleFormulaNode node) {
    state = [...state, node];
  }

  void removeAt(int index) {
    final newList = [...state];
    newList.removeAt(index);
    state = newList;
  }

  void clear() {
    state = [];
  }

  void addSample() {
    state = [
      SimpleFormulaNode(
          displayText: '0.3', type: 'value', color: Colors.orange),
      SimpleFormulaNode(displayText: '×', type: 'operator', color: Colors.blue),
      SimpleFormulaNode(
          displayText: 'UAS', type: 'component', color: Colors.red),
      SimpleFormulaNode(displayText: '+', type: 'operator', color: Colors.blue),
      SimpleFormulaNode(
          displayText: '0.7', type: 'value', color: Colors.orange),
      SimpleFormulaNode(displayText: '×', type: 'operator', color: Colors.blue),
      SimpleFormulaNode(
          displayText: 'Tugas', type: 'component', color: Colors.green),
    ];
  }
}

final formulaNodesProvider =
    StateNotifierProvider<FormulaNodesNotifier, List<SimpleFormulaNode>>((ref) {
  return FormulaNodesNotifier();
});
