import 'package:equatable/equatable.dart';

import '../../../../core/data/reference_data.dart';
import 'cart_line.dart';

/// طريقة السداد كما في السيرفر (`payment_mode`).
enum PaymentMode {
  paid('paid', 'مدفوع كامل'),
  partial('partial', 'دفعة جزئية'),
  credit('credit', 'آجل');

  const PaymentMode(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// الجزئي والآجل يحتاجان زبونًا معرّفًا (قاعدة السيرفر).
  bool get needsCustomer => this != paid;
}

/// بيانات إتمام البيع القادمة من الواجهة.
class CheckoutRequest extends Equatable {
  const CheckoutRequest({
    required this.lines,
    required this.mode,
    this.account,
    this.discount = 0,
    this.paidAmount = 0,
    this.amountReceived = 0,
    this.customer,
    this.notes,
  });

  final List<CartLine> lines;
  final PaymentMode mode;

  /// حساب القبض (الدرج/البنك/المحفظة). مطلوب مع المدفوع والجزئي.
  final PaymentAccount? account;

  /// خصم على الفاتورة كلها (بالأغورة).
  final int discount;

  /// المبلغ المدفوع الآن في الدفعة الجزئية.
  final int paidAmount;

  /// المبلغ الذي سلّمه الزبون نقدًا (لحساب الباقي فقط، لا يُرسل للسيرفر).
  final int amountReceived;
  final Party? customer;
  final String? notes;

  int get subtotal => lines.fold(0, (sum, l) => sum + l.lineTotal);

  int get total => subtotal - discount;

  /// ما يُسجل كمقبوض في الفاتورة.
  int get collected => switch (mode) {
    PaymentMode.paid => total,
    PaymentMode.partial => paidAmount,
    PaymentMode.credit => 0,
  };

  int get change => mode == PaymentMode.paid && amountReceived > total ? amountReceived - total : 0;

  @override
  List<Object?> get props => [lines, mode, account, discount, paidAmount, amountReceived, customer, notes];
}
