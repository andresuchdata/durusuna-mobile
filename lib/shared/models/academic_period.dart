class AcademicYear {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  AcademicYear({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory AcademicYear.fromJson(Map<String, dynamic> json) {
    return AcademicYear(
      id: json['id'],
      name: json['name'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
    );
  }
}

class AcademicPeriod {
  final String id;
  final String name;
  final int sequence;
  final DateTime startDate;
  final DateTime endDate;

  AcademicPeriod({
    required this.id,
    required this.name,
    required this.sequence,
    required this.startDate,
    required this.endDate,
  });

  factory AcademicPeriod.fromJson(Map<String, dynamic> json) {
    return AcademicPeriod(
      id: json['id'],
      name: json['name'],
      sequence: json['sequence'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
    );
  }
}

class AcademicPeriodInfo {
  final AcademicYear academicYear;
  final AcademicPeriod currentPeriod;

  AcademicPeriodInfo({
    required this.academicYear,
    required this.currentPeriod,
  });

  factory AcademicPeriodInfo.fromJson(Map<String, dynamic> json) {
    return AcademicPeriodInfo(
      academicYear: AcademicYear.fromJson(json['academic_year']),
      currentPeriod: AcademicPeriod.fromJson(json['current_period']),
    );
  }

  /// Get a formatted display string like "2024-2025 • Semester 1"
  String get displayString => '${academicYear.name} • ${currentPeriod.name}';
}
