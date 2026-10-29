/// إعدادات الاتصال بالسيرفر.
///
/// ⚠️ الـ API لم يُحدد بعد. عند استلامه:
///   1. مرر العنوان عند التشغيل: `flutter run --dart-define=API_BASE_URL=https://example.com/api`
///   2. عبّئ المسارات في [ApiEndpoints].
///   3. طابق أسماء الحقول في `fromJson` / `toJson` داخل ملفات `data/models`.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static bool get isConfigured => baseUrl.isNotEmpty;
}

/// مسارات الـ API. القيمة `null` تعني أن المسار غير معروف بعد،
/// وأي طلب عليه يرمي [ApiNotConfiguredException] بدل أن يفشل بصمت.
abstract final class ApiEndpoints {
  // ---- الكاشير ----
  /// GET: منتجات الفرع (variants) مع الكمية المتوفرة.
  static const String? catalog = null; // مثال: '/branches/{branchId}/catalog'

  /// POST: إنشاء فاتورة بيع. يجب أن يقبل `client_uuid` لمنع التكرار.
  static const String? createSale = null; // مثال: '/sales'

  // ---- طلبات الموقع ----
  /// GET: طلبات المتجر الإلكتروني.
  static const String? onlineOrders = null; // مثال: '/online-orders'

  /// POST/PATCH: تغيير حالة طلب (قبول / رفض).
  static const String? updateOnlineOrderStatus = null; // مثال: '/online-orders/{id}/status'
}
