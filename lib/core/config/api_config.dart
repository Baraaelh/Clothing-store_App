/// إعدادات الاتصال بالسيرفر (appStore API v1، انظر docs/flutter-api-contract.md في مشروع الباك اند).
///
/// العنوان يُمرر عند التشغيل أو البناء:
/// `flutter run --dart-define=API_BASE_URL=https://store.example.com/api/v1`
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 45);

  /// نسخة العقد التي يفهمها التطبيق. السيرفر يرفض غيرها بـ 422.
  static const int schemaVersion = 1;

  static bool get isConfigured => baseUrl.isNotEmpty;
}

/// مسارات API v1 (نسبية لـ [ApiConfig.baseUrl]).
abstract final class ApiEndpoints {
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const logout = '/auth/logout';
  static const operationState = '/operation-state';
  static const bootstrap = '/sync/bootstrap';
  static const pull = '/sync/pull';
  static const push = '/sync/push';
  static const operation = '/sync/operations/{uuid}';
}
