import 'package:anaqa_mobile/features/pos/domain/entities/cart_line.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/catalog_item.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/checkout_request.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/payment_method.dart';
import 'package:anaqa_mobile/features/pos/domain/usecases/create_sale.dart';
import 'package:flutter_test/flutter_test.dart';

const shirt = CatalogItem(
  variantId: 1,
  productId: 1,
  productCode: 'P1',
  productName: 'قميص',
  sku: 'SKU-1',
  sellingPrice: 2500,
  minimumSellingPrice: 2000,
  availableQuantity: 3,
);

CheckoutRequest request({
  int quantity = 1,
  int unitPrice = 2500,
  int discount = 0,
  int? paid,
  PaymentMethod method = PaymentMethod.cash,
}) => CheckoutRequest(
  lines: [CartLine(item: shirt, quantity: quantity, unitPrice: unitPrice)],
  paymentMethod: method,
  discount: discount,
  amountPaid: paid ?? unitPrice * quantity - discount,
);

void main() {
  test('valid request passes', () => expect(CreateSale.validate(request()), isNull));

  test('rejects empty cart, over-stock, price under minimum, bad discount, underpayment', () {
    expect(
      CreateSale.validate(const CheckoutRequest(lines: [], paymentMethod: PaymentMethod.cash, amountPaid: 0)),
      'السلة فارغة',
    );
    expect(CreateSale.validate(request(quantity: 4)), contains('أكبر من المتوفر'));
    expect(CreateSale.validate(request(unitPrice: 1999)), contains('الحد الأدنى'));
    expect(CreateSale.validate(request(discount: 3000, paid: 0)), 'الخصم أكبر من قيمة الفاتورة');
    expect(CreateSale.validate(request(paid: 2000)), 'المبلغ المدفوع أقل من الإجمالي');
  });

  test('non-cash payments do not require amount paid', () {
    expect(CreateSale.validate(request(method: PaymentMethod.wallet, paid: 0)), isNull);
  });
}
