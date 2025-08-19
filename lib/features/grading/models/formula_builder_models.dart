// Formula Builder Models for Drag-Drop UI

import 'package:flutter/material.dart';

class FormulaNode {
  final String id;
  final NodeType type;
  final Offset position;
  final dynamic data;
  final bool isSelected;
  final bool isValid;

  FormulaNode({
    required this.id,
    required this.type,
    required this.position,
    required this.data,
    this.isSelected = false,
    this.isValid = true,
  });

  FormulaNode copyWith({
    String? id,
    NodeType? type,
    Offset? position,
    dynamic data,
    bool? isSelected,
    bool? isValid,
  }) {
    return FormulaNode(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      data: data ?? this.data,
      isSelected: isSelected ?? this.isSelected,
      isValid: isValid ?? this.isValid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'position': {'x': position.dx, 'y': position.dy},
      'data': _dataToJson(),
    };
  }

  factory FormulaNode.fromJson(Map<String, dynamic> json) {
    final nodeType = NodeType.values.firstWhere(
      (type) => type.name == json['type'],
    );

    return FormulaNode(
      id: json['id'],
      type: nodeType,
      position: Offset(
        json['position']['x'].toDouble(),
        json['position']['y'].toDouble(),
      ),
      data: _dataFromJson(nodeType, json['data']),
    );
  }

  dynamic _dataToJson() {
    switch (type) {
      case NodeType.component:
        return (data as ComponentNodeData).toJson();
      case NodeType.operator:
        return (data as OperatorNodeData).toJson();
      case NodeType.value:
        return (data as ValueNodeData).toJson();
      case NodeType.condition:
        return (data as ConditionNodeData).toJson();
      case NodeType.parenthesis:
        return (data as ParenthesisNodeData).toJson();
    }
  }

  static dynamic _dataFromJson(NodeType type, Map<String, dynamic> json) {
    switch (type) {
      case NodeType.component:
        return ComponentNodeData.fromJson(json);
      case NodeType.operator:
        return OperatorNodeData.fromJson(json);
      case NodeType.value:
        return ValueNodeData.fromJson(json);
      case NodeType.condition:
        return ConditionNodeData.fromJson(json);
      case NodeType.parenthesis:
        return ParenthesisNodeData.fromJson(json);
    }
  }
}

enum NodeType {
  component,
  operator,
  value,
  condition,
  parenthesis,
}

class ComponentNodeData {
  final String componentKey;
  final String displayName;
  final String sourceType;
  final Color color;
  final IconData icon;
  final String? description;

  ComponentNodeData({
    required this.componentKey,
    required this.displayName,
    required this.sourceType,
    required this.color,
    required this.icon,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'component_key': componentKey,
      'display_name': displayName,
      'source_type': sourceType,
      'color': color.value,
      'icon': icon.codePoint,
      'description': description,
    };
  }

  factory ComponentNodeData.fromJson(Map<String, dynamic> json) {
    return ComponentNodeData(
      componentKey: json['component_key'],
      displayName: json['display_name'],
      sourceType: json['source_type'],
      color: Color(json['color']),
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      description: json['description'],
    );
  }
}

class OperatorNodeData {
  final String operator;
  final String displaySymbol;
  final int precedence;
  final Color color;

  OperatorNodeData({
    required this.operator,
    required this.displaySymbol,
    required this.precedence,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'operator': operator,
      'display_symbol': displaySymbol,
      'precedence': precedence,
      'color': color.value,
    };
  }

  factory OperatorNodeData.fromJson(Map<String, dynamic> json) {
    return OperatorNodeData(
      operator: json['operator'],
      displaySymbol: json['display_symbol'],
      precedence: json['precedence'],
      color: Color(json['color']),
    );
  }
}

class ValueNodeData {
  final double value;
  final String displayValue;
  final bool isPercentage;
  final bool isWeight;
  final Color color;

  ValueNodeData({
    required this.value,
    required this.displayValue,
    this.isPercentage = false,
    this.isWeight = false,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'display_value': displayValue,
      'is_percentage': isPercentage,
      'is_weight': isWeight,
      'color': color.value,
    };
  }

  factory ValueNodeData.fromJson(Map<String, dynamic> json) {
    return ValueNodeData(
      value: json['value'].toDouble(),
      displayValue: json['display_value'],
      isPercentage: json['is_percentage'] ?? false,
      isWeight: json['is_weight'] ?? false,
      color: Color(json['color']),
    );
  }
}

class ConditionNodeData {
  final String conditionType;
  final String? conditionExpression;
  final String displayText;
  final Color color;

  ConditionNodeData({
    required this.conditionType,
    this.conditionExpression,
    required this.displayText,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'condition_type': conditionType,
      'condition_expression': conditionExpression,
      'display_text': displayText,
      'color': color.value,
    };
  }

  factory ConditionNodeData.fromJson(Map<String, dynamic> json) {
    return ConditionNodeData(
      conditionType: json['condition_type'],
      conditionExpression: json['condition_expression'],
      displayText: json['display_text'],
      color: Color(json['color']),
    );
  }
}

class ParenthesisNodeData {
  final String parenthesisType;
  final String displaySymbol;
  final String? groupId;
  final Color color;

  ParenthesisNodeData({
    required this.parenthesisType,
    required this.displaySymbol,
    this.groupId,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'parenthesis_type': parenthesisType,
      'display_symbol': displaySymbol,
      'group_id': groupId,
      'color': color.value,
    };
  }

  factory ParenthesisNodeData.fromJson(Map<String, dynamic> json) {
    return ParenthesisNodeData(
      parenthesisType: json['parenthesis_type'],
      displaySymbol: json['display_symbol'],
      groupId: json['group_id'],
      color: Color(json['color']),
    );
  }
}

class FormulaConnection {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final ConnectionType connectionType;
  final ConnectionStyle style;

  FormulaConnection({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.connectionType,
    required this.style,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_node': fromNodeId,
      'to_node': toNodeId,
      'connection_type': connectionType.name,
      'display_style': style.toJson(),
    };
  }

  factory FormulaConnection.fromJson(Map<String, dynamic> json) {
    return FormulaConnection(
      id: json['id'],
      fromNodeId: json['from_node'],
      toNodeId: json['to_node'],
      connectionType: ConnectionType.values.firstWhere(
        (type) => type.name == json['connection_type'],
      ),
      style: ConnectionStyle.fromJson(json['display_style']),
    );
  }
}

enum ConnectionType {
  flow,
  conditionTrue,
  conditionFalse,
}

class ConnectionStyle {
  final Color color;
  final double width;
  final LineStyle lineStyle;
  final String? label;

  ConnectionStyle({
    required this.color,
    this.width = 2.0,
    this.lineStyle = LineStyle.solid,
    this.label,
  });

  Map<String, dynamic> toJson() {
    return {
      'color': color.value,
      'width': width,
      'style': lineStyle.name,
      'label': label,
    };
  }

  factory ConnectionStyle.fromJson(Map<String, dynamic> json) {
    return ConnectionStyle(
      color: Color(json['color']),
      width: json['width']?.toDouble() ?? 2.0,
      lineStyle: LineStyle.values.firstWhere(
        (style) => style.name == json['style'],
        orElse: () => LineStyle.solid,
      ),
      label: json['label'],
    );
  }
}

enum LineStyle {
  solid,
  dashed,
  dotted,
}

class VisualFormulaStructure {
  final List<FormulaNode> nodes;
  final List<FormulaConnection> connections;
  final String? resultNodeId;
  final CanvasSettings canvasSettings;

  VisualFormulaStructure({
    required this.nodes,
    required this.connections,
    this.resultNodeId,
    required this.canvasSettings,
  });

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((node) => node.toJson()).toList(),
      'connections': connections.map((conn) => conn.toJson()).toList(),
      'result_node_id': resultNodeId,
      'canvas_settings': canvasSettings.toJson(),
    };
  }

  factory VisualFormulaStructure.fromJson(Map<String, dynamic> json) {
    return VisualFormulaStructure(
      nodes: (json['nodes'] as List)
          .map((nodeJson) => FormulaNode.fromJson(nodeJson))
          .toList(),
      connections: (json['connections'] as List)
          .map((connJson) => FormulaConnection.fromJson(connJson))
          .toList(),
      resultNodeId: json['result_node_id'],
      canvasSettings: CanvasSettings.fromJson(json['canvas_settings']),
    );
  }

  VisualFormulaStructure copyWith({
    List<FormulaNode>? nodes,
    List<FormulaConnection>? connections,
    String? resultNodeId,
    CanvasSettings? canvasSettings,
  }) {
    return VisualFormulaStructure(
      nodes: nodes ?? this.nodes,
      connections: connections ?? this.connections,
      resultNodeId: resultNodeId ?? this.resultNodeId,
      canvasSettings: canvasSettings ?? this.canvasSettings,
    );
  }
}

class CanvasSettings {
  final Size size;
  final double zoom;
  final double? gridSize;
  final bool snapToGrid;
  final Color backgroundColor;

  CanvasSettings({
    required this.size,
    this.zoom = 1.0,
    this.gridSize,
    this.snapToGrid = true,
    this.backgroundColor = Colors.white,
  });

  Map<String, dynamic> toJson() {
    return {
      'width': size.width,
      'height': size.height,
      'zoom': zoom,
      'grid_size': gridSize,
      'snap_to_grid': snapToGrid,
      'background_color': backgroundColor.value,
    };
  }

  factory CanvasSettings.fromJson(Map<String, dynamic> json) {
    return CanvasSettings(
      size: Size(json['width'].toDouble(), json['height'].toDouble()),
      zoom: json['zoom']?.toDouble() ?? 1.0,
      gridSize: json['grid_size']?.toDouble(),
      snapToGrid: json['snap_to_grid'] ?? true,
      backgroundColor: Color(json['background_color'] ?? Colors.white.value),
    );
  }
}

class DraggableItem {
  final String id;
  final NodeType type;
  final String displayName;
  final IconData icon;
  final Color color;
  final String category;
  final String? description;
  final dynamic defaultData;

  DraggableItem({
    required this.id,
    required this.type,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.category,
    this.description,
    required this.defaultData,
  });

  factory DraggableItem.fromJson(Map<String, dynamic> json) {
    return DraggableItem(
      id: json['id'],
      type: NodeType.values.firstWhere((type) => type.name == json['type']),
      displayName: json['display_name'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      category: json['category'],
      description: json['description'],
      defaultData: json['default_data'],
    );
  }
}

class FormulaBuilderState {
  final VisualFormulaStructure canvas;
  final String? selectedNodeId;
  final bool isDragging;
  final DraggableItem? dragItem;
  final double zoomLevel;
  final bool isPreviewMode;
  final List<ValidationError> validationErrors;
  final FormulaPreviewResult? computedResult;

  FormulaBuilderState({
    required this.canvas,
    this.selectedNodeId,
    this.isDragging = false,
    this.dragItem,
    this.zoomLevel = 1.0,
    this.isPreviewMode = false,
    this.validationErrors = const [],
    this.computedResult,
  });

  FormulaBuilderState copyWith({
    VisualFormulaStructure? canvas,
    String? selectedNodeId,
    bool? isDragging,
    DraggableItem? dragItem,
    double? zoomLevel,
    bool? isPreviewMode,
    List<ValidationError>? validationErrors,
    FormulaPreviewResult? computedResult,
  }) {
    return FormulaBuilderState(
      canvas: canvas ?? this.canvas,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      isDragging: isDragging ?? this.isDragging,
      dragItem: dragItem ?? this.dragItem,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      isPreviewMode: isPreviewMode ?? this.isPreviewMode,
      validationErrors: validationErrors ?? this.validationErrors,
      computedResult: computedResult ?? this.computedResult,
    );
  }
}

class ValidationError {
  final String? nodeId;
  final String? connectionId;
  final ErrorType errorType;
  final String message;
  final ErrorSeverity severity;

  ValidationError({
    this.nodeId,
    this.connectionId,
    required this.errorType,
    required this.message,
    required this.severity,
  });

  factory ValidationError.fromJson(Map<String, dynamic> json) {
    return ValidationError(
      nodeId: json['node_id'],
      connectionId: json['connection_id'],
      errorType: ErrorType.values.firstWhere(
        (type) => type.name == json['error_type'],
      ),
      message: json['message'],
      severity: ErrorSeverity.values.firstWhere(
        (severity) => severity.name == json['severity'],
      ),
    );
  }
}

enum ErrorType {
  missingConnection,
  invalidOperator,
  missingComponent,
  circularDependency,
}

enum ErrorSeverity {
  error,
  warning,
  info,
}

class FormulaPreviewResult {
  final String expression;
  final String sampleCalculation;
  final double estimatedResult;
  final List<ComponentContribution> componentContributions;
  final List<String>? warnings;

  FormulaPreviewResult({
    required this.expression,
    required this.sampleCalculation,
    required this.estimatedResult,
    required this.componentContributions,
    this.warnings,
  });

  factory FormulaPreviewResult.fromJson(Map<String, dynamic> json) {
    return FormulaPreviewResult(
      expression: json['expression'],
      sampleCalculation: json['sample_calculation'],
      estimatedResult: json['estimated_result'].toDouble(),
      componentContributions: (json['component_contributions'] as List)
          .map((contrib) => ComponentContribution.fromJson(contrib))
          .toList(),
      warnings: json['warnings']?.cast<String>(),
    );
  }
}

class ComponentContribution {
  final String componentKey;
  final String displayName;
  final double sampleValue;
  final double weight;
  final double contribution;
  final double percentage;

  ComponentContribution({
    required this.componentKey,
    required this.displayName,
    required this.sampleValue,
    required this.weight,
    required this.contribution,
    required this.percentage,
  });

  factory ComponentContribution.fromJson(Map<String, dynamic> json) {
    return ComponentContribution(
      componentKey: json['component_key'],
      displayName: json['display_name'],
      sampleValue: json['sample_value'].toDouble(),
      weight: json['weight'].toDouble(),
      contribution: json['contribution'].toDouble(),
      percentage: json['percentage'].toDouble(),
    );
  }
}
