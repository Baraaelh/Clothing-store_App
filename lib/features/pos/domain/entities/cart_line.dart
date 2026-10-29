import 'package:equatable/equatable.dart';

import 'catalog_item.dart';

/// سطر في سلة الكاشير.
class CartLine extends Equatable {
  const CartLine({required this.item, required this.quantity, required this.unitPrice});

  factory CartLine.of(CatalogItem item) => CartLine(item: item, quantity: 1, unitPrice: item.sellingPrice);

  final CatalogItem item;
  final int quantity;

  /// سعر البيع الفعلي (قد يعدّله الكاشير ضمن الحد الأدنى).
  final int unitPrice;

  int get lineTotal => unitPrice * quantity;

  CartLine copyWith({int? quantity, int? unitPrice}) =>
      CartLine(item: item, quantity: quantity ?? this.quantity, unitPrice: unitPrice ?? this.unitPrice);

  @override
  List<Object?> get props => [item, quantity, unitPrice];
}
