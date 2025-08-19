// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'formula_builder_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$formulaBuilderServiceHash() =>
    r'6a46d0921034cc7af2b771b69d1909b6528a597c';

/// See also [formulaBuilderService].
@ProviderFor(formulaBuilderService)
final formulaBuilderServiceProvider =
    AutoDisposeProvider<FormulaBuilderService>.internal(
  formulaBuilderService,
  name: r'formulaBuilderServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$formulaBuilderServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FormulaBuilderServiceRef
    = AutoDisposeProviderRef<FormulaBuilderService>;
String _$formulaBuilderHash() => r'054a8e8e5eb160e5f341338f19471aae858c0074';

/// See also [FormulaBuilder].
@ProviderFor(FormulaBuilder)
final formulaBuilderProvider =
    AutoDisposeNotifierProvider<FormulaBuilder, FormulaBuilderState>.internal(
  FormulaBuilder.new,
  name: r'formulaBuilderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$formulaBuilderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FormulaBuilder = AutoDisposeNotifier<FormulaBuilderState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
