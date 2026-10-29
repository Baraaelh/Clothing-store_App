import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../entities/checkout_request.dart';
import '../entities/payment_method.dart';
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
      final minimum = item.minimumSellingPrice;
      if (minimum != null && line.unitPrice < minimum) {
        return 'سعر ${item.productName} أقل من الحد الأدنى ${Money.format(minimum)}';
      }
    }
    if (request.discount < 0) return 'الخصم لا يمكن أن يكون سالبًا';
    if (request.discount > request.subtotal) return 'الخصم أكبر من قيمة الفاتورة';
    if (request.paymentMethod == PaymentMethod.cash && request.amountPaid < request.total) {
      return 'المبلغ المدفوع أقل من الإجمالي';
    }
    return null;
  }
}
