/// استثناءات طبقة الـ data. تُحوَّل إلى [Failure] داخل الـ repositories.
class CacheException implements Exception {
  const CacheException(this.message);

  final String message;

  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'No connection']);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// أخطاء 4xx (غير 408/429) لن تنجح بإعادة المحاولة.
  bool get isPermanent =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500 && statusCode != 408 && statusCode != 429;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// الـ API لم يُضبط بعد (لا يوجد baseUrl أو endpoint).
class ApiNotConfiguredException implements Exception {
  const ApiNotConfiguredException(this.endpoint);

  final String endpoint;

  @override
  String toString() => 'ApiNotConfiguredException: $endpoint';
}
