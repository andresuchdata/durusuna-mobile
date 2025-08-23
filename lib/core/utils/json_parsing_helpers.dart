/// JSON parsing utility functions for handling dynamic type conversions
///
/// These helpers safely convert dynamic values from JSON to specific types,
/// handling common cases where backend APIs return numbers as strings.

/// Converts a dynamic value to int, handling strings, doubles, and null values
int intFromDynamic(dynamic value) {
  if (value == null) throw ArgumentError.notNull('value');
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    if (value.isEmpty) {
      throw ArgumentError.value(
          value, 'value', 'Empty string cannot be converted to int');
    }
    // Handle decimal strings by parsing as double first
    return double.parse(value).toInt();
  }
  throw ArgumentError.value(value, 'value', 'Cannot convert to int');
}

/// Converts a dynamic value to int?, handling null values gracefully
int? intFromDynamicNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    if (value.isEmpty) return null;
    // Handle decimal strings by parsing as double first
    return double.parse(value).toInt();
  }
  throw ArgumentError.value(value, 'value', 'Cannot convert to int');
}

/// Converts a dynamic value to double, handling strings, ints, and null values
double doubleFromDynamic(dynamic value) {
  if (value == null) throw ArgumentError.notNull('value');
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    if (value.isEmpty) {
      throw ArgumentError.value(
          value, 'value', 'Empty string cannot be converted to double');
    }
    return double.parse(value);
  }
  throw ArgumentError.value(value, 'value', 'Cannot convert to double');
}

/// Converts a dynamic value to double?, handling null values gracefully
double? doubleFromDynamicNullable(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    if (value.isEmpty) return null;
    return double.parse(value);
  }
  throw ArgumentError.value(value, 'value', 'Cannot convert to double');
}

/// Converts a dynamic value to bool, handling strings and null values
bool boolFromDynamic(dynamic value) {
  if (value == null) throw ArgumentError.notNull('value');
  if (value is bool) return value;
  if (value is String) {
    final lowerValue = value.toLowerCase();
    if (lowerValue == 'true' || lowerValue == '1') return true;
    if (lowerValue == 'false' || lowerValue == '0') return false;
    throw ArgumentError.value(value, 'value', 'Cannot convert string to bool');
  }
  if (value is int) {
    if (value == 1) return true;
    if (value == 0) return false;
    throw ArgumentError.value(value, 'value', 'Cannot convert int to bool');
  }
  throw ArgumentError.value(value, 'value', 'Cannot convert to bool');
}

/// Converts a dynamic value to bool?, handling null values gracefully
bool? boolFromDynamicNullable(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is String) {
    if (value.isEmpty) return null;
    final lowerValue = value.toLowerCase();
    if (lowerValue == 'true' || lowerValue == '1') return true;
    if (lowerValue == 'false' || lowerValue == '0') return false;
    throw ArgumentError.value(value, 'value', 'Cannot convert string to bool');
  }
  if (value is int) {
    if (value == 1) return true;
    if (value == 0) return false;
    throw ArgumentError.value(value, 'value', 'Cannot convert int to bool');
  }
  throw ArgumentError.value(value, 'value', 'Cannot convert to bool');
}
