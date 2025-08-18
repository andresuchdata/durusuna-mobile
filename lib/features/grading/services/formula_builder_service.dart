import '../models/formula_builder_models.dart';
import '../../../shared/services/api_service.dart';

class FormulaBuilderService {
  final ApiService _apiService = ApiService();

  Future<FormulaTemplate?> getFormulaTemplate(String templateId) async {
    try {
      final response =
          await _apiService.get('/formula-builder/templates/$templateId');
      if (response.statusCode == 200) {
        return FormulaTemplate.fromJson(response.data['template']);
      }
      return null;
    } catch (e) {
      print('Error getting formula template: $e');
      return null;
    }
  }

  Future<ComponentLibrary> getComponentLibrary() async {
    try {
      final response =
          await _apiService.get('/formula-builder/components/library');
      if (response.statusCode == 200) {
        return ComponentLibrary.fromJson(response.data);
      }
      return ComponentLibrary.empty();
    } catch (e) {
      print('Error getting component library: $e');
      return ComponentLibrary.empty();
    }
  }

  Future<FormulaPreviewResult?> previewFormula(
      VisualFormulaStructure structure) async {
    try {
      final response =
          await _apiService.post('/formula-builder/preview', data: {
        'visual_structure': structure.toJson(),
      });
      if (response.statusCode == 200) {
        return FormulaPreviewResult.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error previewing formula: $e');
      return null;
    }
  }

  Future<List<ValidationError>> validateFormula(
      VisualFormulaStructure structure) async {
    try {
      final response =
          await _apiService.post('/formula-builder/validate', data: {
        'visual_structure': structure.toJson(),
      });
      if (response.statusCode == 200) {
        final validation = response.data;
        if (validation['validation_errors'] != null) {
          return (validation['validation_errors'] as List)
              .map((error) => ValidationError.fromJson(error))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error validating formula: $e');
      return [];
    }
  }

  Future<bool> saveFormula(VisualFormulaStructure structure) async {
    try {
      final response = await _apiService.post('/grading/formulas', data: {
        'visual_structure': structure.toJson(),
      });
      return response.statusCode == 201;
    } catch (e) {
      print('Error saving formula: $e');
      return false;
    }
  }

  Future<void> exportFormula(VisualFormulaStructure structure) async {
    try {
      await _apiService.post('/formula-builder/convert', data: {
        'visual_structure': structure.toJson(),
        'output_format': 'readable',
      });
    } catch (e) {
      print('Error exporting formula: $e');
    }
  }
}

// Extension classes for the missing types
class ComponentLibrary {
  final List<DraggableItem> assessmentComponents;
  final List<DraggableItem> operators;
  final List<DraggableItem> values;
  final List<DraggableItem> conditions;
  final List<DraggableItem> functions;

  ComponentLibrary({
    required this.assessmentComponents,
    required this.operators,
    required this.values,
    required this.conditions,
    required this.functions,
  });

  factory ComponentLibrary.fromJson(Map<String, dynamic> json) {
    return ComponentLibrary(
      assessmentComponents: (json['assessment_components'] as List?)
              ?.map((item) => DraggableItem.fromJson(item))
              .toList() ??
          [],
      operators: (json['operators'] as List?)
              ?.map((item) => DraggableItem.fromJson(item))
              .toList() ??
          [],
      values: (json['values'] as List?)
              ?.map((item) => DraggableItem.fromJson(item))
              .toList() ??
          [],
      conditions: (json['conditions'] as List?)
              ?.map((item) => DraggableItem.fromJson(item))
              .toList() ??
          [],
      functions: (json['functions'] as List?)
              ?.map((item) => DraggableItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  factory ComponentLibrary.empty() {
    return ComponentLibrary(
      assessmentComponents: [],
      operators: [],
      values: [],
      conditions: [],
      functions: [],
    );
  }
}

class FormulaTemplate {
  final String id;
  final String? schoolId;
  final String name;
  final String? description;
  final VisualFormulaStructure visualStructure;
  final String generatedExpression;
  final ValidationRules validationRules;
  final String category;
  final bool isTemplate;
  final bool isPublic;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  FormulaTemplate({
    required this.id,
    this.schoolId,
    required this.name,
    this.description,
    required this.visualStructure,
    required this.generatedExpression,
    required this.validationRules,
    required this.category,
    required this.isTemplate,
    required this.isPublic,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FormulaTemplate.fromJson(Map<String, dynamic> json) {
    return FormulaTemplate(
      id: json['id'],
      schoolId: json['school_id'],
      name: json['name'],
      description: json['description'],
      visualStructure:
          VisualFormulaStructure.fromJson(json['visual_structure']),
      generatedExpression: json['generated_expression'],
      validationRules: ValidationRules.fromJson(json['validation_rules']),
      category: json['category'],
      isTemplate: json['is_template'],
      isPublic: json['is_public'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class ValidationRules {
  final List<String>? requiredComponents;
  final List<String>? forbiddenComponents;
  final int? maxNodes;
  final int? minNodes;
  final List<String>? allowedOperators;
  final bool? requireFinalExam;
  final double? minWeightSum;
  final double? maxWeightSum;

  ValidationRules({
    this.requiredComponents,
    this.forbiddenComponents,
    this.maxNodes,
    this.minNodes,
    this.allowedOperators,
    this.requireFinalExam,
    this.minWeightSum,
    this.maxWeightSum,
  });

  factory ValidationRules.fromJson(Map<String, dynamic> json) {
    return ValidationRules(
      requiredComponents: json['required_components']?.cast<String>(),
      forbiddenComponents: json['forbidden_components']?.cast<String>(),
      maxNodes: json['max_nodes'],
      minNodes: json['min_nodes'],
      allowedOperators: json['allowed_operators']?.cast<String>(),
      requireFinalExam: json['require_final_exam'],
      minWeightSum: json['min_weight_sum']?.toDouble(),
      maxWeightSum: json['max_weight_sum']?.toDouble(),
    );
  }
}
