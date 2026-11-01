import '../../../../core/session/session.dart';
import '../../../../core/utils/result.dart';

abstract interface class AuthRepository {
  /// يتطلب إنترنت. عند النجاح تُحفظ الجلسة على الجهاز.
  Future<Result<Session>> login({required String username, required String password});

  /// الجلسة المحفوظة من تشغيل سابق (تعمل بدون إنترنت).
  Future<Session?> restoreSession();

  /// ينهي الجلسة على الجهاز. البيانات والعمليات المنتظرة تبقى.
  Future<void> logout();
}
