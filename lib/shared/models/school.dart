import 'package:json_annotation/json_annotation.dart';

part 'school.g.dart';

@JsonSerializable()
class School {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  @JsonKey(name: 'logo_url')
  final String? logoUrl;
  final String? description;
  @JsonKey(name: 'is_active')
  final bool? isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  School({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.logoUrl,
    this.description,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory School.fromJson(Map<String, dynamic> json) => _$SchoolFromJson(json);
  Map<String, dynamic> toJson() => _$SchoolToJson(this);

  School copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return School(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is School && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
