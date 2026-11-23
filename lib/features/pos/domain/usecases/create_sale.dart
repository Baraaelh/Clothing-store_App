import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/checkout_request.dart';
import '../entities/sale.dart';
import '../repositories/pos_repository.dart';

/// قواعد إتمام البيع، ثم الحفظ المحلي.
class CreateSale implements UseCase<Sale, CheckoutRequest> {
  const CreateSale(this._repository);

  final PosRepository _repository;

  @override
  Future<Result<Sale>> call(CheckoutRequest request) {
    final error = validate(request);
    if (error != null) return Future.value(Err(ValidationFailure(error)));
    return _repository.createSale(request);
  }

  static String? validate(CheckoutRequest request) {
    if (request.lines.isEmpty) return 'السلة فارغة';
    for (final line in request.lines) {
      final item = line.item;
      if (line.quantity <= 0) return 'كمية غير صحيحة: ${item.productName}';
      if (line.quantity > item.availableQuantity) {
        return 'الكمية المطلوبة من ${item.productName} (${item.variantLabel}) أكبر من المتوفر (${item.availableQuantity})';
      }
      if (line.unitPrice < 0) return 'سعر غير صحيح: ${item.productName}';
    }
    if (request.discount < 0) return 'الخصم لا يمكن أن يكون سالبًا';
    if (request.discount > request.subtotal) return 'الخصم أكبر من قيمة الفاتورة';
    if (request.mode.needsCustomer && request.customer == null) return 'اختر الزبون للبيع ${request.mode.label}';
    if (request.mode != PaymentMode.credit && request.account == null) return 'اختر حساب القبض';
    if (request.mode == PaymentMode.partial) {
      if (request.paidAmount <= 0) return 'أدخل المبلغ المدفوع الآن';
      if (request.paidAmount >= request.total) return 'المبلغ يغطي الفاتورة كاملة؛ اختر "مدفوع كامل"';
    }
    return null;
  }
}
