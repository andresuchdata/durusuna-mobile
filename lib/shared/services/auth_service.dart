import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../../core/storage/storage_service.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

class AuthService {
  final ApiService _apiService;

  AuthService(this._apiService);

  /// Login user with email and password
  Future<AuthResponse> login(String email, String password) async {
    try {
      final loginRequest = LoginRequest(email: email, password: password);

      final response = await _apiService.post(
        ApiConstants.login,
        data: loginRequest.toJson(),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);

        // Store user data and tokens
        await StorageService.saveUser(authResponse.user.toJson());
        await StorageService.saveToken(authResponse.accessToken);
        await StorageService.saveRefreshToken(authResponse.refreshToken);

        return authResponse;
      } else {
        throw ApiException(
          message: 'Login failed',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Login failed: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Register new user
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserType userType,
    required String schoolId,
    String? phone,
    DateTime? dateOfBirth,
    String? studentId,
    String? employeeId,
  }) async {
    try {
      final registerRequest = RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        userType: userType,
        schoolId: schoolId,
        phone: phone,
        dateOfBirth: dateOfBirth,
        studentId: studentId,
        employeeId: employeeId,
      );

      final response = await _apiService.post(
        ApiConstants.register,
        data: registerRequest.toJson(),
      );

      if (response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(response.data);

        // Store user data and tokens
        await StorageService.saveUser(authResponse.user.toJson());
        await StorageService.saveToken(authResponse.accessToken);
        await StorageService.saveRefreshToken(authResponse.refreshToken);

        return authResponse;
      } else {
        throw ApiException(
          message: 'Registration failed',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Registration failed: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get current user profile
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiService.get(ApiConstants.profile);

      if (response.statusCode == 200) {
        final userData = response.data as Map<String, dynamic>;
        debugPrint('🔄 [AuthService] getCurrentUser data from API: $userData');

        // Filter the data to only include fields present in the User model
        final filteredData = <String, dynamic>{};
        final validFields = [
          'id',
          'first_name',
          'last_name',
          'email',
          'phone',
          'avatar_url',
          'user_type',
          'role',
          'school_id',
          'school',
          'is_active',
          'email_verified',
          'email_verified_at',
          'last_login_at',
          'created_at',
          'updated_at'
        ];
        final fieldMapping = {'last_login_at': 'last_active_at'};

        for (final field in validFields) {
          if (userData.containsKey(field)) {
            try {
              final frontendField = fieldMapping[field] ?? field;
              var value = userData[field];

              // Handle null boolean fields explicitly
              if (field == 'is_active' && value == null) {
                value = false;
              } else if (field == 'email_verified' && value == null) {
                value = false;
              }

              filteredData[frontendField] = value;
            } catch (e) {
              debugPrint('🔄 [AuthService] Error processing field $field: $e');
              rethrow;
            }
          }
        }

        debugPrint(
            '🔄 [AuthService] getCurrentUser filtered data: $filteredData');

        User user;
        try {
          user = User.fromJson(filteredData);
        } catch (e) {
          debugPrint(
              '🔄 [AuthService] Error parsing user data in getCurrentUser: $e');
          rethrow;
        }

        // Update stored user data
        await StorageService.saveUser(user.toJson());

        return user;
      } else {
        throw ApiException(
          message: 'Failed to get user profile',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to get user profile: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Update user profile
  Future<User> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarUrl,
    DateTime? dateOfBirth,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (phone != null) updateData['phone'] = phone;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (dateOfBirth != null) {
        updateData['date_of_birth'] = dateOfBirth.toIso8601String();
      }
      if (preferences != null) updateData['preferences'] = preferences;

      final response = await _apiService.put(
        ApiConstants.updateUserProfile,
        data: updateData,
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'] as Map<String, dynamic>;

        // Filter out fields that aren't in our User model
        final filteredData = <String, dynamic>{};
        final validFields = [
          'id',
          'first_name',
          'last_name',
          'email',
          'phone',
          'avatar_url',
          'user_type',
          'role',
          'school_id',
          'school',
          'is_active',
          'email_verified',
          'email_verified_at',
          'last_login_at',
          'created_at',
          'updated_at'
        ];

        // Map backend field names to frontend field names
        final fieldMapping = {
          'last_login_at': 'last_active_at',
        };

        for (final field in validFields) {
          if (userData.containsKey(field)) {
            try {
              final frontendField = fieldMapping[field] ?? field;
              var value = userData[field];

              // Handle null boolean fields explicitly
              if (field == 'is_active' && value == null) {
                value = false; // Default to false if null
              } else if (field == 'email_verified' && value == null) {
                value = false; // Default to false if null
              }

              filteredData[frontendField] = value;
              debugPrint(
                  '🔄 [AuthService] Processing field: $field -> $frontendField = $value (type: ${value.runtimeType})');
            } catch (e) {
              debugPrint('🔄 [AuthService] Error processing field $field: $e');
              rethrow;
            }
          }
        }

        // Debug: Print the data to see what's causing the type casting error
        debugPrint('🔄 [AuthService] User data from API: $userData');
        debugPrint('🔄 [AuthService] Filtered data: $filteredData');
        debugPrint('🔄 [AuthService] Field mapping: $fieldMapping');

        // Debug specific boolean fields that might be causing issues
        debugPrint(
            '🔄 [AuthService] is_active value: ${userData['is_active']} (type: ${userData['is_active'].runtimeType})');
        debugPrint(
            '🔄 [AuthService] email_verified value: ${userData['email_verified']} (type: ${userData['email_verified'].runtimeType})');

        // Debug all fields to find the problematic one
        for (final entry in userData.entries) {
          if (entry.value != null &&
              entry.value.runtimeType.toString().contains('bool')) {
            debugPrint(
                '🔄 [AuthService] Boolean field: ${entry.key} = ${entry.value} (type: ${entry.value.runtimeType})');
          }
        }

        User user;
        try {
          user = User.fromJson(filteredData);
        } catch (e) {
          debugPrint('🔄 [AuthService] Error parsing user data: $e');
          debugPrint(
              '🔄 [AuthService] User data keys: ${userData.keys.toList()}');
          debugPrint(
              '🔄 [AuthService] Filtered data keys: ${filteredData.keys.toList()}');
          debugPrint('🔄 [AuthService] Filtered data content: $filteredData');
          rethrow;
        }

        // If we updated the avatar but the response doesn't include it,
        // manually update the user object with the new avatar URL
        User finalUser = user;
        if (avatarUrl != null && user.avatarUrl != avatarUrl) {
          debugPrint(
              '🔄 [AuthService] Backend returned null avatar_url, manually updating with: $avatarUrl');
          finalUser = user.copyWith(avatarUrl: avatarUrl);
        }

        // Update stored user data
        await StorageService.saveUser(finalUser.toJson());

        return finalUser;
      } else {
        throw ApiException(
          message: 'Failed to update profile',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to update profile: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Change user password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to change password',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to change password: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Refresh authentication token
  Future<String?> refreshToken() async {
    try {
      final refreshToken = StorageService.getRefreshToken();
      if (refreshToken == null) return null;

      final response = await _apiService.post(
        ApiConstants.refresh,
        data: {
          'refresh_token': refreshToken
        }, // Use snake_case as backend expects
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['accessToken'] as String;
        final newRefreshToken = response.data['refreshToken'] as String;

        // Save both new tokens
        await StorageService.saveToken(newAccessToken);
        await StorageService.saveRefreshToken(newRefreshToken);

        return newAccessToken;
      }
    } catch (e) {
      // Token refresh failed
    }
    return null;
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Call logout endpoint to invalidate server-side session
      await _apiService.post(ApiConstants.logout);
    } catch (e) {
      // Continue with local logout even if server call fails
    } finally {
      // Clear all user data and cached data thoroughly
      await StorageService.clearUserData();
    }
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    final token = StorageService.getToken();
    final user = StorageService.getUser();
    return token != null && user != null;
  }

  /// Get current user from local storage
  User? getCurrentUserFromStorage() {
    final userData = StorageService.getUser();
    if (userData != null) {
      return User.fromJson(userData);
    }
    return null;
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    // At least 8 characters, one uppercase, one lowercase, one digit, one special character
    return RegExp(
            r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
        .hasMatch(password);
  }

  /// Get password strength description
  static String getPasswordStrengthMessage() {
    return 'Password must be at least 8 characters long and contain:\n'
        '• At least one uppercase letter\n'
        '• At least one lowercase letter\n'
        '• At least one number\n'
        '• At least one special character (@\$!%*?&)';
  }
}

// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AuthService(apiService);
});

// Auth state provider
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthStateNotifier(authService);
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(AuthState()) {
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    final user = _authService.getCurrentUserFromStorage();
    final isAuthenticated = _authService.isLoggedIn();

    state = state.copyWith(
      user: user,
      isAuthenticated: isAuthenticated,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authResponse = await _authService.login(email, password);
      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isAuthenticated: false,
      );
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserType userType,
    required String schoolId,
    String? phone,
    DateTime? dateOfBirth,
    String? studentId,
    String? employeeId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authResponse = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        userType: userType,
        schoolId: schoolId,
        phone: phone,
        dateOfBirth: dateOfBirth,
        studentId: studentId,
        employeeId: employeeId,
      );

      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isAuthenticated: false,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authService.logout();
      state = AuthState(); // Reset to initial state
    } catch (e) {
      // Even if logout fails, clear local state
      state = AuthState(error: e.toString());
    }
  }

  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    try {
      final user = await _authService.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      // If refresh fails, user might be logged out
      if (e is ApiException && e.statusCode == 401) {
        state = AuthState();
      }
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Public method to force re-check of auth status from storage
  void checkAuthStatus() {
    _checkAuthStatus();
  }
}
