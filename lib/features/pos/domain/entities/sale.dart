import 'package:equatable/equatable.dart';

enum SaleStatus {
  /// محفوظة على الجهاز وتنتظر قبول السيرفر.
  pending,

  /// قبلها السيرفر واعتمدها (لها رقم فاتورة).
  accepted,

  /// رفضها السيرفر وتحتاج مراجعة.
  review;

  static SaleStatus fromDb(String value) => values.firstWhere((s) => s.name == value, orElse: () => pending);
}

class SaleItem extends Equatable {
  const SaleItem({
    required this.variantId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    this.variantLabel,
  });

  final int variantId;
  final String productName;
  final String? variantLabel;
  final String sku;
  final int quantity;
  final int unitPrice;

  int get lineTotal => unitPrice * quantity;

  @override
  List<Object?> get props => [variantId, productName, variantLabel, sku, quantity, unitPrice];
}

/// فاتورة بيع أُنشئت على هذا الجهاز.
class Sale extends Equatable {
  const Sale({
    required this.id,
    required this.operationUuid,
    required this.cashierName,
    required this.paymentLabel,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paid,
    required this.createdAt,
    required this.status,
    this.customerName,
    this.number,
    this.change = 0,
  });

  final String id;

  /// عملية المزامنة الحالية لهذه الفاتورة (تتغير فقط عند إعادة إرسال مصححة بعد مراجعة).
  final String operationUuid;
  final String cashierName;
  final String? customerName;
  final String paymentLabel;
  final List<SaleItem> items;
  final int subtotal;
  final int discount;
  final int total;

  /// المقبوض في الفاتورة.
  final int paid;
  final DateTime createdAt;
  final SaleStatus status;

  /// رقم فاتورة السيرفر بعد القبول (مثل SL-0000017).
  final String? number;

  /// الباقي للزبون (للعرض بعد الحفظ فقط).
  final int change;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  @override
  List<Object?> get props => [id, operationUuid, status, number, total, paid, items];
}
