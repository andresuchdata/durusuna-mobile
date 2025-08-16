import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/storage_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/global_auth_handler.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Request interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add authorization token if available
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) async {
        // Handle unauthorized responses (401)
        if (error.response?.statusCode == 401) {
          debugPrint(
              '🚫 ApiService: 401 Unauthorized detected for ${error.requestOptions.path}');
          // Check if this is already a logout/login request to avoid loops
          final isAuthRequest = error.requestOptions.path.contains('/auth/');

          if (!isAuthRequest && GlobalAuthHandler.isInitialized) {
            final refreshToken = StorageService.getRefreshToken();

            if (refreshToken != null) {
              final accessToken = StorageService.getToken();
              debugPrint(
                  '🔑 ApiService: Found refresh token, attempting refresh');
              debugPrint(
                  '🔑 ApiService: Access token: ${accessToken?.substring(0, 20)}...');
              debugPrint(
                  '🔑 ApiService: Refresh token: ${refreshToken.substring(0, 20)}...');
              debugPrint(
                  '🔑 ApiService: Tokens are same? ${accessToken == refreshToken}');
              try {
                // Attempt to refresh the token
                final refreshResponse = await _refreshToken(refreshToken);
                if (refreshResponse != null) {
                  // Retry the original request with new token
                  final originalRequest = error.requestOptions;
                  originalRequest.headers['Authorization'] =
                      'Bearer ${refreshResponse['accessToken']}';

                  final retryResponse = await _dio.request(
                    originalRequest.path,
                    options: Options(
                      method: originalRequest.method,
                      headers: originalRequest.headers,
                    ),
                    data: originalRequest.data,
                    queryParameters: originalRequest.queryParameters,
                  );

                  return handler.resolve(retryResponse);
                }
              } catch (refreshError) {
                // Refresh failed, logout user
                debugPrint(
                    '🚨 ApiService: Refresh failed with error: $refreshError');

                // Check if refresh token is completely invalid (401 on refresh endpoint)
                if (refreshError is DioException &&
                    refreshError.response?.statusCode == 401) {
                  debugPrint(
                      '🔥 ApiService: Refresh token is invalid (401), forcing immediate logout');
                  try {
                    await GlobalAuthHandler.forceImmediateLogout();
                    debugPrint(
                        '✅ ApiService: Force immediate logout completed');
                  } catch (handlerError) {
                    debugPrint(
                        '❌ ApiService: Force immediate logout failed: $handlerError');
                  }
                } else {
                  debugPrint(
                      '🚨 ApiService: Calling standard tokenRefreshFailed()');
                  debugPrint(
                      '🚨 ApiService: GlobalAuthHandler.isInitialized = ${GlobalAuthHandler.isInitialized}');

                  try {
                    await GlobalAuthHandler.tokenRefreshFailed();
                    debugPrint(
                        '✅ ApiService: GlobalAuthHandler.tokenRefreshFailed() completed successfully');
                  } catch (handlerError) {
                    debugPrint(
                        '❌ ApiService: GlobalAuthHandler.tokenRefreshFailed() failed: $handlerError');
                    // Force fallback logout
                    await _handleLogout();
                  }
                }
                // Return a custom error response to prevent further propagation
                return handler.resolve(Response(
                  requestOptions: error.requestOptions,
                  statusCode: 401,
                  data: {
                    'error': 'Session expired',
                    'message': 'Please log in again'
                  },
                ));
              }
            } else {
              // No refresh token available
              debugPrint('❌ ApiService: No refresh token found, logging out');
              await GlobalAuthHandler.handleUnauthorized(
                customMessage: 'Your session has expired. Please log in again.',
              );
              // Return a custom error response to prevent further propagation
              return handler.resolve(Response(
                requestOptions: error.requestOptions,
                statusCode: 401,
                data: {
                  'error': 'Session expired',
                  'message': 'Please log in again'
                },
              ));
            }
          } else if (!isAuthRequest) {
            // GlobalAuthHandler not initialized - use fallback
            await _handleLogout();
            // Return a custom error response to prevent further propagation
            return handler.resolve(Response(
              requestOptions: error.requestOptions,
              statusCode: 401,
              data: {
                'error': 'Session expired',
                'message': 'Please log in again'
              },
            ));
          }
          // If it's an auth request (login/logout), let it fail normally
        }

        handler.next(error);
      },
    ));

    // Logging interceptor (only in debug mode)
    if (ApiConstants.enableLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
      ));
    }
  }

  Future<Map<String, dynamic>?> _refreshToken(String refreshToken) async {
    try {
      debugPrint('🔄 ApiService: Attempting token refresh');
      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken, // Use snake_case as backend expects
      });

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        // Save both new tokens
        await StorageService.saveToken(data['accessToken']);
        await StorageService.saveRefreshToken(data['refreshToken']);
        debugPrint('✅ ApiService: Token refresh successful');
        return data;
      } else {
        debugPrint(
            '❌ ApiService: Token refresh failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ApiService: Token refresh failed with exception: $e');

      // If it's a 401 on refresh, the refresh token is invalid
      if (e is DioException && e.response?.statusCode == 401) {
        debugPrint(
            '🚨 ApiService: Refresh token is invalid (401), forcing logout');
        // Don't return null, throw to trigger immediate logout
        throw e;
      }

      return null;
    }
  }

  Future<void> _handleLogout() async {
    // Use global auth handler for consistent logout behavior
    if (GlobalAuthHandler.isInitialized) {
      await GlobalAuthHandler.sessionTimeout();
    } else {
      // Fallback if global handler not initialized
      await StorageService.clearUser();
    }
  }

  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Upload file
  Future<Response<T>> uploadFile<T>(
    String path,
    FormData formData, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timeout. Please check your internet connection.',
          statusCode: 0,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = _extractErrorMessage(error.response?.data);
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: error.response?.data,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request was cancelled',
          statusCode: 0,
        );
      case DioExceptionType.unknown:
      default:
        return ApiException(
          message: 'An unexpected error occurred. Please try again.',
          statusCode: 0,
        );
    }
  }

  String _extractErrorMessage(dynamic errorData) {
    if (errorData is Map<String, dynamic>) {
      if (errorData.containsKey('message')) {
        return errorData['message'].toString();
      }
      if (errorData.containsKey('error')) {
        final error = errorData['error'];
        if (error is String) return error;
        if (error is Map && error.containsKey('message')) {
          return error['message'].toString();
        }
      }
    }
    return 'An error occurred';
  }

  // Update FCM token
  Future<void> updateFCMToken(String token) async {
    try {
      final response = await put('/users/fcm-token', data: {
        'fcm_token': token,
      });

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token updated successfully');
      } else {
        throw ApiException(
          message: 'Failed to update FCM token',
          statusCode: response.statusCode ?? 0,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to update FCM token: $e');
      rethrow;
    }
  }

  void dispose() {
    _dio.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    required this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
