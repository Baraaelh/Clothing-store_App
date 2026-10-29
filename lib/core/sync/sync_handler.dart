import 'sync_operation.dart';

/// يرسل نوعًا واحدًا من العمليات للسيرفر.
///
/// - عند النجاح: يحدّث السجل المحلي (مثل حفظ server_id) ثم تُحذف العملية من الطابور.
/// - يرمي `NetworkException` إذا لا يوجد اتصال، و`ServerException` إذا رفض السيرفر.
abstract interface class SyncHandler {
  String get operation;

  Future<void> push(SyncOperation op);

  /// يُستدعى عندما يرفض السيرفر العملية نهائيًا (مثل خطأ 422)، لتعليم السجل المحلي.
  Future<void> onPermanentFailure(SyncOperation op, String error);
}

/// يسحب بيانات من السيرفر ويحدّث النسخة المحلية (المنتجات، الطلبات...).
abstract interface class PullHandler {
  String get name;

  Future<void> pull();
}
