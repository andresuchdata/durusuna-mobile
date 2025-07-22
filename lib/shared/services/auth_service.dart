import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../../core/storage/storage_service.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';
import 'realtime_service.dart';

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

        // Store user data and token
        await StorageService.saveUser(authResponse.user.toJson());
        await StorageService.saveToken(authResponse.accessToken);

        // Force reconnect realtime service with fresh token
        print(
            '🔄 AuthService: Login successful, reconnecting realtime service...');
        try {
          await RealtimeService.instance.reconnect();
          print('✅ AuthService: Realtime service reconnected successfully');
        } catch (e) {
          print('⚠️ AuthService: Realtime reconnection failed: $e');
          // Don't fail login if realtime fails
        }

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

        // Store user data and token
        await StorageService.saveUser(authResponse.user.toJson());
        await StorageService.saveToken(authResponse.accessToken);

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
        final userData = response.data['user'] as Map<String, dynamic>;
        final user = User.fromJson(userData);

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
    DateTime? dateOfBirth,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (phone != null) updateData['phone'] = phone;
      if (dateOfBirth != null)
        updateData['date_of_birth'] = dateOfBirth.toIso8601String();
      if (preferences != null) updateData['preferences'] = preferences;

      final response = await _apiService.put(
        ApiConstants.profile,
        data: updateData,
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'] as Map<String, dynamic>;
        final user = User.fromJson(userData);

        // Update stored user data
        await StorageService.saveUser(user.toJson());

        return user;
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
      final refreshToken = StorageService
          .getToken(); // In production, use separate refresh token
      if (refreshToken == null) return null;

      final response = await _apiService.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['accessToken'] as String;
        await StorageService.saveToken(newToken);
        return newToken;
      }
    } catch (e) {
      print('Token refresh failed: $e');
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
      print('Logout API call failed: $e');
    } finally {
      // Disconnect realtime service
      print('🔌 AuthService: Logout - disconnecting realtime service...');
      RealtimeService.instance.disconnect();

      // Clear local storage
      await StorageService.clearUser();
      print('✅ AuthService: Logout completed');
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
}
