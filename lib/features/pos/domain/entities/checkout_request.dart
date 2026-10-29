import 'package:equatable/equatable.dart';

import 'cart_line.dart';
import 'payment_method.dart';

/// بيانات إتمام البيع القادمة من الواجهة.
class CheckoutRequest extends Equatable {
  const CheckoutRequest({
    required this.lines,
    required this.paymentMethod,
    required this.amountPaid,
    this.discount = 0,
    this.customerName,
  });

  final List<CartLine> lines;
  final PaymentMethod paymentMethod;
  final int discount;
  final int amountPaid;
  final String? customerName;

  int get subtotal => lines.fold(0, (sum, l) => sum + l.lineTotal);

  int get total => subtotal - discount;

  @override
  List<Object?> get props => [lines, paymentMethod, discount, amountPaid, customerName];
}
