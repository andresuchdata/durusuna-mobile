import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse {
  final String message;
  final User user;
  @JsonKey(name: 'accessToken')
  final String accessToken;
  @JsonKey(name: 'refreshToken')
  final String refreshToken;
  @JsonKey(name: 'expiresIn')
  final String expiresIn;

  AuthResponse({
    required this.message,
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => 
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  AuthResponse copyWith({
    String? message,
    User? user,
    String? accessToken,
    String? refreshToken,
    String? expiresIn,
  }) {
    return AuthResponse(
      message: message ?? this.message,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn ?? this.expiresIn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthResponse && 
      runtimeType == other.runtimeType && 
      user.id == other.user.id &&
      accessToken == other.accessToken;

  @override
  int get hashCode => user.id.hashCode ^ accessToken.hashCode;

  @override
  String toString() => 'AuthResponse(user: ${user.email}, hasToken: ${accessToken.isNotEmpty})';
}

@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) => 
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class RegisterRequest {
  final String email;
  final String password;
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  @JsonKey(name: 'user_type')
  final UserType userType;
  @JsonKey(name: 'school_id')
  final String schoolId;
  final String? phone;
  @JsonKey(name: 'date_of_birth')
  final DateTime? dateOfBirth;
  @JsonKey(name: 'student_id')
  final String? studentId;
  @JsonKey(name: 'employee_id')
  final String? employeeId;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.userType,
    required this.schoolId,
    this.phone,
    this.dateOfBirth,
    this.studentId,
    this.employeeId,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => 
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
} 