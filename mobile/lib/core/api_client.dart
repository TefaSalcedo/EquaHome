import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

/// Dio configurado con base URL, bearer token y refresh transparente en 401.
Dio buildApiClient(TokenStorage storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  dio.interceptors.add(_AuthInterceptor(dio, storage));
  return dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;
  bool _refreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _storage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final retried = err.requestOptions.extra['retried'] == true;
    if (err.response?.statusCode != 401 || retried || _refreshing) {
      return handler.next(err);
    }
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return handler.next(err);

    _refreshing = true;
    try {
      final response = await _dio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      await _storage.save(
        access: response.data['access_token'] as String,
        refresh: response.data['refresh_token'] as String,
      );
    } on DioException {
      await _storage.clear();
      return handler.next(err);
    } finally {
      _refreshing = false;
    }

    final retry = err.requestOptions..extra['retried'] = true;
    retry.headers['Authorization'] =
        'Bearer ${await _storage.readAccessToken()}';
    try {
      handler.resolve(await _dio.fetch(retry));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Mensaje de error legible a partir de un DioException del backend.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final msg = detail.first;
        if (msg is Map && msg['msg'] is String) {
          return (msg['msg'] as String).replaceFirst('Value error, ', '');
        }
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No se pudo conectar con el servidor';
    }
  }
  return 'Algo salió mal. Inténtalo de nuevo.';
}
