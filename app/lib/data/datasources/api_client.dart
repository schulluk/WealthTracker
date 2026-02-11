import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import '../../services/secure_storage_service.dart';

/// Exception thrown when authentication fails and user needs to re-login.
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException([this.message = 'Authentication failed']);

  @override
  String toString() => message;
}

/// Exception thrown for API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// API client for making authenticated requests to the backend.
class ApiClient {
  final SecureStorageService _storage;
  late final Dio _dio;
  String? _baseUrl;

  /// Callback to be invoked when authentication fails and user should be logged out.
  VoidCallback? onAuthenticationFailed;

  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Set base URL from storage if not already set
          _baseUrl ??= await _storage.getServerUrl();
          if (_baseUrl != null) {
            options.baseUrl = _baseUrl!;
          }

          // Add auth token if available
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['X-Auth-Token'] = 'Bearer $token';
          }

          // Add KEK header if available (for migrated users)
          final kek = await _storage.getKEK();
          if (kek != null) {
            options.headers['X-KEK'] = kek;
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 by trying to refresh token
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request
              try {
                final token = await _storage.getAccessToken();
                error.requestOptions.headers['X-Auth-Token'] = 'Bearer $token';
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } catch (e) {
                // If retry fails, continue with the error
              }
            }

            // Refresh failed, notify about authentication failure
            onAuthenticationFailed?.call();
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: AuthenticationException(),
              ),
            );
          }

          return handler.next(error);
        },
      ),
    );

    // Add logging in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final baseUrl = await _storage.getServerUrl();
      if (baseUrl == null) return false;

      final response = await Dio().post(
        '$baseUrl${ApiConfig.refreshPath}',
        data: {'refresh': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final accessToken = response.data['access'] as String?;
      final newRefreshToken =
          response.data['refresh'] as String? ?? refreshToken;

      if (accessToken != null) {
        await _storage.setTokens(accessToken, newRefreshToken);
        return true;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }

    return false;
  }

  /// Set the base URL for API requests.
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    await _storage.setServerUrl(url);
  }

  /// Get the configured base URL.
  Future<String?> getBaseUrl() async {
    _baseUrl ??= await _storage.getServerUrl();
    return _baseUrl;
  }

  /// Make a GET request.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a POST request.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Duration? timeout,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        options: timeout != null
            ? Options(
                sendTimeout: timeout,
                receiveTimeout: timeout,
              )
            : null,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a PATCH request.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.patch<T>(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a PUT request.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.put<T>(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Make a DELETE request.
  Future<Response<T>> delete<T>(String path) async {
    try {
      return await _dio.delete<T>(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.error is AuthenticationException) {
      return e.error as AuthenticationException;
    }

    final response = e.response;
    if (response != null) {
      final data = response.data;
      String message = 'Request failed';

      if (data is Map) {
        // Try common error fields
        message = data['error']?.toString() ??
            data['detail']?.toString() ??
            data['message']?.toString() ??
            message;
      }

      return ApiException(message, response.statusCode);
    }

    return ApiException(e.message ?? 'Network error');
  }
}
