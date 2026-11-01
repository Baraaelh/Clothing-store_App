import 'package:equatable/equatable.dart';

/// أخطاء طبقة الـ domain. الـ UI يتعامل مع هذه فقط، لا مع الاستثناءات.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// خطأ في قاعدة البيانات المحلية.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'تعذر الوصول إلى البيانات المحلية']);
}

/// لا يوجد اتصال، أو السيرفر لم يرد.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'لا يوجد اتصال بالإنترنت']);
}

/// السيرفر رد بخطأ.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// مخالفة لقاعدة عمل (كمية غير متوفرة، سلة فارغة، ...).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// الجلسة انتهت أو التوكن غير صالح.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'انتهت الجلسة، يرجى تسجيل الدخول من جديد']);
}
