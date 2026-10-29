import 'package:equatable/equatable.dart';

import 'payment_method.dart';

enum SaleSyncState { pending, synced, failed }

class SaleItem extends Equatable {
  const SaleItem({
    required this.variantId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    this.colorName,
    this.sizeName,
  });

  final int variantId;
  final String productName;
  final String? colorName;
  final String? sizeName;
  final String sku;
  final int quantity;
  final int unitPrice;

  int get lineTotal => unitPrice * quantity;

  @override
  List<Object?> get props => [variantId, productName, colorName, sizeName, sku, quantity, unitPrice];
}

/// فاتورة بيع محفوظة على الجهاز.
class Sale extends Equatable {
  const Sale({
    required this.id,
    required this.branchId,
    required this.cashierName,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.amountPaid,
    required this.createdAt,
    required this.syncState,
    this.customerName,
    this.serverId,
  });

  /// UUID يُولد على الجهاز، ويُرسل للسيرفر كـ `client_uuid` لمنع تكرار الفاتورة.
  final String id;
  final int? serverId;
  final int branchId;
  final String cashierName;
  final String? customerName;
  final PaymentMethod paymentMethod;
  final List<SaleItem> items;
  final int subtotal;
  final int discount;
  final int total;
  final int amountPaid;
  final DateTime createdAt;
  final SaleSyncState syncState;

  int get change => amountPaid > total ? amountPaid - total : 0;

  @override
  List<Object?> get props => [
    id,
    serverId,
    branchId,
    cashierName,
    customerName,
    paymentMethod,
    items,
    subtotal,
    discount,
    total,
    amountPaid,
    createdAt,
    syncState,
  ];
}
