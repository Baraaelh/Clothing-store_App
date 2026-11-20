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

/// السيرفر رد بخطأ HTTP. [body] هو رد JSON كما هو (فيه `message` و`errors` عادةً).
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode, this.body, this.retryAfter});

  final String message;
  final int? statusCode;
  final Map<String, Object?>? body;

  /// من ترويسة Retry-After (مع 429/503).
  final Duration? retryAfter;

  /// أخطاء 4xx (غير 408/429) لن تنجح بإعادة المحاولة.
  bool get isPermanent =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500 && statusCode != 408 && statusCode != 429;

  /// أول رسالة تحقق من `errors` إن وُجدت، وإلا `message`.
  String get displayMessage {
    final errors = body?['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty && value.first is String) return value.first as String;
      }
    }
    return message;
  }

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// السيرفر رد بـ 401: التوكن غير صالح أو منتهي. يجب تسجيل الدخول من جديد.
class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Unauthorized']);

  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// عنوان السيرفر غير مضبوط في هذه النسخة.
class ApiNotConfiguredException implements Exception {
  const ApiNotConfiguredException();

  @override
  String toString() => 'ApiNotConfiguredException';
}
