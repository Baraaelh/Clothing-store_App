import 'dart:io';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../error/exceptions.dart';

typedef TokenProvider = Future<String?> Function();

/// غلاف حول Dio يوحد الأخطاء:
/// - [NetworkException]: لا اتصال / انتهت المهلة.
/// - [ServerException]: السيرفر رد بخطأ.
/// - [ApiNotConfiguredException]: المسار أو العنوان غير مضبوط بعد.
class ApiClient {
  ApiClient({Dio? dio, TokenProvider? tokenProvider, String baseUrl = ApiConfig.baseUrl})
    : _baseUrl = baseUrl,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              headers: {'Accept': 'application/json'},
            ),
          ) {
    if (tokenProvider != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await tokenProvider();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          },
        ),
      );
    }
  }

  final Dio _dio;
  final String _baseUrl;

  Future<Object?> get(String? endpoint, {Map<String, Object> pathParams = const {}, Map<String, Object?>? query}) =>
      _send(endpoint, pathParams, (path) => _dio.get<Object?>(path, queryParameters: query));

  Future<Object?> post(String? endpoint, {Map<String, Object> pathParams = const {}, Object? body}) =>
      _send(endpoint, pathParams, (path) => _dio.post<Object?>(path, data: body));

  Future<Object?> patch(String? endpoint, {Map<String, Object> pathParams = const {}, Object? body}) =>
      _send(endpoint, pathParams, (path) => _dio.patch<Object?>(path, data: body));

  Future<Object?> _send(
    String? endpoint,
    Map<String, Object> pathParams,
    Future<Response<Object?>> Function(String path) request,
  ) async {
    if (_baseUrl.isEmpty || endpoint == null) {
      throw ApiNotConfiguredException(endpoint ?? '(endpoint not set)');
    }
    try {
      final response = await request(resolvePath(endpoint, pathParams));
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// يستبدل `{name}` في المسار بالقيم المعطاة.
  static String resolvePath(String endpoint, Map<String, Object> params) => endpoint.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => Uri.encodeComponent('${params[m.group(1)] ?? (throw ArgumentError('Missing path param ${m.group(1)}'))}'),
  );

  static Exception _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException(e.message ?? 'Connection failed');
      case DioExceptionType.badResponse:
        final response = e.response;
        return ServerException(_extractMessage(response?.data) ?? 'Server error', statusCode: response?.statusCode);
      case DioExceptionType.unknown:
        if (e.error is SocketException) return NetworkException(e.message ?? 'Socket error');
        return ServerException(e.message ?? 'Unknown error');
      // cancel, badCertificate، وأي نوع تضيفه نسخ Dio القادمة.
      // ignore: no_default_cases
      default:
        return ServerException(e.message ?? e.type.name);
    }
  }

  /// Laravel يرجع الأخطاء بالشكل `{ "message": "..." }`.
  static String? _extractMessage(Object? data) {
    if (data is Map && data['message'] is String) return data['message'] as String;
    return null;
  }
}
