import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/formula_builder_models.dart';
import '../services/formula_builder_service.dart';
import 'dart:math' as math;

part 'formula_builder_provider.g.dart';

// Service provider
@riverpod
FormulaBuilderService formulaBuilderService(FormulaBuilderServiceRef ref) {
  return FormulaBuilderService();
}

// Main state provider using StateNotifier pattern
@riverpod
class FormulaBuilder extends _$FormulaBuilder {
  @override
  FormulaBuilderState build() {
    return FormulaBuilderState(
      canvas: VisualFormulaStructure(
        nodes: [],
        connections: [],
        canvasSettings: CanvasSettings(
          size: const Size(1200, 800),
        ),
      ),
    );
  }

  // Canvas operations
  void addNode(FormulaNode node) {
    state = state.copyWith(
      canvas: state.canvas.copyWith(
        nodes: [...state.canvas.nodes, node],
      ),
      isDirty: true,
    );
  }

  void removeNode(String nodeId) {
    final updatedNodes =
        state.canvas.nodes.where((n) => n.id != nodeId).toList();
    final updatedConnections = state.canvas.connections
        .where((c) => c.fromNodeId != nodeId && c.toNodeId != nodeId)
        .toList();

    state = state.copyWith(
      canvas: state.canvas.copyWith(
        nodes: updatedNodes,
        connections: updatedConnections,
      ),
      isDirty: true,
    );
  }

  void updateNode(String nodeId, FormulaNode updatedNode) {
    final nodeIndex = state.canvas.nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex != -1) {
      final updatedNodes = [...state.canvas.nodes];
      updatedNodes[nodeIndex] = updatedNode;

      state = state.copyWith(
        canvas: state.canvas.copyWith(nodes: updatedNodes),
        isDirty: true,
      );
    }
  }

  void addConnection(FormulaConnection connection) {
    final exists = state.canvas.connections.any((c) =>
        c.fromNodeId == connection.fromNodeId &&
        c.toNodeId == connection.toNodeId);

    if (!exists) {
      state = state.copyWith(
        canvas: state.canvas.copyWith(
          connections: [...state.canvas.connections, connection],
        ),
        isDirty: true,
      );
    }
  }

  void removeConnection(String connectionId) {
    final updatedConnections =
        state.canvas.connections.where((c) => c.id != connectionId).toList();

    state = state.copyWith(
      canvas: state.canvas.copyWith(connections: updatedConnections),
      isDirty: true,
    );
  }

  void updateNodePosition(String nodeId, Offset position) {
    final nodeIndex = state.canvas.nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex != -1) {
      final node = state.canvas.nodes[nodeIndex];
      final updatedNode = node.copyWith(position: position);
      updateNode(nodeId, updatedNode);
    }
  }

  void clearCanvas() {
    state = state.copyWith(
      canvas: VisualFormulaStructure(
        nodes: [],
        connections: [],
        canvasSettings: state.canvas.canvasSettings,
      ),
      isDirty: false,
    );
  }

  void setSelectedNode(String? nodeId) {
    state = state.copyWith(selectedNodeId: nodeId);
  }

  void setHoveredNode(String? nodeId) {
    state = state.copyWith(hoveredNodeId: nodeId);
  }

  void startConnection(String nodeId) {
    state = state.copyWith(
      isConnecting: true,
      connectionStartNodeId: nodeId,
    );
  }

  void endConnection() {
    state = state.copyWith(
      isConnecting: false,
      connectionStartNodeId: null,
    );
  }
}

// Data classes
class FormulaBuilderState {
  final VisualFormulaStructure canvas;
  final bool isDirty;
  final String? selectedNodeId;
  final String? hoveredNodeId;
  final bool isConnecting;
  final String? connectionStartNodeId;

  const FormulaBuilderState({
    required this.canvas,
    this.isDirty = false,
    this.selectedNodeId,
    this.hoveredNodeId,
    this.isConnecting = false,
    this.connectionStartNodeId,
  });

  FormulaBuilderState copyWith({
    VisualFormulaStructure? canvas,
    bool? isDirty,
    String? selectedNodeId,
    String? hoveredNodeId,
    bool? isConnecting,
    String? connectionStartNodeId,
  }) {
    return FormulaBuilderState(
      canvas: canvas ?? this.canvas,
      isDirty: isDirty ?? this.isDirty,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      hoveredNodeId: hoveredNodeId ?? this.hoveredNodeId,
      isConnecting: isConnecting ?? this.isConnecting,
      connectionStartNodeId:
          connectionStartNodeId ?? this.connectionStartNodeId,
    );
  }
}
