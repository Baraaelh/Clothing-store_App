import '../../../../core/session/session.dart';
import '../../../../core/utils/result.dart';

abstract interface class AuthRepository {
  /// يتطلب إنترنت. عند النجاح تُحفظ الجلسة على الجهاز.
  Future<Result<Session>> login({required String username, required String password});

  /// الجلسة المحفوظة من تشغيل سابق (تعمل بدون إنترنت).
  Future<Session?> restoreSession();

  /// تبديل الفرع: يمسح بيانات القراءة للفرع السابق ويبدأ تنزيلًا جديدًا.
  Future<Session> switchBranch(int branchId);

  /// ينهي الجلسة ويمسح بيانات القراءة. العمليات غير المرسلة تبقى على الجهاز.
  Future<void> logout();

  /// السيرفر رفض التوكن (401): ننهي الجلسة محليًا فقط، ونترك البيانات للحساب نفسه عند العودة.
  Future<void> expire();
}
