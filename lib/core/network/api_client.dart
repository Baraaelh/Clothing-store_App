import 'dart:io';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../config/server_config.dart';
import '../error/exceptions.dart';

typedef TokenProvider = Future<String?> Function();

/// غلاف حول Dio يوحد الأخطاء:
/// - [NetworkException]: لا اتصال / انتهت المهلة.
/// - [UnauthorizedException]: 401.
/// - [ServerException]: أي رد خطأ آخر، مع جسم الرد ورمز الحالة.
/// - [ApiNotConfiguredException]: لا يوجد عنوان سيرفر.
class ApiClient {
  ApiClient({Dio? dio, TokenProvider? tokenProvider, String? baseUrl, ServerConfig? server})
    : _server = server ?? ServerConfig.fixed(baseUrl ?? ApiConfig.baseUrl),
      _dio =
          dio ??
          Dio(
            BaseOptions(
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

  /// العنوان يُقرأ مع كل طلب: قد يغيّره المستخدم من شاشة الدخول.
  final ServerConfig _server;

  Future<Map<String, Object?>> get(
    String endpoint, {
    Map<String, Object> pathParams = const {},
    Map<String, Object?>? query,
  }) => _send(() => _dio.get<Object?>(resolvePath(endpoint, pathParams), queryParameters: query));

  Future<Map<String, Object?>> post(String endpoint, {Map<String, Object> pathParams = const {}, Object? body}) =>
      _send(() => _dio.post<Object?>(resolvePath(endpoint, pathParams), data: body));

  Future<Map<String, Object?>> _send(Future<Response<Object?>> Function() request) async {
    if (!_server.isConfigured) throw const ApiNotConfiguredException();
    _dio.options.baseUrl = _server.url;
    try {
      final data = (await request()).data;
      return data is Map ? data.cast<String, Object?>() : const {};
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// يستبدل `{name}` في المسار بالقيم المعطاة.
  static String resolvePath(String endpoint, Map<String, Object> params) => endpoint.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => Uri.encodeComponent('${params[m.group(1)] ?? (throw ArgumentError('Missing path param ${m.group(1)}'))}'),
  );

  static Exception mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException(e.message ?? 'Connection failed');
      case DioExceptionType.badResponse:
        final response = e.response;
        final body = response?.data is Map ? (response!.data as Map).cast<String, Object?>() : null;
        final message = body?['message'] is String ? body!['message']! as String : 'Server error';
        if (response?.statusCode == 401) return UnauthorizedException(message);
        final retry = int.tryParse(response?.headers.value('retry-after') ?? '');
        return ServerException(
          message,
          statusCode: response?.statusCode,
          body: body,
          retryAfter: retry == null ? null : Duration(seconds: retry),
        );
      case DioExceptionType.unknown:
        if (e.error is SocketException) return NetworkException(e.message ?? 'Socket error');
        return ServerException(e.message ?? 'Unknown error');
      // cancel, badCertificate، وأي نوع تضيفه نسخ Dio القادمة.
      // ignore: no_default_cases
      default:
        return ServerException(e.message ?? e.type.name);
    }
  }
}
